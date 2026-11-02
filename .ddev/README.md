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
| `commands/host/engine`, `next`, `pg`, `meridian-status` | T06 | Custom commands: `ddev engine`, `ddev next`, `ddev pg`, `ddev meridian-status` (`ddev quality` exists from T04a) |
| `meridian-engine/entrypoint.sh` | T06 | Builds the CA bundle (system CAs plus the DDEV mkcert root), then runs the command |
| `meridian-web/start.sh`, `placeholder-server.mjs` | T06 | Starts `npm run dev` when `apps/web/package.json` exists, else the placeholder server |
| `commands/host/e2e` | T27 | `ddev e2e`, not part of the services task |
| `providers/pantheon.yaml` | T07 | `ddev pull pantheon` (pull only; takes a fresh backup first) |
| `commands/web/deploy-drupal` | T07 | `ddev deploy-drupal [--ref REF] [--dry-run] [--allow-unmerged]`, a wrapper of `scripts/deploy-drupal.sh` |
| `web-build/Dockerfile` | T07 | Installs the pinned Terminus 4.3.3 in the web image |

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

## Services and commands (T06)

Three extra services join the DDEV project. `ddev start` brings up all five containers (`web`,
`db`, `meridian-postgres`, `meridian-engine`, `meridian-web`) and waits for their health checks.
Images are pinned by tag and digest (official Docker Hub images only). Each service reads
`.env.example`, then the optional `.env`.

- `meridian-postgres`: Postgres 16, database and user `meridian`, named volume
  `meridian-postgres-data` (labelled for DDEV; `ddev delete` removes it, so run `ddev pg dump`
  first). No host port.
- `meridian-engine`: Python 3.12 runtime, idle until T13 adds `services/engine/Dockerfile`.
  Reaches Drupal at `https://meridian.ddev.site` through `ddev-router`, trusting the mkcert
  root via `SSL_CERT_FILE`.
- `meridian-web`: Node 22 runtime. **`https://meridian.ddev.site:3001` serves a placeholder until
  T21** (the Next.js app arrives then). The router maps port 3001 to container port 3000.

| Command | What it does |
|---|---|
| `ddev engine <cmd> [args...]` | Runs `<cmd>` in `meridian-engine`, in `/var/www/html/services/engine`. Arguments pass through unchanged |
| `ddev next <cmd> [args...]` | Same for `meridian-web`, in `/var/www/html/apps/web` |
| `ddev pg psql [args...]` | psql as `meridian` on database `meridian` |
| `ddev pg dump [FILE]` | Custom-format dump, default `db-dumps/meridian-postgres-<UTC>.dump` (git-ignored) |
| `ddev pg restore FILE --yes` | Replaces the `meridian` database with the dump; validates the file first |
| `ddev meridian-status` | State and health of the five services; exit 1 and a last line of standard output naming the bad ones |

`ddev engine` and `ddev next` use `docker exec` (see the facts below). DDEV reports every failed
host command as exit status 1, so the exit codes 2 (usage) and N (command status) are visible
only when a script is run directly, for example `.ddev/commands/host/pg bogus`. Through
`ddev`, a failure is exit 1, and the original status N appears only in the stderr line
`Failed to run ...; error=exit status N`.

## Verified facts (T06)

Checked by the developer on 2026-11-02 with DDEV v1.24.4, Docker 28.1.1, docker-compose v2.34.0
on WSL2. Sources are the commands run. The tester's evidence for the network and TLS facts is
in `docs/tests/T06/evidence/`: TC-T06-23, TC-T06-24 and TC-T06-40 (run 20261102T064955Z), all
Pass; the full list is in `docs/tests/T06/test-report.md`.

| Fact | Result | Source |
|---|---|---|
| Image `postgres:16.15-trixie` | Exists, multi-arch index digest `sha256:5db6dac2ef5dcff512f4f00a009c3c332b9f2f28f24277175bf3e4a3d02ef83a` | `docker pull`, `docker image inspect` (RepoDigests), Docker Hub tags API |
| Image `python:3.12.16-slim-trixie` | Exists, digest `sha256:8523d6abeb48ceae0b7240d30c5808fc26cb79c1a635bacdf19cf3baecfbec07`; has `bash` and `/etc/ssl/certs/ca-certificates.crt` | same, plus `docker run` |
| Image `node:22.23.4-trixie-slim` | Exists, digest `sha256:2117f713a417f3aff682ac8f5bc2ebbdf1beed51f36e67ab1e0fd3866b6d2d8f`; has `bash`, runs as node 22.23.4 | same |
| Digest pinning (`image: name:tag@sha256:...`) works under DDEV | Yes, `ddev restart` starts all three | `ddev restart` |
| `env_file` long syntax with `required: false`, absolute `${DDEV_APPROOT}` | Works; no `.env` present, services start with `.env.example` values | `ddev restart` without `.env` |
| `DDEV_SITENAME`, `DDEV_APPROOT` in host commands; `DDEV_UID`, `DDEV_GID` in compose `user:` | Present; containers run as uid 1000 | probe host command, `ddev engine id -u` |
| Custom services join `default` and `ddev_default` automatically | Yes, no `networks:` needed | `docker inspect`, `.ddev-docker-compose-full.yaml` |
| Labels `com.ddev.site-name` and `com.ddev.approot` | `ddev stop` and `ddev start` manage the containers | `ddev stop`, `docker ps --filter label=...` |
| HTTPS-only expose (`HTTPS_EXPOSE=3001:3000`, no `HTTP_EXPOSE`) | Works; the router binds 127.0.0.1:3001 and nothing on 3000 | `ss -ltn`, `curl` |
| `ddev exec --raw -d` argument fidelity | Arguments arrive intact, **but stdin is not forwarded** (`echo hi \| ddev exec -s S --raw -- cat` prints nothing) | probe |
| `ddev exec` without `--raw` | Mangles quoted arguments | probe |
| `docker exec -i -w` | Keeps arguments, stdin and cwd; used by `ddev engine` and `ddev next` | probe |
| No `## Flags` line passes `--version`, `--help`, `-h` to a host command unparsed | Yes | probe host command |
| Exit codes of host commands | DDEV v1.24.4 maps every non-zero exit to 1 and writes `Failed to run ...; error=exit status N` to stderr; stdout is unchanged, so the last line of stdout is still the script's own | probe host command, `ddev exec` |
| `ddev start` waits for custom health checks | Yes: "Waiting 120s for additional project containers [...] to become ready" | `ddev restart` output |
| `ddev delete` removes the labelled volume | Yes: `<site>-postgres-data` is gone after `ddev delete -Oy` (throwaway project `t06probe`) | `docker volume ls` before and after |
| Mount only the `mkcert` folder (compose `volume.subpath`) to hide the CA key | `subpath: mkcert` works with Compose 2.34 and Docker 28, but `rootCA-key.pem` sits in the same folder as `rootCA.pem`, so the key stays visible. A volume cannot select one file. Kept the read-only mount of the whole volume | tried and reverted, 2026-11-02 |
| Containers resolve `meridian.ddev.site` to `ddev-router` with `external_links`; mkcert root trusted | Yes for Python (`SSL_CERT_FILE` bundle) and Node (`NODE_EXTRA_CA_CERTS`); without the variables verification fails | `ddev engine`, `ddev next` |

## Pantheon: Terminus 4.x, provider and deploy command (T07)

- **Terminus is pinned to 4.3.3 in the web container.** The DDEV v1.24.4 web image ships Terminus
  3.6.2. With a Pantheon personal access token (PAT) it failed on 2026-11-02 with `HTTP request
  POST https://<host>/api/authorize/machine-token has failed with error Undefined` and `Maximum
  retry attempts reached`, while the Pantheon API was reachable. `web-build/Dockerfile` downloads
  the 4.3.3 `terminus.phar` from the GitHub release, checks its SHA-256
  (`e7ca9bcad3acbb1cfc0cec32550eeb2351e578dc6d5f79cd3a5303201893bade`), and installs it over
  `/usr/local/bin/terminus`, so `terminus` on PATH, `ddev pull pantheon` and `ddev deploy-drupal`
  all use it. Record: version 4.3.3 (released 2026-08-20), source
  `github.com/pantheon-systems/terminus/releases/tag/4.3.3`, checked 2026-11-02. Upgrade by
  changing both `ARG` values in a task with a plan entry, then `ddev debug rebuild -s web`.
  Check: `ddev exec terminus --version`. The workflow `deploy-drupal.yml` pins the same version.
- `.hadolint.yaml` (repo root) ignores DL3061 because `web-build/Dockerfile` is appended to the
  DDEV web image and so has no `FROM`.
- `config.yaml` sets `web_environment: PANTHEON_SITE=meridian-trade` (not a secret). The PAT
  (`TERMINUS_MACHINE_TOKEN`) goes only in the global DDEV config, never in this folder.
- `providers/pantheon.yaml` has no push commands on purpose. `ddev pull pantheon` replaces the
  local database and files; run `ddev snapshot` first.
- Setup, deploy, rollback and troubleshooting: `docs/runbooks/deploy.md`.
