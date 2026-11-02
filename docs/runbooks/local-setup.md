# Runbook: Local setup (DDEV, Drupal)

| Field | Value |
|---|---|
| Owner | developer |
| Last verified | 2026-11-02 by developer: the T06 commands were run in the existing working tree only. A clean-clone run is not done yet; the tester records it in `/test-task` |
| Applies to | Local DDEV |

## When to use

You have a fresh clone of the Meridian repository and want the Drupal part of the local stack
running, or you want to reset it. Since T06 the stack has five containers: `web`, `db`,
`meridian-postgres`, `meridian-engine` and `meridian-web`.

## Prerequisites

- Docker (Docker Engine or Docker Desktop) running.
- DDEV v1.24 or newer ([install guide](https://docs.ddev.com/en/stable/users/install/ddev-installation/)).
- git, and Python 3.11 or newer for `scripts/bootstrap-dev.sh` (pre-commit). On Python 3.10
  (Ubuntu 22.04) the pinned pre-commit needs `typing_extensions` 4.16 or newer on a path that is
  not a `site-packages` directory, because the pre-commit zipapp drops those from `sys.path`.
  Without sudo (DEF-003):

  ```bash
  python3 - <<'EOF'
  import io, json, os, site, urllib.request, zipfile
  d = json.load(urllib.request.urlopen("https://pypi.org/pypi/typing_extensions/json"))
  url = next(u["url"] for u in d["urls"] if u["packagetype"] == "bdist_wheel")
  extra = os.path.join(os.path.dirname(site.getusersitepackages()), "pyextra")
  os.makedirs(extra, exist_ok=True)
  zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(url).read())).extractall(extra)
  os.makedirs(site.getusersitepackages(), exist_ok=True)
  with open(os.path.join(site.getusersitepackages(), "zz-pyextra.pth"), "w") as f:
      f.write(extra + "\n")
  EOF
  ```

  `scripts/bootstrap-dev.sh` checks this and stops with a message if it is missing.
- On Windows with WSL2: run everything inside WSL2 and keep the clone on the WSL2 Linux
  filesystem, for example under `~/`. Do not clone under `/mnt/c`, it is very slow and breaks
  file watching.
- HTTPS trust: run `mkcert -install` once (DDEV bundles mkcert). On WSL2 follow the DDEV page
  above so that the Windows browser trusts the DDEV certificate. `ddev drush uli` and `curl -k`
  work without it.
- Use `ddev composer` and `ddev drush`. Never run host `composer`: the host PHP may be too old.
- No secrets are needed. The admin password that Drupal prints on install is local and
  throwaway: do not record it. Use `ddev drush uli` to log in.

## Steps

1. Clone and enter the repository.

   ```bash
   git clone git@github.com:iamPawanSaini/Meridian.git meridian
   cd meridian
   ```

   Expected: a `meridian` folder on the Linux filesystem. Until T05 is merged into `main`, also
   run `git checkout task/T05-ddev-drupal`: `main` has no `.ddev/` yet.

2. If another checkout of this project is registered, remove that registration first. Two DDEV
   projects named `meridian` cannot coexist, and `ddev stop --unlist` alone keeps the old
   database volume, so step 4 would then refuse with "already installed". This deletes the old
   checkout's local database (local, disposable data only).

   ```bash
   ddev delete -Oy meridian
   ```

   Expected: nothing to do on a first setup (`ddev list` does not show `meridian`).

3. Start the project. The first run pulls Docker images and runs `composer install`, which can
   take several minutes.

   ```bash
   ddev start
   ```

   Expected: `Successfully started meridian` and `https://meridian.ddev.site`. `git status`
   shows a clean tree. `ddev start` waits for the health checks of the three extra services.
   No `.env` is needed: the services read `.env.example`, then `.env` if it exists. Port 3001
   must be free on the host (`ss -ltn | grep 3001`; if not, `ddev poweroff`).

4. Install Drupal from the committed config.

   ```bash
   ddev drupal-install
   ```

   Expected: site install and config import, then `No differences between DB and sync
   directory.` and `Next step: ddev drush uli`.

5. Log in as admin.

   ```bash
   ddev drush uli
   ```

   Expected: a `https://meridian.ddev.site/user/reset/...` link. Open it.

6. Check the five services.

   ```bash
   ddev meridian-status
   ```

   Expected: five lines, each `running healthy`, and `OK`. If a service is not, the last line
   names it and the exit status is 1.

7. Install the git hooks and dev tooling (needed for commits and for `ddev quality`).

   ```bash
   scripts/bootstrap-dev.sh
   ```

   Expected: `Done. Hooks installed (pre-commit and commit-msg).` On Python 3.10 see the
   Prerequisites first.

## Verification

```bash
ddev composer validate
ddev drush status
ddev drush config:status
ddev drush cex -y
git status --porcelain
ddev quality
```

- `ddev composer validate` exits 0.
- `ddev drush status` shows `Drupal bootstrap : Successful` and the database connected.
- `ddev drush config:status` says `No differences`, and `ddev drush cex -y` leaves
  `git status --porcelain` empty.
- `ddev quality` exits 0 with `PASS component-drupal` and
  `SKIP component-drupal-tests (no apps/drupal/phpunit.xml.dist)`. The engine and web steps SKIP
  until T13 and T21. `ddev quality` also runs pre-commit (step 7). Run it on a committed tree:
  the pre-commit fixers rewrite files in place. Until DEF-004 is fixed, `ddev quality` exits 1 on
  the pre-commit step because of older files; the two Drupal step lines above are what T05 needs.

## Engine, Postgres and web commands (T06)

```bash
ddev engine python3 --version        # run a command in meridian-engine
ddev next node --version             # run a command in meridian-web
ddev pg psql -c 'select 1'           # psql as meridian on database meridian
ddev pg dump                         # writes db-dumps/meridian-postgres-<UTC>.dump
ddev pg restore db-dumps/FILE.dump --yes
ddev meridian-status
```

- `https://meridian.ddev.site:3001` serves a placeholder until T21 (the Next.js dashboard
  arrives then). The text names T21.
- `ddev pg restore` replaces the whole `meridian` database. It refuses without `--yes`. Before
  the drop it reads the whole dump (`pg_restore -f /dev/null`), so a truncated or corrupt file
  is refused and the database stays unchanged. If the restore itself fails after the drop, the
  database may be empty or partial: restore again from a good dump.
- `ddev pg dump FILE` and `ddev pg restore FILE`: FILE must be a file name (a directory is
  refused). A relative FILE is resolved against the directory you ran `ddev` from.
- **`ddev delete` removes the Postgres data** together with the Drupal database. Run
  `ddev pg dump` first. Dumps are local developer data: they stay out of git (`db-dumps/` is
  ignored) and out of chat and tickets.
- Data survives `ddev restart`, `ddev stop` and `ddev poweroff`.
- The three extra containers read the whole root `.env`, so every one of them sees every
  variable in it. This is accepted for local DDEV only. Deployed environments use per-component
  secret stores (D7).
- The password in `MERIDIAN_POSTGRES_PASSWORD` is applied only when the volume is first
  created. To change it later: `ddev pg psql -c "ALTER ROLE meridian PASSWORD 'new'"`, then
  change both `MERIDIAN_POSTGRES_PASSWORD` and `MERIDIAN_DATABASE_URL` in `.env`.
- `meridian-engine` and `meridian-web` reach Drupal at `https://meridian.ddev.site` through
  `ddev-router` and trust the DDEV mkcert root. The root's folder also holds its key, so the
  containers mount it read-only. Local development only.

## Reinstall

`ddev drupal-install` refuses to run on an installed site. To start over, run
`ddev drupal-install --force`. This drops the local database, then reinstalls from
`apps/drupal/config/sync`.

## Rollback

- Reset the Drupal database only: `ddev drupal-install --force`.
- Remove the project containers and database: `ddev delete -Oy meridian`, then repeat the steps.
- Ports clash or the router is unhealthy: `ddev poweroff`, then `ddev start`.
- Reset local Postgres only: `ddev pg dump` first if you want to keep it, then
  `ddev stop && docker volume rm meridian-postgres-data && ddev start`.

## Escalation

- Never apply Pantheon dashboard upstream updates. Code reaches Pantheon by subtree push only
  (ADR-0004, T07).
- If `ddev start` fails in the composer hook, read the hook output, run `ddev composer install`
  and fix the cause (usually network). Do not bypass with `fail_on_hook_fail: false`.
- HTTPS errors inside `meridian-engine` or `meridian-web` (certificate verify failed): run
  `mkcert -install` on the host, then `ddev restart`. `meridian-engine` prints a warning on
  start when the mkcert root is missing.
- A service shows `exited` or `unhealthy` in `ddev meridian-status`: `ddev logs -s <service>`,
  then `ddev start`.
- Anything else: open an issue with the output of `ddev describe` and `ddev logs`.
