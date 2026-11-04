# .github

GitHub configuration.

| Path | Task | Purpose |
|---|---|---|
| `workflows/ci.yml` | T08 | "Meridian CI": the quality suite by group, tests, coverage gates, history secret scan, dependency audit |
| `workflows/daily-run.yml` | T20 | "Meridian daily run": engine on weekdays at 10:30 UTC (16:00 IST) |
| `workflows/deploy-drupal.yml` | T07 | `deploy-drupal`: runs `scripts/deploy-drupal.sh` for `apps/drupal` to Pantheon dev. Skips itself until the variable `PANTHEON_SITE` is set |

## ci.yml (T08)

"Meridian CI" runs on every pull request to `main`, every push to `main` and on demand
(`workflow_dispatch`). There are no path filters, because a required check must always report.
There is no `pull_request_target` and no `schedule`.

It runs `scripts/quality.sh` natively on `ubuntu-24.04`, not DDEV (decision
`docs/tasks/T08/decision-native-quality.md`). The YAML holds no check logic: each job sets up its
toolchain, then runs `scripts/quality.sh --group <g>` and uploads the reports.

| Job | Group | Setup | Steps (see `scripts/quality.sh --list`) |
|---|---|---|---|
| `core` | `core` | Python 3.12, caches, `scripts/bootstrap-dev.sh` | pre-commit, branch-name, commit-range, exceptions, assets, tooling-tests, secret-history, ci-config |
| `docs` | `docs` | the same, plus `pip install -r scripts/requirements-docs-tests.txt` (PyYAML, which the suites import) | docs-regression (every `docs/tests/T*/run-checks.sh --regression`) |
| `drupal` | `drupal` | setup-php 8.3, Composer, Composer cache | build-drupal, component-drupal, component-drupal-tests, audit-drupal |
| `engine` | `engine` | none yet (T13) | build-engine, component-engine, audit-engine |
| `web` | `web` | none yet (T21) | build-web, component-web, audit-web |
| `ci-ok` | none | none | fails when any of the five jobs failed, was cancelled or was skipped |

The only required status check for `main` is **`ci-ok`**. Later tasks add jobs under it and the
branch setting never changes (`docs/runbooks/ci-secrets.md`, plan KD-10).

- **SKIP.** A step whose component does not exist yet prints `SKIP`. Every expected SKIP is
  listed with a ticket in `quality/expected-skips.txt`. An unlisted SKIP fails the run, and so
  does a listed step that runs: the task that adds a manifest deletes its line there.
- **Artifacts.** Each job uploads `reports-<group>` (14 days, `if: always()`): the log
  `quality-<group>.txt`, and from `.tools/reports/` the `gitleaks.json` report (redacted) and
  `exceptions-report.txt` in `reports-core`. JUnit and coverage files of the components are
  uploaded when they exist (`include-hidden-files: true` is needed because `.tools/` is a hidden
  directory). Artifacts hold tool reports only: no symbol-level decision content (output rule,
  `docs/tasks/T08/decision-repo-visibility.md`).
- **Caches** (`actions/cache`, no setup action caches anything itself): `~/.cache/pre-commit`
  keyed on OS, Python version and the hash of `.pre-commit-config.yaml` and
  `scripts/tool-versions.env`; `.tools/` keyed on the hash of `scripts/tool-versions.env`; the
  Composer cache directory keyed on the hash of `apps/drupal/composer.lock`. `vendor/` is never
  cached. Every job has `timeout-minutes: 10` (NFR-07): do not raise it.
- **Permissions.** `permissions: {}` at the top, `contents: read` per job. No secrets.
- **Checks on the workflow files.** `.tools/actionlint` (a pre-commit hook) and
  `scripts/check_ci.py` (the `ci-config` step) run on every change.

### Pinned toolchain and the record of checked values

Toolchain versions in CI must equal the versions in DDEV and on Pantheon. `scripts/check_ci.py`
rule 2 checks them against this file.

- DDEV Composer version: 2.11.1 (output of `ddev exec composer --version`, checked 2026-11-03)
- PHP: 8.3, from `.ddev/config.yaml` and `apps/drupal/pantheon.yml`; the patch level floats in
  both places. Accepted differences: `scripts/README.md`, "Accepted differences".

- MariaDB: the `drupal` job runs a `mariadb:10.6.22` service container (health check, port
  3306) and sets `SIMPLETEST_DB` for the Kernel tests (T09). The tag must share its major.minor
  with `database.version` in `.ddev/config.yaml` and `apps/drupal/pantheon.yml` (rule 2). The
  root password in the job is a throwaway for an ephemeral container, not a secret.
- Coverage: setup-php `coverage: pcov` in the `drupal` job (DDEV uses Xdebug coverage, see
  `scripts/README.md`, "Accepted differences").

To change the Composer version, update the `ddev exec composer --version` line above and
`tools: composer:<version>` in `ci.yml` together.

### Pinned actions

Every third-party action is pinned by full commit SHA, with the version in a comment on the line
above. The SHAs were looked up with `git ls-remote <https://github.com/<owner>/<repo>>
refs/tags/<tag>` (annotated tags: the peeled `^{}` commit) and the release page was checked on
2026-11-03 (none is a pre-release, and every repository is MIT licensed and not
archived). They were never typed from memory. To update one, repeat that lookup and change this
table and `ci.yml` (and `deploy-drupal.yml` for `actions/checkout`) together.

| Action | Version | Commit SHA | Release page | Released | Checked |
|---|---|---|---|---|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` | <https://github.com/actions/checkout/releases/tag/v7.0.1> | 2026-07-20 | 2026-11-03 (same pin as T07) |
| `actions/setup-python` | v7.1.0 | `6d4fd22b20465ccc0f7354476588e8df7c9ca0e0` | <https://github.com/actions/setup-python/releases/tag/v7.1.0> | 2026-10-22 | 2026-11-03 |
| `actions/cache` | v6.1.0 | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | <https://github.com/actions/cache/releases/tag/v6.1.0> | 2026-06-26 | 2026-11-03 |
| `actions/upload-artifact` | v7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` | <https://github.com/actions/upload-artifact/releases/tag/v7.0.2> | 2026-10-07 | 2026-11-03 |
| `shivammathur/setup-php` | 2.40.0 | `eb7c497e18156a6bbabfef1d3a82760b9eda3962` | <https://github.com/shivammathur/setup-php/releases/tag/2.40.0> | 2026-10-08 | 2026-11-03 (the tag is annotated: the tag object is `4424c9aab975b57bd706ee5a39c6b4334d6e4f60`, the commit is the SHA used) |

The owner allows `shivammathur/setup-php@eb7c497e18156a6bbabfef1d3a82760b9eda3962` in Settings,
Actions, General (plan KD-10); the other four are GitHub-owned.

### Pinned tools

`scripts/tool-versions.env` holds the version and SHA-256 of each tool that
`scripts/bootstrap-dev.sh` installs (pre-commit, gitleaks, actionlint and shellcheck). The
values were copied from the publisher files on 2026-11-03 and bootstrap fails on a mismatch.

| Tool | Version | Released | Source of the SHA-256 |
|---|---|---|---|
| pre-commit (zipapp) | 4.7.0 | 2026-10-13 | release asset digest, <https://api.github.com/repos/pre-commit/pre-commit/releases/tags/v4.7.0> (equals the SHA-256 of the file downloaded earlier by T00) |
| gitleaks (Linux x64) | 8.30.1 | 2026-03-21 | <https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_checksums.txt> |
| actionlint (Linux amd64) | 1.7.12 | 2026-03-30 | <https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_checksums.txt> |
| shellcheck (Linux x86_64) | 0.11.0 | 2025-08-04 | release asset digest, <https://api.github.com/repos/koalaman/shellcheck/releases/tags/v0.11.0>. The runner image has 0.9.0, which flags info-level findings in older suites (T04a, T06); the `docs` group puts the pinned binary first on `PATH` |

### Dependency audit (T08, CODING_STANDARDS "Audit before adding")

Two dependencies were added after the plan was approved. The review of 2026-11-04 accepts them
as plan departures.

| Dependency | Licence | Released | Advisories | Why needed |
|---|---|---|---|---|
| PyYAML 6.0.3 (`scripts/requirements-docs-tests.txt`) | MIT | 2025-09-25 (latest on PyPI at the check) | none in PyPI metadata or OSV (`api.osv.dev` query for PyPI/PyYAML 6.0.3 returned no entry), 2026-11-04 | The docs suites (T04a and later) import `yaml`; the CI runner Python has no PyYAML. Used only in the `docs` job and on a developer's own Python. Pinned by version; hash pinning is an open owner decision |
| shellcheck 0.11.0 binary (`scripts/tool-versions.env`) | GPL-3.0 (a tool that is run, not shipped) | 2025-08-04 | no repository security advisory (GitHub API, 2026-11-04) | The suites call `shellcheck` from `PATH`; the runner's 0.9.0 reports findings the pre-commit hook (0.11.0.1) does not. SHA-256 pinned |

### Adding the heavier set

The heavier set is the slow tests that do not run on every pull request: Drupal Functional and
FunctionalJavascript tests, Schemathesis against a live Drupal, Playwright, `ddev e2e`. It is
deferred to T10 (or T09 if it adds a PHPUnit Functional test), decision
`docs/tasks/T08/decision-heavier-set.md`. T08 adds no placeholder job. `scripts/check_ci.py`
rule 6 fails as soon as a heavier-set test exists and `ci.yml` has no `heavier-*` job. The
contract for the task that adds the first job:

- Jobs live in `ci.yml` with the id `heavier-<area>`. No new workflow file.
- They are **never** in the `needs` of `ci-ok`, so they are never a required check (rule 6
  checks this).
- Triggers: a nightly `schedule`, off the hour and away from the 10:30 UTC daily run (for
  example `17 21 * * *`); `workflow_dispatch`; `push` to `main`; and `pull_request` with the
  label `heavier-set`. Each job is gated with `if:`. Adding `labeled` to the pull request types
  also re-runs the PR set; T10 accepts or filters that.
- Each job has its own `timeout-minutes` (30 proposed) and uploads `reports-heavier-<area>`.
- T10 and T27 choose between DDEV and a native stack for these jobs.

### Not verifiable until the first run

The runner image has `shellcheck` 0.9.0 (measured on PR #3), so actionlint also checks `run:`
blocks, with that older version. One fact is recorded after the first `push` run on GitHub, in
the test report: that `branch-name` sees `main` on a `push` event.

## deploy-drupal.yml (T07)

A thin wrapper. It runs only when the repository variable `PANTHEON_SITE` is set; otherwise the
`skip` job prints "deploy-drupal: not configured (PANTHEON_SITE unset), skipped". Secrets
`TERMINUS_MACHINE_TOKEN` (a Pantheon PAT) and `PANTHEON_DEPLOY_KEY` are read only through `env:`.
Actions are pinned by commit SHA; Terminus 4.3.3 is pinned by SHA-256. Lint with actionlint
1.7.12 (`.tools/actionlint .github/workflows/deploy-drupal.yml`, also a pre-commit hook). Setup:
`docs/runbooks/deploy.md`.
