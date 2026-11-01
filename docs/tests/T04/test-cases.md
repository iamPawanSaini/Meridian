# T04: Master test plan and test infrastructure design, Test cases

| Field | Value |
|---|---|
| Task | T04 |
| Author | tester (design mode; a different tester session authors the T04 documents) |
| Date | 2026-11-01 |
| Criteria source | `docs/TASKS.md` T04 (AC1 to AC6) and section 3.3 (C1 to C7); approved plan `docs/tasks/T04/plan.md`; decisions `docs/tasks/T04/decision-t04-test-strategy.md` (D-1 to D-6) |

## How to run

- All automated cases: `docs/tests/T04/run-checks.sh 2>&1 | tee docs/tests/T04/evidence/run-checks.txt`. Each automated case is the block headed `== TC-T04-nn`; copy it to `docs/tests/T04/evidence/TC-T04-nn.txt`. The script exits non-zero if any check fails. It prints `SKIP` only for optional tools (pre-commit, markdownlint), which the report must list.
- Regression mode (decision D-5): `docs/tests/T04/run-checks.sh --regression` runs only the checks tagged `ckp`/`pyp` (invariant, "permanent") and skips those tagged `cka`/`pya` (snapshot, "at-close"). It prints how many were excluded. Excluded checks are not `SKIP`s in the optional-tool sense. The snapshot checks are: git order (TC-T04-21), comparison with `task/T03-technical-design` (TC-T04-18) and the pending-owner-confirmation wording (TC-T04-25). Everything else is invariant, including the 49-row ID-set and task-equality checks.
- Helpers (python3 stdlib only, run from the repo root): `python3 -I docs/tests/T04/check_trace.py all`, `python3 -I docs/tests/T04/check_defects.py severity|states|workflow|legacy|meanings`, `python3 -I docs/tests/T04/selftest_trace.py`.
- Manual cases (26 to 32): performed at execution; notes and command output go to `evidence/TC-T04-nn.txt`.
- Designed from the criteria, plan and decisions before the documents existed. Today the script fails every content check (117 FAIL, 9 PASS, in `evidence/design-time-run.txt`). The checks that pass today guard existing files: `check-names.sh`, the `DEF-001`/`DEF-002` entries, the R table header, the checker self-test, the no-trading-host grep on the scripts, the 49 IDs in `solution-architecture.md`, and (at-close) the unchanged-columns comparison. No check passes on a missing file.
- Execution must be by a session other than the one that authored the documents (plan step 7). The report states who executed.

### Assumed layout (raise a defect if the author deviates, never loosen the script)

- `docs/tests/master-test-plan.md`: `#` headings for Test levels (with one sub-heading per level: Unit, Integration, Contract, End-to-end, Security, Performance, Data reconciliation, Manual simulation), Tools per component (a Markdown table whose first cell is the component: Engine, Drupal, Next.js, Contract, Security, Performance), Test layout, Environments (with a level-by-environment table), Entry criteria, Exit criteria, Defect severity scale (table: Severity, Meaning), Regression suite, Test data strategy, Reconciliation, Conventions, and a heading containing "defect" for the workflow states. A level sub-section is at least 200 characters, names owning tasks (`Tnn`) and a pass rule.
- `docs/TRACEABILITY.md`: heading "Planned tests", then a 7-column table: ID, Parent R, Verifying task, Level(s), Planned test, Planned case ID or pattern, Status. Verifying tasks are comma separated in the order of `solution-architecture.md`. The case cell has one `TC-Txx-*` pattern per verifying task. Levels come from: unit, integration, contract, end-to-end, security, performance, data reconciliation, manual simulation, docs check (`docs check` is added for FR-28/FR-29, which are verified by documents, not product tests). Status: Planned, Partially verified, Verified, `Blocked (accepted, re-run in Txx)`.
- `docs/tests/defects.md`: a transitions table whose first cell is each of the 8 states with the role that moves it; a triage SLA table with one row per severity and a number with a unit; rules; a short section on defects versus review findings; a link to `master-test-plan.md` as the severity source.
- `docs/templates/defect.md`: `Severity` line `Critical / High / Medium / Low`; `Status` line with the 8 states separated by ` / ` in order: Open / Triaged / In progress / Fixed / Retest passed / Closed / Reopened / Won't fix.

## Acceptance criteria (labels used below)

- AC1: `docs/tests/master-test-plan.md` defines test levels (unit, integration, contract, end-to-end, security, performance, data reconciliation, manual simulation), tools per component, environments, entry and exit criteria, defect severity scale
- AC2: tool choices documented: pytest (engine), PHPUnit (Drupal), Vitest and Playwright (Next.js), OpenAPI contract tests, axe for accessibility
- AC3: regression suite definition and how it runs in CI
- AC4: test data strategy: fixtures, recorded market data, fake LLM responses, seeded Drupal content
- AC5: traceability matrix has a planned test-case column for every requirement (100% requirement coverage planned)
- AC6: defect workflow documented in `docs/tests/defects.md` template
- C1 to C7: common criteria, `docs/TASKS.md` section 3.3 (C4 limited to `check-names.sh`, markdown and secret checks, since CI arrives in T08)
- PX: plan extras (layout, reconciliation, conventions, README row, decisions D-1 to D-6, design-before-authoring order)
- SIM: CLAUDE.md simulation-only rule (no broker names or trading domains)

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: levels, tools per component, environments, entry and exit, severity | TC-T04-01, 02, 03, 06, 07, 08, 28 |
| AC2: tool choices (pytest, PHPUnit, Vitest, Playwright, contract tools, axe) | TC-T04-03, 04, 28 |
| AC3: regression suite and CI | TC-T04-09, 28, 29 |
| AC4: test data strategy (fixtures, recorded market data, fake LLM, seeded Drupal) | TC-T04-10, 28 |
| AC5: planned test for every requirement (100% planned) | TC-T04-14, 15, 16, 17, 19, 26 |
| AC6: defect workflow in `defects.md` and template | TC-T04-08, 13 |
| C1: plan reviewed before writing | TC-T04-21, 31 |
| C2: reviewed, findings resolved | TC-T04-31 |
| C3: every criterion maps to an executed case with evidence | TC-T04-32 |
| C4: check-names, markdown, secret checks clean | TC-T04-22, 24 |
| C5: docs, traceability row updates, README | TC-T04-16, 18, 20 |
| C6: no secrets | TC-T04-24 |
| C7: works from a clean checkout with documented commands | TC-T04-29, 30 |
| PX: layout, reconciliation, conventions, decisions D-1 to D-6, order | TC-T04-05, 11, 12, 18, 21, 25, 27 |
| SIM: no broker names or trading domains | TC-T04-23 |

Negative coverage: checker mutation self-test (15 seeded defects plus empty file plus size guard, 19); empty, placeholder and stub cells rejected (15); wrong parent, task, order, level, pattern and status rejected (15, 19); missing or extra rows rejected (14, 19); removed or altered old TRACEABILITY cells rejected (18); script committed after the plan rejected (21); Dredd, Prism, k6, Locust and vcrpy recorded as not adopted (04); D-6 not adopted before owner confirmation (25); broker names rejected (23).

Automated cases: 01 to 25. Manual or owner-run: 26 to 32. Total 32.

## Cases

### TC-T04-01: Eight test levels, each with owning tasks and a pass rule

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Automated |
| Preconditions | Repo root; `master-test-plan.md` authored |
| Steps | 1. `docs/tests/T04/run-checks.sh` and read the block `== TC-T04-01` |
| Expected result | The file exists; a "Test levels" heading exists; each of unit, integration, contract, end-to-end, security, performance, data reconciliation and manual simulation has a sub-heading of at least 200 characters that names at least one task (`Tnn`) and a pass rule. All PASS. Missing file: every line FAIL |
| Actual result | Block TC-T04-01 of the full run: 10 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-01.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-02: Required top-level sections

| Field | Value |
|---|---|
| Linked criterion | AC1, PX |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-02` |
| Expected result | Headings exist for tools, layout, environments, entry, exit, severity, regression, test data, reconciliation, conventions and the defect workflow |
| Actual result | Block TC-T04-02 of the full run: 11 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-02.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-03: Tools per component

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2 |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-03` |
| Expected result | The tools table has a row per component naming: Engine (pytest, pytest-cov, pytest-socket, respx); Drupal (PHPUnit Unit, Kernel, Functional); Next.js (Vitest, Playwright, axe); Contract (Schemathesis, openapi-core, Spectral); Security (gitleaks, pip-audit, composer audit, npm audit, image scan, static broker check); Performance (web-vitals, Python timing harness). The section says versions are pinned in T04a. A tool named only in prose outside its component row fails |
| Actual result | Block TC-T04-03 of the full run: 8 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-03.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-04: Strategy decisions D-2, D-3 and D-4 recorded

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-04` |
| Expected result | Schemathesis against DDEV, openapi-core in engine tests and T11 extending `openapi.yaml` are stated; Dredd and Prism are marked rejected or not adopted; nearest-rank percentiles with raw samples kept; k6 and Locust not adopted; pytest-socket `--disable-socket` plus a no-network container; vcrpy rejected; market data mocked at the provider boundary |
| Actual result | Block TC-T04-04 of the full run: 5 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-04.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-05: Test layout convention

| Field | Value |
|---|---|
| Linked criterion | PX |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-05` |
| Expected result | Layout lists `services/engine/tests/{unit,integration,contract}` and `tests/fixtures`; `meridian_*/tests/src/{Unit,Kernel,Functional}`; Next.js unit tests next to source and `apps/web/e2e`; docs tasks `docs/tests/Txx/run-checks.sh` |
| Actual result | Block TC-T04-05 of the full run: 4 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-05.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-06: Environments and level-by-environment matrix

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-06` |
| Expected result | Sandbox (no network), DDEV, CI on GitHub Actions (no live market data or LLM) and deployed dev (Pantheon, Vercel) are named. A table has one row for each of the 8 levels showing where it runs |
| Actual result | Block TC-T04-06 of the full run: 3 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-06.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-07: Entry and exit criteria

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-07` |
| Expected result | Entry and exit criteria exist per task and per milestone. Exit needs all cases Pass, or Blocked with a recorded owner acceptance, no open Critical or High defect, and evidence for every case |
| Actual result | Block TC-T04-07 of the full run: 4 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-07.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-08: Severity scale is a single source with identical levels

| Field | Value |
|---|---|
| Linked criterion | AC1, AC6 |
| Type | Automated |
| Preconditions | Master plan authored; `defects.md` and template updated |
| Steps | 1. `python3 -I docs/tests/T04/check_defects.py severity` 2. `python3 -I docs/tests/T04/check_defects.py meanings` |
| Expected result | The master plan severity table lists Critical, High, Medium, Low in that order, each with a meaning of at least 15 characters; the Critical meaning covers live-order capability. `defects.md` links to the master plan and, if it keeps its own table, has identical meanings. The template Severity line is `Critical / High / Medium / Low`. Exit 0 |
| Actual result | Block TC-T04-08 of the full run: 3 PASS, 0 FAIL. Helper output in evidence/TC-T04-08-helper*.txt, exit 0. |
| Evidence | `evidence/TC-T04-08.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-09: Regression suite and CI

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-09` |
| Expected result | The section names `ci.yml`; the PR set (unit, Kernel, Vitest, contract against fixtures, static broker check, docs checks); the heavier set (Functional, Playwright, `ddev e2e`) with a trigger; T08 as implementer; docs `run-checks.sh` scripts run with `--regression`, invariant versus snapshot tags, and that excluded checks are counted |
| Actual result | Block TC-T04-09 of the full run: 6 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-09.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-10: Test data strategy

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-10` |
| Expected result | Fixtures (owner, location, refresh rule); recorded market data (committed JSON/CSV, an NSE holiday, a no-new-candle date, FR-23); fake LLM responses (one per FR-06 failure type: malformed, empty, timeout, API error, schema violation; the FR-07 injection set); seeded Drupal content (5,000 records, NFR-03, NFR-05); golden parity file (T13); rules: no real secrets, no live network in CI, deterministic data |
| Actual result | Block TC-T04-10 of the full run: 7 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-10.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-11: Reconciliation method and tolerances

| Field | Value |
|---|---|
| Linked criterion | PX |
| Type | Automated |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-11` |
| Expected result | FR-14 is 0 differences; FR-18 is 0.01 for amounts and 0.01 percentage points for returns; the hops Postgres, Drupal and UI are named; T27 and T31 are the users |
| Actual result | Block TC-T04-11 of the full run: 2 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-11.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-12: Conventions section codifies T00 to T03

| Field | Value |
|---|---|
| Linked criterion | PX |
| Type | Automated (keywords); content quality is TC-T04-27 |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-12` |
| Expected result | Conventions cover: statuses and the meaning of Blocked; owner-run cases and tool version; main-session execution and "Executed by"; evidence naming (`TC-Txx-nn.txt`, `run-checks.txt`, `-static`, `-spotcheck`); script style (no vacuous pass, non-zero exit, SKIP only for optional tools); Change log and no loosening; live-API cases manual and never in CI (T17); a "Blocked at close" table with owner acceptance; independent execution |
| Actual result | Block TC-T04-12 of the full run: 9 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-12.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-13: Defect workflow in `defects.md` and the template

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Type | Automated |
| Preconditions | `defects.md` and template updated |
| Steps | 1. `python3 -I docs/tests/T04/check_defects.py states` 2. `python3 -I docs/tests/T04/check_defects.py workflow` 3. `python3 -I docs/tests/T04/check_defects.py legacy` |
| Expected result | The 8 states (Open, Triaged, In progress, Fixed, Retest passed, Closed, Reopened, Won't fix) appear in this order on the template Status line, and in `defects.md` and the master plan defect section. Each state has a table row naming the role that moves it. Each severity has a triage SLA with number and unit. Rules: retest by the tester with evidence; Won't fix for Critical or High needs a solution-architect decision; a section separates defects from review findings (Blocker to Note). DEF-001 and DEF-002 stay with valid states. Exit 0 each |
| Actual result | Block TC-T04-13 of the full run: 4 PASS, 0 FAIL. Helper output in evidence/TC-T04-13-helper*.txt, exit 0. |
| Evidence | `evidence/TC-T04-13.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-14: Planned-tests table exists and its ID set equals the FR/NFR set

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated |
| Preconditions | `TRACEABILITY.md` updated |
| Steps | 1. `python3 -I docs/tests/T04/check_trace.py header` 2. `python3 -I docs/tests/T04/check_trace.py ids` |
| Expected result | The IDs in the table equal, as sets and without duplicates, the IDs extracted from `solution-architecture.md` (FR-01 to FR-30, NFR-01 to NFR-19, 49). Neither a missing nor an extra row. Header has 7 columns. Exit 0 |
| Actual result | Block TC-T04-14 of the full run: 3 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-14.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-15: Planned-tests cells and cross-checks

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated |
| Preconditions | As TC-T04-14 |
| Steps | 1. `python3 -I docs/tests/T04/check_trace.py all` (the checks nocells, parents, tasks, levels, patterns, status, text) |
| Expected result | No empty or placeholder cell in 49 rows. Parent R equals that in `solution-architecture.md`. Verifying tasks equal those in `solution-architecture.md` in the same order. Levels are in the controlled vocabulary. The case cell has exactly one `TC-Txx-*` pattern per verifying task. Status is in the vocabulary. The planned-test text is at least 20 characters |
| Actual result | Block TC-T04-15 of the full run: 7 PASS, 0 FAIL. Helper output in evidence/TC-T04-15-helper*.txt, exit 0. |
| Evidence | `evidence/TC-T04-15.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-16: R rows link to their FR/NFR rows; R table intact

| Field | Value |
|---|---|
| Linked criterion | AC5, C5 |
| Type | Automated |
| Preconditions | As TC-T04-14 |
| Steps | 1. `python3 -I docs/tests/T04/check_trace.py rtable` 2. `python3 -I docs/tests/T04/check_trace.py rlinks` |
| Expected result | The R table has its original 8-column header and rows R-01 to R-12. Each R row's Test cases cell contains every FR/NFR whose parent is that R, and its Refined IDs cell equals the set of children in `solution-architecture.md` |
| Actual result | Block TC-T04-16 of the full run: 2 PASS, 0 FAIL. Helper output in evidence/TC-T04-16-helper*.txt, exit 0. |
| Evidence | `evidence/TC-T04-16.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-17: Spot checks on high-risk planned tests

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated |
| Preconditions | As TC-T04-14 |
| Steps | 1. Read block `== TC-T04-17` |
| Expected result | FR-11 is security level, names the static/broker check, and has patterns for T18, T30 and T33; FR-06 names the five failure types; FR-07 names injection; FR-14, FR-18 are data reconciliation; FR-19 to FR-21 security; FR-23 a holiday fixture; NFR-03 performance with LCP/web-vitals; NFR-01, 04, 05, 07 performance; NFR-04 and NFR-05 p95; NFR-10 security with gitleaks; NFR-11 audit or scan; NFR-12 axe and both themes; NFR-18 coverage; FR-28 and FR-29 docs check |
| Actual result | Block TC-T04-17 of the full run: 17 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-17.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-18: Existing TRACEABILITY columns unchanged (snapshot)

| Field | Value |
|---|---|
| Linked criterion | C5, PX |
| Type | Automated, at-close (excluded by `--regression`) |
| Preconditions | Branch `task/T03-technical-design` exists locally |
| Steps | 1. `python3 -I docs/tests/T04/check_trace.py unchanged --base task/T03-technical-design` |
| Expected result | Header identical; for R-01 to R-12 the columns Req, Requirement, Refined IDs, Tasks and Design element are byte-identical to the base; the base Test cases and Evidence text (including the T00/T01 cells in R-12) is still contained in the new cell. Exit 0. Base ref missing: FAIL, not skip |
| Actual result | Block TC-T04-18 of the full run: 1 PASS, 0 FAIL. Excluded in --regression mode. Helper output in evidence/TC-T04-18-helper*.txt, exit 0. |
| Evidence | `evidence/TC-T04-18.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-19: Traceability checker self-test

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated (passes today; guards the checker) |
| Preconditions | None |
| Steps | 1. `python3 -I docs/tests/T04/selftest_trace.py` |
| Expected result | The good miniature passes 11 checks; 15 seeded defects (dropped row, extra row, duplicate row, empty cell, placeholder, wrong parent, wrong task, task order, bad level, missing task pattern, bad status, stub text, missing R link, changed R header, missing section) are each rejected; an empty file and a 2-row table against the 49-row guard are rejected. Exit 0 |
| Actual result | Block TC-T04-19 of the full run: 1 PASS, 0 FAIL. Helper output in evidence/TC-T04-19-helper*.txt, exit 0. |
| Evidence | `evidence/TC-T04-19.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-20: README points to the master plan

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Type | Automated |
| Preconditions | `docs/tests/README.md` updated |
| Steps | 1. Read block `== TC-T04-20` |
| Expected result | The README row for the master plan is a Markdown link `](master-test-plan.md)` and resolves; links in README and `defects.md` resolve |
| Actual result | Block TC-T04-20 of the full run: 2 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-20.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-21: Test design committed before authoring (snapshot)

| Field | Value |
|---|---|
| Linked criterion | C1, PX |
| Type | Automated, at-close |
| Preconditions | Git history of the branch |
| Steps | 1. Read block `== TC-T04-21`; the checks use `git log --diff-filter=A` and `git merge-base --is-ancestor` |
| Expected result | The first commit of `run-checks.sh` and of `test-cases.md` exists, starts with `T04:`, is a different commit from, and an ancestor of, the first commit of `master-test-plan.md`. If `run-checks.sh` changed later, `test-cases.md` has a Change log row. Design not committed: FAIL |
| Actual result | Block TC-T04-21 of the full run: 3 PASS, 0 FAIL. Excluded in --regression mode. |
| Evidence | `evidence/TC-T04-21.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-22: `check-names.sh` passes

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Type | Automated |
| Preconditions | None |
| Steps | 1. `scripts/check-names.sh` |
| Expected result | Exit 0, "check-names: OK". The master plan uses current names (`meridian_engine`, `meridian-web` or `meridian_ingest`) |
| Actual result | Block TC-T04-22 of the full run: 2 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-22.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-23: Simulation only: no broker names or trading domains

| Field | Value |
|---|---|
| Linked criterion | SIM, C6 |
| Type | Automated |
| Preconditions | All T04 documents exist |
| Steps | 1. Read block `== TC-T04-23` (the vendor list is in `run-checks.sh`; it is not repeated here) |
| Expected result | No broker vendor name or trading hostname in the master plan, `TRACEABILITY.md`, `defects.md`, the template, the README or `test-cases.md`. The FR-11 static check is described generically (no vendor names). Missing documents: FAIL |
| Actual result | Block TC-T04-23 of the full run: 3 PASS, 0 FAIL. |
| Evidence | `evidence/TC-T04-23.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-24: No secrets, markers, broken links

| Field | Value |
|---|---|
| Linked criterion | C4, C6 |
| Type | Automated |
| Preconditions | As TC-T04-23 |
| Steps | 1. Read block `== TC-T04-24` |
| Expected result | No secret pattern; no TODO/TBD/FIXME in the master plan; relative links in the master plan and `TRACEABILITY.md` resolve; no external assets; pre-commit and markdownlint clean if installed. `SKIP` lines for missing optional tools are listed in the report |
| Actual result | Block TC-T04-24 of the full run: 4 PASS, 0 FAIL, 2 SKIP (pre-commit and markdownlint not installed). |
| Evidence | `evidence/TC-T04-24.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-25: Decisions D-1 to D-6 reflected; D-6 not adopted early (snapshot for D-6)

| Field | Value |
|---|---|
| Linked criterion | PX |
| Type | Automated (D-1 invariant; D-6 wording at-close) |
| Preconditions | As TC-T04-01 |
| Steps | 1. Read block `== TC-T04-25` |
| Expected result | The master plan states FR/NFR-level planning with 49 rows. The Blocked-at-close policy is labelled pending owner confirmation, and the T00 to T02 precedent is stated as the rule until the owner confirms. If the owner confirms before execution, the author changes the plan and this check through a Change log entry citing the owner's message |
| Actual result | Block TC-T04-25 of the full run: 3 PASS, 0 FAIL. D-6 is marked pending owner confirmation, so this case does not depend on an owner acceptance. |
| Evidence | `evidence/TC-T04-25.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-26: Sample of 10 planned tests is realistic for the later task

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Manual |
| Preconditions | Planned-tests table complete |
| Steps | 1. Pick these 10 rows: FR-01, FR-07, FR-11, FR-13, FR-20, FR-25, NFR-04, NFR-10, NFR-12, NFR-15. 2. For each, open the criteria of its verifying tasks in `docs/TASKS.md` (T10/T12/T13, T17/T30, T18/T30/T33, T20/T27, T10/T11/T22/T30, T19/T20/T29, T10/T30, T30, T21a/T26, T19/T27). 3. Record in the evidence whether the planned test, level and case pattern can be run with the tools and environment available in that task and measures the FR/NFR target as written |
| Expected result | All 10 are realistic: right level and tool, runnable in the stated environment (for example NFR-04 on DDEV with the timing harness, not in the sandbox), measures the stated target (for example FR-07 one injection case per untrusted field), and the case pattern matches a case the later task could write. Any mismatch is a finding; two or more is Fail |
| Actual result | Reviewed 10 rows (FR-03, FR-09, FR-16, FR-17, FR-24, FR-30, NFR-02, NFR-07, NFR-13, NFR-17), a sample different from the reviewer's: 10 of 10 realistic, 0 mismatches. Observation: TASKS.md T09 still lists 3 roles while FR-16 has 4; the planned test follows the FR. |
| Evidence | `evidence/TC-T04-26.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-27: Conventions faithfully capture T00 to T03 practice

| Field | Value |
|---|---|
| Linked criterion | PX |
| Type | Manual |
| Preconditions | Master plan conventions section authored |
| Steps | 1. Read `docs/tests/T00` to `T03` `test-cases.md`, `test-report.md` and `run-checks.sh` (Change logs, "Executed by", Blocked rows, SKIP handling, owner-run rows). 2. List each recurring practice. 3. Tick it off against the conventions section |
| Expected result | Every recurring practice is present and described the way it was used (not idealised): statuses and Blocked semantics, owner-run cases, main-session execution, evidence naming and suffixes, script style, Change log, no loosening, live-API cases. Nothing is added as established practice that T00 to T03 did not follow; new rules (for example `--regression` tagging) are marked as new |
| Actual result | Every recurring T00 to T03 practice is present and described as used; new rules are flagged new. No invented history. |
| Evidence | `evidence/TC-T04-27.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-28: Plan content serves the criteria of T08 to T31

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2, AC3, AC4 |
| Type | Manual |
| Preconditions | Master plan complete |
| Steps | 1. Read the test-related criteria of T08 (CI), T09 to T11 (Drupal, contract), T15 (market data), T17 (fake LLM), T26 (performance, NFR-03/05), T27 (reconciliation, DDEV), T30 (security) and T31 (window) in `docs/TASKS.md`. 2. For each, check the master plan gives the owner, tool, environment, data and pass rule needed to write the cases without new decisions |
| Expected result | No later task needs to invent a level, tool, fixture kind, tolerance or CI job. Any gap is recorded as "Decisions needed" in the plan, not left implicit. The plan does not set versions, coverage thresholds or YAML (T04a, T08 scope) |
| Actual result | Plan gives owner, tool, environment, data and pass rule for T08, T10, T11, T15, T17, T26, T27, T30, T31. Observations (not defects): T27 failure-injection runs, T30 XSS/CSRF probing and the T26 keyboard walkthrough are not named; they fit existing levels and the later plans must specify the method. |
| Evidence | `evidence/TC-T04-28.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-29: `--regression` mode behaves as decision D-5 requires

| Field | Value |
|---|---|
| Linked criterion | AC3, C7 |
| Type | Manual (runs the script twice) |
| Preconditions | All documents authored |
| Steps | 1. `docs/tests/T04/run-checks.sh \| tee docs/tests/T04/evidence/TC-T04-29-full.txt` 2. `docs/tests/T04/run-checks.sh --regression \| tee docs/tests/T04/evidence/TC-T04-29-regression.txt` 3. `docs/tests/T04/run-checks.sh --bogus; echo $?` 4. In a scratch copy, break one invariant (for example delete one planned-tests row) and re-run with `--regression`. Restore the file |
| Expected result | Step 2 prints a NOTE with the excluded count (6 snapshot checks: TC-T04-18 once, 21 three times, 25 twice) and runs only invariant checks; it lists no `[at-close]` lines. Step 3 exits 2 with a usage line. Step 4 exits non-zero in `--regression` mode. The invariant checks are exactly those that stay true after close (confirm none compares with a branch or reads git order) |
| Actual result | Full 124 checks pass; regression 118 executed, 6 excluded, no [at-close] lines; unknown flag exits 2 with usage; with the NFR-13 row deleted in a scratch clone, --regression exits 1. |
| Evidence | `evidence/TC-T04-29-*.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-30: Works from a clean checkout with documented commands

| Field | Value |
|---|---|
| Linked criterion | C7 |
| Type | Manual |
| Preconditions | T04 committed on its branch |
| Steps | 1. `git clone --branch task/T04-master-test-plan /home/pawan/Meridian <scratch dir>` and add the `task/T03-technical-design` branch with `git fetch origin` equivalents from the source repo 2. In the clone run `docs/tests/T04/run-checks.sh` using only the commands in "How to run" |
| Expected result | Same results as in the working tree; no hidden dependency on untracked files. Optional tools missing in the clone are `SKIP`, not FAIL |
| Actual result | Fresh clone of 61e52f1 (plus the T03 branch fetched): full 124 checks pass, SKIP for pre-commit and markdownlint only; regression 118 executed, 6 excluded, pass. |
| Evidence | `evidence/TC-T04-30.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-31: Independence, review and sign-off rules

| Field | Value |
|---|---|
| Linked criterion | C1, C2 |
| Type | Manual |
| Preconditions | Review done |
| Steps | 1. Confirm `docs/tasks/T04/plan.md` Status is Approved and its date precedes the test-design commit (`git log --format='%h %ad %s'`). 2. Open `docs/tasks/T04/review.md`: every Blocker and Major finding is resolved. 3. Open `docs/tests/T04/test-report.md`: the "Executed by" differs from the author session of the master plan; any Blocked case is in a "Blocked at close" table with the owner's own message referenced |
| Expected result | All three hold. A report with any Fail or Blocked case and no recorded owner acceptance is "Not signed off" |
| Actual result | Plan Approved; design commit 418ad25 precedes docs d440e55; test files untouched afterwards; review findings 1 to 11 Fixed and confirmed; execution by a session other than the author. |
| Evidence | `evidence/TC-T04-31.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

### TC-T04-32: Every criterion maps to an executed case with evidence

| Field | Value |
|---|---|
| Linked criterion | C3 |
| Type | Manual |
| Preconditions | Execution complete |
| Steps | 1. For each of TC-T04-01 to 32, check `evidence/TC-T04-nn.txt` exists and is non-empty (`ls -l docs/tests/T04/evidence`). 2. Check the report's coverage table lists all of AC1 to AC6 and C1 to C7 with a Pass case. 3. Check the report records the commit SHA, environment and every SKIP |
| Expected result | 32 evidence files (or `-full`/`-regression` variants for 29); no criterion without a Pass case |
| Actual result | All 32 evidence files exist and are non-empty (ls in TC-T04-32.txt); report coverage table lists AC1 to AC6 and C1 to C7. |
| Evidence | `evidence/TC-T04-32.txt` |
| Status | Pass |
| Date | 2026-11-01 |
| Executed by | tester (execution session) |

## Change log

| Date | Change | Reason |
|---|---|---|
| 2026-11-01 | Design committed (initial version). | None yet. Entries here are required for any later edit to `run-checks.sh` or the helpers. |
| 2026-11-01 | Execution: no change to any script or helper since 418ad25. | `git log` shows one commit for each. |
