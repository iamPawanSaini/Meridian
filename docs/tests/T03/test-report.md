# T03: Technical design, Test report

| Field | Value |
|---|---|
| Task | T03 |
| Build or commit | base `1b8a031` plus uncommitted T03 working tree on `task/T03-technical-design` (design Revision 2, review Approved) |
| Environment | Linux 6.18 (WSL2), bash, Python 3 with PyYAML, git 2.34.1, no network; pre-commit, markdownlint, mmdc not installed |
| Date | 2026-11-01 |
| Executed by | tester |

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T03-01 | AC1, AC2, AC4, AC5, AC6, AC7 | Pass | `evidence/TC-T03-01.txt` |
| TC-T03-02 | AC1 | Pass | `evidence/TC-T03-02.txt` |
| TC-T03-03 | AC2 | Pass | `evidence/TC-T03-03.txt` |
| TC-T03-04 | AC2 | Pass | `evidence/TC-T03-04.txt` |
| TC-T03-05 | AC4 | Pass | `evidence/TC-T03-05.txt` |
| TC-T03-06 | AC4 | Pass | `evidence/TC-T03-06.txt` |
| TC-T03-07 | AC3, C4 | Pass | `evidence/TC-T03-07.txt` |
| TC-T03-08 | AC3 | Pass | `evidence/TC-T03-08.txt` |
| TC-T03-09 | AC3 | Pass | `evidence/TC-T03-09.txt` |
| TC-T03-10 | AC3, C4 | Blocked | `evidence/TC-T03-10.txt` |
| TC-T03-11 | AC5 | Pass | `evidence/TC-T03-11.txt` |
| TC-T03-12 | AC5 | Pass | `evidence/TC-T03-12.txt` |
| TC-T03-13 | AC5, PX, C5 | Pass | `evidence/TC-T03-13.txt` |
| TC-T03-14 | AC6, C6 | Pass | `evidence/TC-T03-14.txt` |
| TC-T03-15 | AC6, C6 | Pass | `evidence/TC-T03-15.txt` |
| TC-T03-16 | AC7 | Pass | `evidence/TC-T03-16.txt` |
| TC-T03-17 | PX, C5 | Pass | `evidence/TC-T03-17.txt` |
| TC-T03-18 | AC8, C5 | Pass | `evidence/TC-T03-18.txt` |
| TC-T03-19 | AC9, C2 | Pass | `evidence/TC-T03-19.txt` |
| TC-T03-20 | C4 | Pass | `evidence/TC-T03-20.txt` |
| TC-T03-21 | SIM | Pass | `evidence/TC-T03-21.txt` |
| TC-T03-22 | C4, C6, C7 | Pass | `evidence/TC-T03-22.txt` |
| TC-T03-23 | AC1 | Pass | `evidence/manual-review.md` |
| TC-T03-24 | AC2 | Pass (retest) | `evidence/manual-review.md`, `evidence/DEF-002-demo.txt`, `evidence/DEF-002-retest.txt` |
| TC-T03-25 | AC4 | Pass | `evidence/manual-review.md` |
| TC-T03-26 | AC5 | Pass | `evidence/manual-review.md` |
| TC-T03-27 | AC7 | Pass | `evidence/TC-T03-27.txt`, `evidence/manual-review.md` |
| TC-T03-28 | AC6, PX | Pass | `evidence/manual-review.md` |
| TC-T03-29 | AC1, AC2, AC3 | Pass | `evidence/cross-doc-fields.txt`, `evidence/manual-review.md` |
| TC-T03-30 | C3, C7 | Pass | `evidence/TC-T03-30.txt` |
| TC-T03-31 | C1, C2, C5, AC9 | Pass (re-check, commit 96b4c17) | `evidence/manual-review.md` |
| TC-T03-32 | C7 | Blocked | `evidence/manual-review.md` |

Totals: 30 pass, 0 fail, 2 blocked, 0 not run (32 cases). TC-T03-24 failed on the first run
(DEF-002) and passed on retest after Revision 3.

Blocked cases (none is a document defect; TC-T03-31 was Blocked until T03 was committed and passed
on re-check):

- TC-T03-10 Spectral lint: owner-run, no network. The structural validator (TC-07, 49 checks) and
  its self-test (TC-08) pass, but the documented lint has not been run.
- TC-T03-32 Mermaid render: no renderer available.

Optional tools missing (TC-22): pre-commit and markdownlint, recorded as SKIP, not as pass.

Deviation: TC-T03-30 used a clone plus an overlay of the uncommitted T03 files, not a clone of a
committed branch.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| DEF-002 `uq_runs_date_attempt` collides for a second `publish` or `replay` row on the same date (`docs/tests/defects.md`) | Medium | Retest passed (fix commit pending, main session) |

Script defects fixed during design (not product defects): TC-T03-09 and TC-T03-17 quoting errors,
recorded in the Change log of `test-cases.md`.

## Coverage notes

- All nine acceptance criteria and C1 to C7 have at least one executed case; see the coverage table
  in `test-cases.md`.
- Automated evidence: 355 PASS lines in `evidence/run-checks.txt`, split per case. Helper outputs:
  `validate_openapi.txt`, `selftest_validator.txt`, `check_data_model.txt`, `check_env_parity.txt`.
- Not covered: the real Spectral ruleset run (owner), rendering of the Mermaid diagram,
  commit-history checks, and all runtime behaviour (Drupal, Alembic and Pantheon facts marked
  unverified are confirmed by T07, T09, T10, T14 and T22, not by this task).
- Observation, not a defect: Postgres `prices.source` has no named CHECK although Drupal restricts
  it to `yfinance` or `stub` (suggest `ck_prices_source` in T14).

## Sign-off

**Not signed off.** No case fails and TC-T03-31 now passes (commit 96b4c17, deviation: chronology
judged from file contents because everything landed in one commit). Two cases remain Blocked,
neither a document defect: TC-T03-10 (Spectral lint, owner-run, no network) and TC-T03-32 (Mermaid
render, no renderer). Under the sign-off rule the report stays "Not signed off" until the owner
stores the Spectral output and the diagram render is confirmed or the owner accepts the by-eye
check. tester, 2026-11-01.
