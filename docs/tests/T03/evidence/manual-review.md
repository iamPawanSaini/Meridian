# T03 manual and owner-run cases: execution notes

Executed 2026-11-01 by tester on branch `task/T03-technical-design` (base commit `1b8a031`, T03 files uncommitted in the working tree). Documents reviewed: `docs/architecture/technical-design.md` (Revision 2), `docs/specs/data-model.md`, `docs/architecture/openapi.yaml`, `.spectral.yaml`, `.env.example`.

## TC-T03-10 Spectral (owner-run): Blocked

See `TC-T03-10.txt`. No network; the `npx` download was denied by the auto-mode classifier. Not a document defect. Owner must run the documented command and store the output.

## TC-T03-23 Content model quality review: Pass

- Dashboard columns, filters and sorts found in design D1 (line 65: `trade_date`, `symbol`, `mode`, `action`, `vetoed`, `score`, `status`, `entry_date`...) are all Drupal fields marked Indexed: Decision `trade_date`, `symbol`, `mode`, `score`, `action`, `vetoed`, `run`; Position `symbol`, `mode`, `status`, `entry_date`, `exit_date`, `run`, `decision`; Daily Run `trade_date`, `status`, `finished_at`; Price Snapshot `trade_date`, `symbol`; Watchlist Item `enabled`, `sort_order`, `symbol`.
- Every Validation cell is concrete: a regex, an enum, a range, a byte or character limit, or a cross-field rule. None says "valid" alone.
- Enums agree across Drupal, Postgres and OpenAPI: mode `long|short`, action and pre_llm_action `BUY|AVOID`, veto_reason (7 values, OpenAPI also allows null), position status/exit_reason, run status.
- `price_snapshot` is OHLCV summary only; no personal data in any bundle.
- Observation (not a defect): Postgres `prices.source` is documented as `yfinance` or `stub` in the Notes column with no named CHECK, while the Drupal `source` field is a list_string with those two values. A bad value would be a predictable 422 at ingest. Suggest T14 adds `ck_prices_source`. Logged here as a note for the reviewer.

## TC-T03-24 Postgres schema review: FAIL, DEF-002

- Read paths each have a named index: latest run `ix_runs_trade_date`; decisions by date/action `ix_decisions_date_action`; open positions `ix_positions_open` (partial); outbox drain `ix_outbox_drain` (partial); watchlist snapshot `ix_wls_taken_at`; prices by date `ix_prices_trade_date`. Pass.
- Rerun on paper: decisions `uq_decisions_date_symbol_mode`; positions `uq_positions_symbol_mode_entry`; prices primary key (symbol, trade_date); outbox `uq_outbox_one_pending` partial; watchlist_snapshots `uq_wls_run`; runs `uq_runs_date_attempt` (trade_date, attempt). Provenance columns are all `NOT NULL`. FKs are `ON DELETE RESTRICT`. Types are core Postgres 16, no extension. Pass except for runs.
- **Defect:** the data model says `publish` and `replay` rows always use `attempt = 0` (`ck_runs_attempt`), and `uq_runs_date_attempt` is a plain unique constraint on (`trade_date`, `attempt`) with no `WHERE attempt > 0`. A second `publish` or `replay` row for the same `trade_date` (for example two manual `publish` dispatches on one day, which NFR-15 expects, or a `replay` followed by a `publish`) violates the constraint. Demonstration of the documented constraint with sqlite: `DEF-002-demo.txt`. Logged as DEF-002.

## TC-T03-25 Idempotency and outbox scenario walkthrough: Pass

Traced from design D3 and D4, data-model `outbox`:

| Scenario | Outcome from the written rules |
|---|---|
| (a) same date rerun, identical payload | If the date already succeeded: no compute, drain only, 0 new decision/position/outbox rows (D3 rerun 2). If an earlier attempt failed: atomic transaction wrote nothing, so attempt+1 computes fresh; same content gives same hash, so nothing enqueued when equal to last `sent` hash (D4 enqueue) |
| (b) rerun with changed payload | Recompute of a succeeded date is not offered (open item ticketed to T20). Before success, `version` increments only when content changes, upsert outcome `updated` |
| (c) older `source_version` after newer | `stale`, no write (D3 upsert table) |
| (d) Drupal down for 3 runs, then up | Rows stay pending; each later run drains all pending rows, ignoring `next_attempt_at` at drain start; `published: partial` until none pending; no loss |
| (e) 401 mid-batch | Discard token, fetch a new one once, retry the batch; second 401 stops the drain and alerts |
| (f) 422 on one item of 500 | Nothing written for the batch; response lists every failing item; that row goes `dead` with alert (or pending if `unknown_reference`); the rest resent at once |
| (g) wake slower than 120 s | Wake backoff capped at 120 s; rows stay pending; run `published: partial`; alert |
| (h) second pending row for one external ID | `INSERT ... ON CONFLICT ... WHERE status='pending' DO UPDATE` replaces the pending row; partial unique index forbids a second |
| (i) accepted but response lost | Timeout halves the batch and resends; idempotent upsert returns `unchanged`; no duplicate |

No scenario is ambiguous. Interplay note: scenario (d) uses `publish`, whose runs row hits DEF-002 on the second publish for a date.

## TC-T03-26 Authentication design review: Pass

- Authorisation matrix (D6) read cell by cell against least privilege. Dashboard clients (`meridian-web`, user tokens) have no write path: JSON:API write is 405 for every caller, ingest is 403 for all but `meridian-engine`. Analyst cannot ingest. Engine token is limited to ingest plus watchlist read by route-name allowlist, query-parameter allowlist and `view meridian watchlist`; decisions are 403.
- One client per caller; scopes: `meridian-engine` (`meridian_ingest`, `meridian_watchlist_read`), `meridian-web` (`meridian_dashboard_read`), `meridian-web-login` (`meridian_dashboard_user`, auth code + PKCE S256). `meridian_dashboard_user` is not in `openapi.yaml`, which correctly covers only the engine routes.
- FR-21: base URL server-only (`DRUPAL_BASE_URL`), tokens in encrypted HttpOnly Secure SameSite=Lax cookie, no `NEXT_PUBLIC_` Drupal variable (TC-14 confirms).
- Revalidation authenticated by a 32-byte shared secret in an `Authorization: Bearer` header, constant-time compare, 401 otherwise; it is in the exempt-route table with its protection.
- Scope names `meridian_ingest` and `meridian_watchlist_read` identical in `openapi.yaml` and the design (TC-11 check).
- Residual risks are explicitly marked unverified with confirming tasks (scope intersection, PKCE, token revocation); fallback designed. No gaps.

## TC-T03-27 Deploy strategy dry run: Pass

Clone of the local repo at `/tmp/t03-clone` (outside the working tree), `git subtree split --prefix=apps/drupal -b tmp-split` per D8 step 2. Exit 0, created branch `tmp-split` (split of 6 commits). Working tree untouched (checked `git status`). Evidence: `TC-T03-27.txt`. Paths consistent: Composer root `apps/drupal`, docroot `apps/drupal/web`, `config/sync` relative `../config/sync`, `pantheon.yml` at the split root, DDEV `composer_root: apps/drupal`. All six ADR-0004 unverified items are listed with owner and task T07. Clone removed afterwards.

## TC-T03-28 NFR numbers, sources, decisions: Pass

- NFR-04: 30 s p95 for 500 items on DDEV (unchanged from T02, provisional, gate MG-1 end of T09 before T10); Pantheon dev 30 s at provisional batch 100, source Pantheon timeouts doc checked 2026-11-01 (edge 59 s, PHP 120 s). NFR-05 unchanged from T02 (500 ms DDEV, 1,500 ms Pantheon), provisional with gate MG-1 and T11. Body 8 MB, rate 60/min per client, publisher timeout 45 s, revalidate 300 s: each has a source or "design value" with the unverified Pantheon body limit assigned to T07. Nothing loosened versus T02.
- Decisions D-1 to D-5 each have an outcome in `docs/tasks/T03/decision-t03-design.md` (Neon Free; NFR gate; third confidential client `meridian-web-login`; dated amendments without ADR; `web-next` wording fixed).

## TC-T03-29 Cross-document consistency: Pass

Script output in `cross-doc-fields.txt`. For Decision, Position, Daily Run and Price Snapshot, the attributes in the OpenAPI item schemas equal the ingested Drupal fields in `data-model.md` (after mapping `run` to `run_external_id`, `decision` to `decision_external_id`, and excluding `title`, `source_version`, `payload_hash`); only `external_id` differs because it is item-level in OpenAPI, which is by design. External-id patterns match; veto_reason, action and mode enums match; `llm_rationale` max length 2,000 matches. The design states the single documented difference (`[a-z]{4,5}` in table cells vs `(long|short)` in OpenAPI). Choices left open ("or", "for example") are limited to values explicitly marked provisional or unverified with an owner.

## TC-T03-30 Clean-checkout run: Pass (with deviation)

Because the T03 files are not committed, a plain clone of the branch would not contain them. Equivalent: `git clone` of the repo to `/tmp/t03-clean`, then overlay of all modified and untracked files (`git ls-files -m -o --exclude-standard`), then `docs/tests/T03/run-checks.sh`. Result in `TC-T03-30.txt`: all checks PASS, 2 SKIP (pre-commit, markdownlint). Re-run from a real clone after the T03 commit if the reviewer wants the exact steps. The clone was removed afterwards. Evidence completeness is listed in the report.

## TC-T03-31 Plan, review and sign-off hygiene: Blocked

Evaluated: plan `Status | Approved` (pass); `review.md` exists, "Approved (re-review)", findings 1 to 12 Fixed, Notes only remain (pass); design status line records solution-architect sign-off 2026-11-01 Revision 2 (pass); `docs/architecture/README.md` and `docs/specs/README.md` link the new documents (pass). Not evaluable now: step 3 (`git log` order of plan vs design commits) and the `T03:` commit prefix, because nothing for T03 is committed yet. Blocked on the commit; re-verify at close. Not a document defect.

## TC-T03-32 Mermaid render: Blocked

No `mmdc`, no network for mermaid.live or a GitHub preview. The design has one `sequenceDiagram` block (publisher, outbox, Drupal ingest, token endpoint, revalidation, alt branches for 200, 401, 409, 413/504/timeout, 422, outage); read by eye it is syntactically regular (balanced `alt`/`else`/`end`, `loop`/`end`), and the fences are balanced (TC-06 check). Rendering is unconfirmed. Environment block, not a document defect.

## TC-T03-24 retest after DEF-002 fix (Revision 3): Pass

`technical-design.md` D2/D3 and `data-model.md` `runs` now declare `uq_runs_date_attempt` as a partial unique index `WHERE attempt > 0`, keep `ck_runs_attempt`, and state that `uq_runs_one_running` still covers every row (so a running publish excludes other runs). Modelled in sqlite with `docs/tests/T03/def002_retest.py`; output in `DEF-002-retest.txt`: two or more `attempt = 0` rows on one date insert; a duplicate `attempt > 0` row on a date is rejected; a second `running` row is rejected; `ck_runs_attempt` still rejects publish with attempt 1 and daily with attempt 0. D3 "already succeeded" check now reads `attempt > 0`. No new inconsistency found. `run-checks.sh` and `check_data_model.py` re-run: all PASS. Remaining blocks on TC-T03-10, 31, 32 unchanged.

## TC-T03-31 re-check after commit 96b4c17: Pass (with deviation)

`TC-T03-31.txt` has the output. Commit 96b4c17 starts with `T03: `. Plan Approved; `review.md` Approved (re-review) with findings 1 to 12 Fixed (Notes 13, 14, 16, 18 are advisory); the design records Revisions 1 to 3 and the solution-architect sign-off; `docs/architecture/README.md` and `docs/specs/README.md` link the new documents. Deviation from step 3: the main session committed plan, review, design and test artefacts together, so `git log` cannot show the plan before the design. I judged the chronology from file contents (review C1 row says the plan was Approved before the design was written; the design's revision history shows submit, review fixes, DEF-002 fix, all dated 2026-11-01). Accepted as equivalent evidence per the coordinator's instruction.
