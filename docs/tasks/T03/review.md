# T03: Technical design, Review

| Field | Value |
|---|---|
| Task | T03 |
| Reviewer | solution-architect (the technical-architect authored the design) |
| Date | 2026-11-01 |
| Commit range | `1b8a031..` working tree (T03 changes on `task/T03-technical-design`, not yet committed) |
| Plan | `docs/tasks/T03/plan.md` |
| Reviewed | `docs/architecture/technical-design.md`, `docs/specs/data-model.md`, `docs/architecture/openapi.yaml`, `docs/TRACEABILITY.md` (T03 column), the T03 amendments in `docs/architecture/solution-architecture.md`, the `docs/TASKS.md` section 1 edit, `docs/tasks/T03/developer-handoff.md`, and ADR-0001 to ADR-0006 for consistency |
| Decisions checked | `docs/tasks/T03/decision-t03-design.md` (D-1 to D-5) |

## Summary

The design is thorough, simulation-only, and mostly buildable as written. D-1 to D-5 were
applied faithfully (see Note 13). I accept most of the author's choices beyond my decisions
(Note 14).

Three Major findings block sign-off. Each one leads to a duplicate record, a record that
leaks, or a record that no longer matches its source:

1. Two ingest requests can run at the same time and create duplicate nodes (Finding 1).
2. Meridian nodes are readable through `access content`, so anonymous users can read them.
   The authorisation matrix's anonymous 401 has nothing behind it (Finding 2).
3. Re-running a date that already succeeded can leave records behind in Postgres and
   Drupal that the rerun no longer produces (Finding 3).

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `technical-design.md` D3, D4, D5; `openapi.yaml` | **Concurrent ingest can create duplicates (FR-24).** The publisher halves the batch and resends at once after a 504 or a client timeout. On Pantheon, PHP keeps running after the 59 s edge cutoff, up to `max_execution_time` 120 s ([Pantheon timeouts](https://docs.pantheon.io/timeouts), checked 2026-11-01). So the first request can still be inside its transaction when the resend arrives. Both see "no stored record" and both create a node. The core `UniqueField` constraint checks first and inserts later, so it does not stop a race. The database unique index is **unverified** (data-model, "Uniqueness"). The design's claim that a resend after a lost response is harmless only holds if the first request has already committed | Serialise ingest. (a) D5: `meridian_ingest` takes the Drupal lock `meridian_ingest` before validation, with a lock timeout of at least 130 s (above the 120 s PHP limit), and releases it at the end of the request. If it cannot get the lock, it returns **409** with error code `ingest_busy` and `Retry-After: 30`. (b) `openapi.yaml`: add the 409 response (Error schema plus the `Retry-After` header) and add `ingest_busy` to the error code enum. (c) D4 response table: on 409, wait `Retry-After` (at most 60 s) and retry the same batch; this counts as an attempt. (d) D1 or D3: state that `meridian_ingest` is the only writer of the four ingested bundles. With writes serialised, the entity-level `UniqueField` check is then race-free, and the database index stays as defence in depth. (e) Test hook for T10: two concurrent requests with the same `external_id` produce one entity, and one request gets 409 | Fixed (Revision 2, verified 2026-11-01) |
| 2 | Major | `technical-design.md` D6 (matrix, roles); `data-model.md` (roles, Visible to) | **No entity-level access control for Meridian nodes (FR-19, FR-20).** Core node view access is `access content`. Drupal install profiles normally grant that permission to anonymous and authenticated users. Field visibility (`hook_entity_field_access`) hides fields, not entities. The scope-to-route allowlist applies only to OAuth tokens. So an anonymous request, or a Drupal user with no Meridian role, can read Decisions and Positions through `/jsonapi/node/decision` or `/node/{nid}`. The matrix says "Anonymous: 401" but names no mechanism. For collections, JSON:API returns 200 with the inaccessible items left out, not 401 | (a) D6 "Roles": the `anonymous` and `authenticated` roles do **not** have `access content` (T09 config). `analyst`, `engine_ingest` and `dashboard_read` get it explicitly. (b) D6: add an "Entity access" paragraph. `meridian_core` implements `hook_node_access()` for the five bundles. Viewing `decision`, `position`, `daily_run` or `price_snapshot` needs `view meridian records`. Viewing `watchlist_item` needs `view meridian watchlist`. Otherwise access is forbidden. Create, update and delete through any route other than `meridian_ingest` (and the T12 admin UI for `watchlist_item` and for unpublishing) are forbidden. (c) D6: a request subscriber in `meridian_core` returns 401 for unauthenticated requests to `/jsonapi/*` and `/api/meridian/*`. The matrix's anonymous cells then follow from it. (d) Matrix: add the row "Authenticated Drupal user without a Meridian role", with 403 on every Meridian route and the dashboard callback rejecting the user (step 4). (e) `data-model.md`: say that "Visible to" applies on top of this entity access rule | Fixed (Revision 2, verified 2026-11-01) |
| 3 | Major | `technical-design.md` D3 "Rerun of a date" | **A record that a rerun no longer produces is left behind (FR-14, FR-24).** D3 says a rerun recomputes, including the LLM review. LLM output varies between calls, the watchlist can change, and a symbol's data fetch can fail on the second attempt. So attempt 2 may not produce a Decision or Position that attempt 1 created and published. Nothing removes it (nodes are never deleted through the API, and Postgres FKs are `ON DELETE RESTRICT`). The result is an orphaned Position whose Decision is now AVOID, plus accounting that no longer reconciles. This is a likely case: a delayed GitHub cron that fires after a successful manual dispatch (RK-05) is exactly such a rerun | Use the simplest rule that removes the case. Replace the "Rerun of a date" paragraph with the following. (a) The run's final Postgres transaction is atomic. An attempt ending `failed` or `skipped` has therefore written no decisions, positions or prices, and the next attempt computes them fresh. (b) If the date already has an attempt with `status = 'success'`, then `daily` and `run` for that date do **not** compute again. They log "already succeeded", drain the outbox as `publish` does, and exit 0. No new attempt is created and the Drupal Daily Run is not changed. (c) Recomputing a successful date is not offered in this phase. `replay --date` (read-only) covers analysis. (d) Remove "An unchanged rerun therefore enqueues only the Daily Run". (e) T20 test hook: a second `daily` for a successful date writes 0 decision, position and outbox rows | Fixed (Revision 2, verified 2026-11-01) |
| 4 | Minor | `technical-design.md` D6 (Revalidation) | "It is the only route exempt from the login middleware" is wrong. `/login`, `/api/auth/login`, `/api/auth/callback` and static assets (`/_next/static/*`, fonts, favicon) must also be exempt, or login loops. The status of `/api/health` (T21) is not decided | List the exempt routes exactly: `/login`, `/api/auth/login`, `/api/auth/callback`, `/api/revalidate` (secret), and static assets. Recommend that `/api/health` requires a session (FR-19), with an unauthenticated variant returning only `{"status":"ok"}` without Drupal details if T28 smoke tests need one. Add each exempt route to the matrix | Fixed (Revision 2, verified 2026-11-01) |
| 5 | Minor | `technical-design.md` D6 (login step 4) | "The callback reads the user's roles" names no endpoint. The allowlist would block `/jsonapi/user/user` for the `meridian_dashboard_user` scope anyway | Name the endpoint. Recommended: `GET /api/meridian/v1/me` in `meridian_core`, which returns `uid`, display name and Meridian roles, with scope `meridian_dashboard_user`. Add it to the "Routes allowed" column and to the matrix. Alternatively use Simple OAuth's userinfo endpoint and add it to the unverified register for T22 | Fixed (Revision 2, verified 2026-11-01) |
| 6 | Minor | `technical-design.md` D6 (scopes, matrix) | The safety of `meridian_dashboard_user` depends on scope permissions being **intersected** with user permissions (marked **unverified**, T22). The design has no fallback if Simple OAuth 6.x grants the scope's permissions regardless of the user's own (a union). In that case an analyst's token could read `raw_llm_output`. The matrix also puts "user token or Drupal session" in one row, but the allowlist treats the two differently (for example, an administrator token on `/jsonapi/user/user` gets 403) | Add a fallback for T22: if Simple OAuth gives a union, `meridian_dashboard_user` grants only `view meridian records` and `view meridian inputs`, and a second scope `meridian_dashboard_admin` (with `view meridian raw llm output`) is requested only when `/me` reports `administrator`. T22 tests that an analyst token cannot read `raw_llm_output`. Split the matrix rows into "user token" and "Drupal session" | Fixed (Revision 2, verified 2026-11-01) |
| 7 | Minor | `technical-design.md` D6 (allowlist); `openapi.yaml` (401, 403) | (a) A path-based allowlist does not stop JSON:API query features. For example, `?include=uid` on `watchlist_item` exposes author display names, and the `fields` and `filter` parameters reach relationships. Path matching is also fragile: trailing slashes, encoding and language prefixes all change the path. (b) On the ingest route, 401 bodies come from Simple OAuth, not from the `Error` schema, unless the module rewrites them. On `/jsonapi/*`, 401 and 403 come from core JSON:API as `application/vnd.api+json` error documents. The contract claims `application/json` with the `Error` schema, so T10 contract tests would fail | (a) Key the allowlist on route name plus HTTP method, deny by default, and for client-credentials tokens also allowlist query parameters: `filter[field_enabled]`, `sort` and `page[*]` for the engine, and the T11 filter, sort and page set for `meridian-web`. Reject `include` on `uid` and `revision_uid`. (b) State that `meridian_ingest` turns authentication and authorisation errors on its own route into the `Error` schema with an exception subscriber. In `openapi.yaml`, document `listWatchlistItems` 401 and 403 as `application/vnd.api+json` JSON:API error documents | Fixed (Revision 2, verified 2026-11-01) |
| 8 | Minor | `data-model.md` (Postgres `decisions`, `positions`); `technical-design.md` D4 | The Postgres checks are weaker than the Drupal validations. Postgres has no check for "vetoed implies AVOID and `pre_llm_action` BUY", "`veto_reason` NULL when not vetoed", stop < entry < target, a short position needing `time_stop_date`, at most 50 `rule_hits`, or the 64 KB and 32 KB field limits. Rows that are valid for the engine can therefore turn into predictable 422 dead letters. D4 also does not say that a 422 lists **every** invalid item, so N bad items could take N round trips | Add the matching `ck_` constraints to `decisions` and `positions` in `data-model.md`. In D4, have the publisher validate each item against `openapi.yaml` before sending: a failure goes to `dead` at once and raises an alert. In D5, say that a 422 reports every failing item in the batch | Fixed (Revision 2, verified 2026-11-01) |
| 9 | Minor | `technical-design.md` D4; `data-model.md` (outbox) | Gaps in outbox behaviour. (a) A 422 whose error path does not name an item (`''`, `invalid_json`, a bad `batch_id`) has no stated handling. (b) It is not stated whether a `skipped` run (holiday) drains the outbox. NFR-15 needs it to. (c) Rows with a future `next_attempt_at` could miss the NFR-15 limit of 30 min after a manual `publish`. (d) "Outbox reaches 0" does not define whether `dead` rows count. (e) When a pending row is updated in place, it is unclear which `run_id` the row then carries, which affects the `published` calculation | (a) A batch-level 422 stops the drain, keeps the rows pending and raises an alert (engine defect). (b) Every `daily` and `run` command drains the outbox, including skipped runs. (c) At the start of a drain, `publish` and the run commands treat every pending row as due (they ignore `next_attempt_at`). The backoff applies only within one drain. (d) NFR-15 counts `pending` rows only. `dead` rows are reported separately in the run-health panel (T29) and alerted. (e) An in-place update sets `run_id` to the enqueuing run | Fixed (Revision 2, verified 2026-11-01) |
| 10 | Minor | `data-model.md` (`runs`); `technical-design.md` D2 | (a) A crashed run leaves its row `running`, and `uq_runs_one_running` then blocks every later run (NFR-06). (b) `command` includes `publish` and `replay`, but it is not stated whether those rows take an `attempt` number, count as the "latest run", or produce a Daily Run | (a) At start, a run marks any `running` row older than the job timeout (30 min, ADR-0002) as `failed` with reason `stale_lock`, then takes the lock. (b) `publish` and `replay` rows use `attempt = 0`, are excluded from `ix_runs_trade_date` reads and Finding 3's "already succeeded" check, and never enqueue a Daily Run | Fixed (Revision 2, verified 2026-11-01) |
| 11 | Minor | `technical-design.md` D8, D7 | Deploy mechanics. (a) The Pantheon site starts from upstream commits that the subtree split does not descend from, so the first non-force push is rejected (unrelated histories). (b) Pantheon SSH keys belong to a **user account**, not to a site; ed25519 keys are not supported, and ECDSA keys are accepted at 256 bits only ([Pantheon SSH keys](https://docs.pantheon.io/ssh-keys), checked 2026-11-01). "Deploy key" suggests a per-site key. (c) The source of the Pantheon Git remote URL and `known_hosts` is not given. (d) `deploy-drupal.yml` has no concurrency group. (e) ADR-0004 says a manual Pantheon commit "would be overwritten", while D8 makes it "fail loudly" | (a) D8: add a one-time, owner-run initial force push (recorded in `docs/runbooks/deploy.md`, T07), with non-force pushes after that. (b) D7: `PANTHEON_DEPLOY_KEY` is an RSA or ECDSA-256 private key whose public key is registered on a dedicated Pantheon user account with access to the site only. Add "machine user on Sandbox" to the unverified register for T07. (c) The workflow reads the Git URL at run time with `terminus connection:info $PANTHEON_SITE.dev --field=git_url` and pins the host key (T07). (d) Add a `concurrency` group to `deploy-drupal.yml`. (e) Record in D8 that fail-loudly tightens ADR-0004 policy and does not change its decision, so no ADR is needed | Fixed (Revision 2, verified 2026-11-01) |
| 12 | Minor | `technical-design.md` D7; `developer-handoff.md` | Environment matrix. (a) The Vercel environment scope is not stated. If secrets are also in the Preview environment, every PR preview (T21) holds Drupal read and login credentials. (b) No minimum strength is set for `MERIDIAN_REVALIDATE_SECRET`. (c) OAuth consumers and their secrets are content entities, not config, so `config/sync` does not create them on Pantheon. Their provisioning per environment is not described. (d) `.env.example` uses `change-me` in `MERIDIAN_DATABASE_URL` but leaves `MERIDIAN_POSTGRES_PASSWORD` blank, while its comment says the two must match | (a) The Vercel column says "Production environment only". Preview deployments run in mock API mode (T21) with no Drupal secrets. (b) Require at least 32 random bytes, like `MERIDIAN_SESSION_SECRET`. (c) D6 and D7 note that T10 provides a documented drush command that creates the three consumers per environment and prints each secret once. The owner copies the secret into GitHub Secrets or Vercel. (d) Use the same placeholder in both, for example `change-me-local`, or leave both blank. Fix this in the handoff before the developer applies it | Fixed (Revision 2, verified 2026-11-01) |
| 13 | Note | `decision-t03-design.md`, all deliverables | My decisions were applied faithfully. D-1: Neon, `sslmode=require`, connect retry, `pg_dump` backups, pooled or direct connection **unverified** for T28. D-2: provisional values, gate MG-1, 30 s Pantheon budget, batch 100, halving, 500 contract maximum. D-3: three consumers, PKCE S256, refresh tokens, exact redirect URIs, cookie flags, unverified items carried over. D-4: an Amendments table with five rows. Each one is a pointer or resolution, none changes an accepted ADR, and none loosens an FR or NFR beyond D-2. D-5: `docs/TASKS.md` section 1 now reads `meridian-engine`, `meridian-postgres` and `meridian-web`, and a search finds no `web-next` in `docs/` | None | |
| 14 | Note | `technical-design.md` | Author choices I accept: whole-batch validation with 422 and no partial write, then dead-letter and resend (atomic and simple, once Finding 8 makes it converge in one round trip); 8 MB body limit, 4 MB publisher target, 60 requests per minute, 45 s client timeout (under the 59 s edge), batch 500 on DDEV and 100 on Pantheon with halving; Decision not referencing Position (no reference cycle, and Views can use the reverse relationship); the fourth scope `meridian_dashboard_user` (a user token needs its own scope, subject to Finding 6); the scope-to-route allowlist (simplest least-privilege layer, hardened by Findings 2 and 7); `POST /api/revalidate` with a 300 s fallback (ADR-0001); tokens 300 s, refresh and session 8 h; and the unverified register. Suggestion: once halved, the batch size stays halved for the rest of that drain | None | |
| 15 | Note | `openapi.yaml` | The 200 example has `received: 2` and two results, but the request example has four items. Correct schema, inconsistent example. `tokenUrl` names only the DDEV host. A 413 from the Pantheon edge may not be JSON, so the publisher must branch on the status code alone | Optional tidy-up | Fixed (Revision 2): `received: 4`; `tokenUrl` host explained; 413 note added |
| 16 | Note | `technical-design.md` D6, D7 | If OQ-08 (Vercel Deployment Protection) is applied to the production deployment, the engine's call to `/api/revalidate` would be blocked. T22 must keep that route reachable (bypass) or apply protection to previews only | For T22 | None |
| 17 | Note | `technical-design.md` D3; `data-model.md` | Drupal and the engine each compute `payload_hash`, and the design only ever compares hashes made by the same system. The data model, however, reads as if they are equal across systems. The wording should say they need not match, or specify RFC 8785 (JSON Canonicalization Scheme, JCS) if T27 reconciliation will compare them | Optional wording | Fixed (Revision 2): RFC 8785 (JCS) on both sides, and only same-system comparisons drive runtime decisions |
| 18 | Note | `docs/tests/T03/test-cases.md` | AC3 ("passes OpenAPI linting") still needs the owner-run Spectral evidence (TC-T03-10). Design sign-off does not waive it. Finding 1(b) changes `openapi.yaml`, so run the lint after that fix | Tester step | None |
| 19 | Note | `solution-architecture.md` | RK-10 and the cost map still say "chosen in T03 or T28". The OQ-01 resolution and the container table are the authority, so this is acceptable. A pointer could be added in the same amendment | Optional | Fixed (Revision 2): pointer added as amendment row 6. It stays within the D-4 conditions |

## Checks requested by the main session

First-round results. After the re-review, every gap named below is closed (see "Re-review
2026-11-01"). AC1, AC2 and AC4 to AC8 are met, AC9 is met by this sign-off, and AC3 awaits
the Spectral evidence.

| Check | Result |
|---|---|
| Every T03 criterion met | AC1, AC2, AC5, AC6, AC7 and AC8 are met in substance, with the gaps in Findings 2 and 4 to 12. AC4 is not met until Findings 1 and 3 are fixed. AC3 is pending Spectral (Note 18). AC9 is pending this review |
| Idempotency and outbox (NFR-15) | Deterministic IDs, upsert table, ordering (backward references, in-place pending update keeps `outbox_id`), retries, dead-letter and requeue are sound. A duplicate is possible under concurrency (Finding 1). Rerun orphans (Finding 3). Edge cases in Findings 9 and 10 |
| Auth least privilege (T10: engine cannot read users, delete or reach admin) | It holds for OAuth tokens through the allowlist. It does not hold for anonymous users and users without a Meridian role (Finding 2). Query-parameter leaks in Finding 7 |
| Environment matrix complete; no secret reaches the browser | All four environments are covered. No `NEXT_PUBLIC_` variable names Drupal or a secret. Gaps in Findings 11 and 12 |
| Deploy consistent with ADR-0004 | Yes: subtree split, push, Terminus wake, drush. The first push and the policy wording need fixes (Finding 11) |
| Simulation only | Yes. No broker host, scope, credential or order capability appears anywhere (ADR-0006) |
| Claims cited or marked unverified | Yes for Pantheon timeouts, Simple OAuth, Neon and the body limit. Add the Pantheon SSH-key facts (Finding 11) and the scope-intersection fallback (Finding 6) |

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | `plan.md` Approved 2026-11-01 before the design was written |
| C2 Review findings resolved | Yes (re-review) | First round: Findings 1 to 12 open. Re-review 2026-11-01: all fixed in Revision 2. Remaining items are Notes only |
| C3 Criteria mapped to executed tests | Pending | Tester step: `test-cases.md` maps every criterion, and execution follows the fixes |
| C4 CI green | Pending | Structural OpenAPI check and Spectral run (TC-T03-07, TC-T03-10) after the fixes |
| C5 Docs updated | Yes | READMEs link the new documents. The TRACEABILITY T03 column is filled for R-01 to R-12. The Amendments table is present |
| C6 No secrets | Pending | No secrets found in the reviewed files. `.env.example` waits on the developer step and the Finding 12(d) placeholder fix |
| C7 Clean-checkout works | Pending | TC-T03-30 |

## Re-review 2026-11-01

Reviewed: `technical-design.md` Revision 2 ("Revision history"), `data-model.md`,
`openapi.yaml`, `developer-handoff.md` Revision 2 and the `solution-architecture.md`
Amendments table. I checked each resolution in the files themselves, not only in the
revision note. The main session decided my open questions as follows: the 409 response and
the role configuration stay within T03 with no ADR (neither changes an accepted ADR);
recomputing a successful date is ticketed to T20.

| # | Where verified | Result |
|---|---|---|
| 1 | D5 step 1 (lock `meridian_ingest`, 130 s, 409 `ingest_busy`, `Retry-After: 30`); D3 "Concurrent requests"; D1 "Sole writer"; D4 409 row and sequence diagram; `openapi.yaml` 409 response, `ingest_busy` in the error code enum, operation description; T10 test hook; NFR table row "Ingest lock"; `data-model.md` "Uniqueness" | Fixed |
| 2 | D6 "Entity access" items 1 to 4 (no `access content` for anonymous or authenticated users, `hook_node_access()`, 401 subscriber); roles list (analyst now has `access content`); matrix row for a user without a Meridian role; `data-model.md` entity-access paragraph | Fixed |
| 3 | D3 "Rerun of a date" items 1 to 3; D2 rerun table; T20 test hook; open item ticketed to T20 | Fixed |
| 4 | D6 "Routes exempt from the login middleware" table, and `/api/health` decided | Fixed (see Note R2-1) |
| 5 | D6 login step 4 names `GET /api/meridian/v1/me`; it is in the scope table, the matrix and the open-items list | Fixed |
| 6 | D6 fallback scope `meridian_dashboard_admin`; matrix split into token and session rows | Fixed |
| 7 | D6 allowlist keyed on route name and method, deny by default, query-parameter allowlists, `include` of `uid` and `revision_uid` rejected; D5 exception subscriber; `openapi.yaml` watchlist 401 and 403 use `application/vnd.api+json` with `JsonApiErrorDocument` | Fixed (see Note R2-2) |
| 8 | `data-model.md` `ck_decisions_*` and `ck_positions_*` lists; D4 step 4 pre-send validation; D5 and `openapi.yaml` 422 "lists every failing item" | Fixed |
| 9 | D4 batch-level 422 row, drain step 3, "Drain triggers" paragraph (skipped runs and already-succeeded runs drain; NFR-15 counts pending only); `outbox.run_id` note | Fixed |
| 10 | D2 "Run attempts and the lock"; `ck_runs_attempt`; stale lock rule in `data-model.md` and the NFR table | Fixed |
| 11 | D8 concurrency group, `terminus connection:info`, pinned host key, first-push paragraph, policy-wording paragraph; D7 `PANTHEON_DEPLOY_KEY` row and paragraph citing [Pantheon SSH keys](https://docs.pantheon.io/ssh-keys) (checked 2026-11-01); machine user on Sandbox marked **unverified** for T07 | Fixed |
| 12 | D7 Vercel "Production only" column values and paragraph; revalidation secret at least 32 bytes; consumer provisioning in D6 and D7; handoff Revision 2 uses `change-me-local` in both places, with the same 22 names | Fixed |
| N15, N17, N19 | `openapi.yaml` `received: 4` and the `tokenUrl` note; D3 and the data model use JCS; amendment row 6 (RK-10 and the cost map point to OQ-01) | Fixed |

Amendment check (D-4): the six amendment rows only add pointers or resolutions. None
changes an accepted ADR or loosens an FR or NFR. The D8 policy-wording paragraph tightens
ADR-0004 and does not change its decision, which is acceptable without an ADR.

Simulation-only check: Revision 2 adds no broker host, scope, credential or
order-placement capability.

New observations from the re-review. None blocks sign-off:

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| R2-1 | Note | `technical-design.md` D6 | The bullet "The engine calls it with a 10 s timeout ..." now sits after the exempt-routes table and the `/api/health` paragraph, separated from the "Revalidation" list it belongs to. The meaning is clear, but markdownlint may flag a list that starts right after a paragraph | Move the bullet back under "Revalidation" (editorial; at close or in T04a lint) | Open (Note) |
| R2-2 | Note | `technical-design.md` D6 "Scope allowlist" | Query-parameter allowlists are listed for the two client-credentials tokens only. "Any other parameter is rejected" also reads as covering user tokens, whose set is not named. Sparse fieldsets (`fields[...]`) are not mentioned | T11 and T22 record that `meridian-web-login` tokens use the same set as `meridian-web`, plus any `fields[...]` that T11 adopts. The matrix tests in T22 and T30 cover it | Open (Note, for T11 and T22) |
| R2-3 | Note | `docs/tests/T03/` | Note 18 still applies: the `openapi.yaml` changes in Revision 2 (409, `JsonApiErrorDocument`) must pass the structural check and the owner-run Spectral lint (TC-T03-07, TC-T03-10). C3, C4, C6 and C7 remain tester steps | Tester step | Open (Note) |

## Approval

**Approved (re-review).** solution-architect, 2026-11-01.

No Blocker, Major or Minor finding is open. Notes R2-1 to R2-3, 16 and 18 need no design
change before merge. Sign-off is recorded in `technical-design.md` ("Sign-off"), and the
"T03 amendment" line in `solution-architecture.md` is marked reviewed. Design approval does
not waive the tester's evidence for AC3 (Spectral) or for C3, C4, C6 and C7.

**Re-review (DEF-002), 2026-11-01: Approved.** Revision 3 makes `uq_runs_date_attempt` a partial
unique index `WHERE attempt > 0`, so repeated `publish` and `replay` rows (`attempt = 0`) on one
date no longer collide. Compute attempts stay unique per date. `uq_runs_one_running` still covers
every row, so the lock is not weakened. The "already succeeded" check reads only `attempt > 0` rows,
and `ck_runs_attempt` ties `attempt = 0` to `publish` and `replay`, so the check is unaffected.

### First-round verdict (kept for history)

**Changes requested.** solution-architect, 2026-11-01.

The technical-architect fixes Findings 1, 2 and 3 as written above. Minor Findings 4 to 12
are fixed in this task, or ticketed with a task ID in this table. On re-review, if no
Blocker or Major is open, the solution-architect records sign-off in
`technical-design.md` and marks the "T03 amendment" line in `solution-architecture.md` as
reviewed. The amendment entries themselves meet the D-4 conditions (Note 13), so they need
no change.
