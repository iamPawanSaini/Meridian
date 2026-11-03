# Runbook: Deploy Drupal to Pantheon dev and pull data back

| Field | Value |
|---|---|
| Owner | owner (Pawan Kumar) |
| Last verified | 2026-11-02 by developer (offline parts only; the live parts are marked "not yet run") |
| Applies to | Local DDEV, Pantheon dev (`meridian-trade`), GitHub Actions (`deploy-drupal.yml`) |

Task T07. Plan: `docs/tasks/T07/plan.md`. Decisions: `docs/tasks/T07/decision-*.md`.

## When to use

- You change `apps/drupal` and want it on Pantheon dev (`ddev deploy-drupal`).
- You want the Pantheon dev database and files in your local DDEV (`ddev pull pantheon`).
- You must roll back, rotate a token, or recover from a rejected push.

The Pantheon site is `meridian-trade` (machine name), created from the upstream "Drupal (Composer
Managed)". Its dev URL is `https://dev-meridian-trade.pantheonsite.io`. Dev stays in **Git mode**.

How it works, in one paragraph: `scripts/deploy-drupal.sh` splits `apps/drupal` out of the
monorepo (`git subtree split --prefix=apps/drupal`, no branch is created), takes a database
backup, pushes the split commit to Pantheon `master` with a normal (never forced) `git push`,
waits for Pantheon's Integrated Composer build, then runs `updatedb`, `config:import` and
`cache:rebuild` with drush, checks `config:status` and loads `/user/login` over HTTPS.
`ddev deploy-drupal` and `.github/workflows/deploy-drupal.yml` both call that one script.

## Prerequisites

- DDEV running (`ddev start`), an RSA key on your Pantheon account, and a Pantheon personal
  access token (PAT) in the global DDEV config. See "Owner setup" and "Personal access token".
- **Terminus 4.x in the web container.** The DDEV v1.24.4 web image ships Terminus 3.6.2, whose
  `auth:login` fails with a Pantheon PAT (`HTTP request POST .../api/authorize/machine-token has
  failed with error Undefined`, then `Maximum retry attempts reached`). `.ddev/web-build/Dockerfile`
  therefore installs Terminus 4.3.3 (checksum-verified, pinned). Check with
  `ddev exec terminus --version` (expect `Terminus 4.3.3`). After a change to the Dockerfile, run
  `ddev restart` (or `ddev debug rebuild -s web`).
- Never run `env`, `printenv` or `ddev exec env` and paste or store the output: the global
  `web_environment` value, including the PAT, is visible to everything in the web container.
- Secret names only in this repo: `TERMINUS_MACHINE_TOKEN`, `PANTHEON_DEPLOY_KEY`,
  `PANTHEON_SITE` (see `.env.example`).

## Owner setup

Do these once, in your own terminal. Do not paste any token into chat or a file in the repo.

1. **Personal access token (O-1).** Create it in the Pantheon dashboard under Personal Settings,
   Personal Access Tokens (not in Microsoft Edge: Pantheon says tokens cannot be generated
   there). Store it:

   ```bash
   ddev config global --web-environment-add=TERMINUS_MACHINE_TOKEN=<your PAT>
   ddev restart
   ```

   Write its creation date and its expiry date (creation plus 90 days) in the PAT table below.
2. **SSH key (O-2).** Create an RSA key (`ssh-keygen -t rsa -b 4096`; ed25519 is not supported
   by Pantheon), add the public key under Account, SSH Keys on Pantheon, and load it:
   `ddev auth ssh`. Repeat `ddev auth ssh` after a reboot.
3. **Agent permission (O-3).** Tell the main session in your own message that steps 1 and 2 are
   done and that agents may run the Pantheon commands with them.
4. Check: `ddev exec 'terminus auth:login --machine-token="$TERMINUS_MACHINE_TOKEN"'`, then
   `ddev exec terminus auth:whoami`. Expected: your account. `ddev exec` runs the quoted text
   inside the container, so the shell there expands the variable.

## Personal access token

Since 2026-09-30 Pantheon issues personal access tokens (PATs, formerly machine token).
A PAT expires **90 days** after creation. Existing machine tokens keep working, but none can be
created. The variable name `TERMINUS_MACHINE_TOKEN` stays; `terminus auth:login
--machine-token=...` accepts both kinds.

PATs in use (never write the value here):

| Owner | Purpose | Store | Created | Expires |
|---|---|---|---|---|
| Owner (Pawan Kumar) | `ddev pull pantheon`, `ddev deploy-drupal` | `~/.ddev/global_config.yaml` | 2026-11-01 | 2027-01-30 |
| Meridian CI bot (machine user, only if O-5 succeeds) | `deploy-drupal.yml` | GitHub Secrets `TERMINUS_MACHINE_TOKEN` | not created | not created |

**Rotation** (before the expiry date):

1. Create the new PAT (Personal Settings, Personal Access Tokens).
2. Replace it in every store: `ddev config global --web-environment-add=TERMINUS_MACHINE_TOKEN=<new>`
   then `ddev restart`; GitHub Secrets if used.
3. Run `ddev exec 'terminus auth:login --machine-token="$TERMINUS_MACHINE_TOKEN"'` and
   `ddev exec terminus auth:whoami`.
4. Revoke the old PAT in the dashboard.
5. Update the table above (dates only).

An expired PAT breaks deploys and `ddev pull pantheon`. It does not break the daily engine run,
which does not use Terminus. **Before the T31 live-simulation window**, rotate any PAT that
expires within the window plus 7 days.

## Steps

### First push (O-4, owner only, once)

The existing Pantheon `master` holds the upstream history. The first push replaces it with the
split of `main`. This is the only forced push outside an emergency.

1. Make sure `main` holds the T07 files and your clone has it: `git fetch origin`.
2. Take a database backup: `ddev exec terminus backup:create meridian-trade.dev --element=db --keep-for=30`.
3. Get the split SHA of a commit that is on `main`: `ddev deploy-drupal --ref origin/main --dry-run`.
   The last line prints the split SHA.
4. Look up the code server URL (`ddev exec terminus connection:info meridian-trade.dev
   --field=git_url`), then push the split SHA over the old history:

   ```bash
   ddev exec 'GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/var/www/html/scripts/pantheon_known_hosts -o BatchMode=yes" git push --force <git_url> <split_sha>:refs/heads/master'
   ```

   Before this push, the code server key must be captured, verified and committed in
   `scripts/pantheon_known_hosts` (see "Host keys"). There is no "accept the key once" option:
   with the key missing or wrong, the push fails closed.
5. Wait for the build in the dashboard (or `terminus workflow:wait meridian-trade.dev
   --commit=<split_sha> --max=900`). Then follow "Reinstall Pantheon dev".

The site keeps the upstream "Drupal (Composer Managed)". Pantheon upstream and Composer updates
offered by the dashboard are **never applied**. They would write a commit on Pantheon `master`,
and the next deploy would be rejected. If one was applied by mistake, follow "Emergency force
push" with the split of `main`. Update Drupal core and `pantheon-systems/drupal-integrations`
with `composer update` in `apps/drupal` and deploy the result.

### Reinstall Pantheon dev from `config/sync`

**This destroys the Pantheon dev database.** The existing dev install has a different site UUID
from `config/sync`, so `config:import` would refuse it. The owner approved a wipe for T07
testing (dev holds no project data). Run once, after the first push:

```bash
ddev exec terminus backup:create meridian-trade.dev --element=db --keep-for=30
ddev exec terminus env:wipe meridian-trade.dev --yes
ddev exec terminus remote:drush meridian-trade.dev -- site:install --existing-config --yes \
  --account-name=admin --account-mail=<owner mail>
ddev exec terminus remote:drush meridian-trade.dev -- cache:rebuild
ddev exec terminus remote:drush meridian-trade.dev -- config:status
```

Expected: `config:status` prints "No differences". `site:install` prints a generated admin
password. Do not paste it into chat or evidence. Sign in with
`ddev exec terminus remote:drush meridian-trade.dev -- user:login` instead.

Not yet run. If `site:install` cannot run on Pantheon without writing `settings.php`, the
fallback is the dashboard installer, then `config:set system.site uuid <uuid from
config/sync/system.site.yml>` and `config:import`. That fallback needs a review note.

### Deploy

1. Merge your branch into `main` with a **merge commit** (no squash, no rebase), then
   `git fetch origin` (the script needs `origin/main`).
2. `ddev deploy-drupal --dry-run` prints the split SHA and checks the split tree without network.
3. `ddev deploy-drupal` deploys `HEAD`. Options: `--ref REF`, `--allow-unmerged` (for a commit
   not yet on `main`, T07 testing only: merge that branch with a merge commit or the next
   deploy of `main` is rejected), `-h`.
4. The script prints one `stage N` line per step and ends with `deployed <split sha>`. A repeat
   of the same commit skips the backup and the push, but it still confirms that the Pantheon
   workflow (build) for that commit succeeded (`workflow:wait --commit=<sha> --start=1`, which
   must report "completed successfully for commit") and checks `env:code-log`. If the build
   failed, was aborted or cannot be found, the run exits 1 before any drush command. Then run the
   other stages as before.

Exit codes: 0 deployed and verified; 1 a step or check failed (including a build that is not
confirmed); 2 usage error or a guard (unknown argument, `PANTHEON_SITE` unset,
`DEPLOY_SMOKE_BUDGET` not whole seconds, unknown ref, missing `origin/main`, ref not merged into
`origin/main`, no code server key in `scripts/pantheon_known_hosts`, unexpected `git_url` form).
Through `ddev`, any failure is shown as exit status 1.

The workflow `deploy-drupal.yml` runs the same script on a push to `main` that touches
`apps/drupal`, `scripts/deploy-drupal.sh` or `scripts/pantheon_known_hosts`, and on manual
dispatch. It skips itself ("not configured, skipped") until the repository variable
`PANTHEON_SITE` is set (O-6). Until a machine user exists (O-5), deploys are local-only.

### Pull Pantheon dev into local DDEV

A pull **replaces the local database and files**. Take a snapshot first.

```bash
ddev snapshot
ddev auth ssh
ddev pull pantheon
```

The provider (`.ddev/providers/pantheon.yaml`) logs in with the PAT, creates a fresh backup
(`--keep-for=30`, because Sandbox has no automatic backups), downloads it and imports it. There
is no `ddev auth pantheon` in DDEV v1.24.4; the login happens inside `ddev pull pantheon`.
Without a PAT the pull stops with a message that names `TERMINUS_MACHINE_TOKEN`. There is no push
command: data never flows from local to Pantheon.

After a pull both sides share the `config/sync` site UUID (after the reinstall above). Check with
`ddev drush config:status` ("No differences").

### Host keys

`scripts/pantheon_known_hosts` pins the SSH host key of the **code server**
(`[codeserver.dev.<site-uuid>.drush.in]:2222`). `git push` runs with `StrictHostKeyChecking=yes`
against that file. The **app server** (drush) is deliberately not pinned, because Pantheon
changes its key at container migrations; `terminus env:code-log` (HTTPS) and the HTTPS smoke
check verify the result instead (`docs/tasks/T07/decision-host-keys.md`).

The file holds no key yet. Capture it once the PAT works (day 1), repeat on a second day and from
a second network, compare the SHA256 fingerprints, and only then commit the key line (with the
fingerprint in a comment) to `scripts/pantheon_known_hosts` through a reviewed change. Every push,
including the first one (O-4) and the emergency push, then runs with the pinned
`GIT_SSH_COMMAND` shown in the first-push step and in "Emergency force push". Capture the key
with:

```bash
ddev exec terminus connection:info meridian-trade.dev --fields=git_host,git_port
ddev exec 'ssh-keyscan -p 2222 <git_host> | tee /tmp/k | ssh-keygen -lf -'
```

If the code server key changes later, the deploy fails closed. Fetch the new key from two
networks, compare the fingerprints, and commit it through a reviewed pull request. Pantheon
publishes no host key list (searched 2026-11-02, none found).

## Verification

After a deploy (the script does the first three):

1. `terminus env:code-log meridian-trade.dev --format=json`: the newest `hash` equals the split
   SHA the script printed. Also `git ls-remote <git_url> refs/heads/master`.
2. `terminus remote:drush meridian-trade.dev -- config:status` says "No differences".
3. `https://dev-meridian-trade.pantheonsite.io/user/login` returns HTTP 200 and the body holds
   `user-login-form` (the Drupal form, not the Sandbox warning page).
4. Locally: `ddev drush config:status` says "No differences".

## Rollback

### Roll back code

Revert forward. A rewind is rejected, because Pantheon `master` would no longer fast-forward.

1. `git revert <bad commit>` on a task branch.
2. Merge it into `main` with a **merge commit** (no squash, no rebase: they give `main` new SHAs
   and the next non-force push is rejected).
3. Deploy `main`: the workflow, or `git fetch origin` then `ddev deploy-drupal`.

A config-only change is rolled back the same way: the deploy re-imports the reverted
`config/sync`.

### Restore the database

Every deploy that pushes first takes a database backup (`--element=db --keep-for=30`).

```bash
terminus backup:list meridian-trade.dev --element=db
terminus backup:restore meridian-trade.dev --element=db --file=<name> --yes
terminus remote:drush meridian-trade.dev -- cache:rebuild
terminus remote:drush meridian-trade.dev -- config:status
```

Then run the smoke check (load `/user/login`). Both options (`--element=db` and `--file`) are
mandatory. Backup and restore times: not yet measured (the restore test of T07 records them).

### Forbidden on Pantheon dev

Never do these. They reset code on Pantheon and break the non-force deploy path:

- the dashboard Restore button (it restores code, database and files together);
- `terminus backup:restore` without `--element` (it restores the most recent backup of any type);
- `--element=all` or `--element=code`;
- applying Pantheon upstream or Composer updates;
- switching dev to SFTP mode (an SFTP commit on Pantheon breaks the non-force push; dev stays in
  Git mode).

### Emergency force push (owner only)

Only the owner, and only when a revert cannot reach `main` in time, or after a mistaken upstream
update.

1. `terminus backup:create meridian-trade.dev --element=db --keep-for=30`.
2. Get the split SHA of a commit **that is on `main`**: `ddev deploy-drupal --ref <commit>
   --dry-run`.
3. From the web container, with the pinned host key (never a bare `git push`):

   ```bash
   ddev exec 'GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null \
     -o UserKnownHostsFile=/var/www/html/scripts/pantheon_known_hosts -o BatchMode=yes" \
     git push --force <git_url> <split_sha>:refs/heads/master'
   ```

4. Rerun `ddev deploy-drupal --ref <commit>`: it sees master already at the split, skips the
   backup and the push, **waits for and confirms the build of that commit** (exit 1 if it
   failed or cannot be found), then runs stages 7 to 9 (`updatedb`, `config:import`,
   `cache:rebuild`, `config:status`, smoke check).
5. Add a row to the event log below.

Because the target is on `main`, the next normal deploy fast-forwards again.

## Sandbox behaviour and limits

Sources: Pantheon documentation, read 2026-11-02. Values marked "observed" or "measured" were
taken by T07 on the date shown; "not yet measured" means the live run has not happened.

| Topic | Value |
|---|---|
| Sleep | Dev and Sandbox containers sleep after about 1 hour idle; a web request wakes them ("usually within 30 seconds" per Pantheon). Observed wake time: not yet measured |
| Wake by hand | `terminus env:wake meridian-trade.dev`; the deploy script does it first |
| Freeze | A Sandbox site older than 4 months with no code commit or other Git activity for 3 months is frozen. Requests return `530 Site Frozen`. Unfreeze from the workspace Sites tab |
| Sites | Two Sandbox sites per account; no custom domains; no automatic backups |
| Timeouts | Edge 59 s; PHP `max_execution_time` 120 s; Pantheon cron 180 s |
| Backups | None automatic. A manual backup is free. `ddev pull pantheon` takes a fresh one (`--keep-for=30`) |
| Request body size | The design needs 8 MB (8,388,608 bytes). Measured result: not yet measured; the stated limit is unverified |
| Private files | `file_private_path` should be `sites/default/files/private` and not served over HTTP. Measured result: not yet measured |

**Sandbox interstitial.** Since 2025-05-06 every Sandbox environment shows an interstitial
warning page. Automated tools can send the header `Deterrence-Bypass`; its value is unverified.
Whether `curl` or API clients (JSON:API, OAuth, ingest) are intercepted is not yet measured
(T07 result pending). The smoke check therefore requires HTTP 200 **and** the marker
`user-login-form`, and `DEPLOY_SMOKE_HEADER="Deterrence-Bypass: <value>"` adds the header if the
measurement shows it is needed. The web container does not read `.env`: locally run
`ddev exec env DEPLOY_SMOKE_HEADER="Deterrence-Bypass: <value>" scripts/deploy-drupal.sh` (same
for `DEPLOY_SMOKE_BUDGET`, whole seconds), and in CI set the repository variables of the same
names (the workflow passes them). If API requests are intercepted, T10 and T21 must send the header.

**Before the T31 window.** Ingest requests are not Git activity, so a Sandbox freeze can hit a
long run. Confirm that the last Git activity on Pantheon is under 60 days old (
`terminus env:code-log meridian-trade.dev`), or deploy a reviewed change before the window.
Also rotate any PAT that expires within the window plus 7 days.

## Troubleshooting

| Symptom | Cause and action |
|---|---|
| `terminus auth:login` fails with `HTTP request POST .../machine-token has failed with error Undefined` | Old Terminus 3.x in the web container: `ddev exec terminus --version` must say 4.3.3; `ddev restart` rebuilds the image. If it still fails with 4.3.3, the PAT is expired or was stored wrongly: create a new one (see Rotation) |
| `origin/main is missing; run git fetch origin first` | Run `git fetch origin` |
| `ref is not merged into origin/main` (exit 2) | Merge the branch first. `--allow-unmerged` is for T07 testing only |
| `workflow:wait failed` / `build of <sha> not confirmed` (re-run or first run) | The Pantheon build of that commit failed, was aborted, or no workflow was found (Terminus gives up after about 50 s without one). Read the workflow log in the dashboard, fix the cause, push a new commit |
| `pantheon_known_hosts holds no host key line` (exit 2) | Record the code server key (see "Host keys") |
| `Host key verification failed` on push or ls-remote | The code server key differs from the file. Do not bypass: compare fingerprints from two networks and fix the file in a reviewed pull request |
| Push rejected (non-fast-forward) | Pantheon master has a commit that is not in your split (a rewind, a dashboard update, an SFTP commit). See "Roll back code" and "Emergency force push" |
| `database backup failed; nothing was pushed` | Fix the Pantheon error and rerun. The deploy never pushes without a backup |
| `env:code-log newest commit ... expected ...` | The push did not arrive or another commit is newer. Check the dashboard Commits list |
| `the workflow ... did not finish within 900 s` | `terminus workflow:wait` returns 0 on timeout; the script treats it as a failure. Look at the Pantheon workflow log, then rerun: the push and backup are skipped, and the rerun checks the build of that commit again (it exits 1 if the build failed or is not found) |
| Smoke check never shows `user-login-form` | The site is asleep or the Sandbox warning page is shown. Set `DEPLOY_SMOKE_HEADER`, or open the URL in a browser |
| `530 Site Frozen` | Unfreeze from the workspace Sites tab |

## Escalation

Pantheon status and support through the dashboard. For a lost or leaked token, revoke the PAT in
the dashboard first (Personal Settings, Personal Access Tokens), then rotate. For anything that
needs a force push, the owner decides.

## Tool versions

- Terminus 4.3.3 (published 2026-08-20, source
  `https://github.com/pantheon-systems/terminus/releases/tag/4.3.3`, sha256
  `e7ca9bcad3acbb1cfc0cec32550eeb2351e578dc6d5f79cd3a5303201893bade`), checked 2026-11-02.
  Used in the DDEV web image (`.ddev/web-build/Dockerfile`) and in `deploy-drupal.yml`.
- actionlint 1.7.12 (published 2026-03-30), used to lint the workflow
  (`.tools/actionlint -version`, installed by hand from the GitHub release).

## Event log

| Date | Event | By |
|---|---|---|
| 2026-11-02 | Runbook drafted (offline parts); live parts not yet run | developer |
