# T04: Master test plan and test infrastructure design, Review

| Field | Value |
|---|---|
| Task | T04 |
| Reviewer | technical-architect |
| Date | 2026-11-01 |
| Commit range | `0fcc640..d440e55` (418ad25 test design, d440e55 authored documents) |
| Plan | `docs/tasks/T04/plan.md`; decisions `docs/tasks/T04/decision-t04-test-strategy.md` (D-1 to D-6) |

## Scope of this review

The review covers the following:

- Files reviewed:
  - `docs/tests/master-test-plan.md`
  - `docs/TRACEABILITY.md` (the R-row links and the "Planned tests" table)
  - `docs/tests/defects.md`
  - `docs/templates/defect.md`
  - `docs/tests/README.md`
- Content was checked against:
  - the T04 criteria
  - section 3.3
  - the plan
  - D-1 to D-6
  - the test-related criteria of T08 to T31
- Independence:
  - `test-cases.md`, `run-checks.sh` and the helpers were committed in 418ad25, before the documents in d440e55.
  - d440e55 does not touch any T04 test file.
- Reviewer runs: `docs/tests/T04/run-checks.sh` executed 124 checks, and all passed (exit 0). The `--regression` mode executed 118 checks and excluded 6 snapshot checks; all passed.
- SKIPs: pre-commit and markdownlint are not installed in the sandbox.
- `scripts/check-names.sh` passes.

**Planned-test sample (10 rows)**, checked against FR/NFR targets and the criteria of the verifying tasks:

- Realistic as planned: FR-01, FR-05, FR-07, FR-11, FR-25, NFR-14 and NFR-15.
- Need a correction: FR-10, FR-22 and NFR-19 (findings 6, 8 and 5).
- NFR-12 was spotted outside the sample (finding 7).

No requirement is untestable as planned. NFR-02 and NFR-06 can be verified only over the T31 window, which is inherent in the requirement.

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `docs/tests/master-test-plan.md:78-79` | The Security pass rule says "A security case may not be Blocked at close". That is D-6 condition (2), stated as adopted. Lines 423-430 say D-6 is **not adopted** and that the T00 to T02 precedent is the interim rule. The precedent includes Blocked secret-scan cases: the T00 secret-scan demo and TC-T02-29. The close gate for T00 and T02 is therefore contradictory today. | Replace the sentence with: "Once D-6 is confirmed by the owner, a security case may not be Blocked at close; until then the T00 to T02 precedent in 'Blocked at close' applies." No check in `run-checks.sh` depends on the old wording. | Fixed (36cde37) |
| 2 | Minor | `docs/tests/master-test-plan.md:223-224` vs `:371-372` | The exit criteria say a report "reads 'Signed off' only when no case is Fail or Blocked". Conventions say it is "Not signed off until the owner accepts the Blocked case". These two sign-off rules conflict for an accepted Blocked case. | Pick one rule and use it in both places. Suggested: "Signed off" requires no Fail. A Blocked case is allowed only when it is listed in a complete "Blocked at close" table, and the report then reads "Signed off with accepted Blocked cases". | Fixed (36cde37) |
| 3 | Minor | `docs/tests/defects.md:50-51` vs `master-test-plan.md:221-222` | `defects.md` gives the Medium fix target as "before task close". The master plan says "Medium and Low defects are fixed or have a ticket in a named later task". | Align them. Suggested: Medium is "before task close, or ticketed in a named later task with technical-architect agreement"; Low stays as is. Change one of the two files, not both differently. | Fixed (36cde37) |
| 4 | Minor | `docs/tests/defects.md` Rules, bullet 2 | "Entries that reach Retest passed stay in the Closed section (DEF-001 and DEF-002 do so)" mixes up the **Closed state** with the **Closed section**. DEF-001 and DEF-002 show status "Retest passed" under the heading "Closed", while the workflow table makes Closed a separate state moved by the main session. | State that the "Closed" section holds entries in Retest passed, Closed or Won't fix. The main session sets Status to Closed at `/close-task` of the task that found the defect. Leave DEF-001 and DEF-002 as Retest passed until their tasks close. | Fixed (36cde37) |
| 5 | Minor | `docs/TRACEABILITY.md`, row NFR-19 | The row counts requests "through the provider fixture". Under D-4 the fixture provider replaces the market-data library, so counting at that level measures no requests to the source and cannot show the retry cap or the backoff. | Reword it: count calls at the market-data library seam inside the T15 adapter (the monkeypatched library call), with a fake 429 sequence and an injected sleep or clock. Assert at most 2 calls per symbol on average, at most 3 retries, and growing delays. | Fixed (36cde37) |
| 6 | Minor | `docs/TRACEABILITY.md`, row FR-10 | "Property test of the accounting invariant" implies a property-based tool (for example Hypothesis) that is not in the tools table. The row also does not cover the FR-10 text "costs apply to both sides, with rates from config". | Reword it to "invariant asserted at every step of every T18 scenario", and add "cost-component unit tests for buy and sell sides, with rates read from config". Alternatively, add Hypothesis to the Engine tool row, with versions pinned in T04a. | Fixed (36cde37) |
| 7 | Minor | `docs/TRACEABILITY.md`, row NFR-12 | The contrast part of NFR-12 is verified by the T21a automated token-pair contrast test, which fails the build below AA. That test is a unit-level test, not axe in Playwright. The row lists the level "end-to-end" only. | Set the level to `unit; end-to-end`. Name the T21a contrast test for the 4.5:1 and 3:1 ratios, and keep axe for the 0 critical or serious violations. | Fixed (36cde37) |
| 8 | Minor | `docs/TRACEABILITY.md`, row FR-22 | FR-22 also requires a manual trigger, and T20 requires that "a manual-dispatch run on a test branch completes". The row covers the cron schedule and the lock only. | Add: `daily-run.yml` declares `workflow_dispatch`, and one manual dispatch completes, with evidence (T20). | Fixed (36cde37) |
| 9 | Minor | `docs/tests/master-test-plan.md:65` | The text says "against DDEV (the stack of T05 to T07)". T07 is the Pantheon dev environment, not part of the DDEV stack. | Change it to "T05 and T06". | Fixed (36cde37) |
| 10 | Minor | `docs/tests/master-test-plan.md` "Regression suite" | T08 requires "test reports uploaded as workflow artifacts". The regression section does not define which reports each job produces. | Add one line: every PR-set and heavier-set job writes JUnit XML (pytest, PHPUnit, Vitest, Playwright) and the coverage reports, and uploads them as workflow artifacts. T08 implements this. | Fixed (36cde37) |
| 11 | Minor | `docs/tests/master-test-plan.md:283-288` | The heavier set runs nightly, on dispatch, on push to main, or by label. A PR that breaks a Drupal Functional or Playwright test could merge and only fail nightly. | Add an exit criterion: before `/close-task` of a task that changes `apps/drupal`, `apps/web` or the ingest contract, the heavier set is green on the task branch (by label or dispatch), and the run is linked in the test report. | Fixed (36cde37) |
| 12 | Note | `docs/tests/defects.md` workflow table | "Closed: moved by the main session" is confirmed. It matches `/close-task`, which the main session runs. No action needed. | None | n/a |
| 13 | Note | `docs/tests/master-test-plan.md` "Regression suite" | The split between the PR set and the heavier set is confirmed. It matches D-2 (Schemathesis heavy), D-3 (no performance in the PR set), D-4 (no-network PR job), D-5 (docs checks in `--regression`) and the NFR-07 budget. Finding 11 adds a close-time condition only. | None | n/a |
| 14 | Note | `docs/tests/master-test-plan.md:416-430` | The Blocked-at-close handling is confirmed. D-6 is recorded as "Pending owner confirmation (not adopted)", the T00 to T02 precedent is the interim rule, and only the owner's own message can adopt it. Finding 1 removes the one place that contradicts this. | None | n/a |
| 15 | Note | `docs/TRACEABILITY.md`, row NFR-14 | The T20 fake-clock test proves the alert logic only. The real 15 min latency and the 19:00 IST missed-run alert can only be shown on GitHub Actions. | The T29 cases must measure wall-clock latency from a real forced failure and a disabled run. No change in T04. | n/a |
| 16 | Note | `docs/TRACEABILITY.md`, row FR-11 | The "generic denylist" wording is correct under CLAUDE.md, which allows no broker domains even in tests. | The T18 plan must design the static check so that the denylist itself names no broker domain or SDK. | n/a |

## Re-review (2026-11-01, commit 36cde37)

| # | Result |
|---|---|
| 1 | Fixed. Security pass rule now applies the D-6 restriction only once the owner confirms it, and otherwise points to the T00 to T02 precedent. No contradiction remains. |
| 2 | Fixed. Exit criteria and Conventions now use the same rule, including "Signed off with accepted Blocked cases". |
| 3 | Fixed. The Medium rule is the same in both files: fixed, or ticketed in a named later task with technical-architect agreement. |
| 4 | Fixed. The defects rules now separate the Closed state from the Closed section. |
| 5 | Fixed. NFR-19 now counts calls at the library seam in the adapter, with an injected sleep or clock. |
| 6 | Fixed. FR-10 now asserts the invariant per scenario step, with buy-side and sell-side cost tests using rates from config. No property-based tool is implied. |
| 7 | Fixed. NFR-12 now lists `unit; end-to-end` and names the T21a contrast test. |
| 8 | Fixed. FR-22 now covers `workflow_dispatch` and one completed manual dispatch run. |
| 9 | Fixed. The DDEV stack is now T05 and T06. |
| 10 | Fixed. A "Reports" paragraph covers JUnit XML and coverage reports uploaded as artifacts. |
| 11 | Fixed. See Note 17 for where the rule is placed. |

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 17 | Note | `docs/tests/master-test-plan.md` "Regression suite" | The heavier-set rule ("green on the task branch before `/close-task`") sits in the Regression suite section, not in Exit criteria. **Accepted:** it names `/close-task` explicitly, and the exit criteria already require evidence for every case and a linked report. | Optional: add a one-line pointer from "Exit criteria" to this rule when the file is next edited (for example in the T08 retrofit). Not required for T04. | Accepted |
| 18 | Note | `docs/tests/master-test-plan.md:381` | One reflowed prose line is about 115 characters. There is no markdownlint config yet. | T04a sets the line-length rule and the baseline. Fix it then if the rule flags it. | n/a |

Other checks:

- Commit 36cde37 changes nothing under `docs/tests/T04`.
- The reviewer reran `run-checks.sh`:
  - Full mode: 124 checks executed, all passed.
  - `--regression` mode: 118 checks executed, all passed, 6 snapshot checks excluded.

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | The plan is approved. The test design (418ad25) was committed before authoring (d440e55). |
| C2 Review findings resolved | Yes | Findings 1 to 11 were fixed in 36cde37 and re-reviewed. Notes need no action. |
| C3 Criteria mapped to executed tests | Pending | The cases exist (TC-T04-nn). Execution and the report are due in `/test-task` by a session other than the author. |
| C4 CI green | Pending | There is no CI until T08. `run-checks.sh` passes in full and `--regression` modes. pre-commit and markdownlint were SKIP in the sandbox; the owner runs them, or the case is Blocked. |
| C5 Docs updated | Yes | Master plan, TRACEABILITY (49 rows plus R links), `defects.md`, the template and the README are updated. The R-12 test-case cell gets the T04 IDs at close. |
| C6 No secrets | Yes | The secret-pattern check passes. No new variables, so `.env.example` does not change. |
| C7 Clean-checkout works | Pending | A clean-clone run of `run-checks.sh` is part of `/test-task`. |

## Approval

**Approved (re-review, commit 36cde37).** No Blocker or Major finding is open. These items remain for `/test-task` and `/close-task`:

- C3 and C7: an independent tester executes the cases, including the clean-clone run.
- C4: the owner runs pre-commit and markdownlint, or the case is recorded as Blocked.
- OQ-T04-1: owner confirmation of D-6, due before close.

The master plan Status line is set to Approved.

technical-architect, 2026-11-01.

Earlier verdict (first review), kept for the record: Changes requested. Finding 1 (Major) must be fixed. Fix findings 2 to 11 in the same change: each is a one-line or one-row edit, and none needs a change to the T04 checks. If a check does fail after these edits, record it in the `test-cases.md` Change log without loosening anything. The master plan Status line stays "Draft for review" until a re-review approves it.

technical-architect, 2026-11-01.
