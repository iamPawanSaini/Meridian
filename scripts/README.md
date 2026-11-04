# scripts

Repository tooling. Every script runs from any directory inside the repo.

| Script | Purpose |
|---|---|
| `bootstrap-dev.sh` | Installs pinned pre-commit, gitleaks, actionlint and shellcheck into `.tools/` (git-ignored), each checked against its SHA-256 (the binaries are re-installed from the verified tarball on every run), and installs the git hooks. Run it again after a pin changes |
| `tool-versions.env` | Pinned tool versions and SHA-256 checksums used by the bootstrap, with the source of each value |
| `check-names.sh` | Fails if a stale placeholder project name appears (section 0 naming) |
| `demo-secret-scan.sh` | Shows, in a throwaway repo, that a commit containing a fake key is rejected (T00 evidence) |
| `quality.sh` | Runs every quality check once and prints PASS, FAIL or SKIP per step (T04a) |
| `docs_regression.sh` | The `docs-regression` step of `quality.sh` (T08): runs every `docs/tests/T*/run-checks.sh --regression`, `QUALITY_DOCS_JOBS` at a time. Per-suite output goes to `.tools/reports/docs/` |
| `check_commit_msg.py` | Commit-msg hook and `--range` check: `Txx: summary`, known task ID, 72 characters |
| `check_branch_name.py` | Branch must be `main` or `task/Txx-slug` with a known task ID |
| `exceptions_report.py` | Every lint or type suppression and config exclude must cite a ticket; writes counts |
| `coverage_gate.py` | Cobertura line coverage against `quality/coverage-thresholds.json` |
| `check_ci.py` | CI rules YAML cannot check: group coverage, toolchain parity with DDEV and Pantheon, action pins, documented secret names, least privilege, heavier-set tripwire (T08). Standard library only |
| `check_assets.py` | No third-party font, style, script or icon hosts, and no hex colours outside tokens |
| `deploy-drupal.sh` | Deploys `apps/drupal` to Pantheon dev (subtree split, non-force push, drush apply, smoke check); `ddev deploy-drupal` and `deploy-drupal.yml` call it (T07). See `docs/runbooks/deploy.md` |
| `pantheon_known_hosts` | Pinned SSH host key of the Pantheon code server for the deploy push (T07). Public data |
| `taskids.py` | Shared lookup of task IDs and defect IDs used by the checks above |
| `tests/` | `unittest` tests for the checks: `python3 -m unittest discover -s scripts/tests`. They run in CI as the `tooling-tests` step. Fixtures for `check_ci.py` are in `tests/fixtures/ci/` |

## quality.sh

`scripts/quality.sh` is the only implementation of "run every check". The pre-commit hooks,
`ddev quality` (from T05, via `.ddev/commands/host/quality`) and CI (`ci.yml`, T08) all call it.

`scripts/quality.sh [--group GROUP]... | --list`. `--list` prints `GROUP<TAB>STEP` for every
built-in step in run order and exits 0. `--group G` runs only the steps of group `G`
(repeatable); without `--group` every step runs. An unknown group, a missing group name, or
`--group` together with `QUALITY_STEPS` exits 2.

| Group | Steps |
|---|---|
| `core` | `pre-commit` (with `--show-diff-on-failure`), `branch-name`, `commit-range`, `exceptions`, `assets`, `tooling-tests` (both unittest suites), `secret-history` (gitleaks over the full history, redacted report), `ci-config` (`check_ci.py`) |
| `docs` | `docs-regression`: every `docs/tests/T*/run-checks.sh --regression`; a failing script fails the step and is named |
| `drupal` | `build-drupal` (`composer install`, `composer check-platform-reqs --lock`), `component-drupal`, `component-drupal-tests`, `audit-drupal` (`composer audit --locked --abandoned=report`) |
| `engine` | `build-engine`, `component-engine`, `audit-engine` (all SKIP until T13) |
| `web` | `build-web`, `component-web`, `audit-web` (all SKIP until T21) |

- A step prints `PASS`, `FAIL` or `SKIP`. The summary line counts them. The exit code is
  non-zero when any step fails; later steps still run. A step may print `detail: ...` lines,
  which are shown under its result.
- A component step is `SKIP` only when its manifest is absent. With the manifest present, a
  failing or missing tool is a `FAIL`.
- **Expected SKIPs.** `quality/expected-skips.txt` lists each built-in step that is expected to
  SKIP, one per line with a ticket (`NAME  # Txx: reason`). A SKIP that is not listed is a
  `FAIL` ("unexpected SKIP"). A listed step that runs is a `FAIL` ("... remove the line"), so the
  task that adds a manifest deletes its line and the coverage gate applies at once. A line
  without a ticket, or naming an unknown step, exits 2. With `--group`, only the selected
  groups are checked.
- The `audit-*` steps need network access (the advisory databases are remote). With no network
  `audit-drupal` is a `FAIL`, never a pass. `secret-history` is local. Run one area with
  `--group` when working offline.
- `QUALITY_RUNNER=native|ddev` chooses where component tools run (default `native`; `ddev
  quality` sets `ddev`, which maps to `ddev exec`, `ddev engine` and `ddev next`). The runner
  never changes which steps exist or which SKIP.
- `QUALITY_STEPS=FILE` replaces the built-in steps with lines of
  `NAME<TAB>MANIFEST<TAB>COMMAND` (`-` as the manifest means always run). The tests use it. The
  expected-skips rule does not apply to it. `QUALITY_EXPECTED_SKIPS=FILE` replaces
  `quality/expected-skips.txt` (test hook).
- `docs-regression` (`scripts/docs_regression.sh`) runs the suites one after another
  (`QUALITY_DOCS_JOBS=1`; the value must be an integer of at least 1, otherwise exit 2). CI sets
  `QUALITY_DOCS_JOBS=4` in the `docs` job, where there is no DDEV, to stay inside the 10 minute
  budget. A suite that runs `ddev quality` (T04a) starts a nested run: it leaves out the docs
  group (guard: `QUALITY_NESTED` and `.tools/docs-regression.lock`), so there is no recursion.
  The step also sets `T07_SKIP_NESTED=1`, because T07 would run T02 to T06 again. Locally a full
  `ddev quality` is slow (several minutes) because of these nested runs.
- `GITHUB_STEP_SUMMARY`: when set (it is, on GitHub), a Markdown table of the steps and their
  results is appended to that file, each SKIP row with its reason. The exit code is unchanged.
- Reports are written to `.tools/reports/` (git-ignored): `gitleaks.json` and
  `exceptions-report.txt`. CI adds `quality-<group>.txt` and uploads the directory.
- The commit-range step needs `origin/main` (run `git fetch origin`) and the full history.
- Run `scripts/bootstrap-dev.sh` again after pulling T08: the `secret-history` step needs
  `.tools/gitleaks`, and `.tools/actionlint` is a pre-commit hook.

### Accepted differences between `ddev quality` and CI

CI runs `scripts/quality.sh` natively on `ubuntu-24.04`; `ddev quality` runs the component tools
in DDEV containers (decision `docs/tasks/T08/decision-native-quality.md`, SA-2 condition 4). The
step set is the same and `scripts/check_ci.py` checks that the PHP major.minor and the Composer
version match (later Python and Node). These differences are accepted:

1. The runner OS is Ubuntu, and the DDEV containers are Debian-based.
2. setup-php's PHP extension set can differ from `ddev-webserver`'s.
   `composer check-platform-reqs --lock` (in `build-drupal`) covers what the code needs.
3. The PHP patch level floats in both places.
4. CI installs PyYAML 6.0.3 for the docs suites, while a local run uses the PyYAML of the
   developer's Python (any version that imports as `yaml`).
5. (T09) The Drupal tests need a database. CI starts a MariaDB service container
   (`mariadb:10.6.22`) and sets `SIMPLETEST_DB`. DDEV uses its own MariaDB 10.6 and sets
   `SIMPLETEST_DB` in `.ddev/config.yaml`. `check_ci.py` rule 2 checks that the DDEV database
   type and version, the `pantheon.yml` database version and the CI image share one MariaDB
   major.minor.
6. (T09) The coverage driver differs: CI uses pcov (setup-php `coverage: pcov`). The DDEV web
   image cannot install `php8.3-pcov` (the Sury apt key has expired, checked 2026-11-04), so
   `ddev quality` runs PHPUnit with `php -d zend_extension=xdebug -d xdebug.mode=coverage`.
   Both produce the same Cobertura file for the same gate.

A check that passes in one place and fails in the other is a defect to fix, never a reason to
skip the check. A task that changes `quality.sh` records both `ddev quality` and the CI run.

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
check failed (including a build that is not confirmed), 2 usage error or a guard (unknown
argument, `PANTHEON_SITE` unset, `DEPLOY_SMOKE_BUDGET` not whole seconds, unknown ref, missing
`origin/main`, ref not merged into `origin/main`, no code server key in
`scripts/pantheon_known_hosts`, unexpected `git_url` form).
`--dry-run` splits and checks the tree and prints the
split SHA with no network access. Tests: `scripts/tests/test_deploy_drupal.py` (fake `terminus`
and `curl` on `PATH`, a local bare repository as Pantheon) and
`docs/tests/T07/run-checks.sh`.

The workflow linter is actionlint 1.7.12, pinned with its SHA-256 in `tool-versions.env` and
installed by `bootstrap-dev.sh` (T08). It also runs as a pre-commit hook on `.github/workflows/`.
