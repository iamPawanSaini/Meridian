# T06: Extra Docker services in DDEV, Test cases

| Field | Value |
|---|---|
| Task | T06 |
| Author | tester (design mode, before any implementation exists) |
| Date | 2026-11-02 |
| Criteria source | `docs/TASKS.md` T06 (AC1 to AC6) and section 3.3 (C1 to C7) |
| Plan | `docs/tasks/T06/plan.md` (Approved; KD-1 to KD-11, "Test hooks needed") |
| Decision | `docs/tasks/T06/decision-nextjs-placeholder.md` (AC6a, AC6b, start-script switch) |
| Branch / base | `task/T06-ddev-services`, designed at 6e9e69d |

AC numbering (from the plan): AC1 `ddev start` brings up Drupal, Postgres, engine and Next.js
containers; AC2 engine reaches Postgres and Drupal, Next.js reaches Drupal; AC3 custom commands
exist and are documented; AC4 data survives `ddev restart`, tested dump and restore; AC5 health
checks defined, a stopped service is reported by a status command; AC6 Next.js reachable through a
DDEV hostname over HTTPS, split into AC6a (route and TLS, must Pass in T06) and AC6b (Next.js dev
server, Blocked, accepted, re-run in T21).

## How to run

| Mode | Command | Cases |
|---|---|---|
| Static (agent, no DDEV, no network) | `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh` | 01 to 19, plus the BLOCKED lines for 42, 48, 49 |
| Regression (CI PR set, decision D-5) | `docs/tests/T06/run-checks.sh --regression` | invariant static checks only; snapshot (`cka`) checks excluded and counted |
| Live | `docs/tests/T06/run-checks.sh --live` (static, then live) or `--live-only` | 20 to 41, 43 and 50 to 53; needs DDEV, Docker, network. It stops services, runs `ddev restart` and `ddev poweroff`, and creates and drops `t06_*` tables in the local Postgres |
| Clean clone | `T06_CONFIRM=1 docs/tests/T06/run-checks.sh --clean-clone` | 44 to 47 and 54 in a fresh clone with no `.env` |
| Per-case evidence | prefix any mode with `T06_EVIDENCE=1` | writes `evidence/TC-T06-nn.<UTC run id>.txt`; every run uses new filenames, so a rerun never overwrites earlier evidence (T05 lesson) |

Interface: one line per check (`PASS`, `FAIL`, `BLOCKED`, `SKIP`), a per-case roll-up, then
`SUMMARY` and `RESULT`. Exit status 1 if any check FAILs, otherwise 0. `BLOCKED` is not a pass and
does not change the exit status, so the report must list each one. `SKIP` is only for optional host
tools (shellcheck, pre-commit, gitleaks). A missing file makes every dependent check FAIL, and every
live case FAILs (not skips) when the compose files or commands are absent, so nothing passes
vacuously. Live cases are BLOCKED only when DDEV or Docker is not available. Tags: `ckp` invariant,
`cka` snapshot (`[at-close]`, skipped by `--regression`). Snapshot checks compare with `T06_BASE`
(default 6e9e69d).

Order matters in live mode: 20 first, 43 last. Cases 36 to 39 stop or break one service and
restore it before the next case. Run the live set on a project that holds no Postgres data you need:
the test tables are dropped, but `ddev poweroff` and `ddev restart` interrupt the stack.

Clean-clone procedure (44 to 47): commit all work; `ddev stop --unlist meridian`; clone the branch
into a scratch directory on the WSL2 Linux filesystem; no `.env`; `ddev start`; checks; delete the
scratch project and restore this tree with `ddev start`. The script does this when
`T06_CONFIRM=1`. AC6b procedure for T21 is in TC-T06-42 and is printed by the script.

Environment notes: the agent sandbox has Python with PyYAML, `.tools/pre-commit` (which runs
shellcheck and yamllint as hooks), DDEV and Docker. The first `ddev start` pulls three images; if
pulls are blocked the owner runs the live cases.

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: `ddev start` brings up Drupal, Postgres, engine and Next.js containers | TC-T06-01, 02, 20, 21, 44 |
| AC2: engine reaches Postgres and Drupal; Next.js reaches Drupal | TC-T06-04, 05, 06, 22, 23, 24, 41, 45 |
| AC3: custom commands exist and are documented | TC-T06-08, 14, 25, 26, 27, 28, 29, 30, 53 |
| AC4: data survives restart; dump and restore works (tested) | TC-T06-07, 09, 13, 31, 32, 33, 34, 47, 50, 51, 52 |
| AC5: health checks defined; stopped service reported by a status command | TC-T06-03, 10, 35, 36, 37, 38, 39 |
| AC6a: route and TLS on `https://meridian.ddev.site:3001` (placeholder) | TC-T06-06, 11, 40, 41, 45, 48 |
| AC6b: Next.js dev server on that route | TC-T06-42 (Blocked, accepted, re-run in T21) |
| Decision condition 2: start-script switch | TC-T06-11, 46 |
| Decision condition 3: no overclaim in docs | TC-T06-11, 14 |
| C1: plan exists and was reviewed first | Evidence outside the suite: `docs/tasks/T06/plan.md` Status, `review.md` (checked at close) |
| C2: code reviewed, findings resolved | `docs/tasks/T06/review.md` (checked at close) |
| C3: every criterion maps to an executed case with evidence | This table; the report at close |
| C4: no new lint, type or security warning; quality green | TC-T06-02, 12, 19, 29, 30 |
| C5: docs and traceability updated | TC-T06-14 (`TRACEABILITY.md` FR-26 and R-11 rows are updated by `/close-task`) |
| C6: no secrets; `.env.example` reviewed | TC-T06-04, 15, 16, 13, 43 |
| C7: works from a clean checkout with documented commands | TC-T06-44, 45, 46, 47, 49, 54 |
| Rule: simulation only (CLAUDE.md, FR-11, ADR-0006) | TC-T06-17 |
| Rule: naming (section 0) | TC-T06-18, 01 |
| Scope and non-goals (T13, T14, T21, T27 not started early) | TC-T06-12 |
| KD-7 invariant: `git status --porcelain` empty after start, restart, dump | TC-T06-33, 43, 44 |
| T05 regression guards re-tagged | TC-T06-19 (T05 `--regression` exits 0) |

## Cases

Evidence for static cases is the block headed `== TC-T06-nn` in the run output, also written to
`evidence/TC-T06-nn.<run id>.txt` with `T06_EVIDENCE=1`. Execute mode ran on 2026-11-02 (see the
report). Design-time run: `evidence/design-time-run.txt` (nothing is built, so the implementation
checks FAIL; the passing cases are the absence and regression checks).

### TC-T06-01: Compose files, service names, container names, DDEV labels

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Static |
| Preconditions | T06 implementation committed |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-01` |
| Expected result | Exactly three files `.ddev/docker-compose.{postgres,engine,next}.yaml`, each defining only `meridian-postgres`, `meridian-engine`, `meridian-web`; `container_name: ddev-${DDEV_SITENAME}-<service>`; labels `com.ddev.site-name: ${DDEV_SITENAME}` and `com.ddev.approot: ${DDEV_APPROOT}`; each file opens with a comment naming T06. A missing file FAILs |
| Actual result | 4 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-01.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-02: Images pinned by exact tag and digest

| Field | Value |
|---|---|
| Linked criterion | AC1, C4, dependency policy |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-02` |
| Expected result | `postgres:16.x-<variant>@sha256:<64 hex>`, `python:3.12.x-slim-<variant>@sha256:...`, `node:22.x.y-<variant>@sha256:...`; no `latest`, no floating major tag, no `build:`; official Docker Hub images only; `CODING_STANDARDS.md` Docker rule no longer says "where T06 confirms it" (digest rule confirmed) |
| Actual result | 3 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-02.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-03: Health checks and no restart policy

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-03` |
| Expected result | Each service has `healthcheck` with test, interval, timeout, retries, start_period. Postgres: `pg_isready -U meridian -d meridian -h 127.0.0.1`, retries 12. Engine: `python3 -c` on `/tmp/meridian-ca-bundle.pem`. Web: `fetch` of `http://127.0.0.1:3000/`, start period 120 s. Engine and web checks do not mention Postgres, Drupal or `meridian.ddev.site` (no cascading unhealthy). No `restart:` on any service |
| Actual result | 2 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-03.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-04: env_file order, no values in compose, no new variable

| Field | Value |
|---|---|
| Linked criterion | C6, KD-3 |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-04` |
| Expected result | `env_file` is exactly `[${DDEV_APPROOT}/.env.example, {path: ${DDEV_APPROOT}/.env, required: false}]` on all three; no secret-like literal and no `change-me` placeholder in compose files; no `.ddev/.env*`; every `MERIDIAN_*` / `DRUPAL_*` name used exists in `.env.example` |
| Actual result | 4 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-04.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-05: No host ports, shared service settings

| Field | Value |
|---|---|
| Linked criterion | AC2, KD-2 |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-05` |
| Expected result | No `ports:` anywhere; networks (if declared) include `default` and `ddev_default`; engine and web run as `${DDEV_UID}:${DDEV_GID}` with `HOME=/tmp` and the repo mounted at `/var/www/html`; Postgres has no router variables |
| Actual result | 2 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-05.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-06: Router route and CA trust wiring

| Field | Value |
|---|---|
| Linked criterion | AC2, AC6a |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-06` |
| Expected result | Web: `VIRTUAL_HOST=meridian.ddev.site`, `HTTPS_EXPOSE=3001:3000`, no `HTTP_EXPOSE`, `NODE_EXTRA_CA_CERTS=/mnt/ddev-global-cache/mkcert/rootCA.pem`, working dir `/var/www/html/apps/web`, `start.sh` wired. Engine: `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` = `/tmp/meridian-ca-bundle.pem`, `init: true`, `entrypoint.sh` wired, working dir `/var/www/html/services/engine`. Both: `external_links: ddev-router:meridian.ddev.site` and the external volume `ddev-global-cache` mounted read-only. If the developer used the documented fallback (`HTTP_EXPOSE=3002:3000` or `http://web`) this FAILs and goes back to the technical-architect |
| Actual result | 1 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-06.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-07: meridian-postgres service and data volume

| Field | Value |
|---|---|
| Linked criterion | AC4, KD-4 |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-07` |
| Expected result | `POSTGRES_DB` and `POSTGRES_USER` = `meridian`; `POSTGRES_INITDB_ARGS` has `--encoding=UTF8 --locale=C.UTF-8`; password only from `MERIDIAN_POSTGRES_PASSWORD` through an entrypoint that `exec`s `docker-entrypoint.sh`; named volume at `/var/lib/postgresql/data` declared with both DDEV labels; no literal `POSTGRES_PASSWORD` |
| Actual result | 3 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-07.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-08: Host commands: form and annotations

| Field | Value |
|---|---|
| Linked criterion | AC3, KD-7 |
| Type | Static |
| Preconditions | `.ddev/commands/host/{engine,next,pg,meridian-status}` committed |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-08` |
| Expected result | Each command: executable, bash shebang, `set -euo pipefail`, `## Description`, `## Usage`, `## Example`, no `## Flags`, handles `-h`/`--help`, usage errors to stderr with `exit 2`, `bash -n` clean. `engine` and `next` forward `"$@"` (no `eval`, no `$*`) to `meridian-engine` / `meridian-web` in the right directories. `pg` offers `psql`, `dump`, `restore` as user `meridian` on database `meridian`. `meridian-status` lists web, db and the three new services via `docker inspect`. No `ddev e2e` (T27) |
| Actual result | 22 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-08.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-09: pg dump and restore script logic

| Field | Value |
|---|---|
| Linked criterion | AC4, KD-8 |
| Type | Static |
| Preconditions | as 08 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-09` |
| Expected result | Dump: `pg_dump -Fc --no-owner --no-acl`, default `db-dumps/meridian-postgres-<UTC>.dump`, `umask 077`, temp file then `mv`. Restore: requires `--yes`; reads the WHOLE archive with `pg_restore -f /dev/null` on a line BEFORE the call that runs `dropdb` (`--list` reads only the table of contents; plan addendum 2026-11-02); `dropdb --force --if-exists`, `createdb -O meridian`, `pg_restore --exit-on-error`; streams with `docker exec -i`; no password on a command line |
| Actual result | 6 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-09.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-10: meridian-status logic

| Field | Value |
|---|---|
| Linked criterion | AC5, KD-10 |
| Type | Static |
| Preconditions | as 08 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-10` |
| Expected result | Reads `.State.Status` and `.State.Health.Status`, reports `missing`, exits 1 unless every service is running and healthy, names bad services last, no colour unless stdout is a terminal, container names `ddev-meridian-web`, `ddev-meridian-db`, `ddev-meridian-<service>` |
| Actual result | 3 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-10.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-11: Helper scripts and the placeholder server

| Field | Value |
|---|---|
| Linked criterion | AC6a, KD-1, KD-5, KD-6 |
| Type | Static |
| Preconditions | `.ddev/meridian-engine/entrypoint.sh`, `.ddev/meridian-web/{start.sh,placeholder-server.mjs}` committed |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-11` |
| Expected result | Scripts executable, `bash -n` clean, strict mode. Entrypoint builds `/tmp/meridian-ca-bundle.pem` from the system bundle plus the mkcert root, warns on stderr when the root is absent, then `exec "$@"`. `start.sh` runs `exec npm run dev -- --hostname 0.0.0.0 --port 3000` when `apps/web/package.json` exists, else the placeholder. Placeholder: 40 lines or fewer, `node:http` only, fixed sentence `meridian-web placeholder; the dashboard arrives in T21`, 200 `text/plain`, no fs, env or fetch. No README in the helper folders |
| Actual result | 7 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-11.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-12: Scope discipline (snapshot at T06 close)

| Field | Value |
|---|---|
| Linked criterion | KD-1, non-goals |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-12` |
| Expected result | `[at-close]` no `services/engine/pyproject.toml`, no `apps/web/package.json` tracked or present, no Dockerfile, no `ddev e2e`, `.ddev/config.yaml`, `scripts/quality.sh` and `.ddev/commands/host/quality` unchanged since 6e9e69d. Invariant: `quality.sh` maps the ddev runner to `ddev engine` / `ddev next`; no `providers/pantheon.yaml` (T07), no ci.yml DDEV job (T08). Retire the `[at-close]` checks with a Change log row when T13 or T21 starts |
| Actual result | 8 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-12.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-13: Dumps and generated files stay out of git

| Field | Value |
|---|---|
| Linked criterion | AC4, C6 |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-13` |
| Expected result | `git check-ignore -v db-dumps/x.dump` names the root `.gitignore`; any `*.dump` is ignored; no tracked file matches an ignore rule; the new `.ddev` files are not ignored; no dump or `.env` tracked |
| Actual result | 5 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-13.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-14: Documentation updated

| Field | Value |
|---|---|
| Linked criterion | C5, AC3, decision condition 3 |
| Type | Static |
| Preconditions | docs committed |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-14` |
| Expected result | Runbook: the four commands, `--yes`, port 3001 serves a placeholder until T21, `ddev delete` loses Postgres data so run `ddev pg dump` first, `ALTER ROLE` password change, mkcert, port check. `.ddev/README.md`: file table, commands, Verified facts table, e2e not under T06, placeholder until T21. `CLAUDE.md` Commands table, root `README.md`, `services/engine/README.md`, `apps/web/README.md` (placeholder until T21), D7 in `technical-design.md` (router, mkcert, 3001; "unverified (T06)" sentence gone; open-items row resolved). No doc claims the Next.js dev server runs in T06 |
| Actual result | 13 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-14.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-15: .env.example: names and values unchanged

| Field | Value |
|---|---|
| Linked criterion | C6, KD-9 |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-15` |
| Expected result | `[at-close]` variable lines identical to 6e9e69d (comments only differ); `MERIDIAN_WEB_BASE_URL=https://meridian.ddev.site:3001`; the comment no longer says "host fixed in T06"; no compose/command file uses a variable name missing from `.env.example` |
| Actual result | 4 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-15.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-16: No secrets in T06 files

| Field | Value |
|---|---|
| Linked criterion | C6 |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-16` |
| Expected result | No key, token or credential pattern in any T06 file; `rootCA-key.pem` never referenced; `ddev-global-cache` only mounted read-only; gitleaks clean when on PATH (else SKIP, covered by the pre-commit hook in 19) |
| Actual result | 3 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). gitleaks binary not on PATH (SKIP); the pre-commit gitleaks hook ran and passed. |
| Evidence | `evidence/TC-T06-16.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-17: Simulation-only denylist

| Field | Value |
|---|---|
| Linked criterion | FR-11, ADR-0006, CLAUDE.md |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-17` |
| Expected result | No broker, trading-domain or order-placement string in the implementation files or changed docs; images only `postgres`, `python`, `node`; no outbound host in the helper scripts except `meridian.ddev.site`, `127.0.0.1`, `localhost`, `0.0.0.0`. Empty file set FAILs |
| Actual result | 4 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-17.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-18: Naming

| Field | Value |
|---|---|
| Linked criterion | section 0 |
| Type | Static |
| Preconditions | as 01 |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-18` |
| Expected result | `scripts/check-names.sh` passes; section 0 service and container names; no old placeholder names |
| Actual result | 3 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-18.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-19: Hygiene and earlier regression sets

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Type | Static |
| Preconditions | `.tools/pre-commit` bootstrapped |
| Steps | 1. `docs/tests/T06/run-checks.sh` and read block `== TC-T06-19`; 2. `.tools/pre-commit run shellcheck yamllint --files <T06 files>` (never `--all-files`) |
| Expected result | shellcheck and yamllint pass on commands, helpers and compose files (through the hook when not on PATH); `pre-commit run --files` over every file T06 changes exits 0; `docs/tests/T05/run-checks.sh --regression` and the T04a, T03, T04 regression sets exit 0 |
| Actual result | 3 checks PASS, 0 FAIL (static run (`T06_EVIDENCE=1 run-checks.sh --live`, static part), HEAD 5bf194e plus uncommitted check fixes). `shellcheck` and `yamllint` are not on PATH (3 SKIP lines counted); the pre-commit hooks ran them. T04a, T05 and T06 `--regression` all exit 0. |
| Evidence | `evidence/TC-T06-19.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-20: ddev start: five containers running and healthy

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Live-DDEV |
| Preconditions | DDEV, Docker, network; implementation present; images pullable |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-20`; 2. note the `ddev start` time |
| Expected result | `ddev start` exits 0; `web`, `db`, `meridian-postgres`, `meridian-engine`, `meridian-web` are `running` and `healthy` (`docker inspect`); `ddev meridian-status` exits 0; `pg_isready` answers. Warm start time recorded (plan target: at most 20 s over the T05 baseline) |
| Actual result | 5 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-20.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-21: ddev stop and start manage the new containers by label

| Field | Value |
|---|---|
| Linked criterion | AC1, KD-2 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-21` |
| Expected result | After `ddev stop` no container labelled `com.ddev.site-name=meridian` runs and the three new containers are not running; `ddev start` brings all five back healthy |
| Actual result | 5 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-21.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-22: Engine reaches meridian-postgres:5432

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-22`; manual form: `ddev engine python3 -c "import socket; socket.create_connection(('meridian-postgres', 5432), 3)"` |
| Expected result | Exit 0 and `connected`. Negative: port 5999 and an unknown host name both fail (the check can fail). `getent hosts meridian-postgres` resolves |
| Actual result | 4 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-22.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-23: Engine reaches `https://meridian.ddev.site` with trusted TLS

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Live-DDEV |
| Preconditions | as 20; mkcert root in `ddev-global-cache`; Drupal reachable |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-23`; manual form: `ddev engine python3 -c "import urllib.request as u; print(u.urlopen('https://meridian.ddev.site/user/login').status)"` |
| Expected result | Prints 200 (a 403 is also accepted: TLS success is the point) with verification on and no `-k`. `getent hosts meridian.ddev.site` returns a `ddev-router` address. `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` are set in an exec session. Negative: with both unset the same call fails with `CERTIFICATE_VERIFY_FAILED` (trust comes from the bundle). The bundle holds more than 50 certificates (public CAs kept) |
| Actual result | 5 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-23.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-24: meridian-web reaches Drupal over trusted HTTPS

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Live-DDEV |
| Preconditions | as 23 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-24`; manual form: `ddev next node -e "fetch(process.env.DRUPAL_BASE_URL + '/user/login').then(r => { console.log(r.status); process.exit(r.ok ? 0 : 1) })"` |
| Expected result | Exit 0, prints 200. Negative: with `NODE_EXTRA_CA_CERTS` unset the fetch fails on certificate trust (`UNABLE_TO_VERIFY_LEAF_SIGNATURE` or another CERT error) |
| Actual result | 2 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-24.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-25: ddev engine: argument fidelity, cwd, exit status, stdin

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-25`; manual: `ddev engine bash -c 'printf "<%s>\n" "$@"' _ 'a b' '' 'c"d'` |
| Expected result | Prints exactly `<a b>`, `<>`, `<c"d>`; metacharacters (`$HOME`, backtick, `*`, `;`) arrive literally; `ddev engine pwd` = `/var/www/html/services/engine`; `ddev engine python3 --version` = `Python 3.12.x` (flags pass through); container exit status 7 propagates (run directly: 7; through `ddev`: exit 1 and `error=exit status 7` on stderr, plan addendum 2026-11-02); stdin is forwarded; runs as the host uid; files written are owned by the host user |
| Actual result | 9 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-25.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-26: ddev next: argument fidelity, cwd, exit status

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-26` |
| Expected result | Same quoting result as 25; `ddev next pwd` = `/var/www/html/apps/web`; `ddev next node --version` = `v22.x`; exit status 5 propagates; host uid. T21 re-runs this case if it changes `start.sh` |
| Actual result | 6 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-26.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-27: ddev pg psql

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-27` |
| Expected result | `ddev pg psql -c 'select 1'` exits 0; current user and database are `meridian`; quoted SQL with a space is unchanged; server version 16.x; encoding UTF8; negative: a failing statement gives a non-zero exit |
| Actual result | 6 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-27.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-28: Usage and exit codes of the four commands

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-28` |
| Expected result | `--help` exits 0 with Usage for engine, next, pg, meridian-status; no argument for engine, next, pg exits 2 (run directly) with usage on stderr and nothing on stdout; negative: `pg bogus`, `pg restore` (no file), `meridian-status --bogus` exit 2 when run directly. Through `ddev` each gives exit 1 and `error=exit status 2` on stderr; `ddev engine python3 --help` reaches Python |
| Actual result | 20 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). Exit 2 asserted by running the script directly; through ddev exit 1 and `exit status 2` on stderr (plan addendum). |
| Evidence | `evidence/TC-T06-28.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-29: QUALITY_STEPS probe through ddev engine / ddev next

| Field | Value |
|---|---|
| Linked criterion | AC3, KD-7 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-29`; manual: a steps file with `probe<TAB>-<TAB>` + the `printf %q` form of `ddev engine bash -c 'test -f ../../scripts/coverage_gate.py && python3 --version'`, then `QUALITY_RUNNER=ddev QUALITY_STEPS=<file> scripts/quality.sh` |
| Expected result | `PASS probe-engine` and `PASS probe-next` (the quoted command reaches the container in the right directory, `../../scripts/coverage_gate.py` resolves). Negative: a probe that runs `exit 3` in the container gives `FAIL` and a non-zero summary exit |
| Actual result | 3 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). The FAIL line of the probe-fail step is the expected negative; the case checks it is reported as FAIL. |
| Evidence | `evidence/TC-T06-29.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-30: ddev quality exits 0 with engine and web steps SKIP

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-30` |
| Expected result | `ddev quality` exits 0; `SKIP component-engine (no services/engine/pyproject.toml)`; `SKIP component-web (no apps/web/package.json)`; `PASS component-drupal`; no `FAIL` line |
| Actual result | 4 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-30.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-31: Rows survive ddev restart

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-31` |
| Expected result | A seeded table `t06_persist` (25 rows) has the same md5 checksum after `ddev restart`; all five healthy; `meridian-status` exits 0. The test tables are dropped afterwards |
| Actual result | 5 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-31.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-32: Rows survive stop/start and poweroff/start; volume labels

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Live-DDEV |
| Preconditions | as 31 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-32` |
| Expected result | Same checksum after `ddev stop` + `ddev start` and after `ddev poweroff` + `ddev start`; `docker volume inspect meridian-postgres-data` shows `com.ddev.site-name=meridian` and `com.ddev.approot` |
| Actual result | 6 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-32.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-33: Dump and restore round trip

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-33`; manual: seed `t06_t`, `ddev pg dump`, drop it and create `t06_extra`, `ddev pg restore <path> --yes` |
| Expected result | Dump prints a path under `db-dumps/meridian-postgres-<UTC>.dump`; file is a `PGDMP` archive, mode 600 or stricter; `git check-ignore -v` names `.gitignore`; `git status --porcelain` empty. After restore the md5 checksum equals the original, `t06_extra` is gone, the table owner is `meridian`, all five services healthy |
| Actual result | 13 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-33.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-34: Dump and restore negatives

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Live-DDEV |
| Preconditions | as 33 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-34` |
| Expected result | Restore without `--yes`: exit 2 run directly (through `ddev`: exit 1 and `exit status 2`), message says the database is replaced, data unchanged. Garbage file, missing file, empty file: exit 1, data unchanged. Truncated archive (64 bytes): non-zero, data unchanged. Restore with an open client session succeeds (`--force`). Explicit `FILE` dump works and restores. Dump to an unwritable path: non-zero, no partial file. No stray temp files in `db-dumps/`. The test removes its own dump files |
| Actual result | 18 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-34.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-35: meridian-status healthy

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-35` |
| Expected result | Exit 0; five lines `SERVICE STATE HEALTH` each `running healthy`; no colour codes when piped. `ddev describe` output is stored for information |
| Actual result | 4 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-35.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-36: Stopped meridian-engine is reported

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-36`; manual: `docker stop ddev-meridian-meridian-engine; ddev meridian-status; echo $?` |
| Expected result | Exit 1 (with `error=exit status 1` on stderr); the engine line shows `exited`; the last line of standard output names `meridian-engine` and no healthy service; `ddev start` brings it back and `meridian-status` exits 0 |
| Actual result | 7 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-36.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-37: Stopped meridian-postgres is reported, no cascade

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-37` |
| Expected result | As 36 for `ddev-meridian-meridian-postgres`; additionally engine and web stay `running healthy` while Postgres is down (health checks do not cascade) |
| Actual result | 8 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-37.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-38: Stopped meridian-web is reported

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-38` |
| Expected result | As 36 for `ddev-meridian-meridian-web` |
| Actual result | 7 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-38.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-39: Unhealthy meridian-engine is reported

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-39`; manual: `docker exec ddev-meridian-meridian-engine rm /tmp/meridian-ca-bundle.pem` |
| Expected result | Within about 90 s the engine is `running unhealthy`; `meridian-status` exits 1, shows `unhealthy`, the last line of standard output names `meridian-engine`; `docker restart` regenerates the bundle and it is healthy again |
| Actual result | 5 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-39.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-40: AC6a: route and TLS on `https://meridian.ddev.site:3001`

| Field | Value |
|---|---|
| Linked criterion | AC6a |
| Type | Live-DDEV |
| Preconditions | as 20; mkcert root trusted in WSL (runbook step) |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-40`; manual: `curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}' https://meridian.ddev.site:3001/` |
| Expected result | Prints `200 0` with no `-k`; body is exactly `meridian-web placeholder; the dashboard arrives in T21`; any other path also gives 200 `text/plain`; meridian-web is `running healthy`; the container environment carries `HTTPS_EXPOSE=3001:3000`. Claim limited to the placeholder (decision file) |
| Actual result | 5 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-40.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-41: AC6a negative: no HTTP 3000 route, no host ports

| Field | Value |
|---|---|
| Linked criterion | AC6a, AC2, KD-2 |
| Type | Live-DDEV |
| Preconditions | as 20 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-41` |
| Expected result | `http://meridian.ddev.site:3000/` does not return the placeholder; `docker port` is empty for the three new containers; `ddev-router` does not publish 3000 or 5432; 3001 is bound on 127.0.0.1 only |
| Actual result | 5 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-41.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-42: AC6b: Next.js dev server on `https://meridian.ddev.site:3001` (deferred)

| Field | Value |
|---|---|
| Linked criterion | AC6b |
| Type | Deferred (Blocked, accepted, re-run in T21) |
| Preconditions | `apps/web/package.json` exists (T21) |
| Steps | Procedure for T21, run unchanged and cited by ID: 1. `ddev next npm ci`, `ddev restart`, wait for `ddev meridian-status` to show meridian-web `running healthy`; 2. `curl -sS -o body.txt -w '%{http_code} %{ssl_verify_result}' https://meridian.ddev.site:3001/`; 3. check the body is not the placeholder; 4. `ddev meridian-status`; 5. store evidence under `docs/tests/T21/evidence/` |
| Expected result | A status below 500 (200 or the T21 middleware 307) with `ssl_verify_result` 0, from the Next.js dev server (known page body or redirect), body not the placeholder; meridian-web `running healthy`. In T06 the script prints BLOCKED with this procedure. The owner must accept the deferral in writing at T06 close; an agent message is not owner acceptance. T21 adds a dated addendum to the T06 report |
| Actual result | Blocked: AC6b needs apps/web/package.json (T21). The script printed BLOCKED with the T21 procedure. Owner written acceptance of the deferral is still needed at T06 close; re-run in T21. |
| Evidence | `evidence/TC-T06-42.20261102T064955Z.txt` (BLOCKED line and procedure); T21: `docs/tests/T21/evidence/` |
| Status | Blocked (accepted, re-run in T21) once the owner accepts in writing; until then Blocked |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-43: git status clean after start, restart and dump

| Field | Value |
|---|---|
| Linked criterion | KD-7, C6 |
| Type | Live-DDEV |
| Preconditions | run after 20 to 41 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-43` |
| Expected result | `git status --porcelain` empty; `git diff --quiet`; `git status --ignored .ddev` lists only expected generated paths (reviewed in the report; T05 review item 14) |
| Actual result | 3 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-43.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-44: Clean clone with no .env: ddev start, five healthy

| Field | Value |
|---|---|
| Linked criterion | C7, AC1 |
| Type | Clean-clone |
| Preconditions | work committed; `T06_CONFIRM=1`; clone on the Linux filesystem |
| Steps | 1. `T06_CONFIRM=1 T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --clean-clone` and read block `== TC-T06-44` (it runs `ddev stop --unlist meridian`, `ddev delete -Oy meridian`, clones the branch, restores this tree at the end) |
| Expected result | Clone has no `.env`; `ddev start` exits 0 with no manual step; all five healthy; `ddev meridian-status` exits 0; `git status --porcelain` empty; Postgres accepts the `.env.example` placeholder password. Cold start time (image pulls included) recorded against the 30 min NFR-17 budget. Uncommitted T06 paths in the source tree FAIL (a clone cannot contain them) |
| Actual result | 6 checks PASS, 0 FAIL (clean-clone run (`T06_CONFIRM=1 T06_EVIDENCE=1 run-checks.sh --clean-clone`), HEAD 5bf194e plus uncommitted check fixes). Cold `ddev start` in the clone took 43 s (images already local, so not a first-pull figure). |
| Evidence | `evidence/TC-T06-44.20261102T070024Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-45: Clean clone: AC2 checks and AC6a

| Field | Value |
|---|---|
| Linked criterion | AC2, AC6a, C7 |
| Type | Clean-clone |
| Preconditions | 44 passed |
| Steps | 1. `T06_CONFIRM=1 T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --clean-clone` and read block `== TC-T06-45` |
| Expected result | Cases 22, 23, 24 and 40 checks pass inside the clone with no `.env` |
| Actual result | 13 checks PASS, 0 FAIL (clean-clone run (`T06_CONFIRM=1 T06_EVIDENCE=1 run-checks.sh --clean-clone`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-45.20261102T070024Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-46: Clean clone: start-script switch with a temporary package.json

| Field | Value |
|---|---|
| Linked criterion | decision condition 2, KD-5 |
| Type | Clean-clone |
| Preconditions | 44 passed |
| Steps | 1. `T06_CONFIRM=1 T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --clean-clone` and read block `== TC-T06-46` |
| Expected result | In the clone only, write `apps/web/package.json` (`dev` = `node t06-probe.js`) and a dependency-free server that reads `--port` and `--hostname`; `docker restart` meridian-web; `curl` (no `-k`) gives `200 0` and body `T06-SWITCH-PROBE port=3000 host=0.0.0.0` (so `start.sh` passed its arguments), not the placeholder. After removing the files and restarting, the placeholder is served again. The clone is clean afterwards and the files never reach the repo |
| Actual result | 8 checks PASS, 0 FAIL (clean-clone run (`T06_CONFIRM=1 T06_EVIDENCE=1 run-checks.sh --clean-clone`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-46.20261102T070024Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-47: Clean clone: ddev delete and the Postgres volume

| Field | Value |
|---|---|
| Linked criterion | KD-4, AC4 |
| Type | Clean-clone |
| Preconditions | 44 passed |
| Steps | 1. `T06_CONFIRM=1 T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --clean-clone` and read block `== TC-T06-47` |
| Expected result | Records whether `meridian-postgres-data` survives `ddev delete -Oy`; the runbook (in the clone) matches the recorded behaviour and tells the reader to run `ddev pg dump` before `ddev delete`; no container of the project remains |
| Actual result | 3 checks PASS, 0 FAIL (clean-clone run (`T06_CONFIRM=1 T06_EVIDENCE=1 run-checks.sh --clean-clone`), HEAD 5bf194e plus uncommitted check fixes). Recorded: `ddev delete -Oy` removed the `meridian-postgres-data` volume; the runbook says so. |
| Evidence | `evidence/TC-T06-47.20261102T070024Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-48: Browser check of `https://meridian.ddev.site:3001` in Windows

| Field | Value |
|---|---|
| Linked criterion | AC6a |
| Type | Owner-run |
| Preconditions | owner machine with the mkcert root trusted (same prerequisite as TC-T05-40) |
| Steps | 1. `ddev start`; 2. open `https://meridian.ddev.site:3001` in a Windows browser; 3. note the result (screenshot or text) |
| Expected result | The placeholder sentence naming T21 is shown, with no certificate warning. The script prints BLOCKED (owner-run) |
| Actual result | Blocked: owner-run (Windows browser check). The script printed BLOCKED with the procedure. |
| Evidence | `evidence/TC-T06-48.20261102T064955Z.txt` |
| Status | Blocked (owner-run) |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-49: Runbook followed verbatim

| Field | Value |
|---|---|
| Linked criterion | C7 |
| Type | Owner-run |
| Preconditions | fresh machine or container |
| Steps | 1. follow `docs/runbooks/local-setup.md` word for word through `ddev meridian-status` exit 0 and the dump and restore steps; 2. record each command, output and the total time |
| Expected result | Every step works as written with no undocumented action. The script prints BLOCKED (owner-run) |
| Actual result | Blocked: owner-run (runbook word for word on a clean machine). The tester walk-through is TC-T06-54. |
| Evidence | `evidence/TC-T06-49.20261102T064955Z.txt` |
| Status | Blocked (owner-run) |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-50: Half a dump and a near-complete dump are refused; data unchanged

| Field | Value |
|---|---|
| Linked criterion | AC4 (review finding 1; plan addendum 2026-11-02, KD-8) |
| Type | Live-DDEV |
| Preconditions | as 33 |
| Steps | 1. `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live-only` and read block `== TC-T06-50` |
| Expected result | A seeded database (`t06_t` 50 rows, `t06_big` 40000 rows) is dumped; the dump is at least 1 MB. A copy cut at half its size, and a copy missing its last 10 bytes, are each refused by `ddev pg restore --yes` with a non-zero exit and the message `database unchanged`; the checksum of both tables is unchanged. Control: the complete dump restores with exit 0 and the same checksum. All five services stay healthy |
| Actual result | 11 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). Dump 3,088,437 bytes; cut at 1,544,218 bytes and a copy missing its last 10 bytes were both refused with `database unchanged`; the control restore matched the checksum. |
| Evidence | `evidence/TC-T06-50.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-51: Dump path containing a single quote

| Field | Value |
|---|---|
| Linked criterion | AC4 (review finding 3) |
| Type | Live-DDEV |
| Preconditions | as 33 |
| Steps | 1. as 50, block `== TC-T06-51` |
| Expected result | `ddev pg dump "<dir with '>/x.dump"` exits 0 and writes a PGDMP archive, with no temp file left. A dump that fails after the temp file exists (script run with a non-existing site name) exits non-zero, and the EXIT trap removes the temp file with no shell error (`command not found`, `syntax error`). Restore from the quoted path exits 0 with the original checksum |
| Actual result | 7 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-51.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-52: Directory given as the dump or restore target

| Field | Value |
|---|---|
| Linked criterion | AC4 (review finding 4) |
| Type | Live-DDEV |
| Preconditions | as 33 |
| Steps | 1. as 50, block `== TC-T06-52` |
| Expected result | `pg dump DIR` run directly exits 2 with a message naming a directory; through `ddev` exit 1 and `exit status 2`; no `.pgdump.*` file is created in DIR. `ddev pg restore DIR --yes` exits 1 (`exit status 1`) and the data is unchanged |
| Actual result | 6 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). |
| Evidence | `evidence/TC-T06-52.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-53: Relative FILE resolves against the calling directory

| Field | Value |
|---|---|
| Linked criterion | AC3 (documentation claim, review finding 5) |
| Type | Live-DDEV |
| Preconditions | as 33 |
| Steps | 1. as 50, block `== TC-T06-53` (runs `ddev pg dump REL` with the working directory `docs/`) |
| Expected result | The file appears in `docs/` (the rule in the runbook and in `pg --help`); the test removes it. If it appears elsewhere, the runbook, README and help text are wrong: a defect |
| Actual result | 1 checks PASS, 0 FAIL (live run (`T06_EVIDENCE=1 run-checks.sh --live`), HEAD 5bf194e plus uncommitted check fixes). Run from `docs/`, the relative FILE landed in `docs/`, as the runbook says. |
| Evidence | `evidence/TC-T06-53.20261102T064955Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

### TC-T06-54: Clean clone: runbook steps 4 to 7, Verification and the T06 commands

| Field | Value |
|---|---|
| Linked criterion | C7 (tester walk-through; TC-T06-49 stays the owner-run word-for-word case) |
| Type | Clean-clone |
| Preconditions | as 44; runs inside the same clone after 46 |
| Steps | 1. `T06_CONFIRM=1 docs/tests/T06/run-checks.sh --clean-clone` and read block `== TC-T06-54`. It runs, in the clone, the commands of `docs/runbooks/local-setup.md` as written: step 4 `ddev drupal-install`, 5 `ddev drush uli`, 6 `ddev meridian-status`, 7 `scripts/bootstrap-dev.sh`, the Verification list including `ddev quality`, then the T06 command list (`ddev engine`, `ddev next`, `ddev pg psql`, `dump`, `restore`, `meridian-status`) |
| Expected result | Each command exits 0 and prints what the runbook says it prints; `git status --porcelain` is empty after the walk-through; `ddev quality` exits 0 with the engine and web steps SKIP. Step 1 differs only in the clone source (the branch is local, so `file://` replaces the GitHub URL); this is recorded in the evidence |
| Actual result | 18 checks PASS, 0 FAIL (clean-clone run (`T06_CONFIRM=1 T06_EVIDENCE=1 run-checks.sh --clean-clone`), HEAD 5bf194e plus uncommitted check fixes). Step 1 uses `file://` instead of the GitHub URL (branch not on the remote). Step 7 took 5 s, `ddev quality` 20 s. |
| Evidence | `evidence/TC-T06-54.20261102T070024Z.txt` |
| Status | Pass |
| Date | 2026-11-02 |
| Executed by | tester (execute mode) |

## Totals

| Type | Cases | IDs |
|---|---|---|
| Static (agent-runnable) | 19 | 01 to 19 |
| Live-DDEV | 27 | 20 to 41, 43, 50 to 53 |
| Clean-clone | 5 | 44 to 47, 54 |
| Owner-run | 2 | 48, 49 |
| Deferred (Blocked, accepted, re-run in T21) | 1 | 42 |
| Total | 54 | |

The script runs 19 static, 27 live, 5 clean-clone cases and prints BLOCKED for 42, 48 and 49.
The close step needs the owner's written acceptance of TC-T06-42 (AC6b) before T06 is `Done`.

## Change log

| Date | Change | Reason |
|---|---|---|
| 2026-11-02 | Initial design | n/a |
| 2026-11-02 | `docs/tests/T05/run-checks.sh`: TC-T05-23 (3 checks) and TC-T05-15 (`.env.example` unchanged) re-tagged `ckp` to `cka` (T05 Change log row added) | T06 plan, "Test hooks needed": these checks assert that T06 has not happened, so they are snapshots, not invariants |
| 2026-11-02 | TC-T06-01: the `ls .ddev/docker-compose.*.yaml` list is compared with the expected list sorted the same way | Review "suspected test defects": the listing is alphabetical (engine, next, postgres) and the expected list was not |
| 2026-11-02 | TC-T06-09: the "validate before drop" check now looks for `pg_restore -f /dev/null` (whole archive) before the line that calls `restore_into_db` | Plan addendum 2026-11-02 and review finding 1: `--list` reads only the table of contents; `dropdb` now sits in a function defined above its caller, so the line order of the old check no longer meant anything |
| 2026-11-02 | TC-T06-17: `deny_docs` scans only the lines T06 added (`git diff -U0` against the base, plus whole untracked files), not whole changed files | Review: `CLAUDE.md`, `README.md` and `CODING_STANDARDS.md` already hold the words "order-placement code" in the simulation-only rule text. No line T06 added matches. Not a loosening of the implementation-file scan, which is unchanged |
| 2026-11-02 | TC-T06-19 and TC-T05-21: `docs/tests/T04a/run-checks.sh` TC-T04a-33 `envsame` now compares the variable lines of `.env.example` only (T04a Change log row added) | Review: plan KD-9 allows comment edits; names and values are still compared. T04a, T05 and T06 `--regression` re-run |
| 2026-11-02 | TC-T06-24: the failure pattern also accepts `UNABLE_TO_VERIFY_LEAF_SIGNATURE` (case-insensitive) | Review: Node reports that code when the CA is missing |
| 2026-11-02 | TC-T06-25, 26, 28, 34: exit codes 2, 5 and 7 are asserted by running the script directly; through `ddev` the checks assert exit 1 and `exit status N` on stderr. TC-T06-34 "has" pattern `(?i)replace\|--yes` (invalid in ERE) is now `replace\|--yes` | Plan addendum 2026-11-02: DDEV v1.24.4 maps every non-zero host-command exit to 1 |
| 2026-11-02 | TC-T06-36 to 39: the last line is taken from standard output only; stderr is captured apart and must hold `exit status 1` | Review: the merged capture made `tail -1` read DDEV's `Failed to run` line |
| 2026-11-02 | New cases TC-T06-50 (half a dump and a dump missing its last bytes refused, data unchanged), 51 (path with a single quote), 52 (directory as target), 53 (relative FILE from `docs/`) | Review findings 1, 3, 4, 5 |
| 2026-11-02 | TC-T06-33 and TC-T06-43 "git status --porcelain is empty" and "git diff --quiet": compare with a baseline taken at the start of the live run (evidence folder ignored) instead of requiring an empty tree | First live run (HEAD 5bf194e plus the uncommitted check fixes and evidence, because the tester does not commit): both failed on pre-existing uncommitted files, not on anything DDEV, restart or dump changed. On a committed tree the baseline is empty, so the check is the same. The clean-clone checks (44, 46) still require an empty status |
| 2026-11-02 | New case TC-T06-54 (clean-clone mode): runbook steps 4 to 7, the Verification list and the T06 command list run in the clone as written | Owner instruction for `/test-task`: follow `docs/runbooks/local-setup.md` exactly in the clean clone. TC-T06-49 stays Blocked (owner-run) |
