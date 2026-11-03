# T07: Pantheon dev environment and deployment path, Plan

| Field | Value |
|---|---|
| Task | T07 |
| Author | technical-architect |
| Date | 2026-11-02 (Revision 2: solution-architect decisions SA-1 to SA-7 applied) |
| Branch | `task/T07-pantheon-dev` (cut from `main` at 1200ad0, which holds T00 to T06) |
| Status | Approved (owner, 2026-11-02; owner also applied the proposed AC2, AC3 and AC4 wording to `docs/TASKS.md`) |
| Covers | R-11 (FR-27, the Pantheon dev part; deploy smoke checks) |
| Depends on | T05 (In test; only the owner-run TC-T05-39 and TC-T05-40 are open). The owner accepted the risk of starting T07 before T05 is signed off (owner facts, 2026-11-02). See risk R1 |
| Decisions | [`decision-ci-credentials.md`](decision-ci-credentials.md) (SA-1), [`decision-rollback.md`](decision-rollback.md) (SA-2), [`decision-upstream.md`](decision-upstream.md) (SA-3), [`decision-host-keys.md`](decision-host-keys.md) (SA-4), [`decision-scope.md`](decision-scope.md) (SA-5, SA-6, SA-7), all solution-architect, 2026-11-02 |

## Goal

Connect the existing Pantheon sandbox site `meridian-trade` to the monorepo. After T07, the
Composer root `apps/drupal` reaches Pantheon dev by one tested mechanism (a subtree split pushed
with a normal, non-force `git push`), Integrated Composer builds it, and drush applies database
updates and imports `config/sync`, so `config:status` is clean on Pantheon dev and locally.
`ddev pull pantheon` brings the Pantheon dev database and files into local DDEV. The deploy
logic is one script, `scripts/deploy-drupal.sh`. A local DDEV command and the GitHub workflow
`deploy-drupal.yml` are thin wrappers around it, so AC4 is proven by a real local deploy
before any GitHub secret exists (SA-7). `docs/runbooks/deploy.md` records the owner steps,
the one-time force push, token rotation, rollback, and sandbox sleep, freeze and limits. T07
also closes the Pantheon items in the technical-design "unverified" register, each with a
source and date.

Acceptance criteria from `docs/TASKS.md`, numbered for traceability. The solution-architect
proposed new wording for AC2, AC3 and AC4; `docs/TASKS.md` is the owner's document, so the
current text stays until the owner applies it (see "Owner decisions").

| ID | Criterion (current text) | Reading for T07 (solution-architect) |
|---|---|---|
| AC1 | Pantheon sandbox site created from the Composer-managed Drupal upstream; `pantheon.yml` committed | Unchanged; the site keeps that upstream (SA-3) |
| AC2 | Terminus machine token setup documented; token never committed (secret scan passes) | Proposed: "Terminus personal access token (PAT, formerly machine token) setup and 90-day rotation documented; token never committed (secret scan passes)" (SA-1) |
| AC3 | `ddev auth pantheon` and `ddev pull pantheon` pull database and files into local DDEV (tested) | Proposed: "Terminus authentication for DDEV is set up (PAT in the global DDEV config; `ddev auth ssh` loads the SSH key) and `ddev pull pantheon` pulls database and files into local DDEV (tested)". The test runs from a fresh shell with no manual `terminus auth:login` first (SA-5) |
| AC4 | Code in `apps/drupal` deploys to Pantheon dev by the decided mechanism (for example subtree push from CI); site loads on its dev URL | Proposed: "... by the decided mechanism (subtree split pushed by `scripts/deploy-drupal.sh`, run with `ddev deploy-drupal` or from `deploy-drupal.yml`) ...". Met by the local real deploy under the SA-7 conditions |
| AC5 | Config imported on Pantheon dev matches local (`drush config:status` clean) | Unchanged |
| AC6 | Rollback procedure and sandbox sleep and limits behaviour documented in `docs/runbooks/deploy.md` | Unchanged; rollback per SA-2; sleep, freeze, limits and the interstitial per SA-6 |

## Facts established while planning (2026-11-02)

Owner facts (main session relay, 2026-11-02): site machine name `meridian-trade`; upstream
"Drupal (Composer Managed)"; Drupal already installed on dev through Pantheon (its site UUID
differs from `config/sync`); dev connection mode Git; wipe and reinstall of Pantheon dev from
`config/sync` approved for T07 testing; GitHub repo `iamPawanSaini/Meridian` pushed, `main` at
the merged T06; no CI (T08), no GitHub secrets or variables, no `gh` CLI. The owner creates the
Pantheon token and adds an RSA SSH key to their Pantheon account.

Probed read-only by the technical-architect on the owner's machine (DDEV v1.24.4, WSL2):

- `ddev auth --help` lists only `ssh`. There is **no `ddev auth pantheon`** (KD-11).
- Terminus **3.6.2** is in the DDEV web container. `terminus workflow:wait <site_env>
  [<description>] --commit=SHA --max=SECONDS` exists (default description "code sync", default
  max 180 s). `env:wake`, `env:code-log`, `connection:info`, `upstream:updates:*` exist. This is
  CLI help only; behaviour against the Pantheon API is not yet verified.
- `terminus self:config:dump` shows `ssh_command` (env `TERMINUS_SSH_COMMAND`, default `ssh`).
  Terminus 3.x places it before its own `-o "StrictHostKeyChecking=no"` (SA-4, source checked
  on branch `3.x`; the developer confirms the 3.6.2 tag).
- The web container has git 2.39.5 with `git subtree`, plus `ssh`, `ssh-add`, `curl` and `jq`.
- `TERMINUS_MACHINE_TOKEN` is not set in `~/.ddev/global_config.yaml` yet (checked by count
  only; no value read).
- `apps/drupal/.gitignore` exists on disk but is scaffold-generated and ignored by the root
  `.gitignore`. The tracked files under `apps/drupal` are `README.md`, `composer.json`,
  `composer.lock`, `pantheon.yml`, `phpcs.xml.dist`, `phpstan.neon.dist`, `config/sync/*`,
  `web/modules/custom/.gitkeep` and `web/sites/default/settings.php`. So the split tree holds
  **no `.gitignore`** and no build output (KD-7).
- `settings.php` includes `settings.pantheon.php` in step 2 and sets
  `config_sync_directory = '../config/sync'` unconditionally in step 4 (KD-5).
- `docs/architecture/openapi.yaml` still has the server variable `site` defaulting to
  `meridian`; `.env.example` says `PANTHEON_SITE=meridian`.

Pantheon facts from the solution-architect (sources and dates in the decision files):

- Since **2026-09-30** Pantheon issues **Personal Access Tokens (PATs)** that expire **90
  days** after creation; no new machine tokens. `--machine-token` accepts both.
- Since **2025-05-06** every Sandbox environment shows an **interstitial warning page**;
  automated tools can send the header `Deterrence-Bypass` (value **unverified**). Whether
  non-browser requests are intercepted is unverified.
- Sandbox: sleep after about 1 h idle (wake "usually within 30 seconds"); a site over 4 months
  old with no Git activity for 3 months is **frozen** (`530 Site Frozen`); no automatic
  backups; no custom domains; two Sandbox sites per account. Edge timeout 59 s, PHP 120 s.
- The dashboard Restore button and code restores reset code on Pantheon. The app server host
  key changes at container migrations. Integrated Composer installs `require-dev` on Dev.

## Key decisions

### KD-1 One deploy script, two thin wrappers

`scripts/deploy-drupal.sh` is the only implementation of the D8 deploy steps. Interface:

```text
scripts/deploy-drupal.sh [--ref REF] [--dry-run] [--allow-unmerged] [-h]
  --ref REF          commit to deploy (default HEAD); resolved with git rev-parse --verify
  --dry-run          split and check the tree, print the split SHA and the target; no network
  --allow-unmerged   allow a REF that is not an ancestor of origin/main (see stage 1)
env:
  PANTHEON_SITE           required (site machine name)
  TERMINUS_MACHINE_TOKEN  optional; Pantheon PAT. When set the script runs terminus
                          auth:login, otherwise it requires an existing session
                          (terminus auth:whoami)
exit: 0 deployed and verified; 1 a deploy or verification step failed; 2 usage or guard error
```

Stages, each printed as one line with the stage name:

1. **Resolve and guard the ref.** Resolve `REF`. Ancestor guard (SA-2 decision 6; exact guard
   decided here): `git merge-base --is-ancestor REF origin/main` must succeed; if
   `origin/main` is missing, exit 2 with "run git fetch origin". Otherwise exit 2, unless
   `--allow-unmerged` is given; then print a warning that the branch must be merged into `main`
   with a merge commit (no squash or rebase), or the next deploy of `main` is rejected. The
   workflow never passes `--allow-unmerged`. Split with
   `git subtree split --prefix=apps/drupal "$REF"` and **no `-b`** (no local branch); the
   output is the split SHA. The split is deterministic, so a later split of `main` descends
   from a task-branch split merged with a merge commit.
2. **Guard the split tree.** Fail if `git ls-tree -r` of the split SHA lists any of `vendor/`,
   `web/core/`, `web/modules/contrib/`, `sites/*/files/`, `private/`, `.env`, `*.key`, `*.pem`,
   `settings.local.php`. Fail if `composer.json`, `composer.lock`, `pantheon.yml` or
   `config/sync/system.site.yml` is missing. `--dry-run` stops here.
3. **Authenticate.** `terminus auth:login` (only if the token is set), then
   `terminus connection:info "$PANTHEON_SITE.dev" --field=git_url`.
4. **Wake.** `terminus env:wake`. If `git ls-remote` shows `master` already at the split SHA,
   skip stages 5 and 6 (idempotent re-run; no new backup) and go to stage 7.
5. **Back up and push.** `terminus backup:create "$PANTHEON_SITE.dev" --element=db
   --keep-for=30`; a failed backup exits 1 before the push (SA-2 decision 5; the exit code on
   failure is checked with a stub and one real run). Then
   `git push "$git_url" "$split_sha:refs/heads/master"`. Never `--force`, never a `+` refspec.
   A rejected push exits 1 with a pointer to "Roll back code" and "Emergency force push" in
   `docs/runbooks/deploy.md`.
6. **Wait and verify the code.** `terminus workflow:wait "$PANTHEON_SITE.dev"
   --commit="$split_sha" --max=900`, then check the workflow succeeded (if `workflow:wait` exits
   0 on a failed build, check `workflow:info:status`). Then the out-of-band check (SA-4):
   `terminus env:code-log "$PANTHEON_SITE.dev" --format=json` must show the split SHA as the
   newest `hash`.
7. **Apply.** `terminus remote:drush "$PANTHEON_SITE.dev" -- updatedb -y`, then
   `config:import -y`, then `cache:rebuild`.
8. **Config check.** `config:status` must print "No differences" (same check as
   `ddev drupal-install`).
9. **Smoke check.** HTTPS GET with certificate verification of
   `https://dev-$PANTHEON_SITE.pantheonsite.io/user/login`: status 200 **and** the body holds
   the Drupal marker `user-login-form` (not the Sandbox interstitial). It sends the
   `Deterrence-Bypass` header with the value found in KD-12 if KD-12 shows it is needed (a
   non-secret constant in the script). Wake retry budget 120 s (RK-04). Print the deployed split
   SHA last.

Wrappers:

- **Local:** `.ddev/commands/web/deploy-drupal` (`ddev deploy-drupal [options]`) runs the script
  in the web container, which has git, Terminus, ssh and the DDEV ssh agent. The owner loads the
  Pantheon key with `ddev auth ssh` and has the PAT in the global DDEV config. This is the AC4
  path (SA-7) and, if no machine user is possible, the only deploy path (SA-1).
- **CI:** `.github/workflows/deploy-drupal.yml` installs a pinned Terminus, loads the key, and
  calls the script (KD-8).

No `set -x` anywhere in the script, the wrapper, the provider file or the workflow. The script
never prints an environment variable or the token, and prints only the host part of the git URL.

### KD-2 SSH host keys (SA-4)

- **Code server, pinned strictly.** The committed, non-secret file
  `scripts/pantheon_known_hosts` holds the key line(s) for
  `[codeserver.dev.<site-uuid>.drush.in]:2222` only. A comment above each line records the
  SHA256 fingerprint, the date, how it was fetched, and a comment states that the app server is
  deliberately not pinned, with a link to `decision-host-keys.md`. `GIT_SSH_COMMAND` is
  `ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile=<known hosts file> -o BatchMode=yes`,
  where the file is `scripts/pantheon_known_hosts` resolved from the repo root.
- **Fetching the key:** `ssh-keyscan -p 2222` from the owner's machine on two different days,
  and once from a second network (a GitHub-hosted runner after merge, or a phone hotspot);
  fingerprints must match. Pantheon publishes no host key list (re-checked at review; record
  "none found" with the date).
- **App server, not pinned.** `TERMINUS_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o
  BatchMode=yes -o LogLevel=ERROR"`. Its key changes at routine container migrations. The drush
  channel carries no secret; stage 6 (`env:code-log` over HTTPS) and stage 9 (TLS smoke check
  with a body marker) catch a faked result.
- `TERMINUS_ALTERNATE_NAMESERVER` must be unset (it swaps host names for IPs).
- **If the code server key changes:** the deploy fails closed. The owner fetches the new key from
  two networks, compares fingerprints and commits it by a reviewed pull request. More than one
  change in 90 days is raised at review; the technical-architect may then drop code server
  pinning with a dated finding.

### KD-3 DDEV Pantheon provider

`.ddev/providers/pantheon.yaml` is created from `pantheon.yaml.example`, with these changes:

- Remove the `#ddev-generated` line, so DDEV does not overwrite the file.
- The commands use `${PANTHEON_SITE:?}.dev` (KD-4) instead of the static `project` variable.
- `db_pull_command` runs `terminus backup:create "${PANTHEON_SITE}.dev" --element=db
  --keep-for=30` before `backup:get`, so a pull gets the current database (Sandbox has no
  automatic backups). `files_pull_command` does the same with `--element=files`.
- **Delete `db_push_command` and `files_push_command`.** Pantheon dev is a deploy target; data
  never flows from local to Pantheon (ADR-0004).
- Drop the `set -x` lines. `auth_command` keeps the example's token check and
  `terminus auth:login`; its error text says "personal access token (PAT)".

### KD-4 `PANTHEON_SITE` has one source per environment

- DDEV: `.ddev/config.yaml` gets `web_environment: [PANTHEON_SITE=meridian-trade]`. It is not a
  secret, and the provider commands and `ddev deploy-drupal` run in the web container, which does
  not read the repo-root `.env`.
- `.env.example`: `PANTHEON_SITE=meridian-trade` for parity, with a comment that DDEV takes it
  from `.ddev/config.yaml`. The `TERMINUS_MACHINE_TOKEN` comment becomes "Pantheon personal
  access token (PAT, formerly machine token; expires after 90 days). Global DDEV config locally,
  GitHub Secrets for the machine user; never in this repo".
- GitHub Actions: repository variable `PANTHEON_SITE`, set **only** when a machine user exists
  or the owner accepted owner credentials in CI (SA-1). While it is unset the workflow skips.
- D7 row `PANTHEON_SITE`, DDEV column, changes from `.env` to "`.ddev/config.yaml`
  `web_environment`". A test asserts the values agree (TH-4).
- `openapi.yaml` server variable default changes to `meridian-trade`.

### KD-5 `config_sync_directory` precedence (no code change)

Order in `settings.php`: step 2 includes `settings.pantheon.php`, which sets
`config_sync_directory` only `if (empty(...))`. At that point it is empty, so Pantheon sets
`../config` or `sites/default/config` (or `sites/default/files` on the installer URL). Step 4
then sets `'../config/sync'` unconditionally, so **`settings.php` wins** on Pantheon, on DDEV
and on the web installer. Relative to the Drupal root `/code/web` this is `/code/config/sync`.

- Keep the order. The developer adds a comment at step 4: it must stay after the Pantheon
  include, because the include sets a different default. No other `settings.php` change. This
  comment is also the `apps/drupal` change that phase 2 deploys.
- Verification on Pantheon (TH-7): `terminus remote:drush meridian-trade.dev -- php:eval
  'echo realpath(\Drupal\Core\Site\Settings::get("config_sync_directory"));'` prints
  `/code/config/sync`, and the `system.site` UUID in Pantheon's active config equals the one in
  `apps/drupal/config/sync/system.site.yml`.

### KD-6 Reinstall Pantheon dev from `config/sync` (owner-approved)

The current Pantheon database has a different site UUID, so `config:import` would refuse it.
After the first push (O-4), Pantheon dev is reinstalled once:

```text
terminus backup:create meridian-trade.dev --element=db --keep-for=30   # copy of the old install
terminus env:wipe meridian-trade.dev --yes
terminus remote:drush meridian-trade.dev -- site:install --existing-config --yes \
  --account-name=admin --account-mail=<owner mail>
terminus remote:drush meridian-trade.dev -- cache:rebuild
terminus remote:drush meridian-trade.dev -- config:status     # "No differences"
```

- The safety backup is `--element=db`, not `all`: a code or full restore is forbidden (SA-2
  decision 3), and the old install's code is the upstream history, which we never restore.
- `site:install` prints a generated admin password. It must **not** go into evidence or chat.
  The runner redacts it in the captured output, and the owner signs in with
  `terminus remote:drush meridian-trade.dev -- user:login` afterwards.
- The commands go into `docs/runbooks/deploy.md` under "Reinstall Pantheon dev" with the warning
  that it destroys the dev database. No script: it is a rare, destructive, owner-approved action.
- Whether `site:install` on Pantheon works without writing `settings.php` (Pantheon injects the
  database through `PRESSFLOW_SETTINGS`) is checked on the first run. If it fails, the fallback is
  the dashboard installer pointed at our code, then `config:set system.site uuid` plus
  `config:import`; that fallback needs a review note, because it is not the T05 install path.

### KD-7 Integrated Composer and the upstream (SA-3)

- `pantheon.yml` already has `build_step: true`, `web_docroot: true`, PHP 8.3 and MariaDB 10.6;
  `pantheon.yml` overrides `pantheon.upstream.yml`, and the split tree has no
  `pantheon.upstream.yml` at all. Integrated Composer builds from our `composer.json` and
  `composer.lock`. Our tree has no `upstream-configuration/` path repository and no
  `upstream-require` scripts, and nothing refers to them.
- Integrated Composer installs `require-dev` on Dev and Multidev (documented), so
  `drupal/core-dev` is expected on Pantheon dev. Not a risk.
- **Amended 2026-11-03 (DEF-010):** the split tree carries a tracked `apps/drupal/.gitignore`. The
  original text ("the split tree has no `.gitignore`; T07 does not add one") failed on the first
  Pantheon build: Integrated Composer stops on untracked scaffold output, and the root `.gitignore`
  does not travel with the split. Build output never reaches the split because only tracked files are
  split, and the stage 2 guard fails on any build path. Dev stays in Git mode; SFTP mode is
  forbidden in the runbook, because an SFTP commit on Pantheon would break the non-force push.
- The developer records from the first build log: the Composer version, that the build succeeded
  with only `pantheon.yml`, and that `settings.pantheon.php` is scaffolded on Pantheon
  (`php:eval 'echo (int) file_exists("sites/default/settings.pantheon.php");'` prints 1).
- **Upstream policy (SA-3):** keep the "Drupal (Composer Managed)" upstream; never apply upstream
  or Composer updates offered by the dashboard or `terminus upstream:updates:apply`. Runbook text
  as given in `decision-upstream.md`. Drupal core and `pantheon-systems/drupal-integrations` are
  updated with `composer update` in `apps/drupal` and deployed. Observe the dashboard notice once
  after O-4 and record it.

### KD-8 `deploy-drupal.yml` is a thin wrapper

- Triggers: `push` to `main` with `paths: ['apps/drupal/**', 'scripts/deploy-drupal.sh',
  'scripts/pantheon_known_hosts']`, and `workflow_dispatch` with input `ref` (default `main`).
- `concurrency: { group: deploy-drupal, cancel-in-progress: false }`. `permissions:
  contents: read`. `timeout-minutes: 30`.
- Guard: the deploy job runs only when `vars.PANTHEON_SITE != ''`; otherwise one step prints
  "deploy-drupal: not configured (PANTHEON_SITE unset), skipped" and the job succeeds. This keeps
  `main` green and, under SA-1's local-only branch, guarantees CI never deploys.
- Steps: `actions/checkout` pinned by commit SHA (version in a comment), `fetch-depth: 0`;
  install Terminus 3.6.2 phar with a pinned SHA-256 (the version DDEV ships); start `ssh-agent`
  and `ssh-add -` from `secrets.PANTHEON_DEPLOY_KEY` through stdin, with no third-party action
  and no key file on disk; run `scripts/deploy-drupal.sh --ref "${{ inputs.ref || github.sha }}"`
  with `PANTHEON_SITE` from `vars` and `TERMINUS_MACHINE_TOKEN` from `secrets`, both through
  `env:`, never inline in `run:`. No `--allow-unmerged`, so a dispatch of an unmerged ref fails
  the ancestor guard.
- `workflow_dispatch` works only once the file is on the default branch, so the CI run happens
  after merge (SA-7).
- Lint: yamllint and check-yaml (pre-commit), actionlint at a pinned version (output attached),
  and the static workflow test TH-9. Adding actionlint to CI is T08.

### KD-9 Rollback (SA-2)

The runbook has these sections, with the warnings below in a box:

1. **Roll back code:** `git revert` the bad change on a task branch, merge to `main` with a merge
   commit, deploy `main` (workflow or `ddev deploy-drupal`). Config-only rollbacks are the same.
2. **Restore the database:** `terminus backup:list meridian-trade.dev --element=db`, then
   `terminus backup:restore meridian-trade.dev --file=<name>_database.sql.gz --yes`, then
   `cache:rebuild`, `config:status` and the smoke check. **Amended 2026-11-03 (DEF-011):** the
   original text required `--element=db` and `--file` together; Terminus 4.3.3 refuses that pair.
3. **Forbidden on Pantheon dev:** the dashboard Restore button; `backup:restore` without
   `--file` of a `_database.sql.gz` backup; `--element=all` or `--element=code`. They reset code
   on Pantheon and break the non-force deploy path.
4. **Emergency force push (owner only):** only when a revert cannot reach `main` in time. Backup
   `--element=db --keep-for=30`, `git push --force` of the split of a commit **that is on
   `main`**, run stages 7 to 9 by hand (or rerun the script, which then skips the push), and
   record the event in the runbook log table.
5. A one-time **restore test** runs in T07 (TH-8). The full drill with timings stays in T29.

T08 input (record in the T08 plan): pull requests that touch `apps/drupal` must be merged with a
merge commit (already the standard; squash and rebase are disabled by T08), because the ancestor
guard and the non-force push depend on it.

### KD-10 Credentials (SA-1)

- **Token type.** Every new Pantheon token is a PAT that expires 90 days after creation. The
  variable name `TERMINUS_MACHINE_TOKEN` stays. The runbook has a table of PATs in use (owner,
  purpose, store, creation date, expiry date; never the value) and a rotation step: create the
  new PAT, replace it in every store, run `terminus auth:whoami`, revoke the old one. Before the
  T31 window starts, any PAT expiring within the window plus 7 days is rotated. An expired PAT
  breaks deploys and `ddev pull pantheon`, not the daily engine run.
- **Local:** the owner's PAT in `~/.ddev/global_config.yaml`
  (`ddev config global --web-environment-add=TERMINUS_MACHINE_TOKEN=...`, typed by the owner in
  their own terminal), and the owner's RSA key via `ddev auth ssh`. A global `web_environment`
  value is visible to anything in the web container, so evidence never includes `env`,
  `printenv` or `ddev exec env` output.
- **CI, required design:** a machine user that owns both CI credentials (its own PAT and its own
  RSA key), member of `meridian-trade` only, with the lowest role that can push to dev and run
  drush (Developer if offered, else the default team role). It creates no sites. Registered
  with a mailbox the owner controls and a name that says "Meridian CI bot".
- **If Sandbox cannot add it:** deploys stay local-only. The workflow is merged with its skip
  guard and `PANTHEON_SITE` stays unset in GitHub Variables. The owner's credentials go into
  GitHub Secrets only with an explicit written owner risk acceptance (CI-only RSA key, a PAT used
  for nothing else, its expiry date, the revocation step), recorded in the test report. An agent
  message is not that acceptance.
- The T07 test report states which branch applied: "machine user", "local-only", or "owner
  credentials accepted (date)".

### KD-11 `ddev auth pantheon` does not exist (SA-5)

DDEV v1.24.4 has only `ddev auth ssh`. The provider's `auth_command` (`terminus auth:login`)
runs as part of every `ddev pull pantheon`. T07 tests AC3 by the reading in the AC table: from a
fresh shell, with no manual `terminus auth:login` first. Until the owner changes `docs/TASKS.md`,
the test report records this reading as a note on the AC3 case.

### KD-12 Measurements T07 owns (SA-6)

- **Sandbox interstitial.** `curl -sS -o body -w '%{http_code}'` with certificate verification:
  1. GET `/user/login` without the header: status, and whether the body is Drupal's form or
     the interstitial.
  2. The same with `-H 'Deterrence-Bypass: 1'` (and other values if the Pantheon page, read in a
     browser, shows one): record which value works.
  3. The same for a POST (the body-size request below) and for GET `/jsonapi` (expect Drupal's
     401 or 200, not the interstitial).
  4. Record the result in D8 and the NFR numbers section. If API requests are intercepted, raise
     an item for T10 and T21 (and T22, T28): the engine and the Next.js server send the header
     as a non-secret constant; decide whether it belongs in D7.
- **Edge body size:** POST bodies of 8,388,608 bytes and 9 MB of random data to
  `/user/login` (warm, with the bypass header if needed). Pass for the 8 MB design value: the
  response is not 413 from the edge. Record `post_max_size` and `upload_max_filesize` with
  `php:eval 'echo ini_get(...)'`. If no doc states a limit, record the measured result with the
  date and keep "stated limit unverified".
- **Wake and warm timing:** time `terminus env:wake` from asleep (if the env is asleep at the
  time) and 20 warm GETs of `/user/login` (p50, p95). The 100-item warm ingest measurement moves
  to T10 (Pantheon dev, warm, 5 runs, p95), confirmed in T28 (SA-6).
- **Private files:** `Settings::get('file_private_path')` is `sites/default/files/private`. Write a
  probe file with `php:eval` to `private://t07-probe.txt`, then GET
  `/sites/default/files/private/t07-probe.txt`: expect 403 or 404 and not the file content.
  Delete the probe.
- **Backup and restore time:** recorded from TH-8.

## Work split

### A. Developer, no secrets needed

1. `scripts/deploy-drupal.sh` (KD-1), with `--dry-run`, the ancestor guard and the offline test
   harness (TH-1 to TH-5).
2. `.ddev/commands/web/deploy-drupal`, `.ddev/providers/pantheon.yaml` (KD-3),
   `.ddev/config.yaml` `web_environment` (KD-4).
3. `.github/workflows/deploy-drupal.yml` (KD-8) and TH-9.
4. `.env.example`, `openapi.yaml` default, `settings.php` comment (KD-5).
5. `docs/runbooks/deploy.md` draft from `docs/templates/runbook.md`, and the doc updates under
   "Interfaces touched".

### B. Runs on the owner's machine with the owner's credentials loaded

Agents may run these only after the owner says, in their own message (O-3), that the PAT and key
are in place and that agents may use them. Nobody reads or prints the PAT.

1. Read-only discovery: `terminus site:info meridian-trade --fields=id,framework,upstream,plan_name`,
   `connection:info`, `git ls-remote` on the Pantheon URL (confirms the dev branch name),
   `ssh-keyscan` of the code server for KD-2 (day 1).
2. After O-4: wait for the build, KD-7 checks, KD-6 reinstall (owner-approved), KD-5 checks.
3. `ddev deploy-drupal --ref task/T07-pantheon-dev --allow-unmerged` (deploys the KD-5 comment),
   the idempotent re-run, and the negative tests (TH-6, a rewind push).
4. `ddev pull pantheon` from a fresh shell (AC3), then local `config:status` and the site UUID
   check.
5. KD-12 measurements, the TH-8 restore test, and the day-2 `ssh-keyscan`.

### C. Owner only, in order

| ID | Action | When |
|---|---|---|
| O-1 | Create a Pantheon **personal access token** (Personal Settings, Personal Access Tokens; not in Microsoft Edge). Store it with `ddev config global --web-environment-add=TERMINUS_MACHINE_TOKEN=<PAT>` in your own terminal, then `ddev restart`. Note its creation and expiry date (creation plus 90 days) for the runbook table. Never paste it in chat or a repo file | Before part B |
| O-2 | Create an RSA key pair (`ssh-keygen -t rsa -b 4096`; ed25519 is not supported), add the public key to your Pantheon account (SSH Keys), and load it with `ddev auth ssh` | Before part B |
| O-3 | Tell the main session in your own message that O-1 and O-2 are done and that agents may run the part B commands with them | Before part B |
| O-4 | One-time force push over the upstream history (runbook "First push"): `terminus backup:create meridian-trade.dev --element=db --keep-for=30`, then from the DDEV web container `git push --force <git_url> <split_sha>:refs/heads/master`, where the split SHA is printed by `ddev deploy-drupal --ref origin/main --dry-run` (a commit on `main`). Only this one push is ever forced outside an emergency | After the part A review |
| O-5 | Read the Pantheon account and acceptable-use sections and record "read, no conflict found" with the date. Then create the machine user (owner-controlled mailbox, name "Meridian CI bot", no sites of its own), invite it with `terminus site:team:add meridian-trade <bot email> [role]` or the dashboard Team page, record the role from `terminus site:team:list meridian-trade`, and give it its own RSA key and PAT (dates recorded). If the invite fails, save the error, date and command as evidence: deploys stay local-only | After part B; before O-6 |
| O-6 | Only if O-5 succeeded (or you give the written owner-credentials acceptance of KD-10): GitHub secrets `TERMINUS_MACHINE_TOKEN` and `PANTHEON_DEPLOY_KEY`, variable `PANTHEON_SITE=meridian-trade` | After merge of T07 |
| O-7 | After O-6, "Run workflow" on `main` once and send the run URL | After O-6 |

## Verification phases for AC4 (SA-7)

1. **Offline (part A):** the script is tested with stubs: a fake `terminus` on `PATH` returns a
   local bare repository as `git_url`, so the real `git push` path runs, including the rejection
   on rewind, the ancestor guard and the idempotent re-run (TH-1 to TH-5). `--dry-run` on the
   real repo prints a split SHA whose tree equals `git rev-parse REF:apps/drupal`. The workflow
   passes actionlint and TH-9.
2. **Local real deploy (part B):** `ddev deploy-drupal` deploys to Pantheon dev, exits 0,
   `env:code-log` shows the split SHA, `config:status` is clean, and `/user/login` returns 200
   with the Drupal marker. **AC4 is met by phases 1 and 2.**
3. **CI run:** a separate test case with status `Blocked (accepted, owner-run after O-6)`. The
   owner accepts this in writing at T07 close; an agent message is not acceptance. If the
   machine user exists, the run is due after O-6 and O-7, the tester adds a dated addendum, and
   **T28 cannot close** until it passes. If deploys are local-only, the case becomes
   `Not run: deploys are local-only by decision`, and T28 checks the local path. The first
   push-triggered run on `main` after the merge (expected: skipped) is recorded as an addendum
   with its run URL; it is not a close condition.

Close wording (from `decision-scope.md`, real case IDs filled in):

- `docs/TRACEABILITY.md`, R-11 and FR-27 evidence cells: "T07: AC4 Pass by local deploy
  (TC-T07-nn); CI run TC-T07-nn Blocked (accepted, owner-run after O-6)". R-11 stays `Open`.
- `docs/PROGRESS.md`, T07 notes: "AC4 by local deploy; CI deploy run owed after O-6
  (owner-accepted); deploys local-only until a machine user exists" (drop the last clause if O-5
  succeeded).

## Scope

- Script, DDEV wrapper and provider, workflow, known-hosts file, `.env.example` and DDEV config
  changes listed in "Interfaces touched".
- First deploy to Pantheon dev, reinstall from `config/sync`, `config:status` clean on both
  sides, `ddev pull pantheon` tested, one database-only restore test.
- `docs/runbooks/deploy.md`: owner setup, PAT table and rotation, first push, deploy, reinstall,
  pull, roll back code, restore the database, emergency force push, forbidden actions, upstream
  rule, sandbox sleep, freeze, limits and interstitial, pre-T31 check, troubleshooting, event log.
- The technical-design, ADR-0004 and unverified-register follow-ups in step 11.

## Non-goals

- The CI quality pipeline `ci.yml`, branch protection, merge settings, actionlint in CI and the
  commit-message check of GitHub merge commits (T08). The split pushed to Pantheon keeps the
  original commit messages, including "Merge pull request #N"; Pantheon does not check them, and
  `check_commit_msg.py` already allows subjects that start with "Merge" plus a space.
- Content model, OAuth key upload, ingest endpoint, ingest timing (T09, T10). T07 only proves the
  private path is not served.
- Test and Live environments, multidev, custom domains (not available or not needed on Sandbox).
- `MERIDIAN_DRUPAL_BASE_URL` and Vercel variables pointing at Pantheon (T28); sending the
  interstitial bypass header from the engine or Next.js (T10, T21, if KD-12 shows it is needed).
- Any live-trading or broker work (ADR-0006).

## Steps

1. Owner approves this plan (Status stays Draft until then).
2. Write `scripts/deploy-drupal.sh` stages 1 and 2 with `--dry-run` and the ancestor guard; add
   `scripts/tests/test_deploy_drupal.py` for TH-1 and TH-2. Commit.
3. Add stages 3 to 9 behind the stub harness (TH-3 to TH-5). Commit.
4. Add `.ddev/commands/web/deploy-drupal`, `.ddev/config.yaml` `web_environment`,
   `.ddev/providers/pantheon.yaml`, `.env.example` and the TH-4 test. Commit.
5. Add `.github/workflows/deploy-drupal.yml`, TH-9; run yamllint and actionlint. Commit.
6. Draft `docs/runbooks/deploy.md`; update `scripts/README.md`, `.github/README.md`,
   `docs/runbooks/README.md`, `docs/runbooks/local-setup.md` (link to pull), `openapi.yaml`, the
   `settings.php` comment. Commit.
7. `/review-task` on the offline part, so no unreviewed code touches Pantheon.
8. Owner O-1 to O-3. Part B discovery; commit `scripts/pantheon_known_hosts` with the day-1
   fingerprint.
9. Owner O-4 (first push); wait for the build; KD-7 checks; KD-6 reinstall; KD-5 checks.
10. Phase 2 deploy, idempotent re-run, negative tests; `ddev pull pantheon`; KD-12; TH-8; day-2
    key fetch.
11. Apply the follow-ups, each with the T07 result, source and date:
    - **D7:** `TERMINUS_MACHINE_TOKEN` row meaning "Pantheon personal access token (PAT, formerly
      machine token; expires 90 days after creation). CI: the machine user's PAT";
      `PANTHEON_SITE` DDEV column (KD-4); the paragraph under the matrix: replace the
      machine-user "unverified" sentence with the O-5 result and the local-only rule text from
      `decision-ci-credentials.md`.
    - **D8:** step 2 (`git subtree split` without `-b`), a "database backup" step before the push,
      step 3 host key text (from `decision-host-keys.md`), the rollback paragraph (from
      `decision-rollback.md`), the upstream paragraph after "First push" (from
      `decision-upstream.md`), the interstitial result and bypass-header rule, and the T07 rows
      of the ADR-0004 verification table.
    - **NFR numbers:** NFR-04 Pantheon dev row ("T07 records wake time, warm GET latency and the
      edge body limit; T10 measures the 100-item warm ingest on Pantheon dev (p95 over 5 runs);
      T28 confirms"); ingest body size row with the KD-12 result or "unverified" with the reason.
    - **Unverified register:** close the T07 row items with results; add and close "Sandbox
      interstitial and API requests".
    - **ADR-0004:** the dated follow-up note from `decision-ci-credentials.md` (no new ADR).
    - `docs/runbooks/deploy.md` "Last verified". Commit.
12. `/test-task`, then merge with a merge commit; O-5 to O-7 per SA-1 and SA-7.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| `scripts/deploy-drupal.sh` | New: the deploy implementation (KD-1) | `ddev deploy-drupal`, `deploy-drupal.yml`, owner, T10, T28 |
| `scripts/pantheon_known_hosts` | New: pinned code server host key with fingerprint comments (KD-2) | deploy script |
| `scripts/tests/test_deploy_drupal.py` | New: offline tests with stubs, workflow static test | `scripts/quality.sh`, T08 CI |
| `.ddev/commands/web/deploy-drupal` | New DDEV command | owner, tester |
| `.ddev/providers/pantheon.yaml` | New provider without push commands (KD-3) | `ddev pull pantheon` |
| `.ddev/config.yaml` | `web_environment: PANTHEON_SITE=meridian-trade` (KD-4) | provider, deploy command |
| `.github/workflows/deploy-drupal.yml` | New workflow with skip guard (KD-8) | GitHub Actions; T08; T28 |
| `.env.example` | `PANTHEON_SITE=meridian-trade`; PAT wording | C6 |
| `apps/drupal/web/sites/default/settings.php` | Comment only at step 4 (KD-5) | Drupal on DDEV and Pantheon |
| Pantheon `meridian-trade` dev | History replaced once (O-4); database reinstalled (KD-6) | T10, T28 |
| `docs/runbooks/deploy.md` | New runbook | owner, T10, T28, T29, T31 |
| `docs/architecture/technical-design.md` | D7, D8, NFR numbers, unverified register (step 11) | all later tasks |
| `docs/architecture/openapi.yaml` | Server variable default `meridian-trade` | T10, T11 |
| `docs/adr/ADR-0004-monorepo-subtree-deploy-pantheon.md` | Dated follow-up note only | readers of ADR-0004 |
| `docs/TRACEABILITY.md`, `docs/PROGRESS.md` | R-11 and FR-27 evidence; T07 status (close wording above) | close step |
| `scripts/README.md`, `.github/README.md`, `docs/runbooks/README.md`, `docs/runbooks/local-setup.md` | Rows and links for the new script, workflow and runbook | readers |

## Unverified items and their T07 checks

Each result goes into the technical design (step 11) with the value, how it was checked, the
source (redacted command output in `docs/tests/T07/evidence/` or a Pantheon doc URL) and the date.

| Item | T07 check |
|---|---|
| Integrated Composer builds our split with only `pantheon.yml`; how to wait | First build log after O-4 and the phase 2 build; `workflow:wait --commit` returns after the build; drush bootstraps; `settings.pantheon.php` exists |
| `workflow:wait` exit code on a failed build | Developer checks the source of 3.6.2 or the API response; if 0, stage 6 checks `workflow:info:status` |
| `env:code-log` newest `hash` equals the split SHA right after the wait | Phase 2 deploy |
| `web_docroot: true` honoured without `pantheon.upstream.yml` | Smoke check serves `/user/login` |
| Dev branch name (`master` assumed) | `git ls-remote <git_url>` before O-4 |
| Private files path and not served | KD-12 probe |
| Edge request body limit (8 MB needed) | KD-12 POST test, plus a doc page if any |
| Sandbox interstitial: which requests it intercepts; `Deterrence-Bypass` value | KD-12 interstitial checks |
| Terminus commands for wake, wait, `connection:info`, `code-log` | Phase 2 deploy log; `terminus --version` |
| Terminus 3.6.2 puts `ssh_command` before its own options | Developer reads the 3.6.2 tag of `SSHBaseCommand.php`; TH-6 static part |
| Code server host key stable | `ssh-keyscan` on two days and from a second network; fingerprints recorded |
| App server key change after a migration | Not forced; record any change seen with the date |
| Pantheon publishes host keys | Docs search at review; record "none found" with the date |
| Machine user can be added to a Sandbox site; its role; it can push and run drush | O-5 attempt and `site:team:list`; phase 3 run or one local run with the bot credentials |
| No terms-of-service clause against an automation account | Owner reads the account and acceptable-use sections (O-5) |
| `site:install --existing-config` works on Pantheon without writing `settings.php` | KD-6 first run |
| `backup:create` exit code on failure; backup and restore time; Sandbox backup limits | Stub test and one real run; TH-8 timings; record "none observed" with the date |
| `--element=db` restore leaves code untouched | TH-8 |
| Dashboard upstream-updates notice harmless if ignored | Observe once after O-4 |
| Wake time and warm GET latency | KD-12 |

## Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | T05 is not signed off (TC-T05-39 and 40 open), and T07 builds on its layout | Low | Medium | Owner accepted the risk (2026-11-02). Those cases test the runbook and a Windows browser login, not the files T07 deploys. If they fail with a layout change, re-run the T07 dry-run tests and redeploy |
| R2 | The force push (O-4) or the wipe (KD-6) destroys the existing Pantheon dev site | Certain (by design) | Low | Owner-approved; database backup first; the existing site has no project data |
| R3 | A rogue app server fakes drush output (app server not pinned, SA-4) | Low | Low | Drush channel carries no secret; `env:code-log` over HTTPS and the TLS smoke check with a body marker |
| R4 | The code server host key changes and deploys fail | Low | Medium | Fail closed; two-network re-fetch and reviewed PR (KD-2); repeated change raised at review |
| R5 | `workflow:wait` or `backup:create` returns 0 on failure | Medium | Medium | Stage 6 checks the workflow status and `env:code-log`; backup exit code checked by stub and real run |
| R6 | Account-wide credentials sit in GitHub Secrets | Low (by decision) | High | Machine user, or local-only deploys; owner credentials in CI only with written owner acceptance (SA-1) |
| R7 | PAT or admin password leaks into logs or evidence | Low | High | No `set -x`; redaction rule (KD-6, KD-10); TH-5; tester greps evidence for the PAT prefix; gitleaks on the branch |
| R8 | A PAT expires (90 days) and deploys or pulls fail, possibly during T31 | High over time | Medium | Runbook PAT table with expiry dates; rotation step; rotate before T31 (KD-10). The daily run does not use Terminus |
| R9 | Sandbox freeze (no Git activity for 3 months) stops the dev site during T31 | Low with the check | High | Runbook pre-T31 check: last Git activity on Pantheon under 60 days, or deploy a reviewed change before the window |
| R10 | The Sandbox interstitial intercepts API requests (JSON:API, OAuth, ingest) | Unknown | High for T10, T21, T22 | KD-12 finds out; smoke check uses a body marker; item raised for T10 and T21 if intercepted |
| R11 | A squash or rebase merge of a deployed branch breaks the next non-force push | Low | Medium | Ancestor guard and `--allow-unmerged` warning (KD-1); merge commits only (standards; T08 input) |
| R12 | The Integrated Composer build fails on a scaffold or plugin rule in our split | Low | Medium | Read the first build log (KD-7); fix in `composer.json` only with a review note. Installing `require-dev` on Dev is documented behaviour, not a risk |
| R13 | Someone applies a dashboard upstream update or uses the dashboard Restore | Low | Medium | Runbook warnings (KD-7, KD-9); the next deploy fails loudly; recovery by emergency force push |
| R14 | The deploy workflow fails on merge to `main` before secrets exist | High without guard | Low | KD-8 skip guard on `vars.PANTHEON_SITE`; TH-9 |
| R15 | A future FR-11 denylist that matches the word "trade" flags the site name `meridian-trade` and its URL | Medium | Low | Note for T18: the broker check matches broker names and domains, not generic words; `pantheonsite.io` is allowed |
| R16 | `ddev pull pantheon` overwrites the local database | Certain (by design) | Low | Runbook: `ddev snapshot` first; after the KD-6 reinstall both sides have the `config/sync` UUID |

## Test hooks needed

- **TH-1** `--dry-run` on a fixture repo: prints a split SHA; the tree of the split equals the tree
  of `REF:apps/drupal`; two runs give the same SHA; no branch or ref is created
  (`git for-each-ref` unchanged).
- **TH-2** Guards: a fixture commit that adds `apps/drupal/vendor/x` or `apps/drupal/.env` exits 1
  before any network step; a `--ref` not reachable from `origin/main` exits 2 without
  `--allow-unmerged` and continues with a warning with it; a missing `origin/main` exits 2.
- **TH-3** Stub `terminus` on `PATH` (logs its arguments, returns a local bare repo as `git_url`,
  scripted `backup:create`, `workflow:wait`, `env:code-log` and `config:status` results) and
  stub `curl`. Cases: first deploy to an empty bare repo; idempotent re-run (no backup, no push,
  no wait); rewind push rejected with exit 1 and the runbook pointer; failed backup exits 1 with
  no push; `env:code-log` showing another SHA exits 1; `config:status` with differences exits 1;
  smoke 200 without the marker (interstitial body) exits 1; `backup:create` called with
  `--element=db --keep-for=30`.
- **TH-4** Consistency: `PANTHEON_SITE` in `.ddev/config.yaml` equals the one in `.env.example`; the
  provider has no `push` command and no `set -x`; the script and workflow contain no `--force`,
  `+` refspec or `set -x`; `TERMINUS_SSH_COMMAND` is exactly the SA-4 value and the script never
  sets `TERMINUS_ALTERNATE_NAMESERVER`.
- **TH-5** Secret hygiene: with `TERMINUS_MACHINE_TOKEN=fake-token-...` the stub receives it, and
  the script's stdout and stderr do not contain it.
- **TH-6** Live negative pinning test (part B): `git push` with a copy of `pantheon_known_hosts`
  that holds a wrong code server key fails with a host key error. Drush is covered by TH-4.
- **TH-7** Live checks: KD-5 sync path and UUID, KD-7 build facts, AC5 `config:status` on both
  sides, AC3 pull from a fresh shell (local UUID equals `config/sync`, a pulled file exists under
  `sites/default/files`), KD-12 measurements.
- **TH-8** Restore test (SA-2 decision 7): backup `--element=db`, change one config value with drush,
  restore with `--element=db --file=<name>`, check the value is back and that `env:code-log` and
  `git ls-remote` of `master` are unchanged; record backup and restore times.
- **TH-9** Workflow static test: the deploy job's `if:` checks `vars.PANTHEON_SITE`; the skip step
  prints the "not configured, skipped" line; the run step calls `scripts/deploy-drupal.sh`; secrets
  and variables arrive only through `env:`; `concurrency` and `permissions: contents: read` are
  set; actions are pinned by SHA; no `--allow-unmerged`.
- Evidence folder `docs/tests/T07/evidence/` holds redacted command output only.

## Decisions needed from solution-architect

All answered on 2026-11-02; none open.

| ID | Question | Answer | File |
|---|---|---|---|
| SA-1 | Machine user vs owner credentials in CI | Machine user owns its own PAT and RSA key, member of `meridian-trade` only; if Sandbox cannot add it, local-only deploys; owner credentials in CI only with written owner acceptance. Tokens are now 90-day PATs | [`decision-ci-credentials.md`](decision-ci-credentials.md) |
| SA-2 | Rollback and pre-deploy backups | Revert-forward via merge commit; database-only restore; forbidden restores listed; force push owner-only emergency to a commit on `main`; backup `--element=db --keep-for=30` on every pushing deploy; ancestor guard; one restore test | [`decision-rollback.md`](decision-rollback.md) |
| SA-3 | Pantheon upstream | Keep Composer Managed; never apply upstream updates | [`decision-upstream.md`](decision-upstream.md) |
| SA-4 | Host key fallback | Pin the code server only; app server not pinned; `env:code-log` and TLS smoke check verify | [`decision-host-keys.md`](decision-host-keys.md) |
| SA-5 | AC3 wording | KD-11 reading accepted; wording change proposed to the owner | [`decision-scope.md`](decision-scope.md) |
| SA-6 | NFR-04 on Pantheon | T07 records wake, warm GET and body limit; 100-item ingest to T10, confirmed in T28; interstitial checks added | [`decision-scope.md`](decision-scope.md) |
| SA-7 | When AC4 counts as met | Local real deploy plus static workflow checks; CI run `Blocked (accepted, owner-run after O-6)` with written owner acceptance | [`decision-scope.md`](decision-scope.md) |

## Owner decisions

Agent messages are not owner decisions; each of these needs the owner's own message.

1. Approve this plan.
2. Apply, or not, the proposed `docs/TASKS.md` wording for AC2, AC3 and AC4 (AC table above).
3. At O-5: create the machine user (recommended), or stay local-only. Optionally, a written risk
   acceptance for owner credentials in CI (KD-10 conditions).
4. At T07 close: accept in writing that the CI deploy run is a deferred case (SA-7).

## Definition of done

- [ ] All task acceptance criteria in `docs/TASKS.md` met (AC2, AC3, AC4 by the readings above)
- [ ] C1: Plan exists and was reviewed before coding started
- [ ] C2: Code reviewed; findings resolved
- [ ] C3: Every criterion maps to an executed test case with evidence (redacted); the CI run case
      is `Blocked (accepted, owner-run after O-6)` with written owner acceptance
- [ ] C4: CI green, no new lint, type or security warnings. CI (`ci.yml`) does not exist until T08:
      recorded reason; the substitute is `ddev quality` and `.tools/pre-commit run --all-files`
      exit 0 (shellcheck, yamllint, check-yaml, gitleaks, check-names), plus a pinned actionlint
      run on the workflow
- [ ] C5: Docs and traceability updated (runbook, D7, D8, NFR numbers, unverified register,
      ADR-0004 note, R-11 and FR-27 rows, READMEs)
- [ ] C6: No secrets; `.env.example` updated (`PANTHEON_SITE=meridian-trade`, PAT wording);
      gitleaks passes on the branch and on the split history pushed to Pantheon
- [ ] C7: Works from a clean checkout with documented commands: `ddev deploy-drupal --dry-run` and
      `ddev pull pantheon` from a fresh clone, following only `docs/runbooks/deploy.md`
- [ ] Simulation-only: no broker SDK, client or domain added; only Pantheon and GitHub hosts

## Addendum 2026-11-02 (technical-architect, from the review)

Recorded by `docs/tasks/T07/review.md`. These change the approved plan as stated; nothing else
changes.

1. **Terminus 4.3.3, not 3.6.2** (owner requirement after Terminus 3.6.2 failed to log in with a
   PAT). KD-8 and the "Facts" section now read 4.3.3. It is pinned by SHA-256 in
   `.ddev/web-build/Dockerfile` and in `deploy-drupal.yml`. The SA-4 `ssh_command` placement
   and the `workflow:wait` exit behaviour are re-checked against 4.3.3 (review finding 10).
2. **Stage 6 status check.** The `workflow:info:status` check is dropped, because 4.3.3
   `workflow:wait` exits non-zero on a failed workflow. A timeout exits 0 with "giving up", and
   the script treats that as a failure. Both behaviours are verified live (review, live items).
3. **Stage 4 re-run (changed by review finding 1).** When `master` is already at the split SHA,
   the script still skips the backup and the push. It must not skip build verification: before
   stage 7 it confirms that the Pantheon workflow for that commit finished successfully, or it
   exits 1. Stages 7 to 9 follow as before.
4. **Exit codes.** A missing code server key line in `scripts/pantheon_known_hosts` is a guard
   error and exits 2. The split-tree guard exits 1, as TH-2 says.
5. **Optional variables** `DEPLOY_SMOKE_BUDGET` and `DEPLOY_SMOKE_HEADER` replace the KD-1
   "constant in the script" for the bypass header. After KD-12 the header is either fixed in
   the script or set in `.ddev/config.yaml` and the workflow (review finding 8).
6. **Workflow shape.** KD-8 uses separate `skip` and `deploy` jobs, each with a job-level `if:`
   on `vars.PANTHEON_SITE`, instead of one job with a skip step. The observable result is the
   same: a green run that prints the "not configured" line.
