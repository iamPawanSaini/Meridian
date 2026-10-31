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
