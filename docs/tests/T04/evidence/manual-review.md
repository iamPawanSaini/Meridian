# T04 manual review notes (TC-T04-26 to 32)

Executed by: tester (execution session, independent of the session that authored the master plan; it did design the cases).
Commit under test: 61e52f1 (design 418ad25, docs d440e55, fixes 36cde37, review approval 61e52f1). Date: 2026-11-01.

## TC-T04-26 Sample of 10 planned tests

Different sample from the reviewer's (who used FR-01, FR-05, FR-07, FR-11, FR-25, NFR-14, NFR-15, plus the corrected FR-10, FR-22, NFR-19). I used: FR-03, FR-09, FR-16, FR-17, FR-24, FR-30, NFR-02, NFR-07, NFR-13, NFR-17. Rows read from docs/TRACEABILITY.md; criteria read from docs/TASKS.md.

| Row | Verifying tasks | Level | Judgement |
|---|---|---|---|
| FR-03 | T16 | unit | Realistic. Table-driven unit test that every decision has mode long or short matches T16 (mode-specific logic tested) and T09 field validation. |
| FR-09 | T18 | unit | Realistic. 12 hand-calculated scenarios with expected values computed outside the code is the FR target. |
| FR-16 | T09, T12 | integration; security | Realistic. PHPUnit permission matrix, 100% of cells, 4 roles. Observation: T09 in TASKS.md still says "admin, analyst-read, engine-ingest" (3 roles) while FR-16 and the T03 final list have 4 (dashboard-read). The planned test follows the FR (correct); the T09 plan should use 4. Not a T04 defect. |
| FR-17 | T23, T24, T25 | unit; end-to-end | Realistic. Vitest for component states, Playwright for page states; 4 areas x 3 states. |
| FR-24 | T14, T19 | integration | Realistic. Matches T14 "tested by running twice" and the T19 Drupal side; counts before and after. |
| FR-30 | T12, T22, T23, T24, T25 | integration; end-to-end | Realistic. Notice on every page via Playwright and CSV header line from both Views and dashboard. One pattern per task as required. |
| NFR-02 | T20, T29, T31 | manual simulation | Realistic. Only measurable over the T31 window; the row says so. |
| NFR-07 | T08 | performance | Realistic. Read from GitHub Actions job timings, clean and warm cache, 10 and 6 min; matches T08 "under 10 minutes on a clean cache". Runs only in CI. |
| NFR-13 | T21a | end-to-end | Realistic. Matches the T21a Playwright same-origin assertion. |
| NFR-17 | T27, T32 | end-to-end; manual simulation | Realistic. Timed clean clone, README commands only. |

Result: 10/10 realistic, 0 mismatches (Fail threshold is 2). Pass.

## TC-T04-27 Conventions faithfully capture T00 to T03

Read the Conventions section of master-test-plan.md against the T00-T03 test cases, reports and scripts.

| Practice seen in T00-T03 | Where seen | In conventions |
|---|---|---|
| Statuses Pass/Fail/Blocked/Not run; Blocked keeps criterion open | all reports | Yes (Statuses) |
| Owner-run cases (T00-04/05 hooks, T02-29 secret scan, T03-10 Spectral) Blocked until the owner runs them | T00, T02, T03 reports | Yes (Owner-run cases) |
| "tester (role played by the main session)" as Executed by | T00, T01 reports | Yes (Main-session execution) |
| Evidence naming TC-Txx-nn.txt, run-checks.txt, -static, -spotcheck, manual-review.md, DEF-nnn-retest | T02, T03 evidence dirs | Yes (Evidence naming) |
| No vacuous pass, non-zero exit, SKIP only for optional tools, SKIPs listed | T02, T03 scripts | Yes (Script style) |
| Change log for script defects, never loosen | T03 test-cases Change log | Yes |
| Live API cases manual | T17 plan | Yes (forward-looking, from the plan) |
| Reports with Blocked cases awaiting the owner were "Not signed off" | T00-T03 reports | Yes: Statuses says Blocked without a complete table is Not signed off. "Signed off with accepted Blocked cases" is a new wording tied to the complete table; D-6 itself is marked pending. |
| New rules flagged as new (tags, --regression) | n/a | Yes ("A rule marked new has not been used yet"; flagged again in Regression suite) |

Nothing is described as past practice that T00-T03 did not follow. Pass.

## TC-T04-28 Plan serves the criteria of T08 to T31

Read the test criteria of T08, T10, T11, T15, T17, T26, T27, T30, T31 and checked owner, tool, environment, data and pass rule in the master plan.

- T08: PR and heavier sets, artifacts (Reports paragraph), NFR-07 budget. Covered.
- T10/T11: Schemathesis plus PHPUnit Functional retained; authorisation matrix; seed script owned by T11. Covered.
- T15/T17: recorded fixtures with manifests, 429 sequence, five fake LLM failure types, injection set, valid veto/pass, manual real-LLM smoke test. Covered.
- T26/T30 performance: nearest-rank, raw samples, 5,000 seed, DDEV or dev only. Covered.
- T27: reconciliation hops and tolerances. Covered.
- Observations (not defects: no new level, tool, fixture kind, tolerance or CI job is needed, but later plans must define the method):
  1. T27 "failure-injection runs" (Drupal down, LLM error, provider 429, duplicate run) are not named in the plan; they fit Integration and End-to-end, and the fake-LLM and 429 fixtures exist.
  2. T30 "injection, XSS and CSRF checks" and T26 "keyboard-only walkthrough": the plan names prompt injection but not XSS/CSRF probing or the manual keyboard walkthrough. They fit Security and Manual simulation; the T30 and T26 plans must specify the method (no tool is named for XSS/CSRF probing).
  3. No versions, coverage thresholds or YAML are set (T04a and T08 scope respected).
Recommendation: name these in the `/plan-task` of T26, T27 and T30. Result: Pass with observations.

## TC-T04-29 --regression behaviour

Evidence: TC-T04-29-full.txt (124 checks, pass), TC-T04-29-regression.txt (118 invariant executed, 6 excluded, 0 `[at-close]` lines, pass), TC-T04-29-bogus.txt (exit 2 with usage), TC-T04-29-mutation.txt (scratch clone, planned-tests row NFR-13 deleted: `--regression` exits 1 with the ID-set check FAIL). The 6 excluded checks are TC-18 (1), TC-21 (3), TC-25 (2); no invariant check reads git order or the T03 branch. Pass.

## TC-T04-30 Clean checkout

Cloned the repo at 61e52f1 into a scratch directory under /tmp, fetched `task/T03-technical-design` from the source repo (needed by the at-close comparison), ran the script using only the documented command. Full: 124 checks, all pass, SKIP for pre-commit and markdownlint only (TC-T04-30.txt). Regression: 118 executed, 6 excluded, pass (TC-T04-30-regression.txt). Pass.

## TC-T04-31 Independence, review, sign-off rules

- plan.md Status is Approved; test design commit 418ad25 (14:08) precedes the documents d440e55 (14:12). Test files changed only in 418ad25 (`git log` on the T04 scripts and test-cases.md shows one commit).
- review.md: findings 1 to 11 are marked Fixed (36cde37) and confirmed in the re-review table; 12 to 16 are Notes; no open Blocker or Major.
- Report: executed by the execution tester session, not the authoring session. Pass.

## TC-T04-32 Evidence completeness

`ls` of the evidence folder is in TC-T04-32.txt: every TC-T04-01 to 32 has a non-empty file. The report coverage table lists AC1 to AC6 and C1 to C7. Pass.
