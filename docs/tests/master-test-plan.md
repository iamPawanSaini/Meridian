# Master test plan

| Field | Value |
|---|---|
| Task | T04 |
| Author | tester |
| Date | 2026-11-01 |
| Status | Approved (technical-architect review, 2026-11-01; see `docs/tasks/T04/review.md`) |
| Decisions | `docs/tasks/T04/decision-t04-test-strategy.md` (D-1 to D-6) |
| Requirements | [`solution-architecture.md`](../architecture/solution-architecture.md) (FR-01 to FR-30, NFR-01 to NFR-19) |
| Planned tests | [`TRACEABILITY.md`](../TRACEABILITY.md), section "Planned tests" (49 rows) |

This plan says how Meridian is tested from T05 to T33. It names tools by purpose only. Versions,
configuration and coverage thresholds belong to T04a. CI workflow files belong to T08. Test code
and fixtures belong to each owning task. Meridian is a simulation: no test may place, or be able
to place, a live order (FR-11).

Planned tests are kept at FR/NFR level: 49 rows, one per requirement, in the "Planned tests"
table of `TRACEABILITY.md` (decision D-1). Each R row links to its FR and NFR rows.

## Test levels

Eight levels. Each sub-section gives the purpose, the owning tasks, the tools and the pass rule.
A level passes only when every case at that level for the task under test is Pass with stored
evidence (see "Exit criteria").

### Unit

- **Purpose:** one function, class or component in isolation, with time, network and the LLM
  replaced by fakes. Rules, scoring, sizing, costs, state machines, UI components.
- **Owning tasks:** T13, T15, T16, T17, T18 (engine); T09 (Drupal Unit); T21a to T25 (Vitest);
  T01 (path guard); T04a (coverage configuration).
- **Pass rule:** 100% of unit cases pass. Thresholds are tested at three points (below, at,
  above). The coverage target of NFR-18 (90% line coverage on `scoring` and `risk`) is met, and
  T04a sets the other component targets. No unit test opens a socket.

### Integration

- **Purpose:** two or more real parts together: the engine with Postgres, the publisher with a
  running Drupal, Drupal Kernel and Functional tests with a real database, the outbox, replay.
- **Owning tasks:** T10, T12, T14, T19, T20 (engine to Drupal and Postgres); T09, T10, T11, T12
  (PHPUnit Kernel and Functional); T29 (alerts).
- **Pass rule:** 100% of integration cases pass on DDEV or in CI service containers. Idempotency
  holds (0 duplicates after two runs). Integration tests that need Drupal run in the heavier set
  (see "Regression suite").

### Contract

- **Purpose:** the engine, Drupal and the dashboard agree on the HTTP interface in
  `docs/architecture/openapi.yaml`. Request bodies, response bodies, status codes, error
  documents and security schemes.
- **Owning tasks:** T10 (ingest), T11 (read endpoints, which T11 adds to `openapi.yaml`), T19
  (publisher request bodies), T21 (mock API), T22 (read client).
- **Pass rule:** `openapi.yaml` passes Spectral lint. Every example and every publisher request
  body validates against the schema. Schemathesis finds 0 schema conformance failures on a
  disposable DDEV site. The PHPUnit Functional cases in T10 (idempotency, 401, 403, 422, rate
  limit, audit log, concurrent 409) still pass: Schemathesis does not replace them.

### End-to-end

- **Purpose:** a user-visible flow across all components: login, pages, filters, empty, loading
  and error states, CSV export, a full run through to the dashboard.
- **Owning tasks:** T22 to T26 (Playwright on the dashboard), T27 (full stack on DDEV), T28
  (deployed dev), T21a (accessibility and self-hosted assets).
- **Pass rule:** every Playwright scenario passes against DDEV (the stack of T05 and T06) with
  seeded data and the fake LLM. T27 passes `ddev e2e` from a clean clone. T28 shows one
  unattended scheduled run in the deployed dashboard (FR-27).

### Security

- **Purpose:** simulation-only rule (FR-11), authentication and least privilege (FR-19, FR-20,
  FR-21), secret hygiene (NFR-10), known vulnerabilities (NFR-11), prompt injection (FR-07).
- **Owning tasks:** T18 (static broker check added), T30 (security review and probes), T33
  (final check), T10 and T11 (authorisation matrix), T22 (routes and bundles), T26 and T30
  (audits and image scan), T01 (path guard).
- **Pass rule:** the static broker check returns 0 hits. gitleaks finds 0 secrets over the full
  git history. The authorisation matrix has 0 forbidden cells that pass. 0 unresolved high or
  critical findings in the audits and the image scan. Once D-6 is confirmed by the owner, a
  security case may not be Blocked at close; until then the T00 to T02 precedent in "Blocked at
  close" applies.

### Performance

- **Purpose:** measure the NFR targets for run duration, page load, ingest time, read API time
  and CI duration. Single-client latency percentiles over a fixed sample size, not load.
- **Owning tasks:** T10 (NFR-04), T11 (NFR-05), T20 (NFR-01 on DDEV), T26 (NFR-03), T08 (NFR-07),
  T30 (repeat on deployed dev), T31 (NFR-01 on dev over the window).
- **Pass rule:** the measured value meets the NFR target, using nearest-rank percentiles on raw
  samples kept in the evidence. Evidence also records the environment, the seeded record count
  (5,000) and tool versions. Performance runs on DDEV or deployed dev, never in the PR set.

### Data reconciliation

- **Purpose:** the same numbers appear at every hop: Postgres, Drupal and the dashboard.
- **Owning tasks:** T19 (publish, FR-14), T23 and T25 (dashboard against `report`, FR-18), T27
  (end to end on DDEV), T31 (every trading day of the window).
- **Pass rule:** FR-14 has 0 count or key-value differences between Postgres and Drupal. FR-18
  differences are at most 0.01 for amounts and 0.01 percentage points for returns. Method and
  tolerances are in "Reconciliation".

### Manual simulation

- **Purpose:** checks that need a person, real time or real platforms: the 10 to 15 trading day
  window, the real-LLM smoke test, the deployed dev platforms, backup and restore drills, and
  the manual security review.
- **Owning tasks:** T17 (real-LLM smoke test), T28 (deployed dev), T29 (alert and restore
  drills), T30 (manual review), T31 (live simulation window), T33 (go/no-go).
- **Pass rule:** the procedure in the case was followed and the result meets the NFR or FR
  target. The tester or owner records the evidence (logs, screenshots, run records). Manual
  cases are marked as manual and never run in CI.

## Tools per component

One row per component. Tools are named by purpose. Versions are pinned in T04a, which also
confirms each tool installs in DDEV and CI. The selection rule: free, maintained, self-hostable,
works offline in CI and DDEV, no SaaS account.

| Component | Tools | Purpose |
|---|---|---|
| Engine | pytest, pytest-cov, pytest-socket, respx | Unit and integration tests under `services/engine/tests`. pytest-cov measures coverage. pytest-socket blocks the network. respx mocks httpx clients (publisher T19, LLM client below T17). |
| Drupal | PHPUnit Unit, Kernel and Functional | Unit tests for services, Kernel tests with a real database and entities, Functional tests through HTTP and the admin UI (roles, views, ingest, CSV). |
| Next.js | Vitest, Playwright, axe (`@axe-core/playwright`) | Vitest for components and the data client. Playwright for end-to-end flows and page-load timing. axe for accessibility in both themes. |
| Contract | Schemathesis, openapi-core, Spectral | Schemathesis against a running DDEV site. openapi-core validates requests and responses inside engine tests. Spectral lints the OpenAPI file itself. |
| Security | gitleaks, pip-audit, composer audit, npm audit, image scan, static broker check | Secret scan of the full history. Dependency audits for Python, PHP and JavaScript. Container image scan (NFR-11). Static broker check (FR-11). |
| Performance | web-vitals, Python timing harness | `web-vitals` `onLCP()` in Playwright (Chromium) for NFR-03. A harness on `time.perf_counter` and httpx for NFR-04, NFR-05 and NFR-01. |

Tool decisions (D-2, D-3, D-4):

- Contract: Schemathesis runs against DDEV, from the `meridian-engine` container, in the heavier
  set. The tests live under `services/engine/tests/contract/` with a marker such as
  `drupal_live` so that the PR set can exclude them. openapi-core runs in engine tests and needs
  no Drupal. T11 extends `openapi.yaml` with the read endpoints and `/me`; the
  technical-architect writes that edit during planning of T11. Dredd is rejected (its
  repository is archived). Prism is not adopted as the contract tool. The fallback if
  Schemathesis is unusable in T10 is pytest with httpx and openapi-core over hand-written cases.
  Confirm in T10 how Schemathesis handles the DDEV mkcert certificate.
- Performance: percentiles use the nearest-rank method on raw samples. NFR-04 "p95 over 5 runs"
  is the slowest of 5 runs. NFR-05 p95 over 50 requests is the 48th value in ascending order.
  Every raw sample and the computed percentile go to the evidence file. NFR-03 p75 uses at
  least 10 navigations per page, each in a fresh browser context, in Chromium. NFR-01 uses the
  run record timestamps. NFR-07 uses GitHub Actions job timings. k6 and Locust are not adopted.
  Lighthouse CI is optional, diagnostic only, never a gate, with `filesystem` upload only.
- Market data and network: market data is mocked at the provider boundary, using a
  fixture-backed class that implements the T15 provider interface. No HTTP-level cassettes:
  vcrpy is rejected (cassettes store headers, and an HTTP mock may not intercept the market data
  library). respx covers httpx clients only. Network blocking has two layers: pytest-socket with
  `--disable-socket --allow-unix-socket`, plus a no-network container (`--network none`) for the
  engine PR job in CI. The container layer is required because a native library may open sockets
  outside Python's `socket` module; T15 demonstrates that an accidental real call fails.
- Items marked unverified in the decision record are confirmed by the named task before use:
  Schemathesis and mkcert (T10), the 429 exception of the market data library (T15), the
  container network block (T15), `web-vitals` licence and offline install (T04a or T26).

## Test layout

A convention for later tasks. Test code lives with its component. Documentation-only tasks keep
their checks next to their cases.

| Component | Location |
|---|---|
| Engine | `services/engine/tests/unit`, `services/engine/tests/integration`, `services/engine/tests/contract`, and fixtures in `services/engine/tests/fixtures` (market data under `fixtures/market/`, fake LLM responses under `fixtures/llm/`) |
| Drupal | `apps/drupal/web/modules/custom/meridian_*/tests/src/Unit`, `.../Kernel`, `.../Functional` (written `meridian_*/tests/src/{Unit,Kernel,Functional}`) |
| Next.js | unit tests next to the source file they test (`*.test.ts` or `*.test.tsx`), and end-to-end tests in `apps/web/e2e` |
| Docs tasks | `docs/tests/Txx/test-cases.md`, `docs/tests/Txx/run-checks.sh` (plus helper scripts), `docs/tests/Txx/evidence/`, `docs/tests/Txx/test-report.md` |

Case IDs are `TC-Txx-nn`. A test function or file names its case ID in a docstring or comment,
so that evidence can be traced from the case to the code.

## Environments

| Environment | What it is | Limits |
|---|---|---|
| Agent sandbox | The tester and developer agent shell | No network. Some tools missing (for example pre-commit, markdownlint, Spectral, gitleaks). Cannot run DDEV or Docker. |
| DDEV | Local stack: Drupal, `meridian-postgres`, `meridian-engine`, `meridian-web` | Runs on the owner's machine or the main session. Fake LLM, fixture market data. |
| CI | GitHub Actions (`ci.yml`, T08) | No live market data or LLM. Engine PR job in a container with no network. Shared runners give noisy timings. |
| Deployed dev | Drupal on Pantheon dev, the dashboard on Vercel, the engine on GitHub Actions, Postgres on a free host | Real LLM and real market data. Pantheon sleeps (wake about 30 s). Manual and scheduled use only. |

Where each level runs (Yes = run here, No = not run here, Manual = performed by a person):

| Level | Agent sandbox | DDEV | CI | Deployed dev |
|---|---|---|---|---|
| Unit | Yes for engine and docs scripts, if the tool is installed | Yes | Yes (PR set) | No |
| Integration | No (no database services) | Yes | Yes for engine with Postgres service; Drupal Functional in the heavier set | No |
| Contract | Lint and openapi-core on fixtures, if installed | Yes (Schemathesis against Drupal) | PR set against fixtures; Schemathesis in the heavier set | No |
| End-to-end | No | Yes (`ddev e2e`, Playwright) | Heavier set only | Manual smoke (T28) |
| Security | Static broker check, secret scan if installed | Yes (audits, authorisation matrix) | Yes (static broker check, gitleaks, audits) | Manual review (T30) |
| Performance | No | Yes (NFR-03, 04, 05, 01) | Job duration only (NFR-07) | Yes (T30, T31) |
| Data reconciliation | No | Yes (T27) | No | Yes (T31) |
| Manual simulation | No | Manual where needed | No (never) | Manual (T28 to T31) |

Rules: a case states the environment it needs. If the executing context lacks it, the case is
Blocked, not Fail (see "Conventions"). No environment other than deployed dev and the owner-run
capture steps uses live market data or a real LLM.

## Entry criteria

Per task:

- The task plan `docs/tasks/Txx/plan.md` is approved.
- `docs/tests/Txx/test-cases.md` is committed with `Txx:` before development starts (and, for
  scripted checks, `run-checks.sh` too). Every acceptance criterion and each of C1 to C7 maps to
  at least one case.
- The tasks it depends on are Done, or their carried-over Blocked cases are listed in this
  task's plan.
- Needed fixtures and tools exist, or the case lists the owner action that creates them.
- The task branch is `task/Txx-slug` and the working tree is committed for the build under test.

Per milestone (M1 to M7, see `docs/TASKS.md` section 3.5):

- Every task in the milestone is Done, or has an explicit carry-over.
- The regression suite is green on the latest commit of the integration branch.
- Every Blocked case that the milestone depends on has Passed (see "Exit criteria").
- No open Critical or High defect.

## Exit criteria

Per task (all must hold before `/close-task`):

- Every case is Pass, or Blocked with a recorded owner acceptance in the "Blocked at close" table
  of the test report (see "Conventions").
- Evidence is stored for every case in `docs/tests/Txx/evidence/`.
- No open Critical or High defect in `docs/tests/defects.md`. Low defects are fixed or have a ticket
  in a named later task. A Medium defect is fixed, or ticketed in a named later task with
  technical-architect agreement.
- The test report is written, states who executed the cases and the commit SHA, and lists every
  `SKIP`. It reads "Signed off" when no case is Fail or Blocked, and "Signed off with accepted
  Blocked cases" when no case is Fail and every Blocked case is listed in a complete "Blocked at
  close" table.
- The traceability rows of the requirements the task verifies are updated (case IDs and status).

Per milestone:

- Every task in the milestone meets its exit criteria.
- The regression suite is green.
- The milestone outcome in `docs/TASKS.md` is demonstrated with evidence (for example M2: CI
  running, DDEV stack up).
- Carried-over Blocked cases are scheduled in a named task and every such case Passes before the
  gate that depends on it. All Blocked cases must Pass by T32 (FR-29, zero gaps).

## Defect severity scale

This table is the single source of severity. `docs/tests/defects.md` links here and repeats the
same meanings next to its triage times.

| Severity | Meaning | Examples |
|---|---|---|
| Critical | Data loss, security breach, wrong financial result, or any live-order capability | A secret in git history, a path to a broker, a wrong P&L figure, lost records |
| High | Core function broken with no workaround | The daily run cannot finish, the dashboard cannot log in |
| Medium | Function impaired, workaround exists | A filter fails but export works, a retry needed |
| Low | Cosmetic or documentation issue | A typo, a misaligned label |

## Defect workflow

Defects are logged in `docs/tests/defects.md` using `docs/templates/defect.md`. A failed case
(Fail) creates a defect; a Blocked case does not. The log defines who moves each state and the
triage times.

States, in order: Open, Triaged, In progress, Fixed, Retest passed, Closed, Reopened, Won't fix.

- The tester opens a defect (Open) and retests it. Only the tester moves a defect to Retest
  passed, with evidence in the report or the evidence folder.
- The technical-architect triages (Triaged). The developer takes it (In progress) and marks it
  Fixed with the fix commit.
- A failed retest moves the defect to Reopened.
- Won't fix for a Critical or High defect needs a solution-architect decision.
- Defects differ from review findings (Blocker, Major, Minor, Note), which are raised in
  `docs/tasks/Txx/review.md` and resolved in the same task. A Fail in a test report is a defect.

## Regression suite

The regression suite is what CI runs to detect that a change broke something that worked. T08
implements the jobs in `ci.yml` (and the heavier-set triggers). This plan defines the content.

**PR set** (every pull request and push, no live network, aim for NFR-07: at most 10 min on a
clean cache, 6 min warm):

- Engine unit tests and engine integration tests that need only Postgres, with pytest-socket
  and the no-network container.
- Drupal Unit and Kernel tests (PHPUnit).
- Vitest component tests.
- Contract tests against fixtures: Spectral on `openapi.yaml` and openapi-core on committed
  example payloads.
- The static broker check (FR-11), gitleaks and `scripts/check-names.sh`.
- Docs checks: the docs-task `run-checks.sh` scripts in `--regression` mode (below), plus the T01
  path-guard unit tests.

**Reports:** every PR-set and heavier-set job writes JUnit XML (pytest, PHPUnit, Vitest,
Playwright) and the coverage reports, and uploads them as workflow artifacts. T08 implements this.

**Heavier set** (Functional, Playwright and `ddev e2e`; needs the full stack):

- Drupal Functional tests, Schemathesis (marker `drupal_live`), Playwright end-to-end and
  accessibility tests, `ddev e2e`.
- Before `/close-task` of a task that changes `apps/drupal`, `apps/web` or the ingest contract, the
  heavier set is green on the task branch (by label or dispatch), and the run is linked in the
  test report.
- Trigger: a nightly schedule, a manual dispatch, and a push to main (merge to main). A pull
  request can run it by label.
- Performance and manual cases are not part of either set.

**Docs-task checks and `--regression` (decision D-5; new rule, not yet used by T00 to T03).**
Each docs-task `run-checks.sh` accepts `--regression`. Every check is tagged either invariant
(must hold for the rest of the project) or snapshot (true only at the close of its task: git
order, comparison with a named branch, exact counts that may grow, wording pending an owner
decision). In regression mode, snapshot checks do not run. The script prints the count of
excluded checks and the reason, and exits non-zero on any invariant failure. Excluded checks are
not `SKIP`s (SKIP is for optional tools only). Retagging a check from invariant to snapshot, or
loosening an exact check into a bound, needs a Change log entry naming the later task that
changed the content. T08 retrofits tagging into T00 to T03 (with Change log entries) and wires
the job; the technical-architect reviews each retag.

Failure rule: a red PR set blocks merge. A red heavier set creates a defect; High if it blocks a
milestone gate.

## Test data strategy

Four kinds of data plus one shared file. All data is deterministic and committed.

**Fixtures (general).** Owner: the task that first needs them. Location: next to the component
tests (`services/engine/tests/fixtures`, Drupal `tests/` folders, `apps/web/e2e` fixtures). A
manifest per set records source, capture date, capture command, symbols, dates and a SHA-256 per
file. Refresh rule: a refresh is a new set with a new manifest; existing sets are never edited
in place, so old tests stay reproducible.

**Recorded market data.** Committed JSON or CSV under `services/engine/tests/fixtures/market/`
for named dates, chosen by T15 and T20 (the NSE holiday source is cited). Required sets:

- a normal trading day;
- an NSE trading holiday on a weekday (FR-23: status `skipped` with a reason, 0 decisions);
- a no-new-candle date, where the source returns the previous bar (FR-23);
- an HTTP 429 sequence (NFR-19: at most 3 retries with backoff, the run continues for other
  symbols);
- missing fundamentals, stale data and a non-positive price (T15 data quality checks).

Tests use a provider fixture, not a recorded HTTP exchange. Capture is a manual, owner-run step
with network, never in CI. Prefer synthetic or hand-built data for logic tests. Real captures are
kept to the minimum the adapter parsing tests need, until the redistribution question
(OQ-T04-2) is answered by the owner in T15.

**Fake LLM responses.** Committed files served by the T17 fake client, not by respx. One response
per failure type (FR-06): malformed, empty, timeout, API error, schema violation. Plus the
prompt-injection set (FR-07), with at least one case per untrusted input field (headline text,
LLM output). A valid-veto and a valid-pass response complete the set.

**Seeded Drupal content.** The 5,000-record set for NFR-03 and NFR-05, built by a seed script
owned by T11 and reused by T25 and T26. The seed is generated from a fixed random seed, so any
two runs give the same records. The record count goes into the evidence.

**Golden parity file (T13).** A committed file of expected scores and actions for the MVP parity
set. T13 compares the new engine to it; a change to the file needs a reviewed reason.

**Rules for all data:** no real secrets (fake tokens only, from `.env.example`); no live network
in CI; data is deterministic (fixed dates, fixed seeds, no wall clock without an injected
clock); personal data is never used.

## Reconciliation

Reconciliation proves that numbers agree across hops. It is used by T27 (full stack on DDEV) and
T31 (every trading day of the window), with parts earlier in T19, T23 and T25.

Method: take the engine output for one trade date as the reference, then compare at each hop.

| Hop | Compare | Tolerance |
|---|---|---|
| Postgres to Drupal (FR-14) | Record counts and key values (symbol, date, mode, score, action) for decisions, positions and runs, after a publish | 0 differences |
| Engine `report` to the dashboard (FR-18) | Amounts (capital, P&L, costs) and returns (percent) shown in the UI against `report` output | 0.01 for amounts (rupees), 0.01 percentage points for returns |
| Drupal to the UI | The values the dashboard reads from Drupal against the Drupal record | as above |

Rules: the script prints each difference with the key and both values and exits non-zero on any
breach. Tolerance never widens to make a case pass. Output goes to the evidence file.

## Conventions

Codified from the practice of T00 to T03. A rule marked **new** has not been used yet.

### Statuses

Pass, Fail, Blocked, Not run. Fail means the product, document or script is wrong and creates a
defect. Blocked means a precondition or tool is missing (no network, no DDEV, a tool not
installed, an owner action pending); it is not a product fault. A Blocked case keeps its
criterion open. A report with any Fail case is "Not signed off". A report with Blocked cases is "Not
signed off"
until each is listed in a complete "Blocked at close" table (below); it then reads "Signed off with
accepted Blocked cases".

### Owner-run cases

A case the executing context cannot run (for example Spectral without network) is typed
"Owner-run". It gives the exact command, the expected output and the evidence path. The owner
runs it and stores the output, with the tool version, in `evidence/`. Until then it is Blocked.

### Main-session execution and independence

When an agent lacks a tool or a restart is needed, the main session executes the case, and
"Executed by" names who ran it (for example "tester (role played by the main session)"). The
cases are executed by a session other than the one that authored the documents under test
(independence); the report states who executed. Where this was not possible, the report records
the deviation.

### Evidence naming

`evidence/TC-Txx-nn.txt` for one case. `evidence/run-checks.txt` for the full script output. A
`-static` suffix for evidence from reading files without running the product, and a
`-spotcheck` suffix for a sampled comparison (for example `TC-T02-34-main-session-spotcheck.md`).
`manual-review.md` collects manual case notes. Retests add the defect ID
(`DEF-nnn-retest.txt`).

### Script style (`run-checks.sh`)

No vacuous pass: a missing file or section fails. A non-zero exit when any check fails. `SKIP`
is allowed only for optional tools (pre-commit, markdownlint), and the report lists every SKIP.
Checks are designed from the criteria before the documents exist, and the script is committed
before authoring (git order).

### Change log and no loosening

A script defect found later is fixed only through a "Change log" row in `test-cases.md`. A check
may never be loosened to hide a content gap; a gap is a defect in the content. **New:** tags
`ckp`/`pyp` (invariant) and `cka`/`pya` (snapshot) and the `--regression` flag (see "Regression
suite").

### Live-API cases

A case that calls a live service (the T17 real-LLM smoke test, owner-run market data capture) is
manual, marked "Manual" and "live", and never run in CI. Its evidence is the redacted output; no
key is stored.

### Blocked at close

Precedent (T00 to T02): the task closed with Blocked cases, each accepted by the owner, case by
case. The test report lists them in a "Blocked at close" table with the columns case ID,
criterion, block reason, owner who accepted, date, and a reference to the owner's own message.
The main session records the acceptance but cannot give it.

**Pending owner confirmation (decision D-6, not adopted).** The solution-architect recommends a
fixed policy: a task may close with Blocked cases only when (1) the block is environmental or
an owner action, never a defect; (2) the case is not a safety check (FR-11, NFR-10); (3) the
owner accepts in writing; (4) each case names the earliest task that re-runs it; (5) the
criterion stays open and the TRACEABILITY status reads `Blocked (accepted, re-run in Txx)`; (6)
no Critical or High defect is open and every such case passes before the gate that depends on it
and by T32. This policy takes effect only after the owner confirms it in their own message (open
question OQ-T04-1). Until owner confirmation, the T00 to T02 precedent above is the rule.

## Decisions needed

None open for the content of this plan except the owner confirmation of decision D-6 (above) and
the questions OQ-T04-2 to OQ-T04-5 in the decision record, each with a named resolving task.
