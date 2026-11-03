# T08: Continuous integration baseline, Plan

| Field | Value |
|---|---|
| Task | T08 |
| Author | technical-architect |
| Date | 2026-11-03 |
| Branch | `task/T08-ci-baseline` (from `origin/main` at `d935c2f`) |
| Status | Approved (owner, 2026-11-03) |

## Goal

Add `.github/workflows/ci.yml` ("Meridian CI"). It runs the T04a quality suite
(`scripts/quality.sh`, the one implementation behind `ddev quality`) on every pull request to
`main` and every push to `main`. It also adds the checks that T04a, T04 and T05 left to T08:

- a full-history secret scan;
- the dependency audit;
- the component build steps;
- the tooling unit tests;
- the docs-task regression suites (`--regression`, decision D-5).

Each component suite has its coverage gate. Components that do not exist yet show a visible
`SKIP`, and the expected SKIPs are listed in a file that later tasks must update. The task also
gives the owner the exact branch protection settings, so a red CI result blocks a merge. A demo
pull request shows the block. The plan measures the 10 min clean-cache budget (NFR-07) and
records the CI secret names in `docs/runbooks/ci-secrets.md`.

## Context and dependencies

- **T06 is Done.** **T05 is "In test"**: only the owner-run TC-T05-39 and TC-T05-40 remain. On
  2026-11-03 the owner accepted starting T08 while T05 is in test. T08 does not depend on those
  two cases (runbook verbatim run, Windows browser).
- **Branch base.** `origin/main` is now `d935c2f` (merge of PR #2, T07), not `1200ad0`. Its
  tree is identical to `task/T07-pantheon-dev` at `2d67299`. So T08 is built on a `main` that
  already contains the T07 files. T08 must coexist with these files and must not change them:
  - `.github/workflows/deploy-drupal.yml`;
  - `scripts/deploy-drupal.sh` and `scripts/pantheon_known_hosts`;
  - `.ddev/commands/web/deploy-drupal` and `.ddev/providers/pantheon.yaml`;
  - the tracked `apps/drupal/.gitignore`;
  - Terminus 4.3.3 in `.ddev/web-build/Dockerfile`.

  Only the static checks below read the T07 workflow: action pins and secret names. One
  exception may apply: SA-1 checklist item 2 may move `vars.DEPLOY_SMOKE_HEADER` to a secret
  in `deploy-drupal.yml` (KD-13).
- No `ci.yml` exists on either branch.

## Facts established while planning (2026-11-03, read from `origin/main`)

1. `scripts/quality.sh` runs 9 built-in steps. The latest `ddev quality` run gave
   `PASS 6 FAIL 0 SKIP 3` (T06 `ddev-quality-final`, T07 `ddev-quality-part1`). The skipped
   steps are:
   - `component-engine` (no `services/engine/pyproject.toml`, T13);
   - `component-drupal-tests` (no `apps/drupal/phpunit.xml.dist`, T09);
   - `component-web` (no `apps/web/package.json`, T21).
2. `QUALITY_RUNNER=native` exists so that CI can run the component tools without DDEV
   (`scripts/README.md`, T05 plan KD step 5: "CI decides its runner in T08").
3. **Nothing runs the tooling unit tests today.** `scripts/tests/` (unittest) and
   `.claude/hooks/tests/` are not a step in `quality.sh` and not a pre-commit hook.
4. **The gitleaks pre-commit hook does not scan the tree in `run --all-files`.** The upstream
   hook entry is `gitleaks git --pre-commit --staged`. CI stages nothing, so the hook scans
   nothing. The standards require "gitleaks over the full history in CI (T08)"
   (CODING_STANDARDS "No secrets in code"), and NFR-10 requires 0 secrets in the full history.
   T08 needs a separate history scan.
5. No dependency audit runs anywhere. T05 left `composer audit` to T08 (T05 plan, step 6).
6. `scripts/tool-versions.env` has `PRE_COMMIT_SHA256=` empty. Bootstrap then downloads the
   pre-commit zipapp unverified (open item from T00). CI would run that download on every cold
   run.
7. actionlint 1.7.12 was installed by hand into `.tools/` in T07 (`docs/runbooks/deploy.md`,
   "Tool versions"). It is not pinned in the repo and does not run in any hook. T07 plan
   line 295 says "Adding actionlint to CI is T08".
8. `check_commit_msg.py --range` fails with exit 2 on a shallow clone. CI must use
   `fetch-depth: 0` (T04a review, condition 4, R-1).
9. `check_branch_name.py` reads `GITHUB_HEAD_REF` (set only on `pull_request`), else the current
   git branch. For `push` events, `actions/checkout` checks out a local branch named after the
   ref, so `git rev-parse --abbrev-ref HEAD` gives `main`. This closes T04a review finding 16
   by design. Verify it on the first push run.
10. Docs-task suites: T02, T04, T04a, T05, T06 and T07 accept `--regression`. T00 and T03 do
    not; D-5 assigns their retrofit to T08 (tester). T01 has no `run-checks.sh`; its guard
    tests are `.claude/hooks/tests/`.
11. The pre-commit Node pin is 22.14.0 (`default_language_version`). pre-commit downloads that
    Node itself, so CI automatically uses the same version (T05 review note 20).
12. OQ-03 (is the repository public or private?) is ticketed to T08
    (`solution-architecture.md` line 408). It also decides whether branch protection works at
    all. Resolved by SA-1 ([decision-repo-visibility.md](decision-repo-visibility.md), sources
    S1 to S3, checked 2026-11-03):
    - rulesets work on public repositories with GitHub Free, and on private ones only with Pro,
      Team or Enterprise;
    - protected branches in private repositories are a Pro feature;
    - the pricing page marks "Repository rules" as "Public repositories" for Free.

    So a private repository on GitHub Free cannot enforce a required check, and AC2 cannot be
    shown there. The SA recommends making the repository public after a checklist (KD-13).
    **Owner decided 2026-11-03: public** ("approve the plan, make it public"); the KD-13
    checklist runs before the flip (O-1).
13. The T07 workflow pins `actions/checkout` v7.0.1 at
    `3d3c42e5aac5ba805825da76410c181273ba90b1`. T08 reuses that pin.
14. **Timing evidence: none recorded.** No earlier run records how long `quality.sh` or
    `ddev quality` takes. Every timing below is an estimate, marked **unverified**, and is
    confirmed by the measurement in KD-7.

## Key decisions

### KD-1 Runner: `scripts/quality.sh` natively on `ubuntu-24.04`, not DDEV on the runner

CI runs `scripts/quality.sh` with `QUALITY_RUNNER=native`. The runner gets the same pinned tool
versions as DDEV. DDEV is not installed in CI.

Why:

- **One implementation.** `ddev quality` is a 3-line wrapper that sets `QUALITY_RUNNER=ddev`
  and calls `scripts/quality.sh`. The "suite defined in T04a" is the list of steps in
  `quality.sh`, and CI runs exactly that list. The YAML holds only:
  - the toolchain setup;
  - the caches;
  - one call per job: `scripts/quality.sh --group <g>`;
  - the artifact upload.

  It contains no check logic.
- **Budget (NFR-07, 10 min on a clean cache).** DDEV in CI means:
  - installing DDEV;
  - pulling `ddev-webserver`, `ddev-dbserver`, `ddev-router` and the three Meridian images;
  - building the custom web image (Terminus layer);
  - the `composer install` post-start hook.

  This is commonly reported at 3 to 5 min before the first check runs. That figure is
  **unverified** and not measured here. On top of that, the pre-commit cold install (about
  3 to 4 min, also unverified) leaves little or no margin. Native setup costs seconds (setup
  actions) plus the same cold installs.
- **Parity is checked.** It is not assumed: `scripts/check_ci.py` (KD-6) fails when a CI
  toolchain version differs from DDEV or Pantheon. The checks are:
  - PHP `8.3` from `.ddev/config.yaml` and `apps/drupal/pantheon.yml`;
  - the Composer version;
  - later, Python 3.12.16 and Node 22.23.4 from the image tags in
    `.ddev/docker-compose.*.yaml`.
- Rejected: a DDEV parity job inside `ci.yml`, not even a dispatch-only one. It would push the
  wall clock of `ci.yml` past NFR-07, and conditions 3 and 5 below already prove parity. DDEV
  in CI is left to the first heavier-set task (T10, T27; KD-14).

The AC wording "runs the full `ddev quality` suite" means "runs every step of the suite behind
`ddev quality`". SA-2 decided this in
[decision-native-quality.md](decision-native-quality.md). The decision holds under five
conditions, each one a T08 test case:

1. **No check logic in YAML.** Every job calls `scripts/quality.sh --group <g>`.
   `check_ci.py` rule 1 makes the union of the groups equal `quality.sh --list`.
2. **The runner does not change the step set.** The `--list` output and every SKIP decision
   depend only on manifests, never on `QUALITY_RUNNER`. A unit test runs `--list` and the SKIP
   accounting under `QUALITY_RUNNER=native` and `QUALITY_RUNNER=ddev` (with a fake runner)
   and asserts identical output.
3. **Toolchain parity**, as checked by `check_ci.py` rule 2: PHP major.minor and Composer now;
   Python and Node from T13 and T21.
4. **Residual differences are written down.** A new "Accepted differences" paragraph in
   `scripts/README.md` covers:
   - the Ubuntu runner, against DDEV's Debian-based containers;
   - setup-php's extension set, against `ddev-webserver`'s (`composer check-platform-reqs
     --lock` covers what the code needs);
   - the PHP patch level, which floats in both places.

   A check that passes in one place and fails in the other is a defect, never a reason to
   skip the check.
5. **`ddev quality` stays the local gate.** A task that changes `quality.sh` records both
   `ddev quality` and the CI run in its test report (step 9).

Owner option, not required: SA-2 proposes a clarified AC1 wording for `docs/TASKS.md`
("... by calling `scripts/quality.sh` ... natively on the GitHub runner with toolchain versions
checked against DDEV and Pantheon ..."). T08 proceeds on the current wording either way (O-9).

Note for T09 (not T08): Kernel tests need a database service in the `drupal` job. Its engine
and version must match `ddev-dbserver` (MariaDB 10.6), SQLite is not acceptable, and
`check_ci.py` rule 2 gains that check.

### KD-2 Jobs run in parallel and select steps by group

`quality.sh` runs steps one after another. Five parallel jobs keep the wall clock near the
slowest group, and adding the engine and web suites (T13, T21) will not push one job past the
budget. Interface changes to `scripts/quality.sh` (no change to the
`NAME<TAB>MANIFEST<TAB>COMMAND` steps format):

- `--list` prints `GROUP<TAB>STEP` for every built-in step, in run order, then exits 0.
- `--group G` (repeatable) runs only the built-in steps of group `G`. With no `--group`, every
  step runs, so `ddev quality` with no arguments is unchanged in scope. An unknown group gives
  exit 2. Each built-in step belongs to exactly one group. A step with no group is a
  programming error and gives exit 2, and a unit test covers it.
- With `QUALITY_STEPS=FILE` (the test hook), `--group` is not allowed (exit 2). This keeps the
  hook simple.
- When `GITHUB_STEP_SUMMARY` is set, the script appends a Markdown table of the steps and their
  results to that file. Each `SKIP` row includes its reason. This is presentation only; the
  exit code is unchanged.
- The pre-commit step adds `--show-diff-on-failure`, so a fixer hook's diff shows in the CI log.

Groups and steps after T08. **New** marks a step that T08 adds:

| Group | Step | Manifest (SKIP when absent) | Command (summary) | State at T08 |
|---|---|---|---|---|
| `core` | `pre-commit` | `-` | `pre-commit run --all-files --show-diff-on-failure` | Runs |
| `core` | `branch-name` | `-` | `check_branch_name.py` | Runs |
| `core` | `commit-range` | `-` | `check_commit_msg.py --range origin/main..HEAD` | Runs |
| `core` | `exceptions` | `-` | `exceptions_report.py` | Runs |
| `core` | `assets` | `-` | `check_assets.py` | Runs |
| `core` | `tooling-tests` **New** | `-` | `python3 -m unittest discover -s scripts/tests` and `-s .claude/hooks/tests` | Runs |
| `core` | `secret-history` **New** | `-` | `.tools/gitleaks git --redact --no-banner --config .gitleaks.toml --report-format json --report-path .tools/reports/gitleaks.json` over the full history | Runs |
| `core` | `ci-config` **New** | `-` | `python3 scripts/check_ci.py` (KD-6) | Runs |
| `docs` | `docs-regression` **New** | `-` | every `docs/tests/T*/run-checks.sh --regression`, one after another; a script that fails makes the step FAIL and names the script | Runs |
| `drupal` | `build-drupal` **New** | `apps/drupal/composer.lock` | `composer install --no-interaction --no-progress` then `composer check-platform-reqs --lock` | Runs |
| `drupal` | `component-drupal` | `apps/drupal/composer.json` | unchanged (validate, phpcs, guarded PHPStan) | Runs |
| `drupal` | `component-drupal-tests` | `apps/drupal/phpunit.xml.dist` | PHPUnit with `--log-junit junit.xml` added, coverage gate | SKIP (T09) |
| `drupal` | `audit-drupal` **New** | `apps/drupal/composer.lock` | `composer audit --locked --abandoned=report --no-interaction` | Runs |
| `engine` | `build-engine` **New** | `services/engine/Dockerfile` | `docker build -t meridian-engine:ci services/engine` (verify in T13) | SKIP (T13) |
| `engine` | `component-engine` | `services/engine/pyproject.toml` | unchanged, plus `--junitxml=junit.xml` | SKIP (T13) |
| `engine` | `audit-engine` **New** | `services/engine/pyproject.toml` | `pip-audit` on the locked set (T13 sets the exact command with the lock tool) | SKIP (T13) |
| `web` | `build-web` **New** | `apps/web/package.json` | `npm run build` (verify in T21) | SKIP (T21) |
| `web` | `component-web` | `apps/web/package.json` | unchanged, plus a JUnit reporter to `junit.xml` | SKIP (T21) |
| `web` | `audit-web` **New** | `apps/web/package.json` | `npm audit` on the lockfile (T21 sets the exact command) | SKIP (T21) |

Notes on the table:

- `build-drupal` comes first in its group. It replaces the `composer install` that the DDEV
  post-start hook does locally. Locally it is idempotent and takes a few seconds (unverified).
- `secret-history` and `audit-*` need network (the git history is local, but the advisory
  databases are remote). A local `ddev quality` with no network now FAILs `audit-drupal`.
  That is intended (missing data is a FAIL, never a pass) and is documented in
  `scripts/README.md`.
- **Audit policy.** Any known advisory fails, because each tool's default exit code fails on
  any advisory. NFR-11 asks only for 0 high or critical findings, so this gate is stricter;
  that is allowed. Abandoned packages are reported, not failed. An exception uses the tool's
  own ignore list with the advisory ID, a reason that cites a ticket, and a review date:
  - Composer: `config.audit.ignore` in object form, `{"<ID>": "Txx: reason, review by
    YYYY-MM-DD"}`;
  - pip-audit: `--ignore-vuln`;
  - npm: an overrides or audit config.

  The exceptions report must list these entries (`exceptions_report.py` gains the Composer
  form now; T13 and T21 add theirs). T21 may ask the solution-architect for a severity floor
  for npm if noise makes "any" impractical.
- Simulation-only: the audits read public advisory databases only. No allowlist may name a
  broker package or domain.

### KD-3 Expected SKIPs are declared, so a SKIP is never silent

T04a plan risk "a silent SKIP after a component is scaffolded" says "T08 asserts the expected
components". New file `quality/expected-skips.txt`, one step per line, each with a ticket:

```text
component-drupal-tests  # T09: phpunit.xml.dist arrives with the first custom module
build-engine            # T13: services/engine/Dockerfile
component-engine        # T13: services/engine/pyproject.toml
audit-engine            # T13: engine lock file
build-web               # T21: apps/web/package.json
component-web           # T21: apps/web/package.json
audit-web               # T21: apps/web lockfile
```

Rules in `quality.sh` (built-in steps only; test hook `QUALITY_EXPECTED_SKIPS=FILE` replaces the
path):

- A step that SKIPs and is not listed: FAIL, "unexpected SKIP: <step> (no <manifest>)".
- A listed step that runs: FAIL, "<step> ran but is listed in quality/expected-skips.txt:
  remove the line". So the task that adds the manifest must delete its line. The coverage gate
  then applies at once (CODING_STANDARDS "A component without a manifest is SKIP. Once the
  manifest exists the gate applies").
- A line without a `# Txx:` ticket, or naming an unknown step: exit 2.
- With `--group`, only the steps of the selected groups are checked against the list.

### KD-4 Secret scan over the full history with a pinned gitleaks binary

- Pin `GITLEAKS_VERSION=8.30.1` (the same as the pre-commit `rev`) and `GITLEAKS_SHA256` (the
  Linux x64 release tarball) in `scripts/tool-versions.env`.
- `scripts/bootstrap-dev.sh` downloads the tarball, checks the SHA-256 and installs it to
  `.tools/gitleaks`. A checksum mismatch is fatal, as for pre-commit. On a platform other than
  Linux x86_64, the script exits with a clear message. The supported dev platform is WSL2
  Linux (`local-setup.md`).
- The `secret-history` step uses `.tools/gitleaks`, else `gitleaks` on `PATH`. A missing tool
  is a FAIL.
- `--redact` is mandatory, because the JSON report is uploaded as an artifact.
- The pre-commit gitleaks hook stays as it is: it covers the staged changes at commit time.
- The same change pins `PRE_COMMIT_SHA256` (fact 6) and `ACTIONLINT_VERSION=1.7.12` with
  `ACTIONLINT_SHA256`. Bootstrap installs `.tools/actionlint` the same way.
- Every developer must run `scripts/bootstrap-dev.sh` again. `local-setup.md` and
  `scripts/README.md` say so.

### KD-5 actionlint as a local pre-commit hook

A local hook in `.pre-commit-config.yaml`:

- `id: actionlint`, `language: system`, `entry: .tools/actionlint`;
- `files: ^\.github/workflows/.*\.ya?ml$`.

With the binary absent, the hook fails (missing tool, not a pass). It lints `ci.yml` and
`deploy-drupal.yml` locally and in the `core` job, with no Go build. If `shellcheck` is on
`PATH`, actionlint also checks the `run:` blocks with it. It is on the runner image; that is
unverified, so record what the first run shows.

### KD-6 `scripts/check_ci.py` (standard library only, unittest tests)

This script holds the CI rules that YAML cannot check itself. It has no YAML dependency: it
parses the workflow text line by line with regular expressions, which is enough for our own
files. Checks, each with a clear message and exit 1 on failure:

1. **Group coverage.** The set of `scripts/quality.sh --group <g>` calls in `ci.yml` equals the
   set of groups from `quality.sh --list`. Each group is called by exactly one job. No step of
   the suite can be dropped from CI unnoticed.
2. **Toolchain parity** (SA-2 condition 3):
   - the `php-version` in `ci.yml` equals `php_version` in `.ddev/config.yaml` and
     `php_version` in `apps/drupal/pantheon.yml` (major.minor);
   - the Composer version in setup-php `tools: composer:<x.y.z>` equals the DDEV Composer
     version recorded in `.github/README.md`, a line read from `ddev exec composer --version`
     with the date;
   - once present, `python-version` in the engine job must equal the tag version of the
     `meridian-engine` image (3.12.16), and `node-version` in the web job the `meridian-web`
     image tag (22.23.4).
3. **Action pins.** Every `uses:` in `.github/workflows/*.yml` that is not local (`./`) is
   `owner/repo@<40 hex>`, with a `# owner/repo vX.Y.Z` comment on the line above (T07 style).
   This applies the CODING_STANDARDS "Docker and YAML" rule.
4. **Secret names documented.** Every `secrets.NAME` and `vars.NAME` in any workflow appears in
   `docs/runbooks/ci-secrets.md`. `GITHUB_TOKEN` is exempt. This keeps AC5 true for later
   workflows (`daily-run.yml`, T20).
5. **Least privilege.** Every workflow has a top-level `permissions:` key, and no job grants
   `write` without a `# Txx:` comment.
6. **Heavier-set tripwire** (SA-3, [decision-heavier-set.md](decision-heavier-set.md)). If any
   heavier-set marker exists and `ci.yml` has no job whose id starts with `heavier-`, the rule
   fails with "heavier-set tests exist but ci.yml has no heavier-* job
   (decision-heavier-set.md)". The markers are constants in the script, each unit-tested:
   - a `*Test.php` under
     `apps/drupal/web/modules/custom/*/tests/src/Functional/` or `.../FunctionalJavascript/`;
   - the string `drupal_live` in any file under `services/engine/tests/`;
   - `apps/web/playwright.config.*`;
   - `.ddev/commands/*/e2e`.

   The rule also fails if a `heavier-*` job is listed in `ci-ok`'s `needs`: the heavier set is
   never a required check.

Fixtures in `scripts/tests/fixtures/ci/` cover each rule with a passing file and a failing one.
For rule 6 there are three: a Functional test directory with no `heavier-` job (fail), the same
with a `heavier-drupal` job (pass), and a `heavier-*` job inside `ci-ok` `needs` (fail). A
`--root DIR` override points the marker scan at a fixture tree.

### KD-7 The 10-minute budget: design, estimate, measurement

**Design:**

- 5 parallel jobs plus a small `ci-ok` gate.
- `timeout-minutes: 10` on every job, so the budget is a hard stop and not just a hope.
- Caches:
  - `~/.cache/pre-commit`, keyed on the OS, the Python version, a hash of
    `.pre-commit-config.yaml` and a hash of `scripts/tool-versions.env`;
  - `.tools/`, keyed on a hash of `scripts/tool-versions.env`;
  - the Composer cache directory, keyed on a hash of `apps/drupal/composer.lock`;
  - `vendor/` is never cached.
- No setup action caches anything by itself (no `cache:` input), so "clean cache" means
  exactly "no `actions/cache` hit".

**Estimate (all unverified):**

| Job | Cold | Warm |
|---|---|---|
| `core` | 4 to 6 min (pre-commit hook environments: Go build of gitleaks, Node for markdownlint and Spectral, pip for ruff and mypy) | 1 to 2 min |
| `docs` | 2 to 4 min (bootstrap uses the same pre-commit cache key) | 1 to 3 min |
| `drupal` | 2 to 3 min (setup-php, `composer install` of Drupal 11 with dev tools) | 1 to 2 min |
| `engine`, `web` | under 1 min (SKIP only) | under 1 min |

**Measurement (TC for NFR-07):**

- `workflow_dispatch` works only for workflows on the default branch, so before merge the
  measurement uses re-runs on the T08 pull request.
- **Cold:** the first run of the T08 PR (no cache exists yet). Then twice: the owner deletes all
  caches (Actions, Management, Caches) and chooses "Re-run all jobs".
- **Warm:** three plain re-runs.
- Record for each run the run's total duration from the run summary page and each job's
  duration, with the run URL.
- **Pass:** every cold run is at most 10:00 and every warm run at most 6:00. Shared runners are
  noisy, so all three runs must pass, not their mean.

If the measurement fails, apply these in order, each as a recorded change in T08:

1. Switch the pre-commit gitleaks hook to a local `language: system` hook on `.tools/gitleaks`.
   This removes the Go build. Re-check `scripts/demo-secret-scan.sh`, which copies the hook
   `rev`.
2. Move `docs` into its own cache key.
3. Split `core` into `core` and `lint`. This needs a new group, so `check_ci.py` and
   `--list` change together.

Do not raise the timeout. Do not drop a step.

### KD-8 Workflow shape (`ci.yml`)

- `name: Meridian CI` (section 0: display names prefixed "Meridian").
- Triggers:
  - `pull_request` to `main` (types `opened`, `synchronize`, `reopened`);
  - `push` to `main`;
  - `workflow_dispatch` (for after merge).
- No path filters: a required check must always report.
- No `pull_request_target`, no `schedule`. The heavier set is deferred to T10 (KD-14).
- Concurrency:
  - group `ci-${{ github.event.pull_request.number || github.ref }}`;
  - `cancel-in-progress` only for `pull_request` events.
- Permissions:
  - `permissions: {}` at the top;
  - `contents: read` per job;
  - no secrets are used, so `.env.example` gets no new names.
- `runs-on: ubuntu-24.04` (pinned, as in T07). Each run step sets `shell: bash`. GitHub's bash
  default then adds `-eo pipefail`, so a `quality.sh | tee` pipe cannot hide a failure.
- Every job:
  - `actions/checkout` (T07 SHA) with `fetch-depth: 0` and `persist-credentials: false`;
  - `env: QUALITY_RUNNER: native`;
  - runs `scripts/quality.sh --group <g> 2>&1 | tee .tools/reports/quality-<g>.txt`;
  - then `actions/upload-artifact` (SHA-pinned) with `if: always()`, name `reports-<g>`,
    `retention-days: 14`, `if-no-files-found: warn`.
- Jobs. The job id equals its `name:`, so the required-check name is what the owner sees:

| Job | Setup before `quality.sh` | Group |
|---|---|---|
| `core` | `actions/setup-python` 3.12; caches; `scripts/bootstrap-dev.sh` (installs pre-commit, gitleaks, actionlint, hook environments) | `core` |
| `docs` | `actions/setup-python` 3.12; the same caches; `scripts/bootstrap-dev.sh` (the docs suites use `.tools/pre-commit` and linters when present) | `docs` |
| `drupal` | `shivammathur/setup-php` (SHA-pinned), `php-version: '8.3'`, `tools: composer:<pinned 2.x>` (equal to `ddev exec composer --version`, recorded), `coverage: none` (T09 switches to pcov); Composer cache | `drupal` |
| `engine` | none yet; T13 adds `actions/setup-python` 3.12.16 and the lock install (and T15 the no-network container) | `engine` |
| `web` | none yet; T21 adds `actions/setup-node` 22.23.4 and `npm ci` | `web` |
| `ci-ok` | `needs: [core, docs, drupal, engine, web]`, `if: always()`; one step fails when any needed job's result is not `success` (`if: contains(needs.*.result, 'failure') \|\| contains(needs.*.result, 'cancelled') \|\| contains(needs.*.result, 'skipped')` then `exit 1`) | none |

- Artifacts uploaded (paths are relative to the repo root; a missing path is a warning only):
  - `.tools/reports/` (the `quality-<g>.txt` logs, `gitleaks.json`, `exceptions-report.txt`);
  - `services/engine/junit.xml` and `services/engine/coverage.xml`;
  - `apps/drupal/junit.xml` and `apps/drupal/coverage.xml`;
  - `apps/web/junit.xml` and `apps/web/coverage/cobertura-coverage.xml`.

  `quality.sh` creates `.tools/reports/` at the start.
- Third-party actions: only `actions/checkout`, `actions/setup-python`, `actions/cache`,
  `actions/upload-artifact` (GitHub) and `shivammathur/setup-php`. Each is pinned by full
  commit SHA, with the version and the date it was checked recorded in `.github/README.md`.
  The SHAs are looked up with network access and checked against the release page; they are
  never typed from memory.

### KD-9 Coverage thresholds

No floor changes. The floors stay in `quality/coverage-thresholds.json` and are applied by
`coverage_gate.py` inside each component step:

| Component | Floor | Active in CI from |
|---|---|---|
| Engine `scoring` and `risk` | 90% | T13 (manifest), real code in T16 |
| Engine overall | 85% | T13 |
| Drupal custom modules | 70% (provisional) | T09 |
| Web `lib/` and `components/` | 80% | T21 |
| `scripts/`, `.claude/hooks/` | No floor (standards); the tests run in `tooling-tests` | T08 |

At T08, CI proves the gate itself through `scripts/tests/test_coverage_gate.py`, which runs in
`tooling-tests`. Note for T21 (not fixed here): `coverage_gate.py` matches a component when the
report's file name contains the prefix. Vitest Cobertura file names are relative to `apps/web`
(`lib/...`), so `--require apps/web/lib/` may not match. T21 checks the real report paths.

### KD-10 Branch protection and merge settings (owner, in GitHub Settings)

The agent cannot change repository settings, and `gh` is not installed. The owner applies these
after the first CI run on the T08 PR, because the check name must have reported once before
GitHub offers it. Prefer a ruleset; the classic rule is the fallback.

**Settings, General, Pull Requests:**

- Allow merge commits: **on**.
- Allow squash merging: **off**.
- Allow rebase merging: **off**.

D-3 of the T04a decision and the T07 rollback decision require this. Leave the other options
as they are.

**Settings, Actions, General:**

- Workflow permissions: **Read repository contents and packages permissions**.
- "Allow GitHub Actions to create and approve pull requests": **off**.
- Actions permissions: the "select actions" option. For a personal-account repository it
  reads "Allow `<owner>`, and select non-`<owner>`, actions and reusable workflows". The exact
  label is **unverified** (SA-1); pick the option that allows a named list. Tick "Allow actions
  created by GitHub" and add `shivammathur/setup-php@<pinned SHA>`.
- "Fork pull request workflows from outside collaborators": require approval for **all**
  outside collaborators. The option wording is **unverified**; pick the strictest. This is
  needed once the repository is public (SA-1 checklist item 7).

**Settings, Rules, Rulesets, New branch ruleset:**

- Name `main`, Enforcement status **Active**, Bypass list **empty**.
- Target branches: **Include default branch**.
- Rules:
  - **Restrict deletions**;
  - **Block force pushes**;
  - **Require a pull request before merging**, with required approvals **0** (a single owner
    cannot approve their own PR) and allowed merge methods **Merge** only;
  - **Require status checks to pass**, with "Require branches to be up to date before merging"
    **on**, and the check `ci-ok` added with source **GitHub Actions**.
- Leave "Require linear history" **off** (D-3).

The classic fallback (Settings, Branches, Add rule for `main`) needs the same options plus "Do
not allow bypassing the above settings", or the owner, as an admin, can merge a red PR.

**Unverified: bypass by a personal-account owner.** Bypass lists can only hold actors when the
repository belongs to an organization (SA-1, S11). It is **unverified** whether the owner of a
personal-account repository can still bypass a ruleset whose bypass list is empty. KD-11
step 4 verifies it: the merge-box evidence must show that no bypass option is offered. If one
is offered, switch to the classic rule with "Do not allow bypassing the above settings" and
repeat the demo.

Only `ci-ok` is required. Later tasks add jobs under it, and the setting never changes.

### KD-11 Demo pull request (AC2)

1. After KD-10 is active, branch `task/T08-demo-failing-test` from the tip of
   `task/T08-ci-baseline`.
2. Add one commit `T08: add deliberately failing test (demo, do not merge)`. It contains only
   `scripts/tests/test_t08_demo_failure.py`, one `unittest` test that calls
   `self.fail("T08 demo: deliberately failing test, do not merge")`.
3. Push it. The push needs the owner's go-ahead (WORKFLOW rule). The owner opens a PR to
   `main` titled "T08 demo: failing test must block merge (do not merge)".
4. Expected:
   - `core` FAILs at `tooling-tests`, naming the test;
   - `ci-ok` FAILs;
   - the merge box shows the merge is blocked by the required check `ci-ok`;
   - **no bypass option is offered** to the owner. There must be no "Merge without waiting
     for requirements to be met (bypass rules)" checkbox or similar. This verifies the open
     KD-10 item. If a bypass is offered, AC2 is not met yet; apply the KD-10 fallback and
     repeat.
5. Evidence, from the owner: the run URL, the failing log lines, and a screenshot or copied
   text of the whole merge box. The evidence must show that the bypass option is absent.
6. The owner **closes the PR without merging** and deletes the remote branch. Then
   `git merge-base --is-ancestor <demo sha> origin/main` must return 1 (not an ancestor).
7. Positive control: the T08 PR itself is green and mergeable under the same ruleset.

The failing test never lands on `main`: it exists only on the demo branch.

### KD-12 The docs-task regression suites

- **Tester (in `/design-tests`):** add `--regression` with `ckp`/`cka` tags to
  `docs/tests/T00/run-checks.sh` and `docs/tests/T03/run-checks.sh`, with a Change log entry in
  each `test-cases.md` (D-5). The technical-architect reviews each retag in `/review-task`.
- Then, as one of the developer's commits, the `docs-regression` step goes in. Every existing
  suite must pass in `--regression` mode on the T08 branch.
- A suite that fails on an invariant check is a defect against that suite's task. Fix the
  content or the check with a Change log row. Never fix it by retagging to snapshot without the
  D-5 justification.
- BLOCKED and optional-tool SKIP lines inside a suite do not fail the step. That is each
  suite's own rule.

### KD-13 Repository visibility (SA-1)

[decision-repo-visibility.md](decision-repo-visibility.md) recommends **making the repository
public**, after a pre-publication checklist and before the ruleset (O-5). It is the only USD 0
option that meets AC2. The fallback is private with GitHub Pro, which needs an
owner-approved NFR-09 amendment. **Owner decided 2026-11-03: public** (O-1); the checklist
runs before the flip, the flip before O-5.

The checklist is run by the owner with the main session, in this order (the decision file has
the exact commands):

1. A full-history gitleaks scan over every ref GitHub will publish, including
   `refs/pull/*`. It must find 0 findings. Check the `--log-opts` flag spelling for 8.30.1
   (**unverified**). If anything is found, stop: rotate a real secret; allowlist a false
   positive by fingerprint only with a solution-architect decision. Never rewrite history.
2. If `vars.DEPLOY_SMOKE_HEADER` holds a `Deterrence-Bypass` value, move it to a secret of the
   same name. That changes `deploy-drupal.yml` from `vars.` to `secrets.`; it is a T08 commit
   that cites T07, and the T08 review covers it. Review the existing `deploy-drupal` run logs
   and delete any run you do not want public.
3. Decide on the personal address in
   `docs/tests/T07/evidence/TC-T07-56.20261103T062710Z.txt`: accept it, or redact it in a new
   commit. History keeps it either way.
4. Accept the work email in the existing commits. From now on, use the `noreply` address.
5. Add a top-level `README.md` notice in a reviewed T08 commit: "Simulation-only research
   software. It places no orders and gives no investment advice."
6. Flip the visibility to Public.
7. Straight after the flip:
   - turn on secret scanning and push protection;
   - set fork PR workflows to require approval for all outside collaborators (KD-10);
   - then do O-3 to O-5.

T08 changes either way: the README notice (item 5) and, if needed, the item 2 change.

**Output rule (binding on T19, T20, T29, T31; not T08 code).** No symbol-level simulated
decision content may appear in public workflow logs, step summaries, artifacts, issues or
committed files. Decision content means BUY, AVOID or VETO results, scores, LLM text,
positions and P&L by symbol. Counts, statuses, durations, error classes and run IDs are fine.
T08's artifacts hold only tool reports, so they comply. The solution-architect records the rule
in `solution-architecture.md` (RK-06), and the close step carries it to those tasks.

**If the owner chooses private with Pro instead**, these parts of the plan differ:

- skip checklist items 1 to 7 and the post-flip settings. The README notice is still
  recommended, but it is no longer a gate;
- before O-5, the owner approves the NFR-09 amendment and the solution-architect records it;
- KD-7: CI minutes count against about 3,000 included minutes a month. Record the billed
  minutes of one cold run in the test report. Per-job rounding is **unverified**;
- KD-10: the fork-approval setting is not relevant;
- risk row 1 becomes "Pro lapses, so the ruleset stops being enforced", with Medium impact;
- the output rule still applies to collaborators but is not a public-exposure control.

The pre-publication scan in item 1 is separate from the `secret-history` step. That step
scans the checked-out history in CI; item 1 also covers PR refs, once, before publication.

### KD-14 Heavier set deferred to T10 (SA-3)

[decision-heavier-set.md](decision-heavier-set.md) defers the heavier-set jobs and triggers to
T10, or to T09 if it adds a PHPUnit Functional test. T08 adds no placeholder job and no
`schedule`. T08 still delivers three things:

1. **`check_ci.py` rule 6**, the tripwire (KD-6).
2. **A section "Adding the heavier set" in `.github/README.md`**, with this contract:
   - heavier-set jobs live in `ci.yml` with ids `heavier-<area>`; there is no new workflow
     file;
   - they are never in `ci-ok`'s `needs`, so they are never a required check;
   - triggers:
     - nightly `schedule`, off the hour, away from the 10:30 UTC daily run (for example
       `17 21 * * *`);
     - `workflow_dispatch`;
     - `push` to `main`;
     - `pull_request` with the label `heavier-set`.

     Each job is gated with `if:`. Adding `labeled` to the PR types also re-runs the PR set;
     T10 accepts or filters that;
   - each job has its own `timeout-minutes` (30 proposed) and uploads `reports-heavier-<area>`;
   - T10 and T27 choose between DDEV and a native stack.
3. **A note in the master test plan**, written by the tester with a Change log row, in
   "Regression suite":
   - the decision's replacement for "T08 implements the jobs in `ci.yml` (and the
     heavier-set triggers)";
   - the sentence "Until the first heavier-set job exists (T10), the rule has nothing to run
     and does not block a close."

Owner options, proposed only:

- add a heavier-set criterion to T10 in `docs/TASKS.md`;
- at T10, approve narrowing NFR-07 to the PR set.

Both are listed under O-9.

## Scope

- `.github/workflows/ci.yml` (KD-8).
- `scripts/quality.sh`:
  - `--list` and `--group`;
  - the step summary;
  - the new steps in the KD-2 table;
  - JUnit flags on the component commands;
  - the expected-skips rule.
- `quality/expected-skips.txt` (KD-3).
- `scripts/check_ci.py` with tests and fixtures (KD-6).
- `scripts/tool-versions.env` and `scripts/bootstrap-dev.sh`: pins for the pre-commit SHA-256,
  gitleaks and actionlint (KD-4).
- `.pre-commit-config.yaml`: the actionlint local hook (KD-5).
- `scripts/exceptions_report.py`: count Composer `audit.ignore` entries (KD-2).
- Tests in `scripts/tests/` for every changed or new script behaviour.
- `README.md`: the simulation-only notice (KD-13 item 5). `deploy-drupal.yml`: only the
  `DEPLOY_SMOKE_HEADER` move to a secret, if KD-13 item 2 applies.
- Docs:
  - `docs/runbooks/ci-secrets.md` (new);
  - `.github/README.md`, including the DDEV Composer version line (KD-6 rule 2) and the
    section "Adding the heavier set" (KD-14);
  - `scripts/README.md`, including the "Accepted differences" paragraph (KD-1 condition 4);
  - `docs/tests/master-test-plan.md`: the heavier-set note with a Change log row (tester,
    KD-14);
  - `docs/runbooks/local-setup.md` (run bootstrap again; audits need network);
  - the CODING_STANDARDS tool table (gitleaks binary, actionlint, setup actions, Composer
    version);
  - `docs/runbooks/README.md` (link).
- Owner steps KD-10 and KD-11, and the timing measurement KD-7.
- The owner's answer to OQ-03 and the KD-13 checklist. The solution-architect records OQ-03,
  the cost-map row and the RK-06 output rule in `solution-architecture.md`.

## Non-goals

- The heavier set (Drupal Functional, Schemathesis, Playwright, `ddev e2e`) and its triggers.
  These are deferred to T10 ([decision-heavier-set.md](decision-heavier-set.md), KD-14). T08
  only delivers the tripwire and the docs.
- A DDEV job in CI of any kind ([decision-native-quality.md](decision-native-quality.md)).
- The engine no-network container and Python toolchain (T13, T15), and the web toolchain
  (T21). T08 only reserves their jobs and groups.
- The static broker check (FR-11). T18 builds it as a `core` step in `quality.sh`. T08 needs no
  change for it.
- Container image vulnerability scans (NFR-11 container part, T26 and T30).
- Changes to `deploy-drupal.yml` beyond KD-13 item 2, and making the deploy wait for CI.
  Branch protection already means only green merges reach `main`.
- The `deploy-drupal.yml` display name. It is `deploy-drupal`, not "Meridian ...", which is a
  section 0 naming gap. That is a T07 follow-up for the main session to raise at T07's close,
  not T08 scope.
- Any coverage floor change, and any rule change to the commit or branch checks.
- Dependabot or automatic dependency updates. Its branch names would fail `branch-name`.

## Steps

Each step is one commit, with a `T08:` subject unless stated otherwise.

1. **Tester, `/design-tests`:** write `docs/tests/T08/test-cases.md`, including the SA-2
   condition cases. Also do the T00 and T03 `--regression` retrofit and the master test plan
   heavier-set note, each with a Change log entry. This is committed before step 2.
2. Pins: `PRE_COMMIT_SHA256`, `GITLEAKS_*` and `ACTIONLINT_*` in `tool-versions.env`, and the
   bootstrap install and checksum check for both binaries. Record the source URL, the release
   date and the date checked.
3. The actionlint local hook. Run it on `deploy-drupal.yml`; it must pass, as it did in T07.
4. `quality.sh`: `--list`, `--group`, group mapping and the step summary. Extend
   `test_quality_sh.py`, including the SA-2 condition 2 test (the same `--list` and SKIP
   output under `native` and `ddev`). Behaviour with no arguments is unchanged.
5. `quality.sh`: the new steps (`tooling-tests`, `secret-history`, `build-drupal`,
   `audit-drupal` and the SKIP-only engine and web steps). Add JUnit flags.
   `exceptions_report.py` gets the Composer ignore form. Add tests. Run `secret-history` over
   the real history; if it finds anything, stop and report (see the risks), and never
   allowlist without the solution-architect.
6. `quality/expected-skips.txt` and the rule in `quality.sh`, with tests (unexpected SKIP,
   listed-but-ran, missing ticket).
7. The `docs-regression` step (needs step 1).
8. `scripts/check_ci.py` (rules 1 to 6), fixtures and tests. Add it as step `ci-config`.
9. `.github/workflows/ci.yml`. It passes actionlint, yamllint and `check_ci.py`. Then run
   `scripts/quality.sh` (no arguments, native) and `ddev quality`. Both must exit 0, with SKIP
   exactly as listed in the expected-skips file.
10. Docs: `ci-secrets.md` (from `docs/templates/runbook.md`), the READMEs (including "Adding the
    heavier set" and "Accepted differences"), the standards tool table and `local-setup.md`.
    Add the `README.md` simulation-only notice (KD-13 item 5) in its own commit. If KD-13
    item 2 applies, change `deploy-drupal.yml` in its own commit, with "T07 follow-up" in the
    body.
11. **Main session, with the owner's go-ahead:** push the branch and the owner opens the PR.
    If the owner chooses public, the KD-13 checklist and the flip (O-1) can come before or
    after this push, but they must be done before O-5.
    The first run is cold run 1 (KD-7). Iterate until green. Fixes are new commits; do not
    force-push once evidence cites SHAs.
12. **Owner:** O-1 must be complete. Then O-3 to O-5 (settings, ruleset), then O-6 (demo PR)
    and O-7 (timing re-runs).
13. `/review-task`, `/test-task`, then the owner merges with a merge commit (O-8), then
    `/close-task`. The first `push` run on `main` is recorded (it covers branch-name on push).

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| `scripts/quality.sh` CLI | New `--list`, `--group G`; `QUALITY_EXPECTED_SKIPS` test hook; `GITHUB_STEP_SUMMARY` table; `.tools/reports/` output dir. No-argument behaviour keeps every step | `ddev quality` (passes `"$@"`), `ci.yml`, `check_ci.py`, T09, T13, T18, T21 |
| `scripts/quality.sh` steps | New: `tooling-tests`, `secret-history`, `ci-config`, `docs-regression`, `build-drupal`, `audit-drupal`, `build-engine`, `audit-engine`, `build-web`, `audit-web`. JUnit flags on the component steps | Every developer; T09, T13, T21 switch theirs on |
| `quality/expected-skips.txt` | New; the switch-on task deletes its lines | T09, T13, T21 |
| `scripts/check_ci.py` | New, standard library only. Rules 1 to 6 (rule 2 includes Composer; rule 6 is the heavier-set tripwire) | `quality.sh` `ci-config`; T09 (database parity), T10 (heavier jobs), T13, T20, T21 when they edit workflows |
| `README.md` | Top-level simulation-only notice (KD-13) | Public readers, RK-06 |
| `.github/workflows/deploy-drupal.yml` | Only if KD-13 item 2 applies: `vars.DEPLOY_SMOKE_HEADER` becomes `secrets.DEPLOY_SMOKE_HEADER`; `ci-secrets.md` lists it as a secret | T07 deploy, `check_ci.py` rule 4 |
| `scripts/tool-versions.env` | `PRE_COMMIT_SHA256` set; `GITLEAKS_VERSION`, `GITLEAKS_SHA256`, `ACTIONLINT_VERSION`, `ACTIONLINT_SHA256` | `bootstrap-dev.sh` |
| `scripts/bootstrap-dev.sh` | Installs `.tools/gitleaks` and `.tools/actionlint` with checksum checks; Linux x86_64 only for these two | Developers (re-run), `core` and `docs` jobs |
| `.pre-commit-config.yaml` | Local hook `actionlint` | Everyone |
| `scripts/exceptions_report.py` | Lists Composer `audit.ignore` entries | `exceptions` step |
| `.github/workflows/ci.yml` | New. Jobs `core`, `docs`, `drupal`, `engine`, `web`, `ci-ok` | Branch protection (`ci-ok`), T13, T20 (pattern), T21 |
| `docs/runbooks/ci-secrets.md` | New. Lists every secret and variable used by any workflow, with names only. `ci.yml`: none (only `GITHUB_TOKEN`, read-only). `deploy-drupal.yml`: `TERMINUS_MACHINE_TOKEN`, `PANTHEON_DEPLOY_KEY` (secrets); `PANTHEON_SITE`, `DEPLOY_SMOKE_BUDGET`, `DEPLOY_SMOKE_HEADER` (variables). Planned `daily-run.yml` (T20): the names from technical-design D7, marked "planned, T20". It also states the merge-method setting and why (T04a D-3 consequence) | Owner, T20, T28 |
| New third-party action | `shivammathur/setup-php`, MIT licence (verify), maintained (verify the release date), SHA-pinned. Needed for a fixed PHP minor and extension set, and pcov in T09. The preinstalled runner PHP is the rejected alternative: its extension set and patch level change with the runner image | `drupal` job |
| New tools | gitleaks binary 8.30.1 (MIT), actionlint 1.7.12 (MIT). Both are already used, now pinned in the repo | Bootstrap |

No runtime environment variable is added, so `.env.example` is unchanged (C6). The CI knobs
`QUALITY_RUNNER` and the test hooks are documented in `scripts/README.md`.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Repository is private on GitHub Free, so the ruleset is not enforced and AC2 cannot be shown | Resolved by SA-1 | High | KD-13: public after the checklist, or Pro with an NFR-09 change. Open only until the owner confirms (O-1) |
| Publishing exposes something unwanted (a secret in a PR ref, a bypass header in logs, a personal address, the work email) | Low | High | KD-13 checklist items 1 to 4 before the flip; secret scanning and push protection after it. Treat the flip as permanent |
| Personal-account owner can bypass the ruleset despite an empty bypass list (**unverified**) | Low | High | KD-11 step 4 evidence; KD-10 fallback to the classic rule with "Do not allow bypassing" |
| Cold run over 10 min | Medium | Medium | Parallel jobs; KD-7 fallbacks in order; the job timeout makes it visible |
| `secret-history` finds a match in old history | Low | High | Stop and report. A real secret is rotated first (standards). A false positive is allowlisted in `.gitleaks.toml` by fingerprint, with a comment and a solution-architect decision. History is never rewritten (evidence cites SHAs) |
| A new upstream advisory turns `main` red with no code change | Medium over time | Medium | Intended. The response is an upgrade task, or a ticketed ignore with a review date. The runbook says so |
| An older docs suite fails an invariant check in CI (runner differs from the sandbox: tools present, paths) | Medium | Medium | Step 7 runs them on the branch first. A failure is a defect for that suite (KD-12) |
| `ddev quality` gets slower locally (docs suites, audits) | High | Low | Accept. `--group` lets a developer run one area. Record the local time once in the test report |
| Runner PHP or Composer differs from DDEV and a check passes in one place only | Low | Medium | `check_ci.py` parity for PHP; Composer pinned in setup-php to the DDEV version |
| actionlint, gitleaks or pre-commit SHA-256 typed wrong, or from an untrusted source | Low | High | Look them up with network access from the GitHub release page or checksums file; record the URL and date; bootstrap fails on a mismatch |
| GitHub-hosted runner image changes (`ubuntu-24.04` updates weekly) | Medium | Low | Toolchains come from pinned setup actions, not the image defaults |
| `branch-name` on `push` does not see `main` | Low | Medium | Fact 9; the first push run after merge is a test case. Fallback is `GITHUB_REF_NAME` in `check_branch_name.py`, as T04a review finding 16 suggested |

## Test hooks needed

- `QUALITY_STEPS` (existing) and `QUALITY_EXPECTED_SKIPS=FILE` (new) to test the PASS, FAIL,
  SKIP and expected-skip rules with fake steps.
- `scripts/quality.sh --list`, a stable listing for check and test assertions.
- Fixture workflows in `scripts/tests/fixtures/ci/`: good, unpinned action, missing comment,
  undocumented secret, group missing, PHP mismatch, `write` permission without a ticket.
  `check_ci.py` takes `--workflows DIR`, `--secrets-doc FILE`, `--ddev-config FILE`,
  `--pantheon-config FILE`, `--github-readme FILE` (Composer line), `--root DIR` (rule 6 marker
  scan) and `--quality CMD` overrides, so the tests use fixtures. There are rule 6 fixture
  trees for the three cases in KD-6.
- SA-2 condition 2: a fake `ddev` on `PATH` (which records its calls and runs nothing), so
  `quality.sh` can run under `QUALITY_RUNNER=ddev` in a test. The test compares the `--list`
  output and the SKIP lines between both runners.
- Negative controls the tester can run on the branch without pushing:
  - an unpinned `uses:` in a copy of the workflow (`check_ci.py` fails);
  - a removed expected-skip line (unexpected SKIP);
  - a manifest created in a temp copy while its line is still listed (listed-but-ran);
  - a fake secret in a throwaway repo, scanned with the `secret-history` command (gitleaks
    finds it). `scripts/demo-secret-scan.sh` is the pattern.
- Owner-supplied evidence (cannot be produced by an agent):
  - the run URLs, job durations and total duration for 3 cold and 3 warm runs;
  - the demo PR merge box (screenshot or copied text);
  - the ruleset and merge settings (screenshot or copied summary);
  - the artifact list of one run.
- Hints for the tester's case design:
  - map AC1 to the `--list` output plus a CI run where each group's log shows its steps.
    SKIPs equal `expected-skips.txt` exactly;
  - AC2 is KD-11;
  - AC3 is KD-7 (NFR-07, both thresholds);
  - AC4: download one artifact set and check that `quality-<g>.txt` and `gitleaks.json` are in
    it and that the gitleaks report is redacted;
  - AC5: `check_ci.py` rule 4, plus a read of `ci-secrets.md` for names only (no values, no
    value-like strings);
  - one case per SA-2 condition (1 to 5);
  - the KD-13 checklist results as owner evidence (scan output, flip date, settings), or the
    Pro and NFR-09 record;
  - the `README.md` notice text;
  - `check_ci.py` rule 6 with its fixtures;
  - also cover the simulation-only grep over the new files, `check-names.sh` clean, and C7
    (CI is itself a clean checkout).

## Decisions needed from solution-architect

None open. SA-1 to SA-3 are answered below. The owner's open choices are O-1 and O-9.

## Decisions taken

1. **SA-1, repository visibility (OQ-03):**
   [decision-repo-visibility.md](decision-repo-visibility.md). The SA recommends public after
   the pre-publication checklist, done before O-5. The fallback is private with GitHub Pro
   plus an NFR-09 amendment. It also sets a new output rule for T19, T20, T29 and T31. Plan
   effect: fact 12, KD-10, KD-11, KD-13, risk rows 1 to 3, O-1. The decision takes effect
   when the owner confirms it (O-1).
2. **SA-2, native quality suite in CI:**
   [decision-native-quality.md](decision-native-quality.md). Native `quality.sh` meets AC1
   under five conditions, with no DDEV job in CI. Plan effect: KD-1, KD-6 rule 2, step 4, the
   `scripts/README.md` paragraph and the test cases. An AC1 wording clarification is
   optional (O-9).
3. **SA-3, heavier set:** [decision-heavier-set.md](decision-heavier-set.md). Deferred to
   T10, with three T08 deliverables: `check_ci.py` rule 6, the `.github/README.md` section and
   the master test plan note. Plan effect: KD-6, KD-14, scope, non-goals.

## Items for the main session (not owner actions)

- **Pins.** During implementation (steps 2 and 9), the main session looks up these values
  with network access:
  - the SHA-256 values for the pre-commit 4.7.0 zipapp, gitleaks 8.30.1 (Linux x64) and
    actionlint 1.7.12;
  - the full commit SHAs of `actions/setup-python`, `actions/cache`,
    `actions/upload-artifact` and `shivammathur/setup-php`.

  Take them from the release page or checksums file, and record each with its source URL and
  the date checked. The developer agent has no network, so these values are never typed from
  memory.
- **Out of scope.** The display name of `deploy-drupal.yml` (section 0 gap) is a T07
  follow-up, not T08 scope. Raise it at T07's close.

## Owner actions

| ID | Action | When |
|---|---|---|
| O-1 | Confirm **public**, or choose **private with GitHub Pro** and approve the NFR-09 amendment. If public: complete the KD-13 / SA-1 checklist with the main session. That means the all-refs gitleaks scan with 0 findings; the `DEPLOY_SMOKE_HEADER` check (and its move to a secret if needed); a review of the old `deploy-drupal` run logs; your choice on the personal address in `TC-T07-56.20261103T062710Z.txt`; accepting the work email in old commits and switching to `noreply`; the README notice merged into the branch. Then flip to Public, and turn on secret scanning, push protection and fork-PR approval for all outside collaborators. Send the scan result and the flip date | Before O-5 |
| O-2 | Give the go-ahead to push `task/T08-ci-baseline`, then open the PR to `main` in the GitHub UI and send the PR URL | Step 11 |
| O-3 | Settings, General, Pull Requests: merge commits on, squash off, rebase off (KD-10) | After the first CI run |
| O-4 | Settings, Actions, General: read-only workflow permissions, PR creation off, allowed actions = GitHub plus `shivammathur/setup-php@<SHA from .github/README.md>` (KD-10) | After the first CI run |
| O-5 | Create the `main` ruleset exactly as in KD-10, with `ci-ok` as the only required check and an empty bypass list. Send a screenshot or the rule summary | After O-3 and O-4 |
| O-6 | Demo PR (KD-11): allow the push of `task/T08-demo-failing-test` and open the PR. Confirm the merge is blocked and that **no bypass option is offered**. Send the run URL and merge-box evidence (the evidence must show the bypass is absent). Then close it without merging and delete the branch | After O-5 |
| O-7 | Timing (KD-7): on the T08 PR, delete all caches and re-run all jobs twice (cold 2 and 3), then re-run 3 times without deleting (warm). Send each run URL and its total duration | After the PR is green |
| O-8 | After review approval and the test report, merge the T08 PR with **Create a merge commit**, then send the URL of the first `push` run on `main` | Close |
| O-9 | Optional, no T08 gate: (a) approve or decline the SA-2 AC1 clarification in `docs/TASKS.md`; (b) approve or decline the SA-3 proposals: the T10 heavier-set criterion now, and the NFR-07 PR-set wording when T10 adds the first `heavier-*` job | Any time before close (a); T10 (b) |

## Definition of done

- [ ] All task acceptance criteria in `docs/TASKS.md` met:
  - [ ] AC1: `ci.yml` runs every `quality.sh` group, including:
    - lint, format, static analysis and types (pre-commit, the component steps);
    - the commit and branch checks;
    - the tooling unit tests and the component unit tests with coverage gates (SKIP exactly
      as declared);
    - build, the history secret scan and the dependency audit;
  - [ ] AC2: the demo PR is blocked by the `ci-ok` required check with no bypass offered
    (evidence shows it), then closed unmerged. The failing test is not on `main`;
  - [ ] AC3: 3 cold runs at most 10:00 and 3 warm runs at most 6:00 (NFR-07), recorded with
    run URLs;
  - [ ] AC4: the `reports-<group>` artifacts exist on a run and hold the logs and reports;
  - [ ] AC5: `docs/runbooks/ci-secrets.md` lists every secret and variable name, with no
    values, and `check_ci.py` enforces it.
- [ ] C1: Plan exists and was reviewed before coding started.
- [ ] C2: Code reviewed; findings resolved, including the T00 and T03 retag review.
- [ ] C3: Every criterion maps to an executed test case with evidence.
- [ ] C4: CI green on the T08 PR and on the first `push` run on `main`. No new lint, type or
  security warnings.
- [ ] C5: Docs and traceability updated:
  - `ci-secrets.md`, the READMEs, the standards tool table and `local-setup.md`;
  - TRACEABILITY NFR-07 and R-12;
  - OQ-03 closed in `solution-architecture.md` by the solution-architect, with the cost-map
    row and the RK-06 output rule (or the NFR-09 amendment if Pro is chosen);
  - `scripts/README.md` "Accepted differences" and `.github/README.md` "Adding the heavier
    set";
  - the master test plan heavier-set note with its Change log row;
  - the `README.md` simulation-only notice.
- [ ] C6: No secrets; `.env.example` unchanged (no new variables), stated in the test report.
- [ ] C7: Works from a clean checkout with documented commands. Every CI run is a clean
  checkout, and `scripts/bootstrap-dev.sh` then `ddev quality` pass on a fresh clone.
