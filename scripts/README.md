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
| `deploy-drupal.sh` | Deploys `apps/drupal` to Pantheon dev (subtree split, non-force push, drush apply, smoke check); `ddev deploy-drupal` and `deploy-drupal.yml` call it (T07). See `docs/runbooks/deploy.md` |
| `pantheon_known_hosts` | Pinned SSH host key of the Pantheon code server for the deploy push (T07). Public data |
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
- The commit-range step needs `origin/main` (run `git fetch origin`) and the full history.

## Check script details

- `check_commit_msg.py --msg-file F` or `--range A..B`, with `--tasks-file` (default
  `docs/TASKS.md`). `Revert "` subjects are allowed, and `Merge` plus a space subjects only on real merge
  commits (more than one parent) in `--range` mode. `fixup!` and `squash!` fail. The rules apply
  from `RULE_START` (the T04 close commit `7689ec5`) on; older commits are exempt. `--rule-start
  REV` overrides it. A shallow clone, or an explicit boundary that is missing, exits 2 with
  "fetch the full history" (CI needs `fetch-depth: 0`).
- `check_branch_name.py [--branch B]` reads `--branch`, then `GITHUB_HEAD_REF`, then git.
- `exceptions_report.py [--out FILE]` and `check_assets.py` scan the git tree of the current
  directory. The report counts per tool and lists the tickets used. The ticket must be in the
  tool's own comment slot (D-4 addendum in `docs/tasks/T04a/decision-t04a-standards.md`); a bare
  ticket after the rule list fails. A `noqa` needs a rule code, an `eslint-disable` a rule name,
  and inline yamllint disables and the TypeScript ignore directive always fail.
- `coverage_gate.py --thresholds quality/coverage-thresholds.json [--require PREFIX] COBERTURA.xml`.
  A component with no matching file prints `not measured`; a `--require` prefix with no match
  fails. `line` in the thresholds file is always a percentage. It reads the
  line rate only, and a file counts towards every component prefix it matches. Cobertura paths
  must contain the prefixes in the thresholds file, for example `meridian_engine/scoring/`.
- The asset check allows hex colours only in the tokens file `apps/web/styles/tokens.css` (T21a
  owns the final allowlist).

## deploy-drupal.sh (T07)

`scripts/deploy-drupal.sh [--ref REF] [--dry-run] [--allow-unmerged] [-h]`. Needs
`PANTHEON_SITE`; uses `TERMINUS_MACHINE_TOKEN` if set. Exit 0 deployed and verified, 1 a step or
check failed, 2 usage error or a ref guard. `--dry-run` splits and checks the tree and prints the
split SHA with no network access. Tests: `scripts/tests/test_deploy_drupal.py` (fake `terminus`
and `curl` on `PATH`, a local bare repository as Pantheon) and
`docs/tests/T07/run-checks.sh`.

The workflow linter is actionlint 1.7.12 (2026-03-30), installed by hand into `.tools/` from the
GitHub release (sha256 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8` for
`actionlint_1.7.12_linux_amd64.tar.gz`). Adding it to CI is T08.
