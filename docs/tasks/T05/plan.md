# T05: DDEV Drupal project, Plan

| Field | Value |
|---|---|
| Task | T05 |
| Author | technical-architect |
| Date | 2026-11-01 |
| Branch | `task/T05-ddev-drupal` (cut from `task/T04a-coding-standards`) |
| Status | Approved (main session, on the owner instruction "Start Phase 2 and complete T05", 2026-11-01; licence stays `proprietary` pending the owner) |
| Covers | R-11 (FR-26, Drupal part) |
| Depends on | T03 (approved; In test on owner-only items). Builds on T04a tooling (In test) |

## Goal

Create the Drupal 11 Composer project in `apps/drupal` with the Pantheon Composer-managed
layout (`web/` docroot, Integrated Composer, `pantheon-systems/drupal-integrations`), and the
DDEV project `meridian` that runs it. A clean clone needs `ddev start` and one documented
install command. After that, `ddev drush uli` logs in as admin, and `ddev drush cex` shows no
diff against `apps/drupal/config/sync`. DDEV PHP and database versions match
`apps/drupal/pantheon.yml`. `apps/drupal` is the root of the subtree split (ADR-0004), so the
same tree deploys to Pantheon in T07 without changes. T05 also activates the Drupal step of
`ddev quality` (deferred from T04a) without a vacuous pass.

Acceptance criteria from `docs/TASKS.md`, numbered for traceability:

| ID | Criterion |
|---|---|
| AC1 | `ddev start` on a clean clone starts the project without manual steps |
| AC2 | Drupal installs through one documented command (site install plus config import); `ddev drush uli` logs in as admin |
| AC3 | DDEV PHP and database versions match `pantheon.yml` |
| AC4 | Config sync directory set; `ddev drush cex` after a fresh install produces no diff |
| AC5 | `ddev composer validate` and `ddev drush status` pass |
| AC6 | `docs/runbooks/local-setup.md`, followed verbatim on a clean machine or container, works end to end |

## Key decisions (technical-architect)

Items marked **verify** are external facts written without network access. The developer
confirms each one in step 1 and records the result, source URL and date in the version table
in `apps/drupal/README.md`. If a fact is wrong, the developer uses the correct value and notes
the change in the commit. A change to a decision below (not just a version number) goes back
to the technical-architect first.

### KD-1 Composer root: hand-written `composer.json`, lock generated in DDEV

- `apps/drupal/composer.json` is **written by hand**, modelled on
  `pantheon-upstreams/drupal-composer-managed` (Drupal 11 recommended-project style). Record
  the upstream commit or tag and the date it was read in `apps/drupal/README.md`.
  `ddev composer create-project` is not used: `apps/drupal` already holds `README.md`,
  `phpcs.xml.dist` and `phpstan.neon.dist`, and DDEV's behaviour with a non-empty composer
  root is uncertain. A hand-written file is also easier to review.
- Leave out the upstream's `upstream-configuration/` path repository and its Composer scripts.
  We deploy by subtree push (ADR-0004), not by Pantheon upstream updates. The runbook says
  never to apply dashboard upstream updates.
- Content:
  - `name: meridian/drupal`, `type: project`. Set `license` to the repository's licence. The
    repo has no `LICENSE` file yet, so use `proprietary` unless the owner says otherwise.
  - Set `minimum-stability: stable` and `prefer-stable: true`.
  - Repositories: `https://packages.drupal.org/8` (composer type).
  - `require`: `composer/installers`, `drupal/core-composer-scaffold`,
    `drupal/core-recommended` (current stable Drupal 11 minor, caret constraint, **verify**),
    `drush/drush` (current major for Drupal 11, expected `^13`, **verify**),
    `pantheon-systems/drupal-integrations` (major matching Drupal 11, expected `^11`,
    **verify**). Nothing else: modules such as JSON:API and Simple OAuth arrive in T09 and T10.
  - `require-dev`: `drupal/core-dev` with the same constraint as core. Add
    `mglaman/phpstan-drupal` and `phpstan/phpstan-deprecation-rules` explicitly only if
    `core-dev` does not already bring them (**verify**). These are the tools that
    `phpcs.xml.dist` and `phpstan.neon.dist` need (T04a, D-4). Record the phpcs, coder,
    phpstan and phpstan-drupal versions resolved in the lock in the tool table of
    `docs/standards/CODING_STANDARDS.md`. This replaces the "verify" marks there.
  - `config.platform.php`: the PHP version from `pantheon.yml`, for example `"8.3.0"`. This
    resolves the lock for that platform even if Composer runs on another PHP.
  - `config.allow-plugins`: an explicit list (`composer/installers`,
    `drupal/core-composer-scaffold`, `dealerdirect/phpcodesniffer-composer-installer`,
    `phpstan/extension-installer`, and any others the install asks for, each decided
    on purpose). Never `"*": true`. Set `config.sort-packages: true`.
  - `extra.drupal-scaffold.locations.web-root: web/`. Allow
    `pantheon-systems/drupal-integrations` in `allowed-packages` as the upstream does
    (**verify** the key).
  - `extra.installer-paths`: core in `web/core`, contrib in
    `web/{modules,themes,profiles}/contrib/{$name}`, libraries in `web/libraries/{$name}`,
    drush in `drush/Commands/contrib/{$name}`, custom in `web/modules/custom/{$name}`.
- `composer.lock` is committed. `vendor/`, `web/core/`, contrib directories, scaffolded files
  and DDEV-generated files are git-ignored (see KD-7).
- The lock is created once with `ddev composer update` and then installed with
  `ddev composer install`. Host PHP is 8.1, so host `composer` is never used. If the agent
  sandbox blocks package downloads, the owner runs `ddev composer update` and the developer
  commits the result. Record in the commit who generated the lock.

### KD-2 `apps/drupal/pantheon.yml`

```yaml
api_version: 1
web_docroot: true
php_version: 8.3
database:
  version: 10.6
build_step: true
```

- **PHP 8.3**: the Drupal 11 minimum. Pantheon, DDEV v1.24.4 and the contrib modules we need
  later (Simple OAuth, phpstan-drupal) all support it. It has security support until the end of
  2027, past the project horizon (**verify** that Pantheon still offers 8.3; 8.4 is the
  fallback if not). It matches "PHP 8.3 or later" in `CODING_STANDARDS.md`. Moving to 8.4 later
  is a one-line change in three files (pantheon.yml, `.ddev/config.yaml`,
  `config.platform.php`), and the T05 check script compares all three.
- **MariaDB 10.6**: the Drupal 11 minimum. Pantheon supports it for new sites and DDEV v1.24.4
  ships the image (**verify** both).
- **`build_step: true`**: Integrated Composer. Pantheon runs `composer install` from the lock,
  so vendor and scaffold files are not committed. T07 confirms the build behaviour (D8
  unverified list).
- **`web_docroot: true`**: required for the nested `web/` docroot (**verify**).
- **No `drush_version`**: Composer-managed sites use the Drush in `vendor/` (**verify**).
  `enforce_https`, `protected_web_paths` and similar settings are left to T07.
- Only `apps/drupal/pantheon.yml` exists. There is no `pantheon.upstream.yml` in the repo. If
  `drupal-integrations` scaffolds one, it is git-ignored, or disabled in `file-mapping` if it
  would conflict.

### KD-3 `.ddev/config.yaml`

Write it by hand and keep it short. Run `ddev config --auto` only to compare, never to
commit its full commented output.

```yaml
name: meridian
type: drupal11
docroot: apps/drupal/web        # relative to the project root, not the composer root
composer_root: apps/drupal      # relative to the project root
php_version: "8.3"              # must equal pantheon.yml php_version
database:
  type: mariadb
  version: "10.6"               # must equal pantheon.yml database.version
webserver_type: nginx-fpm       # Pantheon serves with nginx
xdebug_enabled: false
hooks:
  post-start:
    - composer: install
```

- `docroot` is relative to the DDEV project root, so it is `apps/drupal/web`, as in D8 of
  `technical-design.md`. The `docroot: web` in the `TASKS.md` text is only an example.
- `composer_version`: leave the DDEV default (Composer 2). Add no extra hostnames: the project
  URL `https://meridian.ddev.site` comes from `name`. T06 adds the `meridian-web` host.
- `upload_dirs`: the drupal11 default (`sites/default/files` under the docroot) is enough.
  Do not set it.
- `performance_mode`: leave the default. On Linux and WSL2 the default is no Mutagen, which is
  correct when the clone is on the WSL2 Linux filesystem (see Risks).
- The `post-start` hook runs `composer install`, so after `ddev start` vendor matches the lock
  and `ddev drush` works (AC1). With a vendor directory that already matches the lock it does
  nothing and needs no network. **Verify** the hook syntax and that a failing hook makes
  `ddev start` exit non-zero.
- No `web_environment` secrets. DDEV sets `IS_DDEV_PROJECT` and `DRUSH_OPTIONS_URI` itself, so
  `ddev drush uli` prints `https://meridian.ddev.site/...` (**verify**).
- Settings management stays on: do **not** set `disable_settings_management`. DDEV writes
  `settings.ddev.php` (database, hash salt, trusted hosts) and we git-ignore it. Because the
  committed `settings.php` already contains the DDEV include block, DDEV does not change it
  (**verify**: after `ddev start` on a clean clone, `git status` must be clean).

### KD-4 `settings.php` (committed, owned by us)

`apps/drupal/web/sites/default/settings.php` follows the upstream's file, in this order:

1. Core defaults that matter: `$databases = [];`, `file_scan_ignore_directories`
   (`node_modules`, `bower_components`), `entity_update_batch_size`.
2. `include __DIR__ . '/settings.pantheon.php';`, guarded by `file_exists()`. The file comes
   from `drupal-integrations` scaffolding and is git-ignored. Pantheon provides the database,
   hash salt and private path there (**verify**).
3. `$settings['skip_permissions_hardening'] = TRUE;` as in the upstream (**verify** that the
   upstream still has it).
4. The DDEV block, exactly as DDEV generates it: include `settings.ddev.php` when
   `getenv('IS_DDEV_PROJECT') == 'true'` and the file exists.
5. `$settings['config_sync_directory'] = '../config/sync';` comes **after** the platform
   includes, so neither the Pantheon nor the DDEV default can override it. The path is relative
   to `web/`, so it resolves to `apps/drupal/config/sync` (D8).
6. `settings.local.php` include last, guarded by `file_exists()`. That file is git-ignored.

Rules (D7, C6):

- No literal `hash_salt`, database credentials, API key or private key in `settings.php`.
  DDEV's generated `settings.ddev.php` provides the local hash salt and database. On Pantheon,
  `settings.pantheon.php` provides them from platform variables (`DRUPAL_HASH_SALT`; platform
  provided, so it is not in `.env.example` per D7). If a new environment ever lacks both,
  Drupal fails loudly. There is no hard-coded fallback.
- `file_private_path` and the OAuth key paths are not set in T05. T10 adds them (D6, D7).
  T05 git-ignores `apps/drupal/private/` now (D8).
- `settings.php` is outside the phpcs and PHPStan scope (`web/modules/custom`). Keep it plain
  and commented.

### KD-5 Install profile and the one install command

- **Profile: `minimal`.** The site is headless (ADR-0001). `standard` adds article, page,
  comment, a front-end theme and other config that T09 would have to remove. `minimal` also
  installs cleanly from existing config (**verify** for the Drupal 11 minor in the lock).
- **One-time config bootstrap (developer, once):**
  `ddev drush site:install minimal --site-name=Meridian --account-name=admin
  --account-mail=admin@example.com --site-mail=admin@example.com -y`, then
  `ddev drush config:export -y`, then commit `apps/drupal/config/sync/`. Only
  `example.com` addresses (RFC 2606). Never a real mailbox.
- **The documented command: `ddev drupal-install`**, a DDEV web command at
  `.ddev/commands/web/drupal-install`. It is named so it is not confused with drush
  `site:install`. Behaviour:
  1. `set -euo pipefail`. Change to the composer root (`/var/www/html/apps/drupal`; use the
     DDEV variable if one exists, **verify**).
  2. `composer install --no-interaction`. Does nothing when vendor is current, and covers a
     `git pull` that changed the lock.
  3. If Drupal is already installed (`drush status --field=bootstrap` reports success),
     refuse with a message and exit 1, unless `--force` is passed. Reinstalling drops the
     local database, so it must never happen by accident.
  4. `drush site:install --existing-config --yes --account-name=admin
     --account-mail=admin@example.com`. This one call is the site install and the config
     import. It keeps the committed site UUID.
  5. `drush cache:rebuild`, then `drush config:status`. Fail if it reports any difference.
  6. Print the next step: `ddev drush uli`.
- The header has `## Description`, `## Usage: drupal-install [--force]` and `## Example`, like
  the existing `quality` command. shellcheck-clean.
- AC4 check: after `ddev drupal-install`, `ddev drush config:export -y` leaves
  `git status --porcelain apps/drupal/config/sync` empty, and `ddev drush config:status` says
  no differences. If Drupal writes extra files into the sync directory on install (for example
  `.htaccess`, **verify**), commit them, so this check is stable.

### KD-6 `ddev quality` activation (in scope, tightly)

T05 adds `apps/drupal/composer.json`, which is the Drupal manifest in `scripts/quality.sh`. The
`component-drupal` step therefore stops being SKIP and would FAIL: there is no custom module
yet, so phpcs and PHPStan have no input, PHPUnit has no tests, and the coverage gate's
`--require web/modules/custom/meridian_` matches no file. C4 requires `quality` to stay green,
and a hidden "pass when empty" would be a vacuous pass. The decision:

1. **Split the Drupal step in `scripts/quality.sh`** and keep the T04a invariant that the
   script names `apps/drupal/composer.json` (T04a `run-checks.sh` checks it):
   - `component-drupal` (manifest `apps/drupal/composer.json`): `composer validate`, then
     phpcs, then PHPStan with the committed configs.
   - `component-drupal-tests` (manifest `apps/drupal/phpunit.xml.dist`): PHPUnit with
     coverage, then the coverage gate, unchanged from T04a. T05 does **not** add
     `phpunit.xml.dist`. T09 adds it with the first module, so the step shows a visible
     `SKIP  component-drupal-tests (no apps/drupal/phpunit.xml.dist)` until then. This uses the
     T04a SKIP rule as designed.
2. **Empty custom tree.** Commit `apps/drupal/web/modules/custom/.gitkeep` so the phpcs and
   PHPStan path exists. The developer checks how phpcs and PHPStan behave on a directory with
   no PHP files (**verify**: PHPStan may report "No files found to analyse" and exit
   non-zero):
   - If both exit 0, run them unconditionally.
   - If either exits non-zero, run that tool only when `web/modules/custom` holds at least one
     `.php`, `.module`, `.inc` or `.install` file. Otherwise print
     `phpstan: not run, no custom PHP yet (T09)`. `composer validate` and the tool version
     calls (`vendor/bin/phpcs --version`, `vendor/bin/phpstan --version`) always run, so a
     missing tool is still a FAIL (T04a rule).
   - Record the result and any guard in a comment that cites T05. T09 removes the guard.
3. **PHPStan extension loading.** If `phpstan/extension-installer` is installed (it probably
   comes with `core-dev`), check whether the manual `includes:` in `phpstan.neon.dist` cause a
   duplicate-include error (**verify**). If they do, remove the `includes:` and add a comment
   saying the extension installer loads phpstan-drupal and the deprecation rules. The T04a
   check accepts either `phpstan-drupal` or `extension-installer` in the file. Level 6,
   `reportIgnoresWithoutComments`, the paths and "no baseline" do not change.
4. **`ddev quality` uses the DDEV runner by default.** In `.ddev/commands/host/quality`, set
   `export QUALITY_RUNNER="${QUALITY_RUNNER:-ddev}"` before the `exec`. Host PHP may be too
   old (it is 8.1 here). An explicit `QUALITY_RUNNER=native` still wins, which keeps T04a
   TC-25 valid. The engine and web steps keep their `ddev engine` and `ddev next` mapping. They
   SKIP until T13 and T21, and T06 adds those commands.
5. Native `scripts/quality.sh` on a host without PHP 8.3 and without vendor gives FAIL on
   `component-drupal`. That is correct (missing tool) and documented: use `ddev quality`. CI
   decides its runner in T08.
6. Out of scope: Drupal unit tests, `phpunit.xml.dist`, the coverage gate on Drupal (T09),
   `composer audit` in the quality suite (needs network; T08 CI). The developer runs
   `ddev composer audit` once and records the output. Any high or critical advisory in core is
   fixed by moving to the patched core release before review.

### KD-7 Git-ignore and generated files

The invariant: on a clean clone, after `ddev start`, `ddev drupal-install` and
`ddev drush cex -y`, **`git status --porcelain` is empty**. The developer adjusts
`.gitignore` until this holds, and lists every generated path in the commit. Expected entries,
added to the existing Drupal block (**verify** each against a real install):

- `apps/drupal/vendor/` (the root `vendor/` rule already covers it; keep it explicit).
- Scaffolded files in `apps/drupal/web/`: `index.php`, `update.php`, `autoload.php`,
  `.htaccess`, `robots.txt`, `web.config`, `*.txt` scaffold docs,
  `sites/default/default.settings.php`, `sites/default/default.services.yml`,
  `sites/example.*`, `sites/development.services.yml`, `sites/default/settings.pantheon.php`.
  Also project-root scaffold files in `apps/drupal/` (`.editorconfig`, `.gitattributes`), and
  anything `drupal-integrations` writes. Use explicit paths, or ignore `web/*` and re-include
  the owned paths (`web/modules/custom/`, `web/themes/custom/`,
  `web/sites/default/settings.php`), whichever is clearer. Do not commit core scaffold files:
  Integrated Composer regenerates them (KD-2).
- `apps/drupal/web/sites/*/settings.ddev.php`, and DDEV's generated
  `apps/drupal/web/sites/default/.gitignore` if DDEV writes one.
- Fix the existing rule `apps/drupal/drush/contrib/` to `apps/drupal/drush/Commands/contrib/`
  so it matches `installer-paths`.
- `apps/drupal/private/` (D8).
- `.ddev/`: commit `config.yaml`, `commands/web/drupal-install`, the existing
  `commands/host/quality` and `README.md`. DDEV writes `.ddev/.gitignore` itself (marked
  `#ddev-generated`) and it covers its own generated files. Commit that file only if it does
  not change between runs. Otherwise ignore it in the root `.gitignore`. Same rule for example
  command files DDEV adds (**verify**).
- Size: `composer.lock` with `core-dev` may come close to the 1024 KB
  `check-added-large-files` limit. If it is over the limit, exclude only `composer.lock` from
  that hook, with a comment that cites T05 (exceptions rule, T04a). Do not raise the global
  limit.

### KD-8 Secrets and environment variables

- T05 adds no variable to `.env.example`. `IS_DDEV_PROJECT`, `DDEV_*`,
  `PANTHEON_ENVIRONMENT` and `DRUPAL_HASH_SALT` are platform provided and excluded by D7.
  State this in the review evidence (C6).
- The admin password that `drush site:install` prints is local and throwaway. The runbook
  tells people to use `ddev drush uli` and never to record the password.

## Scope

- `apps/drupal/composer.json`, `composer.lock`, `pantheon.yml`,
  `web/sites/default/settings.php`, `config/sync/` (minimal profile export),
  `web/modules/custom/.gitkeep`.
- `.ddev/config.yaml` and `.ddev/commands/web/drupal-install`.
- `scripts/quality.sh` (Drupal step split, KD-6), `.ddev/commands/host/quality` (default
  runner), and `apps/drupal/phpstan.neon.dist` only if KD-6 item 3 requires it.
- `.gitignore` (KD-7). Possibly `.pre-commit-config.yaml` (lock size exclusion only, KD-7).
- Docs: new `docs/runbooks/local-setup.md` (from `docs/templates/runbook.md`). Update
  `docs/runbooks/README.md` (index), `.ddev/README.md` (config.yaml done, `drupal-install`,
  `ddev quality` default runner), `apps/drupal/README.md` (layout, version table with sources
  and dates, upstream reference, the config workflow `cex` and commit), root `README.md`
  ("Getting started": point to the runbook) and the tool table in `CODING_STANDARDS.md`
  (resolved PHP tool versions). `CLAUDE.md` Commands table: add `ddev start`,
  `ddev drupal-install`, `ddev drush uli` and note that `ddev quality` now works. The owner
  approves this `CLAUDE.md` change when approving the plan.

## Non-goals

- Extra services (Postgres, engine, Next.js), `ddev engine`, `ddev pg`, `ddev next`,
  `ddev e2e` (T06).
- Pantheon site creation, `providers/pantheon.yaml`, `ddev pull pantheon`,
  `deploy-drupal.yml`, Pantheon edge settings (T07). CI (T08).
- Any contrib module (JSON:API, Simple OAuth, and so on), custom modules, content types,
  `phpunit.xml.dist`, private files path, OAuth keys (T09, T10).
- A front-end or admin theme change beyond what `minimal` installs.
- Retiring or editing T04a test cases. The tester owns that. See "Test hooks".

## Steps

Each step is one reviewable commit (`T05: ...`). Run `.tools/pre-commit run --all-files`
before each commit.

1. **Verify facts.** Check every **verify** item in KD-1 to KD-7 against official sources
   (Pantheon docs for `pantheon.yml` keys, PHP and MariaDB versions; DDEV docs for
   `composer_root`, `docroot`, hooks and settings management; drupal.org for the current
   Drupal 11 minor and Drush major). Record them in the version table in
   `apps/drupal/README.md` with URL and date. If the network is blocked, mark the row
   "owner to verify" and continue with the planned values.
2. **DDEV config.** Add `.ddev/config.yaml` without the `post-start` hook. Run `ddev start` and
   `ddev describe`. Commit together with the `.ddev` and `.gitignore` changes.
3. **Composer project.** Add `composer.json` and `pantheon.yml`. Run `ddev composer update`
   to create the lock (or ask the owner, KD-1). Run `ddev composer validate`. Add the
   `.gitignore` entries for vendor and scaffolded files. Run `git status` to show only owned
   files.
4. **Settings.** Add `settings.php` (KD-4). Run `ddev restart`. Check that `git status` is
   clean and that `ddev drush status --field=config-sync` resolves to `../config/sync`.
5. **Config bootstrap.** Run the one-time install and export (KD-5) and commit
   `config/sync/`.
6. **Install command and hook.** Add `.ddev/commands/web/drupal-install` and the `post-start`
   hook. Prove `ddev drupal-install --force`, then `cex` with no diff, then `ddev drush uli`.
7. **Quality.** Make the KD-6 changes to `scripts/quality.sh`, the `quality` host command and
   possibly `phpstan.neon.dist`. Run `ddev quality` and get exit 0, with
   `component-drupal` PASS and `component-drupal-tests` SKIP. Re-run
   `docs/tests/T04a/run-checks.sh --regression` and show no invariant regression.
8. **Docs.** Write the runbook and make the README, CLAUDE.md and standards table updates
   (Scope).
9. **Clean-clone rehearsal (developer).** Make a fresh `git clone` of the branch into a
   scratch directory. Unlist the existing project first: run `ddev stop --unlist meridian`
   (two DDEV projects with the same name cannot coexist). Then follow the runbook verbatim.
   Record the time taken and any gaps, and fix the runbook. Afterwards restore the working
   project.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| `.ddev/config.yaml` | New: project `meridian`, `drupal11`, `composer_root`, `docroot`, PHP and DB versions | T06 (adds compose files), T07 (Pantheon provider), T08 (CI may run DDEV), all developers |
| `ddev drupal-install [--force]` | New web command; the only documented install path | Runbook, tester, T09 and T10 (reinstall after config changes), T27 (`ddev e2e` seed) |
| `apps/drupal/composer.json` and `composer.lock` | New Drupal Composer root | T07 (Integrated Composer build), T09 and T10 (add modules), T08 (`composer audit`) |
| `apps/drupal/pantheon.yml` | New; source of truth for PHP and DB versions | T07 deploy, KD-2 parity check |
| `settings.php` | New; include order, `config_sync_directory` | T07 (Pantheon), T10 (private path, OAuth key paths) |
| `apps/drupal/config/sync/` | New; minimal profile baseline | T09 onward (every config change exported here) |
| `scripts/quality.sh` | Drupal step split into `component-drupal` and `component-drupal-tests` (manifest `phpunit.xml.dist`) | `ddev quality`, T08 CI, T09 (adds `phpunit.xml.dist`, removes any empty-tree guard) |
| `.ddev/commands/host/quality` | Defaults `QUALITY_RUNNER` to `ddev` | Developers, TC-T04a-48 |
| `.gitignore` | Drupal scaffold, DDEV-generated and `private/` entries | Everyone |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Agent sandbox blocks Docker image pulls or Composer downloads | High | Medium | The developer tries first. Steps that cannot run (lock generation, `ddev start`, install) become owner-run, each with the exact command. The developer commits the owner's output (lock) with a note. Static checks still run without network |
| WSL2 file performance, or the clone placed on `/mnt/c` | Medium | Medium | The runbook requires the clone on the WSL2 Linux filesystem (for example `~/`). Leave Mutagen off (DDEV default on Linux and WSL2). Note `ddev poweroff` if ports clash |
| HTTPS trust on WSL2 (mkcert CA not trusted by the Windows browser) | Medium | Low | The runbook gives the DDEV WSL2 mkcert step (**verify** the current DDEV instructions). `ddev drush uli` and `curl -k` checks do not depend on browser trust |
| First run is slow (image pulls, Composer download) and pushes NFR-17 (30 min, owned by T27 and T32) | Medium | Low | Record the measured time in the T05 evidence as an early data point. No gate in T05 |
| Pantheon version drift: the PHP or MariaDB version is no longer offered, or the defaults change | Medium | Medium | KD-2 verify step. A three-way parity check (pantheon.yml, `.ddev/config.yaml`, `config.platform.php`) in the T05 check script. T07 re-confirms on a real Pantheon site |
| DDEV changes `settings.php` or writes untracked files, so the clean-clone `git status` is dirty | Medium | Medium | Commit the DDEV include block exactly as DDEV generates it. Use the KD-7 invariant and test it on a clean clone |
| Install from existing config fails for the chosen profile, or `cex` shows a diff after install (UUID, langcode, generated files) | Low | High | Use the `minimal` profile. `drupal-install` fails on any `config:status` difference. Test with `--force` reinstall and on a clean clone |
| PHPStan or phpcs fail on an empty custom directory and break `ddev quality` | Medium | Medium | KD-6 item 2: measure the behaviour, then run the tools unconditionally or guard them. Tool version calls always run |
| `composer.lock` over the 1 MB pre-commit limit, or gitleaks false positive on lock hashes | Low | Low | KD-7: narrow exclusion with a ticket-cited comment. Never `--no-verify` |
| Security advisories in the locked core | Low | Medium | `ddev composer audit` once (KD-6 item 6). Update to the patched core release before review |
| T04a not yet Done; T05 branch stacked on it | Medium | Low | Merge order T04a then T05. If T04a changes `quality.sh` during its close, rebase T05 and re-run step 7 |
| The T04a snapshot case TC-T04a-35 ("no composer.json or config.yaml yet") turns false | Certain | Low | Expected. It is a snapshot (`cka`) case, true only at T04a close. Run T04a checks with `--regression` on this branch. The tester records the retirement in the T04a Change log |
| Simulation-only rule (FR-11, ADR-0006) | Very low | High | T05 adds only Drupal core, Drush, the Pantheon integration and dev tools. No broker package, SDK, host or credential. `scripts/check-names.sh`, a denylist grep of the new files and a review of `composer.lock` package names are in the check script |

## Test hooks needed

Hints for the tester (`/design-tests T05`). The tester designs the cases and the evidence
layout.

- **`docs/tests/T05/run-checks.sh`, agent-runnable without DDEV or network** (static):
  - The files exist and parse: YAML (`.ddev/config.yaml`, `pantheon.yml`), JSON
    (`composer.json`, `composer.lock`), PHP lint of `settings.php` if a PHP binary is
    available.
  - Version parity: `pantheon.yml` `php_version` equals `.ddev/config.yaml` `php_version`
    equals the major.minor of `composer.json` `config.platform.php`, and the database
    versions match, with `database.type: mariadb` (AC3, static part).
  - `.ddev/config.yaml`: `name: meridian`, `type: drupal11`, `composer_root: apps/drupal`,
    `docroot: apps/drupal/web`.
  - `pantheon.yml`: `api_version: 1`, `build_step: true`, `web_docroot: true`.
  - `composer.json`: required packages present; `allow-plugins` explicit with no `"*"`;
    `web-root` is `web/`; installer paths for core, contrib and custom.
  - `settings.php`: `config_sync_directory` is `'../config/sync'` and comes after both
    platform includes; no literal `hash_salt` value, `$databases` credentials or key material.
  - `git check-ignore` confirms vendor, `web/core`, contrib, `settings.ddev.php`,
    `settings.local.php`, `settings.pantheon.php`, `private/` and the scaffold files are
    ignored. `git ls-files apps/drupal` contains none of them.
  - `config/sync/core.extension.yml` names profile `minimal`. `system.site.yml` has a UUID and
    an `example.com` mail.
  - `drupal-install` exists, is executable, passes shellcheck, refuses without `--force` on an
    installed site (static grep plus the live case), and uses `--existing-config`.
  - `scripts/quality.sh` still names the three manifests (T04a invariant) and now names
    `apps/drupal/phpunit.xml.dist`. The `quality` host command defaults the runner with
    `${QUALITY_RUNNER:-ddev}`.
  - Hygiene: `scripts/check-names.sh`, a broker and trading-host denylist over the new files
    and the `composer.lock` package names, and gitleaks (or the pre-commit hook) on the
    changed files. `.env.example` is unchanged (C6).
- **Live cases (need DDEV and network; the tester runs them if possible, otherwise they are
  owner-run):**
  - Clean clone into `/tmp` (or the scratch dir), after `ddev stop --unlist meridian`:
    `ddev start` exits 0 and `ddev describe` shows web and db healthy (AC1). Then
    `git status --porcelain` is empty.
  - `ddev exec php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'` and
    `ddev mysql -N -e 'SELECT VERSION()'` match `pantheon.yml` (AC3, live part).
  - `ddev drupal-install`, then `ddev drush uli` gives a `https://meridian.ddev.site/user/reset/`
    URL, and following it with `curl -k -L` (cookie jar) reaches a logged-in page (AC2).
    A second `ddev drupal-install` without `--force` exits non-zero and leaves the site intact.
  - `ddev drush cex -y`, then `git status --porcelain apps/drupal/config/sync` is empty and
    `ddev drush config:status` reports no differences (AC4).
  - `ddev composer validate` exit 0. `ddev drush status` shows a successful bootstrap and a
    database connection (AC5).
  - `ddev quality` exit 0, with `component-drupal` PASS and `component-drupal-tests` SKIP.
    This executes the deferred T04a case **TC-T04a-48**. The phpcs and PHPStan rejection
    demo (**TC-T04a-49**) can run here with a throwaway module in a scratch clone. Otherwise
    it stays deferred to T09.
  - Re-run `docs/tests/T04a/run-checks.sh --regression` with no new failures.
- **AC6 (runbook verbatim on a clean machine or container):** owner-run unless the tester can
  get a fresh environment. A clean clone with `ddev delete -Oy meridian` first is the agent
  approximation, and the report must say so. The tester follows
  `docs/runbooks/local-setup.md` word for word and records each command, its output and the
  total time.
- The evidence for the version parity check also records the verified source URLs from
  `apps/drupal/README.md`.

## Decisions needed from solution-architect

None. All choices above are within the existing design (ADR-0001, ADR-0004, D7, D8).

Notes for the owner, not the solution-architect:

- The `CLAUDE.md` Commands table edit (Scope) needs the owner's approval with this plan.
- The `composer.json` `license` value: `proprietary` unless the owner chooses a licence.
- T04a's D-6 policy for deferred cases (OQ-T04a-1) is still unconfirmed. It affects whether
  TC-T04a-48 and TC-T04a-49 can be closed from T05 evidence.

## Definition of done

- [ ] All task acceptance criteria in `docs/TASKS.md` met (AC1 to AC6 above)
- [ ] Every **verify** item confirmed or marked owner-to-verify in the
  `apps/drupal/README.md` version table
- [ ] On a clean clone, `git status --porcelain` is empty after `ddev start`,
  `ddev drupal-install` and `ddev drush cex -y` (KD-7)
- [ ] `ddev quality` exits 0, with `component-drupal` PASS and `component-drupal-tests` SKIP.
  T04a `--regression` checks show no new failure
- [ ] `ddev composer audit` output recorded; no unresolved high or critical advisory
- [ ] C1: Plan exists and was reviewed before coding started
- [ ] C2: Code reviewed; findings resolved
- [ ] C3: Every criterion maps to an executed test case with evidence
- [ ] C4: CI green, no new lint, type or security warnings (pre-commit and `ddev quality`;
  `ci.yml` arrives in T08)
- [ ] C5: Docs and traceability updated (runbook, READMEs, `CLAUDE.md`, standards tool table;
  TRACEABILITY R-11 and FR-26 rows name the T05 evidence)
- [ ] C6: No secrets; `.env.example` reviewed, with no new variable (KD-8)
- [ ] C7: Works from a clean checkout with documented commands (AC1, AC6)
