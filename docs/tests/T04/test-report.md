# T04: Master test plan and test infrastructure design, Test report

| Field | Value |
|---|---|
| Task | T04 |
| Build or commit | `61e52f1` (design 418ad25, documents d440e55, review fixes 36cde37, review approval 61e52f1) |
| Environment | Linux 6.18 (WSL2), bash, Python 3.10.12, git 2.34.1; agent sandbox, no network, no DDEV, no CI. `pre-commit` and `markdownlint` not installed |
| Date | 2026-11-01 |
| Executed by | tester (execution session). Not the session that authored the master plan, TRACEABILITY table or defect workflow. This session designed the cases (418ad25) and did not edit any production document |

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T04-01 | AC1 eight levels | Pass | `evidence/TC-T04-01.txt` |
| TC-T04-02 | AC1, PX sections | Pass | `evidence/TC-T04-02.txt` |
| TC-T04-03 | AC1, AC2 tools per component | Pass | `evidence/TC-T04-03.txt` |
| TC-T04-04 | AC2 decisions D-2 to D-4 | Pass | `evidence/TC-T04-04.txt` |
| TC-T04-05 | PX layout | Pass | `evidence/TC-T04-05.txt` |
| TC-T04-06 | AC1 environments | Pass | `evidence/TC-T04-06.txt` |
| TC-T04-07 | AC1 entry and exit | Pass | `evidence/TC-T04-07.txt` |
| TC-T04-08 | AC1, AC6 severity single source | Pass | `evidence/TC-T04-08.txt`, `TC-T04-08-helpers.txt` |
| TC-T04-09 | AC3 regression suite | Pass | `evidence/TC-T04-09.txt` |
| TC-T04-10 | AC4 test data | Pass | `evidence/TC-T04-10.txt` |
| TC-T04-11 | PX reconciliation | Pass | `evidence/TC-T04-11.txt` |
| TC-T04-12 | PX conventions (keywords) | Pass | `evidence/TC-T04-12.txt` |
| TC-T04-13 | AC6 defect workflow | Pass | `evidence/TC-T04-13.txt`, `TC-T04-13-helpers.txt` |
| TC-T04-14 | AC5 table and ID set | Pass | `evidence/TC-T04-14.txt` |
| TC-T04-15 | AC5 cells and cross-checks | Pass | `evidence/TC-T04-15.txt`, `TC-T04-15-helper.txt` |
| TC-T04-16 | AC5, C5 R rows link | Pass | `evidence/TC-T04-16.txt` |
| TC-T04-17 | AC5 high-risk row spot checks | Pass | `evidence/TC-T04-17.txt` |
| TC-T04-18 | C5, PX columns unchanged (at-close) | Pass | `evidence/TC-T04-18.txt`, `TC-T04-18-helper.txt` |
| TC-T04-19 | AC5 checker self-test | Pass | `evidence/TC-T04-19.txt`, `TC-T04-19-helper.txt` |
| TC-T04-20 | C5 README link | Pass | `evidence/TC-T04-20.txt` |
| TC-T04-21 | C1, PX design before authoring (at-close) | Pass | `evidence/TC-T04-21.txt` |
| TC-T04-22 | C4 check-names | Pass | `evidence/TC-T04-22.txt` |
| TC-T04-23 | SIM no broker names | Pass | `evidence/TC-T04-23.txt` |
| TC-T04-24 | C4, C6 secrets, markers, links | Pass (2 SKIP) | `evidence/TC-T04-24.txt` |
| TC-T04-25 | PX decisions D-1 to D-6 | Pass | `evidence/TC-T04-25.txt` |
| TC-T04-26 | AC5 sample of 10 planned tests | Pass | `evidence/TC-T04-26.txt`, `manual-review.md` |
| TC-T04-27 | PX conventions faithful | Pass | `evidence/TC-T04-27.txt`, `manual-review.md` |
| TC-T04-28 | AC1 to AC4 serves T08 to T31 | Pass (observations) | `evidence/TC-T04-28.txt`, `manual-review.md` |
| TC-T04-29 | AC3, C7 --regression behaviour | Pass | `evidence/TC-T04-29*.txt` |
| TC-T04-30 | C7 clean checkout | Pass | `evidence/TC-T04-30.txt`, `TC-T04-30-regression.txt` |
| TC-T04-31 | C1, C2 independence and review | Pass | `evidence/TC-T04-31.txt` |
| TC-T04-32 | C3 evidence completeness | Pass | `evidence/TC-T04-32.txt` |

Totals: 32 pass, 0 fail, 0 blocked, 0 not run.

Script totals: full mode 124 checks, 124 PASS, 0 FAIL (`evidence/run-checks.txt`). `--regression` mode 118 invariant checks executed, 6 at-close checks excluded (TC-18 x1, TC-21 x3, TC-25 x2), all PASS (`evidence/run-checks-regression.txt`). Clean clone gives the same results. The design-time run (117 FAIL, 9 PASS, `evidence/design-time-run.txt`) shows the checks failed before authoring. No script or helper changed after 418ad25.

SKIPs (optional tools, not Blocked): `pre-commit` (`.tools/pre-commit` missing) and `markdownlint` not installed, both in TC-T04-24 and both in the clean clone.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| (none) | | |

## Blocked at close

None. No case is Blocked, so no owner acceptance is needed and decision D-6 (pending owner confirmation) does not apply to this report. Nothing here rests on D-6.

## Coverage notes

- Not covered by a tool: pre-commit hooks (secret scan, EOF/whitespace) and markdownlint on the T04 documents did not run. The script's own secret-pattern grep, marker grep and link check passed. The owner or CI should run `.tools/pre-commit run --all-files` after `scripts/bootstrap-dev.sh`; this is a re-run for C4, not a Blocked case under the case wording ("pre-commit and markdownlint clean if installed").
- Content quality of the plan is tested structurally by the script and by sampling (TC-26, 27, 28). Rows beyond the 10 sampled and 17 spot-checked were checked only for structure, task and level.
- Observations for later plans (recorded in `evidence/manual-review.md`, not defects): T27 failure-injection runs, T30 XSS/CSRF probing and the T26 keyboard-only walkthrough are not named in the master plan; the T30, T26 and T27 plans must specify the method. `docs/TASKS.md` T09 lists three roles while FR-16 and T03 fix four; the T09 plan must use four.
- Tool choices (Schemathesis, openapi-core, pytest-socket, web-vitals and others) are unverified as installable; they are confirmed by T04a and T08 as the plan says.
- The at-close checks (TC-18, TC-21, TC-25 D-6 wording) are true only at this commit; later runs should use `--regression`.

## Sign-off

Signed off: all 32 cases pass with stored evidence, no case is Fail or Blocked, and no defect is open. Optional tool SKIPs (pre-commit, markdownlint) are listed above. Tester (execution session), 2026-11-01.
