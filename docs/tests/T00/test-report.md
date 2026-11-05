# T00: Repository scaffold and documentation skeleton, Test report

| Field | Value |
|---|---|
| Task | T00 |
| Build or commit | Branch `task/T00-retest` at `d05dba2` (includes the DEF-015 fix, `0d6eefe` and `d05dba2`) |
| Environment | WSL2 Linux 6.18; `.tools/pre-commit` 4.7.0, `.tools/gitleaks` and git hooks installed |
| Date | 2026-11-06 |
| Executed by | tester |

This is a retest. The 2026-11-01 report had 6 Pass and 2 Blocked (pre-commit not installed). The
first retest run at `5b966fa` had TC-T00-04 fail (DEF-015). After the fix, TC-T00-04 and
TC-T00-05 were rerun at `d05dba2`, and the structural cases (run at `5b966fa`, 122 PASS) are
unchanged by the fix, which touched only `scripts/demo-secret-scan.sh`.

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T00-01 | AC1 folder structure and READMEs | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-02 | AC2 templates | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-03 | AC3 PROGRESS and TRACEABILITY | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-04 | AC4 fake-key commit rejected | Pass (after DEF-015 fix) | `evidence/TC-T00-04-secret-scan.txt`; failed first run `evidence/TC-T00-04-secret-scan-prefix-run1-failed.txt` |
| TC-T00-05 | AC4 hooks pass on tree | Pass | `evidence/TC-T00-05-pre-commit.txt` |
| TC-T00-06 | AC5 ignore rules | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-07 | AC6 naming (positive and negative) | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-08 | AC7 CLAUDE.md content | Pass | `evidence/TC-T00-structural.txt` |

Totals: 8 pass, 0 fail, 0 blocked, 0 not run.

TC-T00-04: control commit OK, fake `ghp_` commit rejected by gitleaks (rule `github-pat`),
`RESULT: PASS`, exit 0. No fake key is committed or staged in Meridian.
TC-T00-05: all 22 hooks Passed, exit 0.

Note on TC-T00-05: a first run at `d05dba2` exited 1. markdownlint flagged two over-long lines in
my own new `docs/tests/defects.md` entry (fixed), and shellcheck reported "files were modified
by this hook" although `git status` showed no change to any shell script. The rerun after the
markdown fix passed all hooks, and the stored evidence is that run. The shellcheck message did
not recur and is not explained.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| DEF-015: `demo-secret-scan.sh` failed under pre-commit 4.7.0 (`-q`; then SIGPIPE exit 141 on the token generator) | Medium | Retest passed |

## Review finding 1 (`docs/tasks/T00/review.md`)

Finding 1 (pre-commit zipapp SHA-256 not pinned) is substantively resolved. Since T08,
`scripts/tool-versions.env` pins `PRE_COMMIT_SHA256=393488513aed...c885` with its source (the
v4.7.0 release digest), and bootstrap fails on a mismatch. The tester checked that
`sha256sum .tools/pre-commit-4.7.0.pyz` equals the pinned value. The pin was not compared with
the live GitHub release page in this run. Updating the review status belongs to the architect.

## Sign-off

**Signed off.** All 8 of 8 cases pass with stored evidence at `d05dba2`; DEF-015 is Retest passed
(to be Closed by the main session).
