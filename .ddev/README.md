# .ddev

DDEV configuration for the local stack. The DDEV project name is `meridian`
(`https://meridian.ddev.site`).

This folder is filled in Phase 2:

| File | Task | Purpose |
|---|---|---|
| `config.yaml` | T05 | Drupal project (`composer_root: apps/drupal`, `docroot: apps/drupal/web`, PHP 8.3, MariaDB 10.6) |
| `commands/web/drupal-install` | T05 | `ddev drupal-install [--force]` |
| `docker-compose.postgres.yaml` | T06 | `meridian-postgres` service |
| `docker-compose.engine.yaml` | T06 | `meridian-engine` service |
| `docker-compose.next.yaml` | T06 | `meridian-web` service |
| `commands/` | T06 | Custom commands: `ddev engine`, `ddev pg`, `ddev next`, `ddev e2e` (`ddev quality` exists from T04a) |
| `providers/pantheon.yaml` | T07 | `ddev pull pantheon` |

## config.yaml (T05)

Hand-written and short. `docroot` and `composer_root` are relative to the project root. PHP
8.3 and MariaDB 10.6 must equal `apps/drupal/pantheon.yml` and `composer.json`
`config.platform.php`. The `post-start` hook runs `composer install`, and `fail_on_hook_fail`
makes a failing hook fail `ddev start`. Settings management stays on: DDEV writes
`settings.ddev.php`, which is git-ignored.

## ddev drupal-install (T05)

`ddev drupal-install [--force]` is the one documented install command. It runs
`composer install`, then `drush site:install --existing-config` (site install and config import
in one call), rebuilds caches and fails if `drush config:status` shows a difference. If Drupal is
already installed it refuses with exit 1 unless `--force` is given. `--force` drops the local
database.

## ddev quality (T04a, T05)

`commands/host/quality` is a thin wrapper that runs `scripts/quality.sh` (the only
implementation of the quality checks) with the same arguments. Since T05 it defaults
`QUALITY_RUNNER` to `ddev`, so the Drupal tools run inside the web container (host PHP may be too
old). `QUALITY_RUNNER=native ddev quality` still selects the native runner. The engine and web
steps SKIP until T13 and T21; T06 adds `ddev engine` and `ddev next`.
