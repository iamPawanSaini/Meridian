# Traceability matrix

Requirement to task to test case to evidence. Requirements are the seeds in `docs/TASKS.md`
section 2. T02 refines them and adds priority and measurable targets. T03 adds design
elements, T04 adds the planned test cases, and every task close updates its rows.

Tasks come from each task's **Covers** line in `docs/TASKS.md`. Refined IDs (`FR-nn`,
`NFR-nn`) are defined, with priority, target and verifying task, in
`docs/architecture/solution-architecture.md` (section "Requirements"). They are stable and
never renumbered.

| Req | Requirement | Refined IDs (T02) | Tasks | Design element (T03) | Test cases | Evidence | Status |
|---|---|---|---|---|---|---|---|
| R-01 | Analyse a configurable NSE watchlist once per trading day | FR-01, FR-02, NFR-19 | T02, T10, T12, T13, T15, T31 | technical-design D1 (Watchlist Item), D2 (`watchlist_snapshots`), D5 (watchlist read in `openapi.yaml`), D6 (`meridian_watchlist_read`); data-model `watchlist_item` | Planned: [FR-01](#planned-tests), [FR-02](#planned-tests), [NFR-19](#planned-tests) |  | Open |
| R-02 | Long-term (fundamental) and short-term (technical) scoring modes | FR-03, FR-04 | T02, T13, T16, T31 | technical-design D1 (Decision `mode`, `score`, `rule_hits`), D2 (`decisions`); data-model `decision`, `decisions` | Planned: [FR-03](#planned-tests), [FR-04](#planned-tests) |  | Open |
| R-03 | LLM analyst review that can veto a buy; failure counts as veto | FR-05, FR-06, FR-07, NFR-08 | T02, T17, T29, T30, T31 | technical-design D1 (Decision `vetoed`, `veto_reason`, `raw_llm_output`), D2 (`runs` LLM cost columns, `ck_decisions_llm_only_veto`); data-model `decisions` | Planned: [FR-05](#planned-tests), [FR-06](#planned-tests), [FR-07](#planned-tests), [NFR-08](#planned-tests) |  | Open |
| R-04 | Risk-based position sizing, stop, target, time-stop, transaction costs | FR-08, FR-09, FR-10 | T02, T03, T16, T18, T25, T31 | technical-design D1 (Position), D2 (`positions`, `prices`); data-model `position`, `positions`, `prices` | Planned: [FR-08](#planned-tests), [FR-09](#planned-tests), [FR-10](#planned-tests) |  | Open |
| R-05 | Simulation only: no live order capability | FR-11 | T02, T18, T30, T31, T33 | technical-design simulation-only statement, D5 and D7 (no broker host, scope or credential; ADR-0006) | Planned: [FR-11](#planned-tests) |  | Open |
| R-06 | Every input, output and decision is stored and reproducible | FR-12, FR-13, FR-14, NFR-04, NFR-16 | T02, T03, T09, T10, T14, T17, T19, T20, T24, T27, T29, T30, T31 | technical-design D2 (provenance NOT NULL, migration plan), D3 (idempotency), D4 (outbox and retry), D5 (`openapi.yaml` ingest), NFR numbers (NFR-04); data-model | Planned: [FR-12](#planned-tests), [FR-13](#planned-tests), [FR-14](#planned-tests), [NFR-04](#planned-tests), [NFR-16](#planned-tests) |  | Open |
| R-07 | Drupal admin can browse, filter and export records, with roles | FR-15, FR-16 | T02, T09, T12, T19 | technical-design D1 (content model, field visibility), D6 (roles, permissions); data-model Drupal content model | Planned: [FR-15](#planned-tests), [FR-16](#planned-tests) |  | Open |
| R-08 | Next.js dashboard: overview, decisions, positions, reports | FR-17, FR-18, FR-30, NFR-03, NFR-05, NFR-12, NFR-13 | T02, T11, T12, T21, T21a, T22, T23, T24, T25, T26, T27, T30 | technical-design D1 (read fields, indexes), D6 (read client, revalidation route), NFR numbers (NFR-05, revalidate 300 s); data-model | Planned: [FR-17](#planned-tests), [FR-18](#planned-tests), [FR-30](#planned-tests), [NFR-03](#planned-tests), [NFR-05](#planned-tests), [NFR-12](#planned-tests), [NFR-13](#planned-tests) |  | Open |
| R-09 | All dashboard and API access is authenticated and least-privilege | FR-19, FR-20, FR-21, NFR-10, NFR-11 | T02, T03, T10, T11, T22, T26, T30 | technical-design D6 (clients, scopes, login flow, authorisation matrix), D7 (environment and secrets matrix); `openapi.yaml` security; ADR-0005 | Planned: [FR-19](#planned-tests), [FR-20](#planned-tests), [FR-21](#planned-tests), [NFR-10](#planned-tests), [NFR-11](#planned-tests) |  | Open |
| R-10 | Scheduled daily run, NSE holiday safe, idempotent, alerts on failure | FR-22, FR-23, FR-24, FR-25, NFR-01, NFR-02, NFR-06, NFR-14, NFR-15 | T02, T10, T14, T15, T19, T20, T27, T28, T29, T30, T31 | technical-design D2 (`runs` lock, status, `published`), D3 (rerun rule), D4 (retry, alerts, drain triggers) | Planned: [FR-22](#planned-tests), [FR-23](#planned-tests), [FR-24](#planned-tests), [FR-25](#planned-tests), [NFR-01](#planned-tests), [NFR-02](#planned-tests), [NFR-06](#planned-tests), [NFR-14](#planned-tests), [NFR-15](#planned-tests) |  | Open |
| R-11 | Whole stack reproducible locally with DDEV and Docker from a clean clone | FR-26, FR-27, NFR-09, NFR-17 | T02, T05, T06, T07, T27, T28, T32 | technical-design D7 (environments), D8 (repo and deploy, ADR-0004) | Planned: [FR-26](#planned-tests), [FR-27](#planned-tests), [NFR-09](#planned-tests), [NFR-17](#planned-tests) |  | Open |
| R-12 | Every task tested and documented inside the project folder | FR-28, FR-29, NFR-07, NFR-18 | T00, T01, T02, T04, T04a, T08, T16, T32, T33 | technical-design D5 (Spectral lint, structural check), test hooks in D1 to D8 | TC-T00-01 to TC-T00-08, TC-T01-01 to TC-T01-07, TC-T04-01 to TC-T04-32; Planned: [FR-28](#planned-tests), [FR-29](#planned-tests), [NFR-07](#planned-tests), [NFR-18](#planned-tests) | `docs/tests/T00/test-report.md`, `docs/tests/T01/test-report.md`, `docs/tests/T04/test-report.md` | Open |

## Planned tests

One row per requirement in `docs/architecture/solution-architecture.md` (FR-01 to FR-30 and
NFR-01 to NFR-19, 49 rows), planned by T04 under decision D-1. Parent R and verifying tasks come
from that file, in the same order. The case cell has one pattern per verifying task; each task
replaces its pattern with real case IDs when it closes. How the tests are run is in
[`master-test-plan.md`](tests/master-test-plan.md).

Level values: unit, integration, contract, end-to-end, security, performance, data
reconciliation, manual simulation, docs check (FR-28 and FR-29 are verified by documents).
Status values: Planned, Partially verified (some verifying tasks have Pass evidence), Verified,
`Blocked (accepted, re-run in Txx)`.

| ID | Parent R | Verifying task | Level(s) | Planned test | Planned case ID or pattern | Status |
|---|---|---|---|---|---|---|
| FR-01 | R-01 | T10, T12, T13 | integration; end-to-end | Change a Watchlist Item in seeded Drupal and check the next engine run uses it with source recorded as drupal; repeat with Drupal down to check the snapshot and YAML seed fallbacks | TC-T10-*, TC-T12-*, TC-T13-* | Planned |
| FR-02 | R-01 | T15, T31 | integration; manual simulation | Run the engine over a fixture watchlist with one failing symbol and assert every enabled symbol has a decision or a logged failure reason; repeat over the T31 window | TC-T15-*, TC-T31-* | Planned |
| FR-03 | R-02 | T16 | unit | Table-driven scoring tests for long and short mode asserting every decision has mode in long or short | TC-T16-* | Planned |
| FR-04 | R-02 | T16 | unit | Threshold tests at three points (below, at, above) for each rule, asserting score 0 to 100 and rule IDs and rule version on every decision | TC-T16-* | Planned |
| FR-05 | R-03 | T17 | unit; integration | Count calls to the fake LLM client over a candidate fixture, equal to the candidates above threshold, and assert the LLM output never creates a BUY | TC-T17-* | Planned |
| FR-06 | R-03 | T17 | unit | One test per failure type (malformed, empty, timeout, API error, schema violation) using fake LLM responses, each asserting a veto with the reason stored | TC-T17-* | Planned |
| FR-07 | R-03 | T17, T30 | unit; security | Prompt-injection set with at least one injection case per untrusted input field, asserting 0 unvalidated BUY results and an unchanged output schema; T30 repeats it in the manual review | TC-T17-*, TC-T30-* | Planned |
| FR-08 | R-04 | T16, T18 | unit | Sizing tests across capital, risk-per-trade cap and position cap asserting neither cap is exceeded, and zero or negative risk per share opens 0 positions | TC-T16-*, TC-T18-* | Planned |
| FR-09 | R-04 | T18 | unit | At least 12 hand-calculated scenarios (gap exits, same-bar stop and target, time-stop) with expected values computed outside the code | TC-T18-* | Planned |
| FR-10 | R-04 | T18, T25 | unit; end-to-end | Accounting invariant asserted at every step of every T18 scenario, cost-component unit tests for buy and sell sides with rates read from config (T18), and a Playwright check that the positions page shows costs and equity from the report (T25) | TC-T18-*, TC-T25-* | Planned |
| FR-11 | R-05 | T18, T30, T33 | security | Static broker check (generic denylist scan of source, dependencies, configuration and hostnames) returns 0 hits in CI; T30 repeats it in the manual review and T33 as the final check | TC-T18-*, TC-T30-*, TC-T33-* | Planned |
| FR-12 | R-06 | T14, T17 | integration | After a run on Postgres, assert all 5 provenance fields are non-null on 100% of decision rows, including constraint tests on the schema (T14) and the LLM fields (T17) | TC-T14-*, TC-T17-* | Planned |
| FR-13 | R-06 | T20, T27 | integration; end-to-end | Run replay for a stored date with no LLM and compare scores and pre-LLM actions with the original run: 0 differences (T20 integration, T27 on DDEV) | TC-T20-*, TC-T27-* | Planned |
| FR-14 | R-06 | T19, T27 | data reconciliation | Publish a seeded day and run the reconciliation script comparing counts and key values between Postgres and Drupal: 0 differences (T19 against Drupal, T27 on the full stack) | TC-T19-*, TC-T27-* | Planned |
| FR-15 | R-07 | T12 | integration | Drupal Functional tests for the 3 admin views: exposed filters work and the CSV export row count equals the filtered row count | TC-T12-* | Planned |
| FR-16 | R-07 | T09, T12 | integration; security | PHPUnit permissions matrix testing every role against every permission, 100% of cells pass, with at least 4 roles present | TC-T09-*, TC-T12-* | Planned |
| FR-17 | R-08 | T23, T24, T25 | unit; end-to-end | Vitest component tests and Playwright scenarios for the empty, loading and error state of each of the 4 page areas | TC-T23-*, TC-T24-*, TC-T25-* | Planned |
| FR-18 | R-08 | T23, T25 | data reconciliation | Compare dashboard figures with the engine report output on seeded data: amounts within 0.01 and returns within 0.01 percentage points | TC-T23-*, TC-T25-* | Planned |
| FR-19 | R-09 | T22, T30 | security; end-to-end | Playwright requests every dashboard page and data route without a session and expects a login redirect or 401 for 100% of routes | TC-T22-*, TC-T30-* | Planned |
| FR-20 | R-09 | T10, T11, T22, T30 | security; integration | Authorisation matrix tests of every role and OAuth client against every endpoint and page (Functional in T10 and T11, Playwright in T22), 0 forbidden cells pass; T30 reviews the matrix | TC-T10-*, TC-T11-*, TC-T22-*, TC-T30-* | Planned |
| FR-21 | R-09 | T22, T30 | security; end-to-end | Scan the production client bundles and the Playwright network traces for tokens and Drupal credentials: 0 hits | TC-T22-*, TC-T30-* | Planned |
| FR-22 | R-10 | T20 | unit; integration | Check the workflow cron is 16:00 IST (10:30 UTC) Monday to Friday, start two runs at once to prove at most 1 run is in progress, and check daily-run.yml declares workflow_dispatch and one manual dispatch completes, with evidence (T20) | TC-T20-* | Planned |
| FR-23 | R-10 | T20 | integration | Run with a holiday fixture and a no-new-candle fixture: status skipped with a reason and 0 decisions written for that date | TC-T20-* | Planned |
| FR-24 | R-10 | T14, T19 | integration | Run the same date twice and compare record counts before and after in Postgres (T14) and in Drupal after publish (T19): 0 duplicates | TC-T14-*, TC-T19-* | Planned |
| FR-25 | R-10 | T19, T20, T29 | integration; end-to-end | Forced-failure test of a failed run and a failed publish: exactly 1 notification with run ID and log link, run marked published partial; T29 repeats it on dev | TC-T19-*, TC-T20-*, TC-T29-* | Planned |
| FR-26 | R-11 | T05, T06, T27 | integration; end-to-end | From a clean clone run ddev start and check the 4 services are up (T05 and T06), then the full-stack flow in T27 | TC-T05-*, TC-T06-*, TC-T27-* | Planned |
| FR-27 | R-11 | T07, T28 | end-to-end; manual simulation | Deploy dev smoke checks (T07) and observe 1 unattended scheduled run visible in the deployed dashboard (T28) | TC-T07-*, TC-T28-* | Planned |
| FR-28 | R-12 | T32 | docs check | At T32 a script checks that each of T00 to T33 has plan, test cases, test report and review in the repo | TC-T32-* | Planned |
| FR-29 | R-12 | T04, T32 | docs check | The T04 checker proves the planned-tests table has all 49 FR and NFR rows; at T32 a script proves 0 requirement rows lack a test case and evidence | TC-T04-*, TC-T32-* | Planned |
| FR-30 | R-08 | T12, T22, T23, T24, T25 | integration; end-to-end | Playwright asserts the notice on every dashboard page, and tests assert the header line in every CSV export from Drupal Views and from the dashboard | TC-T12-*, TC-T22-*, TC-T23-*, TC-T24-*, TC-T25-* | Planned |
| NFR-01 | R-10 | T20, T30, T31 | performance; manual simulation | Time a run on DDEV with the fake LLM for 50 symbols from the run record timestamps (T20), then p95 on dev with the real LLM over the T31 window (T30, T31) | TC-T20-*, TC-T30-*, TC-T31-* | Planned |
| NFR-02 | R-10 | T20, T29, T31 | manual simulation | Per trading day of the T31 window compare the dashboard publish time with 18:00 and 20:00 IST; T20 checks the timestamps and T29 the monitoring | TC-T20-*, TC-T29-*, TC-T31-* | Planned |
| NFR-03 | R-08 | T26, T30 | performance | Playwright with web-vitals onLCP in Chromium on overview and decisions pages with 5,000 decisions seeded, at least 10 navigations each, LCP p75 on DDEV (T26) and dev (T30) | TC-T26-*, TC-T30-* | Planned |
| NFR-04 | R-06 | T10, T30 | performance | Timing harness posts one 500-record ingest request 5 times on DDEV and reports the nearest-rank p95 with raw samples, at most 30 s (T10); T30 repeats it | TC-T10-*, TC-T30-* | Planned |
| NFR-05 | R-08 | T11, T30 | performance | Timing harness fetches a 50-row JSON:API page 50 times with 5,000 records seeded and reports the nearest-rank p95 on DDEV (T11) and Pantheon dev (T30) | TC-T11-*, TC-T30-* | Planned |
| NFR-06 | R-10 | T31 | manual simulation | Count terminal run records per trading day over the T31 window: 100% terminal and at least 90% success or partial | TC-T31-* | Planned |
| NFR-07 | R-12 | T08 | performance | Read the ci.yml wall-clock time from GitHub Actions job timings on a clean cache and warm caches: at most 10 min and 6 min (T08) | TC-T08-* | Planned |
| NFR-08 | R-03 | T17, T29, T31 | unit; manual simulation | Budget test with fake LLM costs: at the cap the engine stops calling the LLM and vetoes with reason budget (T17); cost log review in T29 and T31 | TC-T17-*, TC-T29-*, TC-T31-* | Planned |
| NFR-09 | R-11 | T28 | manual simulation | Inspect the hosting plans and bills for GitHub Actions, Postgres host, Pantheon and Vercel: USD 0 per month, and record it (T28) | TC-T28-* | Planned |
| NFR-10 | R-09 | T30 | security | Run gitleaks over the full git history and the working tree: 0 findings; also confirm secrets exist only in platform stores and local env files (T30) | TC-T30-* | Planned |
| NFR-11 | R-09 | T26, T30 | security | Run pip-audit, composer audit, npm audit and a container image scan: 0 unresolved high or critical findings (T26 for the dashboard, T30 for all) | TC-T26-*, TC-T30-* | Planned |
| NFR-12 | R-08 | T21a, T26 | unit; end-to-end | T21a automated token-pair contrast test (4.5:1, 3:1 for large text and UI) fails the build below AA; Playwright with axe on every page in light and dark themes: 0 critical or serious violations (T21a, T26 all pages) | TC-T21a-*, TC-T26-* | Planned |
| NFR-13 | R-08 | T21a | end-to-end | Playwright network trace of each page load asserts 0 requests to third-party hosts for fonts, styles, scripts or icons | TC-T21a-* | Planned |
| NFR-14 | R-10 | T20, T29 | integration; end-to-end | Forced failure with a fake clock proves a notification within 15 min and a missed-run alert by 19:00 IST (T20); T29 repeats it on dev | TC-T20-*, TC-T29-* | Planned |
| NFR-15 | R-10 | T19, T27 | integration; end-to-end | Stop Drupal, run, restart Drupal and check the outbox drains to 0 with 0 records lost, by the next run or within 30 min of a manual publish (T19, then T27 on DDEV) | TC-T19-*, TC-T27-* | Planned |
| NFR-16 | R-06 | T14, T29 | integration; manual simulation | Backup and restore drill for Postgres and the Drupal database: row counts match, RPO at most 24 h and RTO at most 2 h recorded (T14 script, T29 drill) | TC-T14-*, TC-T29-* | Planned |
| NFR-17 | R-11 | T27, T32 | end-to-end; manual simulation | Time a clean clone to a running DDEV stack using only README commands, at most 30 min (T27, T32) | TC-T27-*, TC-T32-* | Planned |
| NFR-18 | R-12 | T04a, T16 | unit | pytest-cov report shows at least 90% line coverage on the engine scoring and risk modules (threshold configured in T04a, tests in T16) | TC-T04a-*, TC-T16-* | Planned |
| NFR-19 | R-01 | T15 | unit; integration | Count calls at the market-data library seam inside the T15 adapter (the monkeypatched library call) with a fake 429 sequence and an injected sleep or clock: at most 2 calls per symbol on average, at most 3 retries, and growing delays | TC-T15-* | Planned |
