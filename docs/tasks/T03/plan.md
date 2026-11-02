# T03: Technical design, Plan

| Field | Value |
|---|---|
| Task | T03 |
| Author | technical-architect (plan and build); solution-architect reviews |
| Date | 2026-11-01 |
| Branch | `task/T03-technical-design` |
| Status | Approved |

Approved by main session on owner's instruction, 2026-11-01.

## Goal

Turn the approved solution architecture (T02, ADR-0001 to ADR-0006) into a buildable design:
Drupal content model, Postgres schema, ingest contract (OpenAPI 3.1), idempotency and outbox,
authentication, environment and secrets matrix, repo and deploy strategy, and the NFR numbers
T03 owns. T05, T09 to T14, T19, T21, T22 and T28 build "per T03" from these documents, so every
field, key, scope and variable must be named exactly. Documentation task: build means writing docs.

## Scope

- `docs/architecture/technical-design.md`: sections D1 to D8 below, with a requirement map.
- `docs/specs/data-model.md`: the field-level tables (Drupal and Postgres), so T09 and T14 have
  one reference. `technical-design.md` links to it instead of repeating it.
- `docs/architecture/openapi.yaml`: OpenAPI 3.1 for `meridian_ingest` plus the JSON:API watchlist
  read the engine uses (documented subset, so T10 contract tests cover both engine calls).
- `docs/TRACEABILITY.md`: "Design element (T03)" filled for R-01 to R-12.
- `docs/architecture/solution-architecture.md`: only the T02 follow-ups (Notes 17, 18): RK-07
  names the revalidation secret; NFR-04 and NFR-05 rows point to the T03 values; OQ-01 and
  OQ-07 resolution column updated. Sign-off table gets a "T03 amendment" line.
- `.env.example` (developer step, outside `docs/`), and a Spectral ruleset at repo root.

## Non-goals

- No code, config export, Alembic migration or module scaffold (T05, T09, T10, T14).
- Rule thresholds (T16), prompt text (T17), page design (T21a to T25).
- Provisioning Postgres, Pantheon or Vercel (T07, T28). No broker anything (ADR-0006).

## Steps

1. **D1 Drupal content model** (`data-model.md`): bundles `decision`, `position`, `daily_run`,
   `price_snapshot` (summary: date, symbol, OHLCV close-only fields needed by the dashboard, not
   full history), `watchlist_item`. Per field: machine name, type, cardinality, required,
   validation (allowed values, ranges, regex for symbol and `external_id`), indexed or not,
   visible-to roles (raw LLM output: administrator only). `external_id` unique per bundle at
   entity level. Entity references between Decision, Position and Daily Run by `external_id`.
2. **D2 Postgres schema and migration plan** (`data-model.md`): tables `runs`, `watchlist_snapshots`,
   `prices`, `decisions`, `positions`, `outbox` (plus `alembic_version`). Columns with types,
   PKs, FKs, unique constraints that make a rerun idempotent (for example `decisions` unique on
   `trade_date, symbol, mode`), indexes for the read paths, the five FR-12 provenance columns
   `NOT NULL`. Migration plan: one baseline Alembic revision in T14, forward-only in dev, each
   revision has a tested downgrade, naming `NNNN_slug`. Postgres 16, no vendor-only features.
3. **D3 Idempotency**: deterministic external ID format per record type (for example
   `dec-{date}-{symbol}-{mode}`), upsert semantics (create, update, unchanged by payload hash,
   stale rejected by `source_version`), and what "same record" means on a rerun of a date.
4. **D4 Outbox and retry**: row lifecycle (pending, sent, dead), one pending row per
   `(record_type, external_id)`, batch size, wake request and backoff (120 s cap per RK-04),
   token refresh on 401, 422 to dead-letter plus alert, `published: partial` rule, drain
   triggers (NFR-15). Sequence diagram in Mermaid.
5. **D5 OpenAPI** (`openapi.yaml`): `POST /api/meridian/v1/ingest` (batch, typed items with
   discriminator, max 500 items, max body size), per-item result list, error schema with field
   paths; 401, 403, 413, 422, 429 responses; `oauth2` clientCredentials security with scope
   names; `GET /jsonapi/node/watchlist_item` subset. Every operation has `operationId`, tags,
   examples. Validate before handing to review (step 11).
6. **D6 Authentication**: OAuth server module (Simple OAuth, version checked in T10), clients
   and scopes (`meridian_ingest`, `meridian_watchlist_read`, `meridian_dashboard_read`), Drupal
   roles final list (FR-16), token lifetimes, user login flow (authorisation code with PKCE,
   confidential server-side client, session cookie flags), revalidation route path and secret,
   key-file storage locally and on Pantheon. Authorisation matrix skeleton (role x endpoint)
   for T09, T10, T11 and T30.
7. **D7 Environment and secrets matrix**: one table, every variable: name, consumer, purpose,
   secret yes or no, value source per environment (DDEV, Pantheon dev, Vercel, GitHub Actions),
   store, introduced by task. Includes the revalidation secret on both sides, Terminus token,
   Pantheon deploy key, Postgres URL, OAuth clients, OAuth keys, Claude key, revalidate interval.
   Rule: Drupal base URL for `meridian-web` is server-only (no `NEXT_PUBLIC_` prefix, FR-21).
8. **D8 Repo and deploy**: Composer root `apps/drupal`, docroot `web`, `config/sync` path, DDEV
   `composer_root`, subtree split and push per ADR-0004, Vercel root `apps/web`, engine image
   from `services/engine`, workflow names. Items ADR-0004 left unverified are listed for T07.
9. **NFR numbers**: NFR-04 (DDEV and Pantheon dev batch size and time), NFR-05, revalidate
   interval (300 s), payload and rate limits for T10. Each number names its source; any
   unmeasured value is marked provisional with the gate that confirms it (see Decisions).
10. **Traceability and T02 follow-ups**: fill the T03 column; apply the edits listed in Scope.
11. **Self-check**: run the tester's YAML structural check (below); record the Spectral command.
12. **Developer step**: update `.env.example` to match D7 exactly (names, placeholders, grouped
    by consumer); add root `.spectral.yaml` (`extends: ["spectral:oas"]`); commit with `T03:`.
13. **Sign-off**: solution-architect reviews; result recorded in `technical-design.md`.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| `docs/architecture/openapi.yaml` | New ingest contract and watchlist read subset | T10, T19, T04 contract tests |
| `docs/specs/data-model.md` | New Drupal and Postgres field spec | T09, T11, T12, T14, T18, T24 |
| `.env.example` | Renamed and added variables (D7) | T13, T19, T21, T22, T28 |
| OAuth scopes and roles | Names fixed | T09 to T11, T22, T30 |
| `solution-architecture.md` | Follow-up edits only, no FR or NFR loosened | All |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| NFR-04 needs a DDEV measurement, but no Drupal exists until T05/T09 | High | Medium | Provisional value plus a measurement gate before T10 coding (Decision 2) |
| OpenAPI cannot be linted with Spectral here (no network) | High | Low | Stdlib-Python structural check now; Spectral run is an owner step recorded in the report |
| Design drifts from Drupal reality (Simple OAuth scopes, unique constraints) | Medium | Medium | Mark module-version facts **unverified**; T09/T10 confirm; T32 ADR explains drift |
| Renaming `NEXT_PUBLIC_DRUPAL_BASE_URL` breaks nothing yet but is a visible change | Low | Low | No consumers exist yet; note in D7 |
| Doc too long to review | Medium | Low | Field tables in `data-model.md`; design doc stays narrative |

## Test hooks needed

- A stdlib plus PyYAML script in `docs/tests/T03/` that checks `openapi.yaml`: parses, `openapi`
  is `3.1.x`, `info`, `paths`, `components` present; every `$ref` resolves; every operation has
  `operationId` (unique), `responses`, `security`; ingest documents 401, 403, 413, 422, 429;
  every scope used is declared; examples carry required properties.
- Owner-run lint: `npx @stoplight/spectral-cli lint docs/architecture/openapi.yaml
  --ruleset .spectral.yaml --fail-severity=warn` (version pinned in T04a), evidence in the report.
- Parity check: variable names in the D7 matrix equal the names in `.env.example`.
- Traceability check: every R row has a non-empty T03 cell; every FR/NFR with a T03-owned
  number cites a section.

## Decisions needed from solution-architect

1. **OQ-01 Postgres vendor.** Recommend Neon Free now (Supabase pauses after 7 days of low
   activity; a holiday week can trigger it), schema stays vendor-neutral, provisioning in T28.
   Confirm, or keep it open until T28.
2. **NFR-04 and NFR-05 final values (OQ-07).** A DDEV measurement is impossible before T09.
   Proposal: keep the T02 values as provisional, add a measurement gate (end of T09, before T10
   coding) that records the final values in `technical-design.md`; Pantheon dev publisher batch
   size set from the Pantheon request time limit, which T03 records with source or marks
   **unverified** for T07. Accept?
3. **User login flow.** Authorisation code with PKCE through a third, confidential OAuth client
   (`meridian-web-login`) separate from the read client. Confirm, or prefer one client with two
   grants.
4. **Edits to the approved T02 document** (RK-07 wording, NFR-04/05 pointers, OQ-01/OQ-07
   resolutions). Allowed as a dated T03 amendment, or put in an ADR?
5. **TASKS.md section 1 `web-next` wording (T02 Note 12).** Fix in T03, or leave to T32?

## Definition of done

- [ ] All T03 acceptance criteria in `docs/TASKS.md` met
- [ ] C1: Plan exists and was reviewed before writing started
- [ ] C2: Solution-architect review recorded; findings resolved
- [ ] C3: Every criterion maps to an executed test case with evidence
- [ ] C4: Structural OpenAPI check passes; markdown and secret checks clean; Spectral run recorded
- [ ] C5: Docs and traceability updated
- [ ] C6: No secrets; `.env.example` matches the D7 matrix
- [ ] C7: Checks run from a clean checkout with documented commands
