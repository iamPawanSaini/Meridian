# T00: Repository scaffold and documentation skeleton, Test report

| Field | Value |
|---|---|
| Task | T00 |
| Build or commit | `task/T00-scaffold` (first T00 commit) |
| Environment | WSL2 Linux 6.18, git 2.34.1, Python 3.10.12 (no pip, no ensurepip), DDEV 1.24.4, Docker available |
| Date | 2026-11-01 |
| Executed by | tester (role played by the main session) |

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T00-01 | AC1 folder structure and READMEs | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-02 | AC2 templates | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-03 | AC3 PROGRESS and TRACEABILITY | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-04 | AC4 fake-key commit rejected | **Blocked** | Pending: `evidence/TC-T00-04-secret-scan.txt` |
| TC-T00-05 | AC4 hooks pass on tree | **Blocked** | Pending: `evidence/TC-T00-05-pre-commit.txt` |
| TC-T00-06 | AC5 ignore rules | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-07 | AC6 naming (positive and negative) | Pass | `evidence/TC-T00-structural.txt` |
| TC-T00-08 | AC7 CLAUDE.md content | Pass | `evidence/TC-T00-structural.txt` |

Totals: 6 pass, 0 fail, 2 blocked, 0 not run.

### Why TC-T00-04 and TC-T00-05 are blocked

The Claude Code session that built T00 was not allowed to download and run third-party
code (the pre-commit zipapp and the gitleaks hook). The project owner must run these two
cases:

```bash
scripts/bootstrap-dev.sh
scripts/demo-secret-scan.sh docs/tests/T00/evidence/TC-T00-04-secret-scan.txt
.tools/pre-commit run --all-files 2>&1 | tee docs/tests/T00/evidence/TC-T00-05-pre-commit.txt
```

Interim manual check for TC-T00-05: a scan of every file found no trailing whitespace and
no CRLF line endings. `docs/TASKS.md` was missing a final newline, which was fixed. The
`.pre-commit-config.yaml` file parses as valid YAML. This does not replace running the hooks.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| (none) | | |

## Coverage notes

- `bootstrap-dev.sh` and `demo-secret-scan.sh` passed a `bash -n` syntax check but have
  not been run yet. Their first run is TC-T00-04 and TC-T00-05.
- TC-T00-07 includes a negative case. A temp file with a stale name made the check exit 1.

## Sign-off

**Not signed off.** 6 of 8 cases pass. T00 stays "In test" until TC-T00-04 and TC-T00-05
have stored evidence.
