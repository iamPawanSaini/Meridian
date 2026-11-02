# T06: Extra Docker services in DDEV, Plan

| Field | Value |
|---|---|
| Task | T06 |
| Author | technical-architect |
| Date | 2026-11-02 |
| Branch | `task/T06-ddev-services` (cut from `task/T04a-def004-baseline` at 016287b, which holds T05 and the DEF-004 fix) |
| Status | Approved (main session, on the owner instruction "Start with T06", 2026-11-02; AC6b acceptance still owed by the owner at close) |
| Covers | R-11 (FR-26, services part) |
| Depends on | T05 (In test; only the owner-run TC-T05-39 and TC-T05-40 are open) |
| Decisions | `docs/tasks/T06/decision-nextjs-placeholder.md` (solution-architect, 2026-11-02): option (a), placeholder runtime with conditions |

## Goal

Add the three non-Drupal services of the local stack to the DDEV project `meridian`:
`meridian-postgres` (Postgres 16, the engine's system of record), `meridian-engine` (the
Python 3.12 runtime for `meridian_engine`) and `meridian-web` (the Node 22 runtime for the
Next.js dashboard). After `ddev start` on a clean clone, all five containers (web, db and the
three new ones) run and are healthy. The engine reaches Postgres and Drupal, and `meridian-web`
reaches Drupal and is served at `https://meridian.ddev.site:3001`. The custom commands
`ddev engine`, `ddev next`, `ddev pg` and `ddev meridian-status` are the documented interface,
and a tested dump and restore protects local Postgres data. T06 also settles the D7 open item
"DDEV in-container resolution of `meridian.ddev.site`".

T06 builds **runtimes and plumbing only**. The engine package arrives in T13 and T14, and the
Next.js app in T21. Until then the engine container idles on a stock Python image, and
`meridian-web` serves a tiny placeholder on port 3000 (KD-1).

Acceptance criteria from `docs/TASKS.md`, numbered for traceability:

| ID | Criterion |
|---|---|
| AC1 | `ddev start` brings up Drupal, Postgres, engine and Next.js containers |
| AC2 | Engine container reaches Postgres and Drupal over the internal network; Next.js container reaches Drupal |
| AC3 | Custom commands exist and are documented: `ddev engine ...`, `ddev pg ...`, `ddev next ...` |
| AC4 | Data survives `ddev restart`; a documented Postgres dump and restore script works (tested) |
| AC5 | Container health checks defined; a deliberately stopped service is reported by a status command |
| AC6 | Next.js dev server reachable through a DDEV hostname over HTTPS. Split by the solution-architect decision into AC6a and AC6b |
| AC6a | Route and TLS: `https://meridian.ddev.site:3001/` reaches port 3000 in `meridian-web` with a trusted certificate, verified with the placeholder server. **Must pass in T06** |
| AC6b | The Next.js dev server (`next dev`) answers on that route. T06 status: **Blocked (accepted, re-run in T21)**. The owner must accept this deferral in writing at T06 close; an agent message is not owner acceptance |

Claims at T06 close (decision file, "What T06 may claim"): AC1 **Met** (the Next.js runtime
container exists, runs and is healthy, and serves the T06 placeholder until T21). AC6
**Partially met** (AC6a Pass, AC6b Blocked, accepted, re-run in T21). If the close step ticks
boxes in `docs/TASKS.md`, the AC6 box stays unticked until T21 closes.

## Key decisions (technical-architect)

Facts probed on the owner's machine on 2026-11-02 (read-only, DDEV v1.24.4, Docker 28.1.1,
docker-compose v2.34.0, WSL2):

- The generated `.ddev/.ddev-docker-compose-full.yaml` gives the `web` service
  `external_links: [ddev-router:meridian.ddev.site]` and
  `NODE_EXTRA_CA_CERTS=/mnt/ddev-global-cache/mkcert/rootCA.pem`. Inside `web`,
  `meridian.ddev.site` resolves to the router (172.18.0.5) and `curl https://meridian.ddev.site/`
  returns 200 with a trusted certificate.
- The mkcert root is at `/mnt/ddev-global-cache/mkcert/rootCA.pem` in the external volume
  `ddev-global-cache`. The same folder also holds `rootCA-key.pem` (see Risks).
- `web` resolves `web` to the project network (`ddev-meridian_default`), not to `ddev_default`.
- The router binds 127.0.0.1 on 80, 443, 8025, 8026, 8142, 8143 and 10999. Host ports 3000 to
  3009 and 5432 are free. Other projects: `circleoftrust`, `punrasar-baba` (paused), `esure`
  (stopped).
- The pre-commit shellcheck hook lints extensionless executable DDEV commands. `pre-commit run
  shellcheck --files .ddev/commands/host/quality` reports `Passed`, not `Skipped`.
- `ddev exec --help` shows `--raw` (default true) and `-d`.

Items marked **verify** are still unconfirmed. The developer confirms each one in step 1 and
records the result, the source and the date in a "Verified facts (T06)" table in
`.ddev/README.md`. If a fact is wrong, the developer uses the documented fallback. A change to a
decision (not just a version) goes back to the technical-architect first.

### KD-1 Scope boundary: runtimes now, application code later

| Service | T06 delivers | Replaced or extended by |
|---|---|---|
| `meridian-postgres` | Final service: image, volume, health check, credentials | T14 adds the schema (Alembic); T28 mirrors the major version on Neon |
| `meridian-engine` | Stock `python:3.12.x-slim-trixie` image (pinned), idle (`sleep infinity`), repo bind mount, CA bundle entrypoint | T13 adds `services/engine/Dockerfile`, `pyproject.toml` and the lockfile, and switches the compose service from `image:` to `build:`. T13 owns the Dockerfile design (non-root user, dependency install) |
| `meridian-web` | Stock `node:22.x-trixie-slim` image (pinned), start script that runs `npm run dev` when `apps/web/package.json` exists, else a placeholder HTTP server | T21 adds the Next.js app, `package.json` and the lockfile. The start script then runs the real dev server with no compose change |

Rules that follow:

- **No `services/engine/pyproject.toml` and no `apps/web/package.json` in T06.** These files are
  the manifests that turn on the `component-engine` and `component-web` steps of
  `scripts/quality.sh`. Without the real toolchains those steps would FAIL. They stay SKIP.
- **No Dockerfile in T06.** A stock pinned image plus a mounted entrypoint is enough for an idle
  runtime. A T06 Dockerfile would make T06 decide build and dependency details that T13 owns.
- The placeholders live under `.ddev/` (DDEV plumbing), not under `services/engine` or
  `apps/web`, so T13 and T21 start from untouched folders.
- The placeholder server answers every path with HTTP 200, `text/plain`, a fixed sentence
  ("meridian-web placeholder; the dashboard arrives in T21") and no data, no styling and no
  third-party asset. It must stay under about 40 lines.
- AC6 says "Next.js dev server". With the placeholder, T06 proves the hostname, the router, TLS
  and port 3000 inside the container (AC6a). The real Next.js dev server on the same route
  (AC6b) is proven when T21 re-runs the T06 case. The solution-architect accepted this
  (`decision-nextjs-placeholder.md`, option (a)).
- **No overclaim.** `.ddev/README.md`, `apps/web/README.md` and the runbook each say:
  "`https://meridian.ddev.site:3001` serves a placeholder until T21". The placeholder text names
  T21.

### KD-2 Compose files, names and common service settings

Three files, as `.ddev/README.md` already lists:

| File | Service | `container_name` |
|---|---|---|
| `.ddev/docker-compose.postgres.yaml` | `meridian-postgres` | `ddev-${DDEV_SITENAME}-meridian-postgres` |
| `.ddev/docker-compose.engine.yaml` | `meridian-engine` | `ddev-${DDEV_SITENAME}-meridian-engine` |
| `.ddev/docker-compose.next.yaml` | `meridian-web` | `ddev-${DDEV_SITENAME}-meridian-web` |

Common to every service:

- Labels `com.ddev.site-name: ${DDEV_SITENAME}` and `com.ddev.approot: ${DDEV_APPROOT}`, so
  `ddev stop`, `ddev restart` and `ddev delete` manage the containers (**verify**).
- Images are pinned by exact tag **and** digest (`image: name:tag@sha256:...`), using the
  multi-arch index digest. No `latest`, no floating major tag. T06 confirms that digest pinning
  works under DDEV and updates the "Docker and YAML" rule in `docs/standards/CODING_STANDARDS.md`
  from "with a digest where T06 confirms it" to the confirmed rule.
- No `restart:` policy. A container that dies stays down, so the status command sees it (AC5).
- No host `ports:`. Nothing new binds a host port except the router's HTTPS port 3001 (KD-5).
- Networks: DDEV attaches custom services to `default` and `ddev_default` (**verify** in the
  generated full compose file). If it does not, declare both networks explicitly.
- Service hostnames inside the stack are the section 0 service names: `meridian-postgres`,
  `meridian-engine`, `meridian-web`.
- Each file starts with a short comment that names T06, the service and what later tasks
  change. YAML passes yamllint (`.yamllint.yaml`, line length 100) and `check-yaml`.

### KD-3 Environment: one root `.env`, `.env.example` as defaults

- Each service reads `env_file:` in this order: `${DDEV_APPROOT}/.env.example` (required), then
  `${DDEV_APPROOT}/.env` (`required: false`). A later file overrides an earlier one, so the
  developer's `.env` wins, and a clean clone with no `.env` still starts with the placeholder
  values. This keeps T05 AC1 ("`ddev start` on a clean clone without manual steps") true.
  **Verify**: the long `env_file` syntax with `required: false` works with DDEV's bundled
  docker-compose (v2.34.0 supports it), and the absolute `${DDEV_APPROOT}` path resolves.
  Fallback if `required: false` fails: a DDEV `pre-start` `exec-host` hook that copies
  `.env.example` to `.env` when `.env` is missing (never overwrites).
- Not used: `.ddev/.env` and `.ddev/.env.*`. DDEV uses them for compose interpolation and
  `ddev dotenv`. A second env location would split the single source that `.env.example` and D7
  describe.
- Trade-off, accepted for local DDEV only: every new container sees every variable in `.env`.
  The values are the developer's own local values, and deployed environments use per-component
  secret stores (D7). Record this in the runbook.
- No value is written in a compose file. Compose-level `environment:` holds only non-secret
  wiring (paths, `HOME`, CA variables, router variables).
- **No new project variable.** `MERIDIAN_DATABASE_URL`, `MERIDIAN_POSTGRES_PASSWORD`,
  `MERIDIAN_DRUPAL_BASE_URL`, `DRUPAL_BASE_URL` and `MERIDIAN_WEB_BASE_URL` already exist.
  `.env.example` changes only in comments (KD-6, KD-9).

### KD-4 `meridian-postgres`

- Image `postgres:16.x-trixie` with the latest 16 patch at implementation time (**verify** the
  tag and digest). Major 16 matches ADR-0003, D2 and `docs/specs/data-model.md`. Neon offers 16
  when a project is created; T28 creates the Neon project on 16 (**verify** in T28). No
  solution-architect decision is needed.
- Database `meridian`, user `meridian` (`POSTGRES_DB`, `POSTGRES_USER` as plain compose
  values). The password comes from `MERIDIAN_POSTGRES_PASSWORD`: override the entrypoint with
  a one-line `sh -c` that exports `POSTGRES_PASSWORD="$MERIDIAN_POSTGRES_PASSWORD"` and then
  `exec`s the image's `docker-entrypoint.sh postgres`. If the variable is empty, the container
  fails with the image's own message. The password applies only at first init. The runbook
  says how to change it later (`ALTER ROLE` through `ddev pg psql`, then edit both values in
  `.env`).
- `POSTGRES_INITDB_ARGS=--encoding=UTF8 --locale=C.UTF-8`, so sort order is deterministic.
  T28 compares this with Neon.
- Data: named volume `meridian-postgres-data` (declared as `${DDEV_SITENAME}-postgres-data`
  with the two DDEV labels) mounted at `/var/lib/postgresql/data`. It survives `ddev stop`,
  `ddev restart` and `ddev poweroff`. `ddev delete` removes it, together with the Drupal
  database (**verify**). DDEV's MariaDB snapshot on delete does not cover Postgres, so the
  runbook says: run `ddev pg dump` before `ddev delete`.
- Health check: `pg_isready -U meridian -d meridian -h 127.0.0.1`, interval 5 s, timeout 3 s,
  retries 12, start period 30 s.
- No host port. Access is `ddev pg psql`. A developer who needs a host GUI client can add a
  git-ignored `.ddev/docker-compose.postgres.local.yaml` (not documented as supported; not in
  scope).

### KD-5 `meridian-web` (Next.js runtime) and the HTTPS host

- Image `node:22.x-trixie-slim` with the latest Node 22 LTS patch (**verify** the tag and
  digest). The host and pre-commit use 22.14.0. Only the major must match. T21 may move the
  patch, and the standards note "T21 decides the web app's Node version" stays.
- Public URL: **`https://meridian.ddev.site:3001`**, as `.env.example` already says. Router
  variables on the service: `VIRTUAL_HOST=meridian.ddev.site`, `HTTPS_EXPOSE=3001:3000`. No
  `HTTP_EXPOSE`, so the router does not bind host port 3000, which is often in use for other
  local dev servers (**verify** that DDEV accepts HTTPS-only exposure. Fallback:
  `HTTP_EXPOSE=3002:3000`, documented). A sub-hostname such as `web.meridian.ddev.site` was
  rejected: it needs extra DDEV config, and `.env.example` and the OAuth redirect plan already
  use port 3001.
- This settles D7: the DDEV value of `MERIDIAN_WEB_BASE_URL` is `https://meridian.ddev.site:3001`.
  The OAuth redirect URI for `meridian-web-login` on DDEV (T22) is built from it.
- Working directory `/var/www/html/apps/web`. The whole repo is bind-mounted at `/var/www/html`
  (same path as `web`), so `../../scripts/coverage_gate.py` in the `component-web` step resolves.
- Runs as the host user: `user: "${DDEV_UID}:${DDEV_GID}"` (**verify** the interpolation
  variables), `HOME=/tmp`, `npm_config_cache=/tmp/.npm`. Files written in the bind mount are
  owned by the developer, not root.
- `node_modules`: **bind mount, no named volume**. The runbook requires the clone on the WSL2
  Linux filesystem, so the bind mount is native ext4 with working inotify. A named volume would
  add an ownership fix and hide `node_modules` from the host editor. T21 installs with
  `ddev next npm ci`. `node_modules/` is already git-ignored.
- Command: `.ddev/meridian-web/start.sh` (mounted). If `apps/web/package.json` exists it runs
  `exec npm run dev -- --hostname 0.0.0.0 --port 3000`, else
  `exec node .ddev/meridian-web/placeholder-server.mjs` on 0.0.0.0:3000. T21 owns the dev branch
  of this script and may change it.
- Drupal access: `external_links: ["ddev-router:meridian.ddev.site"]` and
  `NODE_EXTRA_CA_CERTS=/mnt/ddev-global-cache/mkcert/rootCA.pem`, with `ddev-global-cache`
  mounted read-only. This is the same mechanism DDEV gives `web`. `DRUPAL_BASE_URL` keeps
  `https://meridian.ddev.site`, which is also the URL the browser is redirected to in the
  login flow (T22), so one value serves both uses.
- Health check: an HTTP GET to `http://127.0.0.1:3000/` with `node -e` and a `fetch`. It is
  healthy on any status below 500, so the T21 login redirect (307) also counts as healthy.
  Interval 10 s, timeout 5 s, retries 6, start period 120 s (the first Next.js compile is
  slow). It must not call Drupal, or a Drupal outage would mark `meridian-web` unhealthy too.
- Note for T21: the `component-web` quality step runs `python3 ../../scripts/coverage_gate.py`
  inside this container, and the slim Node image has no Python. T21 resolves this (for example
  a T21 image with `python3`, or a step change). T06 does not.

### KD-6 `meridian-engine` (Python runtime) and Drupal access

- Image `python:3.12.x-slim-trixie` with the latest 3.12 patch (**verify** the tag and digest,
  and that the image has `bash` and `/etc/ssl/certs/ca-certificates.crt`).
- Command `sleep infinity` with `init: true`. The engine is a batch job. `ddev engine ...` runs
  each command in the idle container.
- Repo bind-mounted at `/var/www/html`, working directory `/var/www/html/services/engine`.
  `user: "${DDEV_UID}:${DDEV_GID}"`, `HOME=/tmp`.
- **Drupal over HTTPS by its public name, not `http://web`.** `external_links:
  ["ddev-router:meridian.ddev.site"]`, so `meridian.ddev.site` resolves to the router inside
  the container. `MERIDIAN_DRUPAL_BASE_URL` stays `https://meridian.ddev.site`. Reasons:
  - Parity with deployed dev (HTTPS on Pantheon). The engine code has one path.
  - OAuth client libraries often refuse plain-HTTP token endpoints (for example
    `oauthlib` without an insecure-transport override). That trap would surface in T10 or T13.
  - The `web` alias on the shared `ddev_default` network is ambiguous when other DDEV projects
    run. The probe above shows `web` only on the project network, but a public name avoids the
    question.
- **CA trust for Python.** The mkcert root is per machine, so it cannot be baked into an image.
  `.ddev/meridian-engine/entrypoint.sh` (mounted, about 10 lines) concatenates
  `/etc/ssl/certs/ca-certificates.crt` and `/mnt/ddev-global-cache/mkcert/rootCA.pem` (when
  present; a warning on stderr when absent) into `/tmp/meridian-ca-bundle.pem`, then
  `exec "$@"`. Compose sets `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` to that path. They are
  static `environment:` values, so `ddev engine` exec sessions, which bypass the entrypoint, get
  them too. Public CAs keep working because the system bundle is included. T13 may move this
  into its Dockerfile entrypoint.
- Fallback, only if the router route fails in step 1: `http://web` for the engine, recorded in
  D7 with the reason. This needs a technical-architect re-check before use.
- `MERIDIAN_DATABASE_URL` keeps `postgresql://meridian:change-me-local@meridian-postgres:5432/meridian`.
- Health check: `python3 -c` that exits 0 when `/tmp/meridian-ca-bundle.pem` is readable and
  `/var/www/html/services/engine` exists. Interval 10 s, timeout 3 s, retries 3, start period
  10 s. It must not call Postgres or Drupal (no cascading unhealthy state). T13 may replace it.

### KD-7 Custom commands (AC3)

All four are **host commands** in `.ddev/commands/host/`: bash, `set -euo pipefail`,
executable, DDEV annotations `## Description`, `## Usage`, `## Example`. No `## Flags` line, so
DDEV passes arguments through unparsed (**verify** that `ddev engine --version` reaches the
container). Each command prints usage for `-h` or `--help` with exit 0, and usage on stderr
with exit 2 for no or bad arguments. Host commands are chosen over service-folder commands:
they need nothing extra mounted in the containers, and they can stream stdin and stdout for
dumps.

| Command | Interface | Runs |
|---|---|---|
| `ddev engine <cmd> [args...]` | Runs `<cmd>` in `meridian-engine` in `/var/www/html/services/engine` | `ddev exec -s meridian-engine -d /var/www/html/services/engine --raw -- "$@"` |
| `ddev next <cmd> [args...]` | Runs `<cmd>` in `meridian-web` in `/var/www/html/apps/web` | same pattern with `-s meridian-web -d /var/www/html/apps/web` |
| `ddev pg psql [args...]` | psql as `meridian` on database `meridian` (local socket) | `ddev exec -s meridian-postgres --raw -- psql -U meridian -d meridian "$@"` |
| `ddev pg dump [FILE]` | Custom-format dump to `FILE` or the default path (KD-8) | KD-8 |
| `ddev pg restore FILE --yes` | Replaces the `meridian` database with `FILE` | KD-8 |
| `ddev meridian-status` | Table of the five services, exit 0 only if all are running and healthy | KD-10 |

- **Argument fidelity is a hard requirement.** `scripts/quality.sh` calls
  `ddev engine bash -c '<quoted command>'` and `ddev next bash -c '...'` (`printf %q`). The
  commands must hand `"$@"` to the container unchanged. **Verify**: whether `--raw` with `-d`
  keeps argument boundaries. Fallback: `docker exec` with `-w`, plus `-i` and `-t` only when
  stdin and stdout are terminals.
- `ddev engine` with no arguments prints usage. T13 can make the bare command run the engine
  CLI (`ddev engine --help` is a T13 criterion). T06 passes `--help` after a command through
  (for example `ddev engine python3 --help`), and a bare `ddev engine --help` prints the T06
  usage.
- `ddev status` and `ddev describe` are DDEV built-ins and are not overridden.
- `ddev e2e` is **not** T06. `.ddev/README.md` lists it under T06 by mistake. It belongs to T27
  (`docs/TASKS.md` line 557). Fix the README row.
- `scripts/quality.sh` and `.ddev/commands/host/quality` need **no change**: the `ddev` runner
  already maps to `ddev engine` and `ddev next`, and both steps stay SKIP until T13 and T21. T06
  proves the mapping with a `QUALITY_STEPS` test hook (see Test hooks).

### KD-8 Dump and restore (AC4)

Implemented as `ddev pg dump` and `ddev pg restore` in `.ddev/commands/host/pg`. That file is
the "documented Postgres dump and restore script". It is the single implementation, with no
duplicate in `scripts/`.

- Streams use `docker exec -i ddev-${DDEV_SITENAME}-meridian-postgres ...`, not `ddev exec`, so
  binary data never passes through a TTY (**verify** that `DDEV_SITENAME` is set for host
  commands. Fallback: read the name from `ddev describe -j`).
- **Dump.** `pg_dump -Fc --no-owner --no-acl -U meridian meridian` into `FILE`. The default is
  `db-dumps/meridian-postgres-<UTC yyyymmddThhmmssZ>.dump` under the repo root. The directory is
  created if missing, with `umask 077`. The command prints the path and size. It writes to a
  temporary file in the same directory and renames it on success, so a failed dump leaves no
  partial file. `db-dumps/` and `*.dump` are already in the root `.gitignore`. Do not add a new
  ignore rule. The tester checks `git check-ignore -v`.
- **Restore.** `ddev pg restore FILE --yes`. Without `--yes` it refuses with exit 2 and says it
  replaces the database. Order:
  1. Validate first: the file exists, is readable and is a `pg_dump` custom archive
     (`pg_restore --list` on the streamed file succeeds). On failure, exit 1 **without touching
     the database**.
  2. `dropdb --force --if-exists -U meridian meridian`, then `createdb -U meridian -O meridian
     meridian`, both on the maintenance database `postgres`. `--force` ends open engine
     sessions (Postgres 13 and later).
  3. `pg_restore --no-owner --no-acl --exit-on-error -U meridian -d meridian` from stdin.
  4. Print the table count from `information_schema.tables` for schema `public`.
- Dumps are local developer data. They may hold Drupal-published content later, but never
  secrets from `.env`. The runbook says they stay out of git and chat.

### KD-9 In-container resolution: settle the D7 open item

The update of `docs/architecture/technical-design.md` is part of T06 (C5):

- D7 prose: replace "Whether DDEV containers resolve `meridian.ddev.site` internally is
  unverified (T06). If not, ... `http://web`." with the T06 result: `meridian-engine` and
  `meridian-web` resolve it to `ddev-router` through `external_links` and trust the mkcert root
  (`SSL_CERT_FILE` bundle for Python, `NODE_EXTRA_CA_CERTS` for Node). Add the date and the
  evidence path.
- D7 table: the DDEV cell of `MERIDIAN_WEB_BASE_URL` becomes `.env`,
  `https://meridian.ddev.site:3001`. The `MERIDIAN_DATABASE_URL` and the two Drupal base URL
  cells stay as they are.
- "Unverified items and open items": mark the T06 row resolved with the date. Add a revision
  history row.
- `.env.example`: comment-only edits. The `MERIDIAN_WEB_BASE_URL` comment changes "host fixed in
  T06" to "DDEV host, port 3001 on the router (T06)". The Drupal base URL comments note that the
  same HTTPS URL works inside the DDEV containers. No variable is added, removed or revalued.

### KD-10 Health checks and the status command (AC5)

- Health checks as in KD-4, KD-5 and KD-6. **Verify** whether `ddev start` in v1.24.4 waits for
  custom services to report healthy, and record the result. If it waits, a broken health check
  fails `ddev start` within `default_container_timeout` (good). If it does not wait,
  `ddev meridian-status` is the check, and the runbook tells the developer to run it after
  `ddev start`.
- `ddev meridian-status` (`.ddev/commands/host/meridian-status`) uses a fixed list: `web`, `db`,
  `meridian-postgres`, `meridian-engine` and `meridian-web` (container names
  `ddev-meridian-web`, `ddev-meridian-db` and `ddev-meridian-<service>`). For each it runs
  `docker inspect` for `.State.Status` and `.State.Health.Status`, and prints one aligned line:
  `SERVICE  STATE  HEALTH`. A container that does not exist shows `missing`. It exits 0 only if
  every service is `running` and `healthy`, else 1, and the last line names the bad services.
  The output is plain text, with no colour when stdout is not a terminal.
- Negative case for AC5: `docker stop ddev-meridian-meridian-engine` (and once for each new
  service), then `ddev meridian-status` exits 1 and shows `exited`. `ddev start` brings it back.
  The tester also records what `ddev describe` shows, for information only.

### KD-11 Lint, standards and the simulation-only rule

- Shell: `entrypoint.sh`, `start.sh` and the four host commands pass shellcheck with the root
  `.shellcheckrc`. The hook picks up extensionless executables (probed above). The
  `.sh` files under `.ddev/meridian-*` are executable.
- YAML: the three compose files pass yamllint and `check-yaml`.
- hadolint: nothing to lint in T06 (no Dockerfile, KD-1). T13 and T21 bring theirs.
- `placeholder-server.mjs` has no linter in the repo yet (ESLint covers `apps/web` from T21).
  Keep it tiny, `node:http` only, no dependency.
- No README files in `.ddev/meridian-engine/` or `.ddev/meridian-web/`: `.ddev/.gitignore`
  ignores `/*/README.*`, and TC-T05 checks that no tracked file matches an ignore rule.
  Document those folders in `.ddev/README.md` instead.
- Simulation-only rule: images come only from Docker Hub official images (`postgres`, `python`,
  `node`). No broker SDK, broker client, broker domain or order code. `scripts/check-names.sh`
  passes.
- Dependency audit (dependency policy): three official images. Licences: PostgreSQL License,
  PSF License, MIT (Node.js), with Debian base packages. All are maintained, with current
  releases. No npm or pip package is added.

## Scope

- `.ddev/docker-compose.postgres.yaml`, `.ddev/docker-compose.engine.yaml` and
  `.ddev/docker-compose.next.yaml` (KD-2 to KD-6).
- `.ddev/meridian-engine/entrypoint.sh`, `.ddev/meridian-web/start.sh` and
  `.ddev/meridian-web/placeholder-server.mjs`.
- Host commands `engine`, `next`, `pg` (psql, dump, restore) and `meridian-status`.
- Docs: `docs/runbooks/local-setup.md`, `.ddev/README.md` (file table, commands, verified facts),
  `CLAUDE.md` (commands table), `README.md` (local stack paragraph), `services/engine/README.md`
  and `apps/web/README.md` (one line each on the container and what T13 or T21 replaces),
  `docs/architecture/technical-design.md` D7 and the open-items table,
  `docs/standards/CODING_STANDARDS.md` (digest rule), `.env.example` comments.
- `.ddev/.gitignore`: add new DDEV-generated paths only if `git status --ignored .ddev` shows any
  (T05 review item 14).

## Non-goals

- Engine package, `pyproject.toml`, Dockerfile, Alembic or schema (T13, T14).
- Next.js app, `package.json`, Node dependencies or the `/api/health` route (T21).
- Wiring or changing the `component-engine` and `component-web` quality steps (T13, T21).
- `ddev e2e` (T27), CI (T08), Pantheon pull (T07), Neon (T28).
- A host port for Postgres, a Postgres GUI, or pgAdmin.
- Authenticated database checks from the engine (T14 brings the driver and migrations).
- Any change to `.ddev/config.yaml` beyond what step 1 proves necessary. Expected: none.

## Steps

Commit after each numbered step that changes files, with a subject that starts with `T06:`.

1. **Verify the open facts** (no commit unless docs change). Confirm and record in the
   ".ddev/README.md verified facts" table: image tags and digests (KD-4 to KD-6); `env_file`
   long syntax with `required: false` and `${DDEV_APPROOT}`; `DDEV_UID`, `DDEV_GID` and
   `DDEV_SITENAME` interpolation and their presence in host commands; automatic network
   attachment; HTTPS-only `HTTPS_EXPOSE`; `ddev exec --raw -d` argument fidelity; `## Flags`
   passthrough; whether `ddev start` waits on custom health checks; `ddev delete` removes the
   labelled volume. Use a scratch compose file outside the repo, or revert before committing.
2. **Postgres.** Add `docker-compose.postgres.yaml` and the volume. `ddev restart`, then check
   `pg_isready` health and the `meridian` login through the socket.
3. **Commands `pg psql` and `meridian-status`.** Add `pg` with `psql` only, and
   `meridian-status`. Check the negative stop case on Postgres.
4. **Engine.** Add `docker-compose.engine.yaml` and `.ddev/meridian-engine/entrypoint.sh`, then
   `ddev engine`. Check that the engine reaches `meridian-postgres:5432` (TCP) and
   `https://meridian.ddev.site/` (HTTPS, verified, status 200 or 403), with quoting fidelity.
5. **meridian-web.** Add `docker-compose.next.yaml`, `start.sh`, `placeholder-server.mjs`, then
   `ddev next`. Check HTTPS from the host on `https://meridian.ddev.site:3001/` and that
   meridian-web reaches Drupal with `fetch`.
6. **Dump and restore.** Add `pg dump` and `pg restore` (KD-8). Run the round trip and the
   invalid-file refusal by hand.
7. **Docs.** Runbook (new steps, verification, dump and restore, `ddev delete` warning, ports,
   troubleshooting), `.ddev/README.md`, `CLAUDE.md`, `README.md`, component READMEs, D7 and the
   open item, standards digest rule, `.env.example` comments. The runbook, `README.md`,
   `.ddev/README.md` and `apps/web/README.md` state that port 3001 serves a placeholder until
   T21 (KD-1, decision condition 3).
8. **Quality gate.** `ddev quality` exits 0 (engine and web steps SKIP), `scripts/check-names.sh`
   passes, `git status --porcelain` and `git status --ignored .ddev` are as expected, and
   `docs/tests/T05/run-checks.sh --regression` passes after the tester re-tags its T06 guards
   (Test hooks).

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| `.ddev/docker-compose.{postgres,engine,next}.yaml` | New services `meridian-postgres`, `meridian-engine`, `meridian-web` | `ddev start`, T13, T14, T21, T27 |
| Service hostnames `meridian-postgres:5432`, `meridian-web:3000` | New, internal | Engine (`MERIDIAN_DATABASE_URL`, `MERIDIAN_WEB_REVALIDATE_URL`, T14, T19) |
| `https://meridian.ddev.site:3001` | New router route to `meridian-web:3000` | Browser, `MERIDIAN_WEB_BASE_URL`, OAuth redirect URI (T22) |
| `meridian.ddev.site` inside the new containers | Resolves to `ddev-router`, mkcert trusted | Engine (T10, T13, T19), meridian-web (T21, T22) |
| Volume `meridian-postgres-data` | New, labelled for DDEV | Local Postgres data |
| `ddev engine`, `ddev next` | New host commands, argument passthrough | `scripts/quality.sh` (`QUALITY_RUNNER=ddev`), developers, T13, T21, T27 |
| `ddev pg psql/dump/restore` | New host command | Developers, T14, T27 |
| `ddev meridian-status` | New host command, exit 0 or 1 | Developers, tester, T27 |
| `db-dumps/` | Default dump location (already git-ignored) | Developers |
| `.env.example` | Comments only | Developers |
| D7 in `technical-design.md` | DDEV value of `MERIDIAN_WEB_BASE_URL`; open item resolved | T10, T13, T19, T21, T22 |
| Docker images | `postgres:16.x-trixie`, `python:3.12.x-slim-trixie`, `node:22.x-trixie-slim`, each pinned with a digest | Dependency policy, T08, T32 |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| mkcert root missing or untrusted inside containers (no `mkcert -install`, or a different CAROOT) | Medium | HTTPS to Drupal fails in the engine and meridian-web | Same CA path as DDEV's own `web` container (probed). The entrypoint warns when the root is absent. The runbook troubleshooting covers `mkcert -install` and `ddev restart`. The fallback (KD-6) needs a re-check |
| `ddev-global-cache` also holds `rootCA-key.pem`, now visible to two more containers | Low | Local CA key exposure inside local containers | Read-only mount. Local dev only, and the same exposure `web` already has. Note it in the runbook. If compose `volume.subpath` works, mount only `mkcert` |
| Port 3001 in use on the host, or used by another project's router config | Low | Router fails to bind, `ddev start` fails | Probed free today. Router routing is per hostname, so other DDEV projects on 3001 do not clash. Runbook: `ss -ltn` check and `ddev poweroff`. Changing the port also changes `MERIDIAN_WEB_BASE_URL` (documented) |
| WSL2 file watching for `next dev` | Low (clone on Linux FS) | HMR misses changes | Runbook already forbids `/mnt/c`. T21 may set `WATCHPACK_POLLING=true` if needed |
| Image pull size and time (about 150 MB Postgres, 50 MB Python slim, 70 MB Node slim, compressed) | Medium | Slower first `ddev start`, NFR-17 budget (30 min) | Slim images. Record `time ddev start` before and after on a warm cache, and the first pull time. If pulls are blocked in the sandbox, the owner runs the live cases |
| Longer `ddev start` (three more containers and health checks) | Medium | Developer friction | Short start periods. Record the timing. Target: a warm restart adds at most 20 s |
| `ddev exec` changes argument quoting | Medium | `quality.sh` engine and web steps break in T13 and T21 | Fidelity test (Test hooks). `docker exec` fallback |
| `env_file` `required: false` unsupported, or the path resolves wrongly | Low | Clean clone fails `ddev start` (T05 AC1 regression) | Verified in step 1. Pre-start hook fallback (KD-3). The clean-clone test runs with no `.env` |
| Password drift: `.env` changes `MERIDIAN_POSTGRES_PASSWORD` after first init | Medium | Engine auth fails in T14 | Runbook: change it with `ALTER ROLE` and keep `MERIDIAN_DATABASE_URL` in step. The `.env.example` comment already pairs them |
| `ddev delete` silently drops Postgres data | Medium | Local data loss | Runbook warning, `ddev pg dump` first. The behaviour is verified and recorded |
| The T05 regression guards (TC-T05-15, TC-T05-23) are tagged invariant but assert "no T06 yet" | Certain | `run-checks.sh --regression` fails on this branch | Tester re-tags those checks as snapshot (`cka`) in `/design-tests` (Test hooks). This is not a T06 defect |
| Placeholder taken for the real dashboard | Low | Confusion | Fixed text naming T21. `.ddev/README.md` and `apps/web/README.md` say so |

## Test hooks needed

The tester designs `docs/tests/T06/test-cases.md` and a `docs/tests/T06/run-checks.sh` in the
T05 style: static mode (no DDEV), `--live`, `--clean-clone` with a confirm variable, and evidence
files. Hints:

- **Static (no DDEV).** The three compose files exist and use the section 0 service names,
  `container_name`, both DDEV labels, `image:` with a tag **and** `@sha256:` digest (no `latest`,
  no major-only tag), `env_file` order (`.env.example` then `.env` with `required: false`),
  health checks on all three, no host `ports:`, no `restart:`, `HTTPS_EXPOSE=3001:3000`,
  `external_links` to `ddev-router:meridian.ddev.site`. The commands exist, are executable, have
  `## Description`, have no `## Flags`, and use `set -euo pipefail`. shellcheck, yamllint and
  check-names pass. No `services/engine/pyproject.toml`, no `apps/web/package.json`, no
  Dockerfile. `.env.example` has the same variable names and values as before T06 (comments may
  differ). No broker string.
- **AC1.** `ddev start` exits 0, then `ddev meridian-status` exits 0 with five `running healthy`
  lines. Record `time ddev start`, warm and cold.
- **AC2.**
  - `ddev engine python3 -c "import socket; socket.create_connection(('meridian-postgres', 5432), 3)"`
    exits 0.
  - `ddev engine python3 -c "import urllib.request as u; print(u.urlopen('https://meridian.ddev.site/user/login').status)"`
    prints 200 with TLS verification on.
  - `ddev engine getent hosts meridian.ddev.site` shows the router address.
  - This command exits 0:

    ```bash
    ddev next node -e "fetch(process.env.DRUPAL_BASE_URL + '/user/login')
      .then(r => { console.log(r.status); process.exit(r.ok ? 0 : 1) })"
    ```

  - Negative: in a container without the CA variables, the same Python call fails certificate
    verification. This proves the trust comes from the bundle, not from verification being off.
- **AC3, argument fidelity.**
  - `ddev engine bash -c 'printf "<%s>\n" "$@"' _ 'a b' '' 'c"d'` prints exactly `<a b>`, `<>`
    and `<c"d>`. The same for `ddev next`.
  - `ddev engine pwd` prints `/var/www/html/services/engine`, and `ddev next pwd` prints
    `/var/www/html/apps/web`.
  - Bare commands give exit 2 with usage, and `-h` gives exit 0.
  - `ddev pg psql -c 'select 1'` exits 0.
  - The runbook and `.ddev/README.md` document each command.
- **AC3, quality mapping.** A `QUALITY_STEPS` file with the line
  `probe<TAB>-<TAB>ddev engine bash -c 'test -f ../../scripts/coverage_gate.py && python3 --version'`,
  run with `QUALITY_RUNNER=ddev scripts/quality.sh`, shows `PASS probe`. The same for
  `ddev next bash -c 'test -f ../../scripts/coverage_gate.py && node --version'`. Default
  `ddev quality` exits 0 with the engine and web steps SKIP.
- **AC4, persistence.** Create a table and insert rows with `ddev pg psql`. Run `ddev restart`
  and check the rows are still there. Repeat with `ddev stop` and `ddev start`, and with
  `ddev poweroff` and `ddev start`. Check that `docker volume inspect meridian-postgres-data`
  shows both DDEV labels.
- **AC4, dump and restore round trip.**
  1. Seed a known table and take a checksum
     (`select md5(string_agg(t::text, ',' order by id)) from t`).
  2. `ddev pg dump`, which prints a path under `db-dumps/`. `git check-ignore -v` names the root
     `.gitignore`, and `git status --porcelain` stays empty.
  3. Change data (drop the table, add another).
  4. Run `ddev pg restore <path> --yes` and compare the checksum. The extra table is gone.
  5. Negatives:
     - restore without `--yes` gives exit 2 and the data is unchanged;
     - restore of a garbage file gives exit 1 and the data is unchanged (checksum before and
       after);
     - restore with an engine session open succeeds (`--force`).
  6. A dump to an explicit `FILE` path works.
- **AC5.** For each new service: `docker stop ddev-meridian-<service>`, then
  `ddev meridian-status` exits 1, shows `exited` for that service and names it on the last line.
  Then `ddev start`, and the status exits 0 again. Record the `ddev describe` output for
  information. One unhealthy case: make the engine health check fail by deleting the bundle
  file inside the container. The status then shows `unhealthy` within the retry window.
- **AC6a, route and TLS (T06 Pass required).**
  - `curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}' https://meridian.ddev.site:3001/`
    from WSL2 prints `200 0` without `-k`.
  - The body is the fixed placeholder sentence, which names T21.
  - `curl http://meridian.ddev.site:3000/` does not reach meridian-web through the router (no
    HTTP exposure), unless the fallback was used.
  - Owner-run, part of this case: open the URL in the Windows browser (the same trust
    prerequisite as TC-T05-40).
- **AC6b, Next.js dev server over HTTPS (T06 status `Blocked (accepted, re-run in T21)`).** The
  same request as AC6a reaches `next dev`. The case text names T21 as the task that runs it. It
  is a separate test case with its own ID, so T21 can cite it.
- **Start-script switch (decision condition 2), `--clean-clone` scratch copy only.**
  1. In the scratch clone, write a temporary `apps/web/package.json` whose `dev` script is a
     dependency-free `node` one-liner. It listens on the `--port` and `--hostname` arguments it
     receives and returns a known body that differs from the placeholder.
  2. Restart `meridian-web`.
  3. The AC6a `curl` returns that server's body, with `200 0`.

  This tests the `start.sh` branch and its argument passing in T06. The file never reaches the
  repo. A static check asserts that no `apps/web/package.json` is tracked. The scratch copy is
  removed afterwards.
- **C7, clean clone.** Fresh clone into a scratch dir with **no `.env`**, then `ddev start`,
  `ddev meridian-status` exit 0, and the AC2 checks. Reuse the T05 `--clean-clone` pattern:
  `ddev stop --unlist meridian` first, restore the working tree at the end, confirm variable
  required. Also run `ddev delete -Oy` on the scratch project and record whether
  `meridian-postgres-data` is removed.
- **Note for the tester: T05 regression fix (tester-owned, in `/design-tests`).** Some T05
  `ckp` (invariant) checks assert that T06 has not happened yet. They must become `cka`
  (snapshot) checks, because they describe the state at T05 close, not an invariant. In
  `docs/tests/T05/run-checks.sh`, re-tag these from `ckp` to `cka`:
  - TC-T05-23: "no docker-compose or extra DDEV services added (T06)", "no ddev
    engine/pg/next/e2e commands (T06)" and "only the planned DDEV commands under
    .ddev/commands".
  - TC-T05-15: ".env.example unchanged by T05 commits". Its range runs to HEAD, so T06 comment
    edits trip it.

  Then `--regression` passes on the T06 branch. Record the change in the T05 test report as a
  maintenance note.
- **Seams the tester needs:** `QUALITY_STEPS` (exists); container names fixed by
  `container_name`; `ddev pg dump FILE` for a known path; `meridian-status` exit codes.

## Close-time wording (from the decision file)

Use the real test case IDs in place of `nn`.

- **`docs/TRACEABILITY.md`, FR-26 row.**
  - Verifying task cell: `T05, T06, T21 (T06 AC6b re-run only), T27`.
  - Case cell: replace `TC-T06-*` with the real IDs and add the note
    `TC-T06-nn AC6b Blocked (accepted, re-run in T21)`.
  - Status stays `Partially verified`. FR-26 is not `Verified` until T21 passes AC6b and T27
    passes.
- **`docs/TRACEABILITY.md`, R-11 row.**
  - Verifying task cell: add `T21`.
  - Evidence cell: add the text below.

    ```text
    T06: TC-T06-nn to nn Pass; AC6 route only (placeholder); Next.js dev server re-run owed by T21 (TC-T06-nn)
    ```

  - Status stays `Open`.
- **`docs/PROGRESS.md`.** The T06 status is `Done`, but only after the owner has accepted AC6b
  in writing. T06 notes:

  ```text
  AC6 partial: HTTPS route verified with placeholder; Next.js dev server re-run (TC-T06-nn) owed by T21, owner-accepted
  ```

  T21 notes (its status is unchanged): `Owes T06 AC6b re-run (TC-T06-nn) before close`.

## Follow-up obligations for T21

T21 (or whichever task brings `apps/web/package.json`, if T21 is replanned or split) cannot
close until it has done all of these:

1. **Plan.** List "re-run T06 AC6b (TC-T06-nn)" as a numbered acceptance item. Also list the two
   items KD-5 leaves to T21:
   - `python3` for `coverage_gate.py` in the `component-web` step;
   - whether the 120 s health-check start period covers the first compile.
2. **Test.** A T21 case runs the AC6b procedure unchanged against `npm run dev`:
   - a `curl` with no `-k` to `https://meridian.ddev.site:3001/` returns a status below 500 with
     `ssl_verify_result` 0;
   - the response comes from the Next.js dev server (a known page body, or the redirect from
     the T21 middleware);
   - `ddev meridian-status` shows `meridian-web` `running healthy`.

   The evidence goes under `docs/tests/T21/evidence/`.
3. **Back-annotate T06.** Add a dated addendum to `docs/tests/T06/test-report.md`: AC6b Pass in
   T21, with a link to the T21 evidence. Do not rewrite the T06 results.
4. **Close wording.**
   - In `docs/TRACEABILITY.md`, change the FR-26 note to
     `TC-T06-nn AC6b Pass (re-run in T21, TC-T21-nn)`, and update the R-11 evidence to match.
   - Remove the T21 notes from the `docs/PROGRESS.md` T06 and T21 rows.
   - FR-26 moves to `Verified` only when T27 has passed too.
5. **Start script.** If T21 changes the dev branch of `.ddev/meridian-web/start.sh`, it re-runs
   the AC6a case and the T06 `ddev next` argument-fidelity case.

## Decisions needed from solution-architect

- None open. The placeholder question is answered in
  `docs/tasks/T06/decision-nextjs-placeholder.md` (option (a), with conditions). The conditions
  are folded into this plan.
- Owner (not solution-architect): accept AC6b as a deferred case in writing at T06 close
  (decision condition 4).
- The Postgres major version needs no decision. ADR-0003, D2 and the data model fix Postgres 16,
  and Neon offers 16 at project creation (T28 confirms).

## Definition of done

- [ ] AC1 to AC5 and AC6a met, and the start-script switch case passes
- [ ] AC6b recorded as `Blocked (accepted, re-run in T21)`, with the owner's written acceptance
  linked in the test report
- [ ] Close-time wording applied to `TRACEABILITY.md` and `PROGRESS.md`, and the T21 note added
- [ ] C1: Plan exists and was reviewed before coding started
- [ ] C2: Code reviewed; findings resolved
- [ ] C3: Every criterion maps to an executed test case with evidence (TC-T06-nn)
- [ ] C4: `ddev quality` exits 0; shellcheck, yamllint, check-yaml and check-names clean; no
  new warnings
- [ ] C5: Docs updated: runbook, `.ddev/README.md` (with the verified-facts table),
  `CLAUDE.md`, `README.md`, component READMEs, D7 and the open item, standards digest rule.
  `TRACEABILITY.md` FR-26 and R-11 rows updated at close
- [ ] C6: No secrets; no value in compose files; `.env.example` names and values unchanged
  (comments only); dumps git-ignored
- [ ] C7: A clean clone with no `.env` reaches `ddev meridian-status` exit 0 using only the
  runbook commands
- [ ] `docs/tests/T05/run-checks.sh --regression` passes after the tester re-tag
- [ ] `git status --porcelain` is empty after `ddev start`, `ddev restart` and a dump

## Addendum 2026-11-02 (technical-architect, from the T06 review)

Exit codes through `ddev`. DDEV v1.24.4 turns every non-zero exit of a host command into exit
status 1. It also writes `Failed to run <cmd> ...; error=exit status N` to **stderr**. This
amends KD-7 and KD-10:

- Through `ddev <cmd>`: success is 0, and every failure is 1. The original status N shows only
  in that stderr line. The stdout of the command is unchanged, so the last line of
  `ddev meridian-status` stdout still names the bad services.
- Run directly (`DDEV_SITENAME=meridian .ddev/commands/host/<cmd> ...`): the script's own codes
  apply. Usage errors are 2, a failed restore check is 1, and the status of the container
  command passes through.
- Tests assert the script codes (2, N) by direct invocation. Through `ddev`, they assert exit 1
  and the `exit status N` text on stderr. The "last line" checks read stdout only.
- No acceptance criterion needs a specific code. AC3 needs the commands to exist and be
  documented. AC5 needs the stopped service to be reported, which means a non-zero exit and an
  `exited` line on stdout.
- T13 and T27 must not depend on engine exit codes seen through `ddev engine`. CI and
  `daily-run.yml` call the engine directly.

Restore validation (review finding 1). `pg_restore --list` reads only the archive's table of
contents. A dump streamed through a pipe has no data offsets, so a truncated data section
passes `--list`. KD-8 step 1 now reads the whole archive (`pg_restore -f /dev/null`) before the
drop.
