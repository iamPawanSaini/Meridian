# T03: Technical design, Test cases

| Field | Value |
|---|---|
| Task | T03 |
| Author | tester |
| Date | 2026-11-01 |
| Criteria source | `docs/TASKS.md` T03 (AC1 to AC9) and section 3.3 (C1 to C7); approved plan `docs/tasks/T03/plan.md` (D1 to D8, test hooks) |

## How to run

- Automated cases: `docs/tests/T03/run-checks.sh 2>&1 | tee docs/tests/T03/evidence/run-checks.txt`.
  Each automated case maps to the block headed `== TC-T03-nn` in the output; copy that block to
  `docs/tests/T03/evidence/TC-T03-nn.txt`. The script exits non-zero if any check fails and prints
  `SKIP` only for optional tools (pre-commit, markdownlint), which the report must list.
- Helpers called by the script (also runnable alone, from the repo root):
  `python3 -I docs/tests/T03/validate_openapi.py [path]` (python3 + PyYAML only),
  `python3 -I docs/tests/T03/check_env_parity.py`, `python3 -I docs/tests/T03/check_data_model.py`
  (path override: env `DM_PATH`), `python3 -I docs/tests/T03/selftest_validator.py`.
- Manual cases (type "Manual" or "Owner-run"): performed at execution; notes and command output go
  in `evidence/TC-T03-nn.txt`.
- Designed from the criteria and plan before the documents existed. The scripts are expected to fail
  until `technical-design.md`, `data-model.md`, `openapi.yaml`, `.spectral.yaml`, the TRACEABILITY
  column and the sign-off exist. No check passes on a missing file. The only checks that pass today
  concern files that already exist (`check-names.sh`, `.env.example` hygiene, the TRACEABILITY
  header, the validator self-test) and guard against regressions.
- Assumed layout (from the plan): `technical-design.md` has `#` headings for D1 to D8, a heading
  with "idempotency", "outbox", an "Environment and secrets matrix" section (Markdown table, first
  column `Name`, columns consumer, purpose, secret yes/no, DDEV, Pantheon, Vercel, GitHub Actions,
  task), and a "Sign-off" section. `data-model.md` has a Drupal region with one subsection per
  bundle (field table with Type, Validation, Indexed columns) and a Postgres region with one
  subsection per table (Column, Type columns). If the author uses another layout, raise a defect
  about the layout and change the scripts only through a recorded change, never to hide a content
  gap.
- The sandbox has no network, so Spectral (`npx`) is an owner-run case (TC-T03-10). Until its output
  is stored, AC3 is Blocked and the report cannot be signed off.

## Acceptance criteria (labels used below)

- AC1: Drupal content model spec: content types (Decision, Position, Daily Run, Price Snapshot
  summary, Watchlist Item), every field with type, validation, indexing
- AC2: Postgres schema spec and migration plan (tables, keys, unique constraints, indexes)
- AC3: engine to Drupal ingest contract as `docs/architecture/openapi.yaml`; passes OpenAPI linting
- AC4: idempotency rule documented (external ID per record, upsert semantics) and outbox/retry
  design for Drupal outages
- AC5: authentication design: engine to Drupal (OAuth client credentials, scope), Next.js to Drupal
  (read scope), user login flow
- AC6: environment and secrets matrix (local DDEV, Pantheon dev, Vercel, GitHub Actions) listing
  every variable
- AC7: repo and deploy strategy decided, including Drupal composer root and how `apps/drupal`
  reaches Pantheon
- AC8: every requirement ID traces to at least one design element in `docs/TRACEABILITY.md`
- AC9: solution-architect sign-off recorded
- C1 to C7: common criteria, `docs/TASKS.md` section 3.3 (C4 limited to `check-names.sh`, markdown,
  secret and OpenAPI checks, since CI arrives in T08)
- PX: plan extras (NFR numbers with source or provisional gate; T02 follow-up edits; revalidation secret)
- SIM: CLAUDE.md simulation-only rule (no broker names or trading domains)

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: five content types, every field typed, validated, indexed | TC-T03-01, 02, 23, 29 |
| AC2: Postgres tables, keys, unique, indexes, migration plan | TC-T03-03, 04, 24, 29 |
| AC3: openapi.yaml exists and lints | TC-T03-07, 08, 09, 10, 29 |
| AC4: idempotency rule, outbox and retry | TC-T03-05, 06, 25 |
| AC5: auth design (client credentials, scopes, read scope, login flow) | TC-T03-11, 12, 13, 26 |
| AC6: env and secrets matrix, four environments, parity with `.env.example` | TC-T03-14, 15, 28 |
| AC7: repo and deploy strategy | TC-T03-16, 27 |
| AC8: every R-ID traces to a design element | TC-T03-18 |
| AC9: solution-architect sign-off | TC-T03-19, 31 |
| C1: plan reviewed before writing | TC-T03-31 |
| C2: reviewed, findings resolved | TC-T03-19, 31 |
| C3: every criterion maps to an executed case with evidence | TC-T03-30 |
| C4: check-names, markdown, secret and OpenAPI checks clean | TC-T03-07, 10, 20, 22 |
| C5: docs, traceability, T02 follow-ups updated | TC-T03-13, 17, 18, 31 |
| C6: no secrets, `.env.example` matches the matrix | TC-T03-14, 15, 22 |
| C7: works from a clean checkout with documented commands; diagrams render | TC-T03-30, 32 |
| PX: NFR numbers owned by T03, T02 follow-ups, revalidation secret | TC-T03-13, 17, 28 |
| SIM: no broker names or trading domains | TC-T03-21 |

Plan test hooks mapped: OpenAPI structural script (07, 08), owner-run Spectral (10), env parity
(14), traceability check (18). Negative coverage: validator mutation self-test (16 seeded defects
plus unparseable and missing file, 08), 401/403/413/422/429 documented (07), stale and changed
records (05, 25), 422 dead-letter and outage paths (06, 25), empty or TBD cells rejected (02, 14,
18), broker-name grep (21).

Automated cases: 01 to 22. Manual or owner-run: 23 to 32. Total 32. Mermaid rendering is
TC-T03-30... see numbering in the case headings below, which is authoritative.

## Cases

Standard steps for automated cases: (1)
`docs/tests/T03/run-checks.sh 2>&1 | tee docs/tests/T03/evidence/run-checks.txt`; (2) copy the
`== TC-T03-nn` block to `evidence/TC-T03-nn.txt`. Standard precondition: T03 documents written and
reviewed, branch `task/T03-technical-design`, run from the repo root with python3 and PyYAML
available.

### TC-T03-01: Technical design has D1 to D8 sections, links and requirement map

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2, AC4, AC5, AC6, AC7 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-01` |
| Expected result | `technical-design.md` and `data-model.md` exist and are non-empty; headings for D1 to D8; links to `data-model.md` and `openapi.yaml`; requirement map names R-04, R-06, R-09. All lines PASS |
| Actual result | 13 PASS |
| Evidence | `evidence/TC-T03-01.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-02: Drupal content model: five bundles, every field has type, validation, indexed

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-02` (runs `check_data_model.py`) |
| Expected result | Subsections for decision, position, daily_run, price_snapshot, watchlist_item, each with a field table that has Type, Validation and Indexed columns, at least 5 fields, and no empty or TBD cell. Each bundle has `external_id` (unique, regex-validated, indexed). Decision has the five FR-12 provenance fields; raw LLM output visible to administrator only; decision and position reference the daily run by `external_id`; symbol is regex-validated; mode is long or short. Sentinel line (exit 0) PASSes. Negative: a field with an empty validation cell makes the check FAIL |
| Actual result | 116 PASS, 0 FAIL (five bundles, all fields typed, validated and indexed; sentinel exit 0) |
| Evidence | `evidence/TC-T03-02.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-03: Postgres schema: tables, PKs, unique constraints, indexes

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-03` |
| Expected result | Subsections for runs, watchlist_snapshots, prices, decisions, positions, outbox, alembic_version, each with a column table (Column, Type), primary key and nullability; every table except alembic_version names at least one index. `decisions` unique on (trade_date, symbol, mode); the five FR-12 columns NOT NULL; decisions and positions have a foreign key to runs; outbox status pending/sent/dead with at most one pending row per (record_type, external_id); prices unique per symbol and date; Postgres 16 and vendor-neutral stated. The `[pg...]` lines printed under TC-T03-02 (from `check_data_model.py`) also PASS. All PASS |
| Actual result | 3 PASS (all seven tables, unique, provenance); the [pg...] lines under 02 also PASS |
| Evidence | `evidence/TC-T03-03.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-04: Migration plan

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-04` |
| Expected result | Migration section exists: baseline Alembic revision in T14, `NNNN_slug` naming, downgrade tested per revision, forward-only in dev. All PASS |
| Actual result | 6 PASS |
| Evidence | `evidence/TC-T03-04.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-05: Idempotency rule (D3)

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-05` |
| Expected result | Idempotency section; deterministic external ID formats (`dec-{date}...`, position and run formats); upsert outcomes create, update, unchanged; payload hash; `source_version` stale rejection; rerun of a date defined; statement that the same payload twice never duplicates. All PASS |
| Actual result | 9 PASS |
| Evidence | `evidence/TC-T03-05.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-06: Outbox and retry design (D4)

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-06` |
| Expected result | Outbox section: pending, sent, dead lifecycle; one pending row per (record_type, external_id); backoff with 120 s cap; wake request; 401 token refresh; 422 dead-letter plus alert; `published: partial`; batch size 500; drain triggers (next run, manual publish, NFR-15); Mermaid sequence diagram with balanced fences. All PASS |
| Actual result | 12 PASS |
| Evidence | `evidence/TC-T03-06.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-07: OpenAPI structural validation

| Field | Value |
|---|---|
| Linked criterion | AC3, C4 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-07` (runs `validate_openapi.py docs/architecture/openapi.yaml`) |
| Expected result | Parses; `openapi` 3.1.x; info.title/version; paths and components; every `$ref` internal and resolving; operationId present and unique; responses, security and tags on every operation; oauth2 clientCredentials with tokenUrl; every scope used is declared (`meridian_ingest`, `meridian_watchlist_read`); `POST /api/meridian/v1/ingest` has a 2xx and 401, 403, 413, 422, 429, requires `meridian_ingest`, has a JSON requestBody with example, batch array `minItems` at least 1 and `maxItems` at least 500, a discriminator, a per-item result list, a 413 description citing the size limit, and an error schema with field paths; `GET /jsonapi/node/watchlist_item` requires `meridian_watchlist_read` and documents 2xx, 401, 403; request examples carry the schema's required properties. Script prints `RESULT: PASS` and exits 0 |
| Actual result | 49 PASS, RESULT: PASS, exit 0 |
| Evidence | `evidence/TC-T03-07.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-08: Validator self-test: seeded defects are rejected

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-08` (runs `selftest_validator.py` against `fixtures/good-openapi.yaml`) |
| Expected result | Good fixture accepted; each of 16 mutations (3.0.3, missing version, dangling and external `$ref`, missing and duplicate operationId, no security, undeclared scope, missing 401/413/429, no 2xx, maxItems 100, no maxItems, wrong flow, example missing a required property) is rejected on the named check; unparseable YAML and a missing file are rejected. Proves the validator is not vacuous. All PASS |
| Actual result | 20 PASS (good fixture accepted, 16 mutations rejected, unparseable and missing file rejected) |
| Evidence | `evidence/TC-T03-08.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-09: Spectral ruleset file present

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-09` |
| Expected result | `.spectral.yaml` at repo root, valid YAML, extends `spectral:oas`, does not disable core rules wholesale; the design doc records the exact lint command. All PASS |
| Actual result | 5 PASS |
| Evidence | `evidence/TC-T03-09.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-10: Spectral lint of openapi.yaml (owner-run)

| Field | Value |
|---|---|
| Linked criterion | AC3, C4 |
| Type | Owner-run |
| Preconditions | Network access to the npm registry; `.spectral.yaml` and `openapi.yaml` present. Record the Spectral version (pinned in T04a if available) |
| Steps | 1. `npx @stoplight/spectral-cli lint docs/architecture/openapi.yaml --ruleset .spectral.yaml --fail-severity=warn 2>&1 | tee docs/tests/T03/evidence/TC-T03-10.txt; echo "exit=${PIPESTATUS[0]}" | tee -a docs/tests/T03/evidence/TC-T03-10.txt` |
| Expected result | Exit 0 with no errors and no warnings; the evidence file shows the tool version (add `npx @stoplight/spectral-cli --version`) and the exit code. Any finding is a defect against the contract and is not suppressed in the ruleset. If the owner has not run it, the case is Blocked and the task is not signed off |
| Actual result | Not run by tester: no network, npx download denied. Owner-run command unchanged. |
| Evidence | `evidence/TC-T03-10.txt` |
| Status | Blocked |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-11: Auth: clients, scopes, tokens, roles, matrix (D6)

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-11` |
| Expected result | Scopes `meridian_ingest`, `meridian_watchlist_read`, `meridian_dashboard_read` present; client credentials grant for the engine; Simple OAuth named with version check deferred to T10; token lifetimes; key-file storage locally and on Pantheon; roles administrator, analyst, engine-ingest, dashboard-read; role x endpoint authorisation matrix; every scope in `openapi.yaml` also appears in the design doc. All PASS |
| Actual result | 11 PASS |
| Evidence | `evidence/TC-T03-11.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-12: User login flow and session

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-12` |
| Expected result | Authorisation code grant with PKCE, a separate confidential server-side client `meridian-web-login`, session cookie flags HttpOnly, Secure, SameSite, redirect or logout behaviour, FR-21 cited. All PASS |
| Actual result | 7 PASS |
| Evidence | `evidence/TC-T03-12.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-13: Revalidation route and secret; T02 RK-07 follow-up

| Field | Value |
|---|---|
| Linked criterion | AC5, PX, C5 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-13` |
| Expected result | Revalidation route path stated; revalidation secret named for Drupal and Next.js; interval 300 s; the RK-07 row in `solution-architecture.md` names the revalidation secret. All PASS |
| Actual result | 4 PASS |
| Evidence | `evidence/TC-T03-13.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-14: Env matrix equals .env.example (both directions)

| Field | Value |
|---|---|
| Linked criterion | AC6, C6 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-14` (runs `check_env_parity.py`) |
| Expected result | Matrix table found with columns consumer, purpose, secret, DDEV, Pantheon, Vercel, GitHub, task; at least 12 variables; no duplicates, no empty cells, secret column yes or no; every `.env.example` name is in the matrix and every matrix name is in `.env.example`; no `NEXT_PUBLIC_` name mentions Drupal; matrix lists revalidation secret and interval, Terminus token, Pantheon deploy key, Postgres URL, Claude key, OAuth ingest and read clients, OAuth key paths; secret-like variables in `.env.example` are blank or placeholders. All PASS. Negative: a name on one side only is reported by name |
| Actual result | 31 PASS (names equal in both directions) |
| Evidence | `evidence/TC-T03-14.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-15: Env matrix covers four environments; .env.example hygiene

| Field | Value |
|---|---|
| Linked criterion | AC6, C6 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-15` |
| Expected result | Matrix section names DDEV, Pantheon, Vercel and GitHub Actions; server-only base URL rule; secret store per secret; `.env.example` grouped by consumer and free of real secret patterns. All PASS |
| Actual result | 9 PASS |
| Evidence | `evidence/TC-T03-15.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-16: Repo and deploy strategy (D8)

| Field | Value |
|---|---|
| Linked criterion | AC7 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-16` |
| Expected result | Composer root `apps/drupal`, docroot `web`, `config/sync`, DDEV `composer_root`, subtree split and push per ADR-0004 via `deploy-drupal.yml`, Terminus token and deploy key, Vercel root `apps/web`, engine image from `services/engine`, workflow names `ci.yml`, `daily-run.yml`, `deploy-drupal.yml`, ADR-0004 unverified items listed for T07. All PASS |
| Actual result | 11 PASS |
| Evidence | `evidence/TC-T03-16.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-17: NFR numbers owned by T03; T02 follow-up edits

| Field | Value |
|---|---|
| Linked criterion | PX, C5 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-17` |
| Expected result | NFR-04 and NFR-05 values in the design; payload size and rate limit numbers for T10; provisional values name a measurement gate before T10; Pantheon request time limit sourced or marked unverified; the NFR-04 and NFR-05 rows and OQ-01 and OQ-07 in `solution-architecture.md` point to the T03 values; its sign-off section has a T03 amendment line. All PASS |
| Actual result | 8 PASS |
| Evidence | `evidence/TC-T03-17.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-18: TRACEABILITY design element (T03) filled for R-01 to R-12

| Field | Value |
|---|---|
| Linked criterion | AC8, C5 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-18` |
| Expected result | Each of R-01 to R-12 has a non-empty Design element (T03) cell that cites a document or D-section (24 PASS lines). Negative: an empty or TBD cell FAILs that row |
| Actual result | 25 PASS (R-01 to R-12) |
| Evidence | `evidence/TC-T03-18.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-19: Solution-architect sign-off recorded; no open markers

| Field | Value |
|---|---|
| Linked criterion | AC9, C2 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-19` |
| Expected result | Sign-off section names solution-architect, has an ISO date and says approved; no TODO, TBD or FIXME in the design docs or `openapi.yaml`; status is not Draft. All PASS |
| Actual result | 6 PASS |
| Evidence | `evidence/TC-T03-19.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-20: check-names.sh passes; current names used

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-20` |
| Expected result | `scripts/check-names.sh` exits 0; design uses `meridian_ingest` and `meridian-web`. All PASS |
| Actual result | 2 PASS |
| Evidence | `evidence/TC-T03-20.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-21: No broker names or trading domains in T03 artefacts

| Field | Value |
|---|---|
| Linked criterion | SIM |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-21` |
| Expected result | All T03 artefacts exist, and a case-insensitive grep for broker names and order-placement terms over them returns nothing; no broker hostnames in the OpenAPI `servers`; the design states simulation-only or cites ADR-0006. All PASS |
| Actual result | 4 PASS |
| Evidence | `evidence/TC-T03-21.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-22: No secrets; links resolve; no external assets

| Field | Value |
|---|---|
| Linked criterion | C4, C6, C7 |
| Type | Automated |
| Preconditions | Standard |
| Steps | Standard steps; block `== TC-T03-22` |
| Expected result | No secret patterns in the docs, `openapi.yaml`, `.env.example`; pre-commit secret scan passes on the T03 files if installed; relative links in the design and data model resolve; no external images or scripts; markdownlint clean if installed (SKIP is recorded in the report, not counted as a pass). All PASS or SKIP |
| Actual result | 3 PASS, 2 SKIP (pre-commit and markdownlint not installed; recorded, not counted as pass) |
| Evidence | `evidence/TC-T03-22.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-23: Content model quality review

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Manual |
| Preconditions | TC-T03-02 passes |
| Steps | 1. Read the Drupal region of `docs/specs/data-model.md` against FR-12, FR-15, FR-17, FR-18, FR-30 in `solution-architecture.md` and the dashboard pages. 2. List every dashboard column, filter and sort and find its field and index. 3. Check each validation is testable (regex, enum or range written out). 4. Check enums match the Postgres types and the OpenAPI schemas. 5. Check price_snapshot stores summary data only and no personal data. Record findings in the evidence file |
| Expected result | Every dashboard column, filter and sort maps to a field; every filter or sort field is indexed; no validation says only valid or as needed; enums agree across Drupal, Postgres and OpenAPI; no gaps, or each gap logged as a defect |
| Actual result | All dashboard columns, filters and sorts map to indexed fields; validations concrete; enums agree across the three documents. Note: prices.source has no named CHECK (suggest ck_prices_source in T14). |
| Evidence | `evidence/manual-review.md` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-24: Postgres schema review against read and rerun paths

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Manual |
| Preconditions | TC-T03-03 passes |
| Steps | 1. For each read path (latest run, decisions by date, open positions, outbox drain, watchlist snapshot) write the SQL and find the index that serves it. 2. Rerun a trading date on paper: name the unique constraint each table uses to absorb the rerun. 3. Check FK delete behaviour and that provenance columns cannot be NULL. 4. Check every type exists in Postgres 16 with no vendor-only extension. Record in the evidence file |
| Expected result | Every read path has a named index; each rerun-affected table has a unique key that turns a rerun into an update or no-op; no vendor-only feature; tables and migration plan agree |
| Actual result | Retest 2026-11-01 after Revision 3: Pass. uq_runs_date_attempt is now a partial unique index WHERE attempt > 0; model in evidence shows repeated publish and replay rows (attempt 0) insert, duplicate attempt greater than 0 and a second running row are rejected. First run on 2026-11-01 was Fail (DEF-002, now Retest passed). |
| Evidence | `evidence/manual-review.md`, `evidence/DEF-002-demo.txt` (original failure), `evidence/DEF-002-retest.txt` |
| Status | Pass |
| Date | 2026-11-01 (retest) |
| Executed by | tester |

### TC-T03-25: Idempotency and outbox scenario walkthrough

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Manual |
| Preconditions | TC-T03-05 and TC-T03-06 pass |
| Steps | 1. Using only the written rules, trace each scenario and record the resulting state of the outbox row and the Drupal entity: (a) same date rerun, identical payload; (b) rerun with changed payload; (c) older `source_version` after newer; (d) Drupal down for 3 consecutive runs, then up; (e) 401 mid-batch; (f) 422 on one item in a 500-item batch; (g) wake slower than 120 s; (h) a second pending row attempted for one external ID; (i) Drupal accepted the batch but the engine lost the response. 2. Record any scenario the document leaves ambiguous |
| Expected result | Each scenario has one unambiguous outcome in the document: no duplicates, no lost records (NFR-15), 422 isolated to its item and dead-lettered with an alert, run marked `published: partial` where specified. Any ambiguity is logged as a defect |
| Actual result | All nine scenarios (a to i) have one unambiguous outcome in D3 and D4; no duplicates or lost records. |
| Evidence | `evidence/manual-review.md` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-26: Authentication design review

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Manual |
| Preconditions | TC-T03-11, 12 and 13 pass |
| Steps | 1. Build the role x endpoint x scope table from the document and test it against least privilege (FR-19, FR-20, NFR-10, NFR-11): dashboard client cannot write, analyst cannot ingest, engine cannot read more than the watchlist. 2. Confirm which client, grant and scope each caller uses (engine ingest, engine watchlist read, Next.js read, user login). 3. Confirm no token, client secret or Drupal URL reaches the browser (FR-21) and that the revalidation call is authenticated. 4. Confirm scope names equal those in `openapi.yaml` |
| Expected result | No write path for read-only clients; each caller has one client and the minimum scope; secrets server-side only; revalidation authenticated by a secret; scope names identical across documents. Gaps logged as defects |
| Actual result | Least privilege holds in the matrix; one client per caller; secrets server-side; revalidation authenticated; scope names identical. |
| Evidence | `evidence/manual-review.md` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-27: Deploy strategy feasibility dry run

| Field | Value |
|---|---|
| Linked criterion | AC7 |
| Type | Manual |
| Preconditions | TC-T03-16 passes; use a scratch clone in the scratchpad, never the working tree |
| Steps | 1. `git clone . $SCRATCH/clone && cd $SCRATCH/clone`. 2. Run the documented subtree split command with a throwaway branch, for example `git subtree split --prefix=apps/drupal -b tmp-split` (if `apps/drupal` has no commits yet, record the git message). 3. Check the documented DDEV `composer_root`, docroot and `config/sync` paths are consistent with each other. 4. Check each ADR-0004 unverified item is ticketed to T07 with an owner |
| Expected result | The documented command is valid for the installed git and leaves the working tree untouched; paths are mutually consistent; every unverified item has an owner and a task. Output stored in the evidence file |
| Actual result | git subtree split --prefix=apps/drupal -b tmp-split in a /tmp clone exited 0; working tree untouched; paths consistent; six unverified items ticketed to T07. |
| Evidence | `evidence/TC-T03-27.txt`, `evidence/manual-review.md` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-28: NFR numbers, sources and recorded decisions

| Field | Value |
|---|---|
| Linked criterion | AC6, PX |
| Type | Manual |
| Preconditions | TC-T03-17 passes |
| Steps | 1. For NFR-04, NFR-05, payload limit, rate limit and revalidate interval, read the cited source or the provisional gate. 2. Check no T02 target was loosened without a recorded reason. 3. Check the five decisions in the plan (OQ-01 vendor, NFR-04/05 gate, login client, T02 amendment, `web-next` wording) each have a recorded outcome |
| Expected result | Each number has a source or a named confirming gate with an owner; no FR or NFR loosened without justification; all five decisions have a recorded outcome |
| Actual result | Every NFR number has a source or a named gate; nothing loosened versus T02; D-1 to D-5 outcomes recorded. |
| Evidence | `evidence/manual-review.md` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-29: Cross-document consistency and buildability

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2, AC3 |
| Type | Manual |
| Preconditions | TC-T03-02, 03, 07 pass |
| Steps | 1. For Decision, Position, Daily Run and Watchlist Item compare field names across the Drupal region, the Postgres region and the OpenAPI schemas (for example `grep -n external_id docs/architecture/openapi.yaml docs/specs/data-model.md`). 2. Compare enum values, regexes and maximum lengths. 3. Read as the T10 and T14 developer and list every place that says or, for example, or leaves a choice where a name or number is needed |
| Expected result | Names, enums, regexes and lengths identical across the three; zero unresolved choices in field names, scopes, paths, limits; each discrepancy logged as a defect |
| Actual result | Item attributes in OpenAPI equal the Drupal fields; patterns and enums match; only documented differences. |
| Evidence | `evidence/cross-doc-fields.txt`, `evidence/manual-review.md` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-30: Clean-checkout run and evidence completeness

| Field | Value |
|---|---|
| Linked criterion | C3, C7 |
| Type | Manual |
| Preconditions | All other cases executed; work committed on `task/T03-technical-design` |
| Steps | 1. `git clone --branch task/T03-technical-design . $SCRATCH/clean && cd $SCRATCH/clean && docs/tests/T03/run-checks.sh 2>&1 | tee $SCRATCH/clean-run.txt`, then copy it to `docs/tests/T03/evidence/TC-T03-30.txt`. 2. `ls docs/tests/T03/evidence/` and tick every case id 01 to 32. 3. Confirm each report row has an Evidence path that exists |
| Expected result | Same results as in the working tree using only documented commands; every case has a stored evidence file; no Pass without evidence |
| Actual result | Deviation: T03 not yet committed, so a clone plus overlay of modified and untracked files was used. run-checks.sh: all PASS, 2 SKIP. Evidence list complete (see report). |
| Evidence | `evidence/TC-T03-30.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester |

### TC-T03-31: Plan, review and sign-off hygiene

| Field | Value |
|---|---|
| Linked criterion | C1, C2, C5, AC9 |
| Type | Manual |
| Preconditions | Review written |
| Steps | 1. `grep -n 'Status' docs/tasks/T03/plan.md` shows Approved. 2. `ls docs/tasks/T03/review.md` exists and every finding is marked resolved. 3. `git log --oneline -- docs/tasks/T03/plan.md docs/architecture/technical-design.md` shows the plan before the design. 4. Check `docs/architecture/README.md`, `docs/specs/README.md` and `docs/adr/README.md` link the new documents and that commits start with `T03:` |
| Expected result | Plan approved before the design was written; review exists with all findings resolved; solution-architect sign-off present; indexes updated; commit prefix correct |
| Actual result | Re-checked after commit 96b4c17 (prefix T03: OK). Plan Approved; review Approved (re-review), findings 1 to 12 Fixed, only Notes 13, 14, 16, 18 not marked Fixed; design revision history rows 1 to 3; indexes link the documents. Deviation: plan, review, design and tests landed in one commit, so git log cannot show plan-before-design; chronology judged from file contents (review C1 row: plan Approved 2026-11-01 before the design was written; design Revisions 1 to 3). |
| Evidence | `evidence/TC-T03-31.txt`, `evidence/manual-review.md` |
| Status | Pass |
| Date | 2026-11-01 (re-check) |
| Executed by | tester |

### TC-T03-32: Mermaid diagrams render

| Field | Value |
|---|---|
| Linked criterion | C7 |
| Type | Manual |
| Preconditions | TC-T03-06 passes |
| Steps | 1. If `mmdc` is installed: extract each mermaid block of `technical-design.md` to a file and run `mmdc -i block.mmd -o $SCRATCH/x.svg`. 2. Otherwise paste each block into a GitHub preview or mermaid.live and record the result |
| Expected result | Every Mermaid block renders without a syntax error; the sequence diagram shows publisher, outbox, Drupal ingest, token refresh and the failure branch |
| Actual result | No mmdc and no network for a preview. Block read by eye (balanced alt, loop, end); render unconfirmed. |
| Evidence | `evidence/manual-review.md` |
| Status | Blocked |
| Date | 2026-11-01 |
| Executed by | tester |

## Change log

| Date | Change | Reason |
|---|---|---|
| 2026-11-01 | `run-checks.sh` TC-T03-17: the NFR-04/05 follow-up check now uses a shell function that counts only table rows whose first cell is NFR-04 or NFR-05 and that cite `technical-design` (exactly 2). | Script defect found by the T03 author: the nested quoting in `bash -c` broke the anchor, so the check matched any line containing NFR-04 or NFR-05 (3 hits, including the OQ-07 row). No content check was loosened; the check is stricter and still requires both rows. |
| 2026-11-01 | `run-checks.sh` TC-T03-09: the ".spectral.yaml does not switch off core rules wholesale" check now uses a shell function (`spectral_rules_on`) instead of an inline `bash -c` string. The rule list and the `off`/`false` test are unchanged; the file must still exist and be non-empty. | Script defect found by the T03 author: a single quote inside the quoted pattern closed the grep argument early, so the check exited with a shell syntax error whatever `.spectral.yaml` contained. No content check was loosened. All other `bash -c` strings were parse-checked with `bash -n -c` (41 of 41 parse); none had the hazard. |
| 2026-11-01 | Added `def002_retest.py` (sqlite model of the partial-index runs constraints). | Retest of DEF-002; not a check change. |
