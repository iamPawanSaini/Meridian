# T00: Repository scaffold and documentation skeleton, Test cases

| Field | Value |
|---|---|
| Task | T00 |
| Author | tester (role played by the main session; the agents do not exist until T01) |
| Date | 2026-11-01 |
| Criteria source | `docs/TASKS.md` T00 |

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: Folder structure from section 4, README in each top-level folder | TC-T00-01 |
| AC2: Templates for plan, review, test cases, test report, defect, ADR, runbook | TC-T00-02 |
| AC3: PROGRESS lists T00 to T33; TRACEABILITY lists R-01 to R-12 | TC-T00-03 |
| AC4: Pre-commit runs secret scanning and formatting; a fake-key commit is rejected | TC-T00-04, TC-T00-05 |
| AC5: `.gitignore` excludes `.env`, DB dumps, `*.db`, `node_modules`, `vendor`, `records/` | TC-T00-06 |
| AC6: Names follow section 0; the placeholder-name grep returns nothing | TC-T00-07 |
| AC7: `CLAUDE.md` states goal, simulation-only rule, layout, commands, loop, doc locations | TC-T00-08 |

Cases TC-T00-01, 02, 03, 06, 07 and 08 are automated in `docs/tests/T00/run-checks.sh`.

### TC-T00-01: Folder structure and READMEs

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Preconditions | Clean checkout of `task/T00-scaffold` |
| Steps | `docs/tests/T00/run-checks.sh` (section TC-T00-01) |
| Expected result | Every section 4 directory exists. `README.md` exists in `.claude`, `.ddev`, `apps`, `services`, `docs`, `.github`, `scripts` and in each `docs/` subfolder. |

### TC-T00-02: Templates contain the Appendix B fields

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Steps | `docs/tests/T00/run-checks.sh` (section TC-T00-02) |
| Expected result | The 7 templates exist, and each contains every minimum field from Appendix B. |

### TC-T00-03: Progress board and traceability matrix

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Steps | `docs/tests/T00/run-checks.sh` (section TC-T00-03) |
| Expected result | PROGRESS has exactly the 36 task IDs in TASKS.md (T00 to T33 plus T04a and T21a), each with a status. TRACEABILITY has R-01 to R-12. |

### TC-T00-04: Commit with a fake key is rejected

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Preconditions | `scripts/bootstrap-dev.sh` has run successfully |
| Steps | `scripts/demo-secret-scan.sh docs/tests/T00/evidence/TC-T00-04-secret-scan.txt` |
| Expected result | The control commit succeeds. The commit with a generated `ghp_` token fails with a gitleaks finding. The script prints `RESULT: PASS` and exits 0. |

### TC-T00-05: Pre-commit hooks pass on the tree

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Preconditions | Bootstrap done |
| Steps | `.tools/pre-commit run --all-files 2>&1 \| tee docs/tests/T00/evidence/TC-T00-05-pre-commit.txt` |
| Expected result | All hooks report Passed: gitleaks, trailing-whitespace, end-of-file-fixer, mixed-line-ending, the check-* hooks and meridian-check-names. |

### TC-T00-06: Ignore rules

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Steps | `docs/tests/T00/run-checks.sh` (section TC-T00-06, uses `git check-ignore`) |
| Expected result | `.env`, `x.sql`, `x.sql.gz`, `x.dump`, `x.db`, `node_modules/x`, `vendor/x`, `records/x`, `apps/web/node_modules/x` and `apps/drupal/vendor/x` are ignored. `.env.example` is not ignored. |

### TC-T00-07: Naming

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Steps | 1. `scripts/check-names.sh` 2. Negative check: write a temp file containing a stale name, rerun, then delete it |
| Expected result | Step 1 exits 0. Step 2 exits 1 and lists the temp file. |

### TC-T00-08: CLAUDE.md content

| Field | Value |
|---|---|
| Linked criterion | AC7 |
| Steps | `docs/tests/T00/run-checks.sh` (section TC-T00-08) |
| Expected result | CLAUDE.md has sections for goal, simulation-only rule, repository layout, commands, per-task loop, and where documents live. |

## Change log

| Date | Change | Reason |
|---|---|---|
| 2026-11-02 | `run-checks.sh`: `cd` now exits when it fails (SC2164) and a deliberate eval'd variable carries an inline SC2034 suppression that cites T04a. No check was added, removed or loosened. | DEF-004: the T04a baseline must be clean under the real hooks. |
