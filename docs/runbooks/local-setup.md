# Runbook: Local setup (DDEV, Drupal)

| Field | Value |
|---|---|
| Owner | developer |
| Last verified | 2026-11-01 by developer: the commands were run in the existing working tree only. A clean-clone run (AC6) is not done yet; the tester records it in `/test-task` |
| Applies to | Local DDEV |

## When to use

You have a fresh clone of the Meridian repository and want the Drupal part of the local stack
running, or you want to reset it. The engine, Postgres and Next.js services join in T06.

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

   Expected: a `meridian` folder on the Linux filesystem.

2. If another checkout of this project is registered, unlist it first. Two DDEV projects named
   `meridian` cannot coexist.

   ```bash
   ddev stop --unlist meridian
   ```

   Expected: nothing to do on a first setup.

3. Start the project. The first run pulls Docker images and runs `composer install`, which can
   take several minutes.

   ```bash
   ddev start
   ```

   Expected: `Successfully started meridian` and `https://meridian.ddev.site`. `git status`
   shows a clean tree.

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
  until T13 and T21. `ddev quality` also runs pre-commit, so run `scripts/bootstrap-dev.sh` first.

## Reinstall

`ddev drupal-install` refuses to run on an installed site. To start over, run
`ddev drupal-install --force`. This drops the local database, then reinstalls from
`apps/drupal/config/sync`.

## Rollback

- Reset the Drupal database only: `ddev drupal-install --force`.
- Remove the project containers and database: `ddev delete -Oy meridian`, then repeat the steps.
- Ports clash or the router is unhealthy: `ddev poweroff`, then `ddev start`.

## Escalation

- Never apply Pantheon dashboard upstream updates. Code reaches Pantheon by subtree push only
  (ADR-0004, T07).
- If `ddev start` fails in the composer hook, read the hook output, run `ddev composer install`
  and fix the cause (usually network). Do not bypass with `fail_on_hook_fail: false`.
- Anything else: open an issue with the output of `ddev describe` and `ddev logs`.
