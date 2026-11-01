# scripts

Repository tooling. Every script runs from any directory inside the repo.

| Script | Purpose |
|---|---|
| `bootstrap-dev.sh` | Installs pinned pre-commit into `.tools/` (git-ignored) and installs the git hooks |
| `tool-versions.env` | Pinned tool versions and checksums used by the bootstrap |
| `check-names.sh` | Fails if a stale placeholder project name appears (section 0 naming) |
| `demo-secret-scan.sh` | Shows, in a throwaway repo, that a commit containing a fake key is rejected (T00 evidence) |
| `quality.sh` | Runs every quality check once and prints PASS, FAIL or SKIP per step (T04a) |
| `check_commit_msg.py` | Commit-msg hook and `--range` check: `Txx: summary`, known task ID, 72 characters |
| `check_branch_name.py` | Branch must be `main` or `task/Txx-slug` with a known task ID |
| `exceptions_report.py` | Every lint or type suppression and config exclude must cite a ticket; writes counts |
| `coverage_gate.py` | Cobertura line coverage against `quality/coverage-thresholds.json` |
| `check_assets.py` | No third-party font, style, script or icon hosts, and no hex colours outside tokens |
| `taskids.py` | Shared lookup of task IDs and defect IDs used by the checks above |
| `tests/` | `unittest` tests for the checks: `python3 -m unittest discover -s scripts/tests` |

## quality.sh

`scripts/quality.sh` is the only implementation of "run every check". The pre-commit hooks,
`ddev quality` (from T05, via `.ddev/commands/host/quality`) and CI (T08) all call it.

Steps: `pre-commit run --all-files`; the branch name; the commit range `origin/main..HEAD`;
the exceptions report and the asset check; then one step per component (engine, Drupal, web),
each running lint, types, tests and the coverage gate.

- A step prints `PASS`, `FAIL` or `SKIP`. The summary line counts them. The exit code is
  non-zero when any step fails; later steps still run.
- A component step is `SKIP` only when its manifest is absent (`services/engine/pyproject.toml`,
  `apps/drupal/composer.json`, `apps/web/package.json`). With the manifest present, a failing or
  missing tool is a `FAIL`.
- `QUALITY_RUNNER=native|ddev` chooses where component tools run. T05 and T06 map `ddev` to
  `ddev exec`, `ddev engine` and `ddev next`.
- `QUALITY_STEPS=FILE` replaces the built-in steps with lines of `NAME<TAB>MANIFEST<TAB>COMMAND`
  (`-` as the manifest means always run). The tests use it.
- The commit-range step needs `origin/main` (run `git fetch origin`).

## Check script details

- `check_commit_msg.py --msg-file F` or `--range A..B`, with `--tasks-file` (default
  `docs/TASKS.md`). `Merge ` and `Revert "` subjects are allowed. `fixup!` and `squash!` fail.
- `check_branch_name.py [--branch B]` reads `--branch`, then `GITHUB_HEAD_REF`, then git.
- `exceptions_report.py [--out FILE]` and `check_assets.py` scan the git tree of the current
  directory. The report counts per tool and lists the tickets used.
- `coverage_gate.py --thresholds quality/coverage-thresholds.json COBERTURA.xml`. It reads the
  line rate only, and a file counts towards every component prefix it matches. Cobertura paths
  must contain the prefixes in the thresholds file, for example `meridian_engine/scoring/`.
- The asset check allows hex colours only in the tokens file `apps/web/styles/tokens.css` (T21a
  owns the final allowlist).
