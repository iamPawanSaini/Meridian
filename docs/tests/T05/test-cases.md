# T05: DDEV Drupal project, Test cases

| Field | Value |
|---|---|
| Task | T05 |
| Author | tester (design mode, before any implementation exists) |
| Date | 2026-11-01 |
| Criteria source | `docs/TASKS.md` T05 (AC1 to AC6, numbered as in the plan) and section 3.3 (C1 to C7) |
| Plan | `docs/tasks/T05/plan.md` (KD-1 to KD-8, "Test hooks needed") |

AC numbering (from the plan): AC1 `ddev start` on a clean clone; AC2 one documented install
command and `ddev drush uli`; AC3 DDEV PHP and database versions match `pantheon.yml`; AC4 config
sync directory set and `ddev drush cex` shows no diff after a fresh install; AC5 `ddev composer
validate` and `ddev drush status` pass; AC6 runbook followed verbatim works.

## How to run

| Mode | Command | Cases |
|---|---|---|
| Static (agent, no DDEV, no network) | `docs/tests/T05/run-checks.sh 2>&1 \| tee docs/tests/T05/evidence/run-checks.txt` | 01 to 24, plus the BLOCKED lines for 39 and 40 |
| Regression (CI PR set, decision D-5) | `docs/tests/T05/run-checks.sh --regression` | invariant static checks only; snapshot (`cka`) checks excluded and counted |
| Live | `docs/tests/T05/run-checks.sh --live` (static, then live) or `--live-only` | 25 to 36; needs DDEV, Docker, network; reinstalls the local Drupal database |
| Clean clone | `T05_CONFIRM=1 docs/tests/T05/run-checks.sh --clean-clone` | 37, 38, then 25 to 36 inside the clone |
| Per-case evidence | prefix any mode with `T05_EVIDENCE=1` | writes `evidence/TC-T05-nn.txt` per case |

Interface: one line per check (`PASS`, `FAIL`, `BLOCKED`, `SKIP`), a per-case roll-up
(`PASS`, `FAIL`, `BLOCKED`, `SKIP`), then `SUMMARY` and `RESULT`. Exit status 1 if any check
FAILs, otherwise 0. `BLOCKED` is not a pass and does not change the exit status, so the report
must list each one. `SKIP` is used only for optional host tools (shellcheck, composer,
pre-commit, gitleaks) and for a case that executed no check. A missing file makes every
dependent check FAIL; live cases FAIL (not skip) when `.ddev/config.yaml`,
`apps/drupal/composer.json` or `drupal-install` is absent, so nothing passes vacuously. In
`--live` mode the cases are BLOCKED only when DDEV or Docker is not available.

Clean-clone procedure (TC-T05-37, 38; the exact owner-run form of AC1 and C7):

1. Commit all work (a clone contains only committed files).
2. `ddev stop --unlist meridian` (two DDEV projects named `meridian` cannot coexist).
3. `git clone --branch task/T05-ddev-drupal <repo> <scratch>/meridian`, on the WSL2 Linux
   filesystem, not `/mnt/c`.
4. In the clone: `ddev start`, then the install command from the runbook, then `ddev drush cex
   -y`, then `git status --porcelain`.
5. Afterwards `ddev delete -Oy meridian` in the clone, remove it, and `ddev start` in the original
   tree. The script automates steps 2 to 5 when `T05_CONFIRM=1`.

Environment notes: agent sandbox has Python 3.10 with PyYAML, host PHP 8.1 (only `php -l` of
`settings.php`), no shellcheck, no pre-commit. DDEV and Docker may be present but cannot start a
project before T05 exists. Cases that need an absent optional tool report SKIP in the script and
are covered by TC-T05-24 (pre-commit) or by the live cases.

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: `ddev start` on a clean clone starts the project without manual steps | TC-T05-01, 02, 26, 37 |
| AC2: one documented install command; `ddev drush uli` logs in as admin | TC-T05-10, 11, 29, 30, 31, 38 |
| AC3: DDEV PHP and database versions match `pantheon.yml` | TC-T05-03, 04, 25 |
| AC4: config sync directory set; `ddev drush cex` after a fresh install produces no diff | TC-T05-07, 10, 32, 38 |
| AC5: `ddev composer validate` and `ddev drush status` pass | TC-T05-05, 06, 27, 28 |
| AC6: runbook followed verbatim works end to end | TC-T05-13, 39, 40 |
| C1: plan exists and was reviewed first | Evidence outside the suite: `docs/tasks/T05/plan.md` Status, `review.md` (checked at close) |
| C2: code reviewed, findings resolved | `docs/tasks/T05/review.md` (checked at close) |
| C3: every criterion maps to an executed case with evidence | This table; the report at close |
| C4: no new lint, type or security warning; quality green | TC-T05-12, 18, 19, 20, 21, 24, 34, 35, 36 |
| C5: docs and traceability updated | TC-T05-14 |
| C6: no secrets; `.env.example` reviewed | TC-T05-02, 08, 10, 15, 22 |
| C7: works from a clean checkout with documented commands | TC-T05-13, 37, 38, 39 |
| Rule: simulation only (CLAUDE.md, FR-11, ADR-0006) | TC-T05-16 |
| Rule: naming (section 0) | TC-T05-17 |
| KD-7 invariant: `git status --porcelain` empty after start, install, cex | TC-T05-09, 33, 37, 38 |
| Scope and non-goals (T06 to T10 not started early) | TC-T05-23, 19 |

## Cases

Evidence for TC-T05-01 to 24 is the block headed `== TC-T05-nn` in `evidence/run-checks.txt`,
also written to `evidence/TC-T05-nn.txt` with `T05_EVIDENCE=1`. Every case is `Not run` until
execute mode. Design-time run: `evidence/design-time-run.txt` (2 PASS, 21 FAIL, 2 BLOCKED, 1 SKIP
at the case level, because nothing is built; the two PASS cases are the T04a/T03/T04 regression
and the absence checks for scope).

### TC-T05-01: DDEV project configuration keys

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Static |
| Preconditions | `.ddev/config.yaml` committed |
| Steps | 1. `docs/tests/T05/run-checks.sh` and read block `== TC-T05-01` |
| Expected result | `name: meridian`, `type: drupal11`, `composer_root: apps/drupal`, `docroot: apps/drupal/web` (relative to the project root), `webserver_type: nginx-fpm`, `database.type: mariadb`, `xdebug_enabled: false`; file is short (60 lines or fewer) and hand-written (no `#ddev-generated` marker). Any other value, or a missing file, FAILs |
| Actual result | |
| Evidence | `evidence/TC-T05-01.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-02: Post-start hook, settings management, no secrets in DDEV config

| Field | Value |
|---|---|
| Linked criterion | AC1, C6 |
| Type | Static |
| Preconditions | as TC-T05-01 |
| Steps | 1. Read block `== TC-T05-02` |
| Expected result | `hooks.post-start` runs `composer install`; `disable_settings_management` is not true; no `web_environment` block, no key, token or password; no `additional_hostnames` (T06 owns them); no `performance_mode` override |
| Actual result | |
| Evidence | `evidence/TC-T05-02.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-03: pantheon.yml keys

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Static |
| Preconditions | `apps/drupal/pantheon.yml` committed |
| Steps | 1. Read block `== TC-T05-03` |
| Expected result | `api_version: 1`, `web_docroot: true`, `build_step: true`, `php_version` of the form `x.y`, `database.version` present; no `drush_version`; no tracked `pantheon.upstream.yml`; the file sits at `apps/drupal` (subtree split root, ADR-0004) |
| Actual result | |
| Evidence | `evidence/TC-T05-03.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-04: PHP and database version parity, three-way

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Static |
| Preconditions | files from TC-T05-01, 03, 05 |
| Steps | 1. Read block `== TC-T05-04`; 2. record the source URLs from the version table in `apps/drupal/README.md` in the evidence |
| Expected result | `pantheon.yml php_version` == `.ddev/config.yaml php_version` == major.minor of `composer.json config.platform.php` (full `x.y.z`); `pantheon.yml database.version` == `.ddev/config.yaml database.version`; PHP is 8.3 or later and the database 10.6 or later (Drupal 11 floors). Negative: the harness self-test shows a skewed fixture (8.4 vs 8.3) is detected as unequal. Any skew FAILs |
| Actual result | |
| Evidence | `evidence/TC-T05-04.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-05: composer.json structure

| Field | Value |
|---|---|
| Linked criterion | AC5 (KD-1) |
| Type | Static |
| Preconditions | `apps/drupal/composer.json` committed |
| Steps | 1. Read block `== TC-T05-05` |
| Expected result | Valid JSON; name `meridian/drupal`, type `project`, `license` set, `minimum-stability: stable`, `prefer-stable: true`, `sort-packages: true`; `require` has exactly `composer/installers`, `drupal/core-composer-scaffold`, `drupal/core-recommended`, `drush/drush`, `pantheon-systems/drupal-integrations` (no contrib module; JSON:API and Simple OAuth are T09 and T10); `require-dev` has `drupal/core-dev`; repository `https://packages.drupal.org/8`; no `upstream-configuration`; `allow-plugins` is a non-empty explicit map with no `"*"` and boolean values, allowing the installers and scaffold; scaffold `web-root: web/`, `pantheon-systems/drupal-integrations` in `allowed-packages`; installer paths for core, contrib modules, themes, profiles, libraries, drush and custom |
| Actual result | |
| Evidence | `evidence/TC-T05-05.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-06: composer.lock committed and consistent

| Field | Value |
|---|---|
| Linked criterion | AC5 (KD-1) |
| Type | Static |
| Preconditions | `apps/drupal/composer.lock` committed |
| Steps | 1. Read block `== TC-T05-06` |
| Expected result | Valid JSON with a `content-hash`; lock holds `drupal/core` 11.x, `drush/drush` 13 or later, `pantheon-systems/drupal-integrations`, `drupal/core-dev`, phpcs, Drupal coder, PHPStan, phpstan-drupal, deprecation rules and PHPUnit; `platform-overrides.php` equals `config.platform.php`; every `composer-plugin` package has an explicit `allow-plugins` entry; `vendor/` and `web/core` are untracked; if host `composer` exists, `composer validate` passes (else SKIP; TC-T05-27 covers it) |
| Actual result | |
| Evidence | `evidence/TC-T05-06.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-07: settings.php include order and config sync directory

| Field | Value |
|---|---|
| Linked criterion | AC4 (KD-4) |
| Type | Static |
| Preconditions | `apps/drupal/web/sites/default/settings.php` committed |
| Steps | 1. Read block `== TC-T05-07` |
| Expected result | `php -l` clean (when PHP exists); `$settings['config_sync_directory'] = '../config/sync'` on an uncommented line; line order `settings.pantheon.php` < `settings.ddev.php` < `config_sync_directory` < `settings.local.php`; the three includes are guarded by `file_exists()`; DDEV block conditional on `IS_DDEV_PROJECT`; `skip_permissions_hardening` set; no private path or OAuth key setting yet (T10) |
| Actual result | |
| Evidence | `evidence/TC-T05-07.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-08: settings.php carries no secrets

| Field | Value |
|---|---|
| Linked criterion | C6 (D7) |
| Type | Static (negative) |
| Preconditions | as TC-T05-07 |
| Steps | 1. Read block `== TC-T05-08` |
| Expected result | No literal `hash_salt`, no literal database `password`, `username` or `host`, no key material, API key or token pattern; `$databases = [];` reset; `settings.ddev.php`, `settings.local.php`, `settings.pantheon.php` are not tracked |
| Actual result | |
| Evidence | `evidence/TC-T05-08.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-09: Git ignore rules and generated-file invariant

| Field | Value |
|---|---|
| Linked criterion | KD-7 invariant, AC1 (clean tree) |
| Type | Static |
| Preconditions | `.gitignore` updated |
| Steps | 1. Read block `== TC-T05-09` (uses `git check-ignore`, `git ls-files -ci`) |
| Expected result | Ignored: vendor, `web/core`, contrib modules, themes, profiles, libraries, `sites/default/files`, `settings.ddev.php`, `settings.local.php`, `settings.pantheon.php`, `private/`, scaffold files (`index.php`, `update.php`, `autoload.php`, `.htaccess`, `robots.txt`, `web.config`, `default.settings.php`, `default.services.yml`), `drush/Commands/contrib`. Not ignored and present: `settings.php`, `web/modules/custom/.gitkeep`, `composer.json`, `composer.lock`, `pantheon.yml`, `config/sync/core.extension.yml`, `.ddev/config.yaml`, `drupal-install`, host `quality`, `phpcs.xml.dist`, `phpstan.neon.dist`. No tracked file matches an ignore rule; no scaffold file is tracked; old `apps/drupal/drush/contrib/` rule replaced by `drush/Commands/contrib/` |
| Actual result | |
| Evidence | `evidence/TC-T05-09.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-10: config/sync baseline from the minimal profile

| Field | Value |
|---|---|
| Linked criterion | AC2, AC4, C6 |
| Type | Static |
| Preconditions | `apps/drupal/config/sync/` committed |
| Steps | 1. Read block `== TC-T05-10` |
| Expected result | At least 10 YAML files (a real export, not a stub); `core.extension.yml` has `profile: minimal` and module `system`; no `jsonapi`, `simple_oauth`, `rest`, `basic_auth`, `consumers`; `system.site.yml` has a UUID, name `Meridian` and an `@example.com` mail; no hash salt, password or private key anywhere in the directory |
| Actual result | |
| Evidence | `evidence/TC-T05-10.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-11: drupal-install command, static

| Field | Value |
|---|---|
| Linked criterion | AC2 (KD-5) |
| Type | Static |
| Preconditions | `.ddev/commands/web/drupal-install` committed |
| Steps | 1. Read block `== TC-T05-11` |
| Expected result | Exists and executable; DDEV header with `## Description`, `## Usage: drupal-install [--force]`, `## Example`; `set -euo pipefail`; `composer install --no-interaction`; `site:install` with `--existing-config`, `--account-name=admin`, `--account-mail=admin@example.com`; an already-installed guard with `--force` and `exit 1`; `cache:rebuild` and `config:status`; prints `ddev drush uli`. Negative: no `--account-pass`, no hard-coded password, no `--db-url`; not named `site-install` |
| Actual result | |
| Evidence | `evidence/TC-T05-11.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-12: ddev quality activation, scripts and host command

| Field | Value |
|---|---|
| Linked criterion | C4 (KD-6) |
| Type | Static |
| Preconditions | `scripts/quality.sh`, `.ddev/commands/host/quality` changed |
| Steps | 1. Read block `== TC-T05-12` |
| Expected result | `quality.sh` still names `apps/drupal/composer.json`, `services/engine/pyproject.toml`, `apps/web/package.json` (T04a invariant); has `component-drupal` (runs `composer validate`, phpcs, PHPStan, and always `phpcs --version` and `phpstan --version`) and `component-drupal-tests` keyed on `apps/drupal/phpunit.xml.dist`; any empty-tree guard cites T05; host `quality` contains `${QUALITY_RUNNER:-ddev}` and does not force `ddev` (explicit `native` still wins, keeps TC-T04a-25 valid); `bash -n` clean |
| Actual result | |
| Evidence | `evidence/TC-T05-12.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-13: Runbook content

| Field | Value |
|---|---|
| Linked criterion | AC6, C7 |
| Type | Static |
| Preconditions | `docs/runbooks/local-setup.md` committed |
| Steps | 1. Read block `== TC-T05-13` |
| Expected result | Follows the runbook template headings; documents `ddev start`, `ddev drupal-install`, `ddev drush uli`, `ddev drush cex` or `config:status`, `ddev drush status`, `ddev composer validate`, `ddev quality`; prerequisites Docker, DDEV, git; clone on the WSL2 Linux filesystem, not `/mnt/c`; `mkcert`; `ddev composer` (not host composer); never apply Pantheon dashboard upstream updates; do not record the admin password; `ddev drupal-install --force` reinstall; `ddev stop --unlist` for a second clone; rollback with `ddev delete` or `poweroff`. Negative: no pasted credential, no host `composer install/update/require`, no `--no-verify` |
| Actual result | |
| Evidence | `evidence/TC-T05-13.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-14: Documentation updates

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Type | Static |
| Preconditions | docs step done |
| Steps | 1. Read block `== TC-T05-14` |
| Expected result | Runbooks index lists `local-setup`; `.ddev/README.md` covers `config.yaml`, `drupal-install` and the default runner; `apps/drupal/README.md` has layout, version table where each row has a source URL or "owner to verify" and a date, upstream reference, config workflow; `CLAUDE.md` Commands table has `ddev start`, `ddev drupal-install`, `ddev drush uli`; root README points to the runbook; CODING_STANDARDS tool rows for phpcs, coder, PHPStan carry a date and no longer say "verify"; TRACEABILITY R-11 and FR-26 rows name T05 (true at close; may FAIL until `/close-task`) |
| Actual result | |
| Evidence | `evidence/TC-T05-14.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-15: No new environment variable, no secrets in changed files

| Field | Value |
|---|---|
| Linked criterion | C6 (KD-8) |
| Type | Static (negative) |
| Preconditions | at least one `T05:` implementation commit |
| Steps | 1. Read block `== TC-T05-15`; 2. if `gitleaks` is on PATH the block also runs it |
| Expected result | `.env.example` unchanged from the parent of the first T05 implementation commit; no tracked `.env`; no private key, `sk-ant-`, AWS, GitHub or Slack token pattern in T05 files (lock excluded from the text scan because of hashes) |
| Actual result | |
| Evidence | `evidence/TC-T05-15.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-16: Simulation-only denylist

| Field | Value |
|---|---|
| Linked criterion | Rule: simulation only (FR-11, ADR-0006) |
| Type | Static (negative) |
| Preconditions | T05 files and lock committed |
| Steps | 1. Read block `== TC-T05-16` |
| Expected result | Zero hits for the generic broker and order-placement denylist (same pattern family as T03 and T04) across every tracked or untracked T05 file (the file set must be non-empty); `composer.lock` package names (non-empty list) contain no broker, trading, order or `ccxt` name; lock URLs have no trading host; `composer.json` and `.ddev/config.yaml` have no broker term or foreign host |
| Actual result | |
| Evidence | `evidence/TC-T05-16.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-17: Naming

| Field | Value |
|---|---|
| Linked criterion | Section 0 naming |
| Type | Static |
| Preconditions | none |
| Steps | 1. Read block `== TC-T05-17` (runs `scripts/check-names.sh`) |
| Expected result | `check-names` passes; DDEV `name` is `meridian`; composer vendor is `meridian`; no old placeholder name in T05 files |
| Actual result | |
| Evidence | `evidence/TC-T05-17.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-18: Shell hygiene of the new command

| Field | Value |
|---|---|
| Linked criterion | C4 (standards: Shell) |
| Type | Static |
| Preconditions | `drupal-install` committed |
| Steps | 1. Read block `== TC-T05-18` |
| Expected result | `bash -n` clean, bash shebang; `shellcheck -s bash` clean on `drupal-install`, `scripts/quality.sh` and host `quality` (SKIP if shellcheck is not installed; the pre-commit hook in TC-T05-24 then covers it); no unquoted variable in test brackets |
| Actual result | |
| Evidence | `evidence/TC-T05-18.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-19: Empty custom tree and PHP tooling configs

| Field | Value |
|---|---|
| Linked criterion | C4 (KD-6), scope |
| Type | Static (the `[at-close]` checks are snapshot `cka`) |
| Preconditions | none |
| Steps | 1. Read block `== TC-T05-19` |
| Expected result | `web/modules/custom/.gitkeep` tracked; `phpstan.neon.dist` keeps level 6, `reportIgnoresWithoutComments: true`, no baseline, still loads phpstan-drupal (explicit include or extension-installer); `[at-close]` `phpunit.xml.dist` absent and no custom module until T09 (retire these two with a Change log row when T09 starts) |
| Actual result | |
| Evidence | `evidence/TC-T05-19.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-20: composer.lock size versus the large-file hook

| Field | Value |
|---|---|
| Linked criterion | C4 (KD-7) |
| Type | Static |
| Preconditions | lock committed |
| Steps | 1. Read block `== TC-T05-20` |
| Expected result | Lock is 1024 KB or smaller; or `.pre-commit-config.yaml` excludes only `composer.lock` with a comment citing T05 and the global `maxkb` stays 1024 |
| Actual result | |
| Evidence | `evidence/TC-T05-20.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-21: Earlier suites still green

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Type | Static (regression) |
| Preconditions | none |
| Steps | 1. Read block `== TC-T05-21` (runs `docs/tests/T04a/run-checks.sh --regression`, then the T03 and T04 `--regression` sets) |
| Expected result | All exit 0. TC-T04a-35 (snapshot "no composer.json or config.yaml yet") is excluded in regression mode and is retired by a T04a Change log row at T05 close (plan, risks) |
| Actual result | |
| Evidence | `evidence/TC-T05-21.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-22: Only example.com addresses in T05 files

| Field | Value |
|---|---|
| Linked criterion | C6 (KD-5) |
| Type | Static (negative) |
| Preconditions | none |
| Steps | 1. Read block `== TC-T05-22` |
| Expected result | Every e-mail address in T05 files (lock excluded) is `@example.com`, `.org` or `.net` (RFC 2606), or `github.com`; `drupal-install` uses `admin@example.com` |
| Actual result | |
| Evidence | `evidence/TC-T05-22.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-23: Scope discipline, non-goals not started early

| Field | Value |
|---|---|
| Linked criterion | Plan non-goals (T06, T07, T08) |
| Type | Static (negative) |
| Preconditions | none |
| Steps | 1. Read block `== TC-T05-23` |
| Expected result | No extra DDEV compose files; no `.ddev/providers/pantheon.yaml`; no DDEV use in `ci.yml`; no `engine`, `pg`, `next`, `e2e` commands; only `drupal-install`, `quality` and DDEV's own files under `.ddev/commands` |
| Actual result | |
| Evidence | `evidence/TC-T05-23.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-24: Pre-commit over the whole tree

| Field | Value |
|---|---|
| Linked criterion | C4, C6 |
| Type | Static (needs bootstrapped hooks; network once) |
| Preconditions | `scripts/bootstrap-dev.sh` was run |
| Steps | 1. `.tools/pre-commit run --all-files` (the script runs it when `.tools/pre-commit` exists) |
| Expected result | Exit 0: gitleaks, large-file, yamllint, shellcheck, markdownlint, check-names all pass with the T05 files. SKIP in the script if not bootstrapped; then Blocked until the owner or a bootstrapped session runs it |
| Actual result | |
| Evidence | `evidence/TC-T05-24.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-25: Live PHP and database versions equal pantheon.yml

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Live-DDEV |
| Preconditions | `ddev start` done in the project |
| Steps | 1. `ddev exec php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'`; 2. `ddev mysql -N -e 'SELECT VERSION()'`; 3. `docs/tests/T05/run-checks.sh --live-only` |
| Expected result | PHP equals `pantheon.yml php_version`; database version starts with `pantheon.yml database.version` and reports MariaDB (for example `10.6.x-MariaDB`) |
| Actual result | |
| Evidence | `evidence/TC-T05-25.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-26: Live web and db healthy, project URL

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Live-DDEV |
| Preconditions | as TC-T05-25 |
| Steps | 1. `ddev describe -j` (script parses it) |
| Expected result | `web` and `db` services have status `running`; URL `https://meridian.ddev.site` is listed |
| Actual result | |
| Evidence | `evidence/TC-T05-26.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-27: ddev composer validate

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Live-DDEV |
| Preconditions | project started |
| Steps | 1. `ddev composer validate --no-check-publish`; 2. same with `--check-lock`; 3. `ddev composer install --no-interaction` |
| Expected result | Steps 1 and 2 exit 0 (lock in sync with `composer.json`); step 3 prints "Nothing to install, update or remove" (the post-start hook leaves vendor current; idempotent, no network) |
| Actual result | |
| Evidence | `evidence/TC-T05-27.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-28: ddev drush status

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Live-DDEV |
| Preconditions | Drupal installed (TC-T05-29 or the clean-clone install) |
| Steps | 1. `ddev drush status --format=json`; 2. `ddev drush status --field=config-sync`; 3. `ddev exec -d /var/www/html/apps/drupal test -x vendor/bin/drush` |
| Expected result | Exit 0; `bootstrap` is `Successful` and `db-status` is `Connected`; config-sync path resolves to `apps/drupal/config/sync`; Drush runs from `apps/drupal/vendor` |
| Actual result | |
| Evidence | `evidence/TC-T05-28.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-29: One documented install command with --force

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Live-DDEV (destructive to the local DB) |
| Preconditions | project started |
| Steps | 1. `ddev drupal-install --force`; 2. `ddev drush config:get system.site uuid --format=string`; 3. `ddev drush status --field=install-profile` |
| Expected result | Exit 0; output ends with the `ddev drush uli` hint; site UUID equals the one in `config/sync/system.site.yml` (config imported during install); profile `minimal` |
| Actual result | |
| Evidence | `evidence/TC-T05-29.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-30: Second install without --force refuses and leaves the site intact

| Field | Value |
|---|---|
| Linked criterion | AC2 (KD-5 step 3), negative |
| Type | Live-DDEV |
| Preconditions | TC-T05-29 passed |
| Steps | 1. count users via `ddev drush sqlq 'SELECT COUNT(*) FROM users'`; 2. `ddev drupal-install` (no flag); 3. count again; `ddev drush status --field=bootstrap` |
| Expected result | Non-zero exit; message says Drupal is already installed and names `--force`; user count unchanged; bootstrap still `Successful` |
| Actual result | |
| Evidence | `evidence/TC-T05-30.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-31: ddev drush uli logs in as admin

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Live-DDEV |
| Preconditions | installed site |
| Steps | 1. `ddev drush uli --no-browser`; 2. `curl -ksL -c jar -b jar <url>` then `curl -ksL -c jar -b jar https://meridian.ddev.site/user`; 3. negative: request `https://meridian.ddev.site/user/reset/1/0/bogus` |
| Expected result | Step 1 prints `https://meridian.ddev.site/user/reset/<uid>/...`; step 2 shows a logged-in page (log-out link, no password field); step 3 never yields a session |
| Actual result | |
| Evidence | `evidence/TC-T05-31.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-32: cex after a fresh install produces no diff

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Live-DDEV |
| Preconditions | TC-T05-29 passed |
| Steps | 1. `ddev drush config:status`; 2. `ddev drush config:export -y`; 3. `git status --porcelain -- apps/drupal/config/sync`; 4. negative control: `ddev drush config:set system.site name 'T05 probe' -y`, check `config:status` reports a difference, then `ddev drush config:import -y` |
| Expected result | Steps 1 and 2 report no differences; step 3 is empty; step 4 proves a real change is detected (so "no diff" is not vacuous) and the site name returns to `Meridian` |
| Actual result | |
| Evidence | `evidence/TC-T05-32.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-33: git status clean after start, install and cex

| Field | Value |
|---|---|
| Linked criterion | KD-7 invariant, C7 |
| Type | Live-DDEV |
| Preconditions | TC-T05-29 and 32 done in a committed tree |
| Steps | 1. `git status --porcelain`; 2. `git diff --quiet -- apps/drupal/web/sites/default/settings.php` |
| Expected result | Both empty and exit 0: DDEV, Composer, Drupal and cex wrote no tracked or unignored file; DDEV did not rewrite `settings.php` |
| Actual result | |
| Evidence | `evidence/TC-T05-33.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-34: ddev quality exit 0 (executes TC-T04a-48)

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Type | Live-DDEV |
| Preconditions | clean tree, project started |
| Steps | 1. `ddev quality` |
| Expected result | Exit 0; `PASS component-drupal`; `SKIP component-drupal-tests (no apps/drupal/phpunit.xml.dist)`; no FAIL line; engine and web steps SKIP (T13, T21). This closes the "clean tree" half of TC-T04a-48 |
| Actual result | |
| Evidence | `evidence/TC-T05-34.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-35: A PHP violation makes ddev quality fail (executes TC-T04a-49 in part)

| Field | Value |
|---|---|
| Linked criterion | C4, negative |
| Type | Live-DDEV (writes then removes `web/modules/custom/zz_t05_probe.php`) |
| Preconditions | TC-T05-34 passed |
| Steps | 1. write `<?php class bad_class{function X(){ return 1;}}` to the probe file; 2. `ddev quality`; 3. remove the file; `git status --porcelain` |
| Expected result | Non-zero exit with `FAIL component-drupal` (phpcs Drupal standard); tree clean again afterwards. The PHPStan level 6 type error and the unticketed-ignore parts of TC-T04a-49 stay with T09 unless run by hand (record which) |
| Actual result | |
| Evidence | `evidence/TC-T05-35.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-36: ddev composer audit recorded

| Field | Value |
|---|---|
| Linked criterion | Plan DoD (security, C4) |
| Type | Live-DDEV (network) |
| Preconditions | project started |
| Steps | 1. `ddev composer audit --no-interaction` |
| Expected result | Exit 0, or advisories listed with none of severity high or critical (full output kept as evidence). Blocked only if the advisory database is unreachable |
| Actual result | |
| Evidence | `evidence/TC-T05-36.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-37: Clean clone, ddev start with no manual steps

| Field | Value |
|---|---|
| Linked criterion | AC1, C7 |
| Type | Live-DDEV (clean clone; owner-run if the sandbox cannot unlist the project) |
| Preconditions | work committed; `ddev stop --unlist meridian` run; clone on the Linux filesystem |
| Steps | 1. `T05_CONFIRM=1 docs/tests/T05/run-checks.sh --clean-clone`, or manually the clean-clone procedure above; 2. note `ddev start` duration (NFR-17 data point) |
| Expected result | `git clone` succeeds; `ddev start` exits 0 with no prior step; `git status --porcelain` empty afterwards; `ddev drush status --field=drupal-version` prints `11.x` (post-start `composer install` ran). Negative sub-check in the report: an uncommitted source tree is flagged FAIL because the clone cannot contain it |
| Actual result | |
| Evidence | `evidence/TC-T05-37.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-38: Clean clone, first install without --force, cex, git status

| Field | Value |
|---|---|
| Linked criterion | AC2, AC4, KD-7 |
| Type | Live-DDEV (clean clone) |
| Preconditions | TC-T05-37 passed |
| Steps | 1. `ddev drupal-install` (no `--force`, empty database); 2. `ddev drush config:export -y`; 3. `git status --porcelain`; 4. `ddev drush uli --no-browser`; 5. the live set 25 to 36 inside the clone |
| Expected result | Install exits 0 without `--force`; config/sync untouched; whole-tree `git status` empty; `uli` prints the `meridian.ddev.site` reset URL; cases 25 to 36 pass in the clone |
| Actual result | |
| Evidence | `evidence/TC-T05-38.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T05-39: Runbook followed verbatim on a clean machine or container

| Field | Value |
|---|---|
| Linked criterion | AC6, C7 |
| Type | Owner-run (tester may approximate with a clean clone after `ddev delete -Oy meridian`; the report must say so) |
| Preconditions | runbook committed; fresh machine, container or clean clone as above |
| Steps | 1. follow `docs/runbooks/local-setup.md` word for word, copy-pasting each command; 2. record each command, output, any deviation, and the total time |
| Expected result | Every step works as written with no undocumented command; ends at a logged-in admin session via `ddev drush uli`, config status clean and `ddev quality` exit 0; any gap is a defect against the runbook |
| Actual result | |
| Evidence | `evidence/TC-T05-39.txt` |
| Status | Not run (Blocked until executed) |
| Date | |
| Executed by | |

### TC-T05-40: WSL2 browser login over HTTPS with mkcert

| Field | Value |
|---|---|
| Linked criterion | AC6 (plan risk: HTTPS trust on WSL2) |
| Type | Owner-run |
| Preconditions | Windows host with WSL2; runbook mkcert step done |
| Steps | 1. open the `ddev drush uli` URL in the Windows browser |
| Expected result | Page loads with no certificate warning and the admin session starts. The `curl -k` checks do not depend on browser trust, so this is the only check of that step |
| Actual result | |
| Evidence | `evidence/TC-T05-40.md` (owner note or screenshot reference) |
| Status | Not run (Blocked until executed) |
| Date | |
| Executed by | |

## Totals

| Type | Cases | IDs |
|---|---|---|
| Static (agent-runnable) | 24 | 01 to 24 |
| Live-DDEV | 14 | 25 to 38 (37 and 38 are the clean-clone pair) |
| Owner-run | 2 | 39, 40 |
| Total | 40 | |

Deferred T04a cases closed from here: TC-T04a-48 by TC-T05-34 and 35; TC-T04a-49 in part by
TC-T05-35 (PHPStan type error part stays with T09). Closing them needs the owner's D-6
acceptance (OQ-T04a-1, unconfirmed).

## Change log

| Date | Change | Reason |
|---|---|---|
| 2026-11-01 | Initial design | n/a |
