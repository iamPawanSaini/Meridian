# .ddev

DDEV configuration for the local stack. The DDEV project name is `meridian`
(`https://meridian.ddev.site`).

This folder is filled in Phase 2:

| File | Task | Purpose |
|---|---|---|
| `config.yaml` | T05 | Drupal project (`composer_root: apps/drupal`, `docroot: web`) |
| `docker-compose.postgres.yaml` | T06 | `meridian-postgres` service |
| `docker-compose.engine.yaml` | T06 | `meridian-engine` service |
| `docker-compose.next.yaml` | T06 | `meridian-web` service |
| `commands/` | T06 | Custom commands: `ddev engine`, `ddev pg`, `ddev next`, `ddev e2e`, `ddev quality` |
| `providers/pantheon.yaml` | T07 | `ddev pull pantheon` |

## ddev quality (T04a)

`commands/host/quality` exists now. It is a thin wrapper that runs `scripts/quality.sh` (the only
implementation of the quality checks) with the same arguments. `ddev quality` works once T05 adds
`config.yaml`; until then run `scripts/quality.sh` directly. T05 and T06 map
`QUALITY_RUNNER=ddev` to `ddev exec`, `ddev engine` and `ddev next` for the component steps.
