# T07: Pantheon dev environment and deployment path, Test cases

| Field | Value |
|---|---|
| Task | T07 |
| Author | tester |
| Date | 2026-11-02 |
| Criteria source | `docs/TASKS.md` T07 (wording updated by the owner 2026-11-02), `docs/tasks/T07/plan.md` (Rev 2, Approved) and `docs/tasks/T07/decision-*.md` |
| Automation | `docs/tests/T07/run-checks.sh` (modes below). Design-time run: `docs/tests/T07/evidence/design-time-run.txt` |
| Base for snapshot checks | `1200ad0` (T07 branch point) |

## How to run

| Command | Covers |
|---|---|
| `docs/tests/T07/run-checks.sh` | Static and offline-harness cases 01 to 28 and 58 to 62. No network, no DDEV, no credentials. Live and owner-run cases are listed as BLOCKED with the reason |
| `docs/tests/T07/run-checks.sh --regression` | Invariant checks only (`ckp`); the `cka` snapshot checks (TC-T07-23 diff, TC-T07-27) are skipped and counted |
| `T07_OWNER_OK=1 T07_O4_DONE=1 docs/tests/T07/run-checks.sh --live` | Static cases, then live cases 30 to 49 against Pantheon `meridian-trade` |
| `T07_CONFIRM_WIPE=1`, `T07_CONFIRM_RESTORE=1`, `T07_CONFIRM_PULL=1` | Extra confirm variable for the destructive live cases 39, 48 and 42 |
| `T07_CONFIRM=1 docs/tests/T07/run-checks.sh --clean-clone` | Case 55 |
| `T07_CLOSE=1` | Enables the three at-close checks of TC-T07-27 (otherwise Blocked until `/close-task`) |
| `T07_EVIDENCE=1` | Writes `evidence/TC-T07-nn.<UTC run id>.txt` per case (redacted) |

Rules that apply to every case:

- Live cases check a gate first and report Blocked (not Fail) when it is not met: `T07_OWNER_OK=1`
  means the owner said in their own message (plan O-3) that the PAT and key are in place and that
  agents may use them; the PAT in the web container, an RSA/ECDSA key in the ddev ssh agent and a
  working `terminus auth:login` are checked without printing any value.
- Nothing prints or stores `env`, `printenv` or `ddev exec env`. The runner redacts passwords,
  token assignments and Authorization values from every line before it is shown or stored.
- The one-time force push (plan O-4) is an owner action, never a test step. Cases verify its
  result (TC-T07-49) and need `T07_O4_DONE=1`.
- Wipe and reinstall of Pantheon dev is owner-approved for T07 testing (owner facts 2026-11-02);
  it still needs the explicit confirm variable, so an accidental run cannot wipe.
- Live steps were written from the plan and Terminus 3.6.2 help (updated for 4.3.3 on 2026-11-02,
  see the Change log) and could not run at design time. If a Terminus JSON field name differs from
  the assumed one (`backup:list` `file`/`date`, `env:code-log` `hash`), correct the script and log
  it in the change log; do not change the expected result.
- TC-T07-29 is unused (reserved gap); numbering keeps the script and this file aligned.
- Tags: `ckp` invariant, runs in every static mode; `cka` snapshot true only at close, skipped by
  `--regression`; `n/a` for live and owner-run cases (never part of a regression pass).

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: Pantheon sandbox site created from the Composer-managed Drupal upstream; `pantheon.yml` committed | TC-T07-01, 30 |
| AC2: Terminus PAT setup and 90-day rotation documented; token never committed (secret scan passes) | TC-T07-02, 03, 19, 28, 53, 56 |
| AC3: Terminus authentication for DDEV set up (PAT in global DDEV config; `ddev auth ssh`) and `ddev pull pantheon` pulls database and files (tested) | TC-T07-04, 05, 42, 43, 55, 58, 59 |
| AC4: Code in `apps/drupal` deploys to Pantheon dev by the decided mechanism; site loads on its dev URL | TC-T07-05 to 19, 31 to 35, 38, 40, 41, 49, 58, 60 to 62; CI run: TC-T07-50 (Blocked, accepted), 51, 52 |
| AC5: Config imported on Pantheon dev matches local (`drush config:status` clean) | TC-T07-23, 36, 37, 39 |
| AC6: Rollback procedure and sandbox sleep and limits documented in `docs/runbooks/deploy.md` | TC-T07-20, 21, 44 to 48, 54 |
| C1: plan exists and was reviewed before coding | Process: `docs/tasks/T07/plan.md` (Approved), `docs/tasks/T07/review.md`; checked by the tester at execution (no automated case) |
| C2: code reviewed, findings resolved | Process: `docs/tasks/T07/review.md`; checked at execution |
| C3: every criterion maps to an executed case with evidence | This table; TC-T07-28 (evidence hygiene); the test report |
| C4: CI green, no new warnings (stand-in until T08) | TC-T07-10, 24, 58 |
| C5: docs and traceability updated | TC-T07-22, 23, 26, 27 |
| C6: no secrets; `.env.example` updated; gitleaks passes | TC-T07-03, 19, 25, 28 |
| C7: works from a clean checkout with documented commands | TC-T07-55, 57 |
| SIM: simulation only, no broker domain or SDK | TC-T07-06, 25 |

Reading notes recorded for the report:

- AC3 uses the owner's updated wording. `ddev auth pantheon` does not exist in DDEV v1.24.4 (plan
  KD-11, SA-5); TC-T07-42 passes only if `ddev pull pantheon` runs from a fresh shell with no
  manual `terminus auth:login`.
- AC4 is met by TC-T07-11 to 19 (phase 1) and TC-T07-32 and 33 (phase 2, real local deploy).
  TC-T07-50 is `Blocked (accepted, owner-run after O-6)` and needs the owner's written acceptance
  at close (SA-7). C4 stand-in: `ddev quality`, pre-commit, pinned actionlint (TC-T07-10, 24).

## Cases

### TC-T07-01: pantheon.yml committed with the build settings

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-7, SA-3 |
| Mode | static |
| Tag | ckp |
| Preconditions | Branch checked out; implementation present |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}`<br>2. `git ls-files --error-unmatch apps/drupal/pantheon.yml` |
| Expected result | pantheon.yml is tracked and holds `build_step: true`, `web_docroot: true`, PHP 8.3, MariaDB 10.6, api_version 1; the split tree has no `pantheon.upstream.yml`, no `upstream-configuration` path and no `.gitignore`; the runbook names the upstream "Drupal (Composer Managed)" and site `meridian-trade`. |
| Actual result | |
| Evidence | `evidence/TC-T07-01.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-02: PAT setup, 90-day rotation and expiry table documented

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Plan item | KD-10, SA-1 |
| Mode | static |
| Tag | ckp |
| Preconditions | `docs/runbooks/deploy.md` exists |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | Runbook covers: PAT (formerly machine token) and 90 days; where to create it and not in Microsoft Edge; `ddev config global --web-environment-add=TERMINUS_MACHINE_TOKEN` and `ddev restart`; rotation steps (create new, replace everywhere, `terminus auth:whoami`, revoke old); a table with owner, purpose, store, creation date, expiry date and no value; the T31 rule (rotate any PAT expiring within window plus 7 days); an expired PAT breaks deploys and pulls, not the daily run; RSA key only; never paste in chat or repo; evidence never includes `env` or `printenv`. `docs/TASKS.md` carries the PAT wording. |
| Actual result | |
| Evidence | `evidence/TC-T07-02.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-03: No secrets in T07 files; placeholders only; no set -x

| Field | Value |
|---|---|
| Linked criterion | AC2, C6 |
| Plan item | KD-4, KD-10, R7 |
| Mode | static |
| Tag | ckp |
| Preconditions | Implementation files exist |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}`<br>2. `.tools/pre-commit run --files <T07 files>` (see TC-T07-24) |
| Expected result | No key, token or credential pattern in any T07 file; `.env.example` has empty `TERMINUS_MACHINE_TOKEN=` and `PANTHEON_DEPLOY_KEY=`, `PANTHEON_SITE=meridian-trade` and the PAT wording; no token value in config, workflow, provider or wrapper; no private key block or `.pem`/`.key` file tracked; no `set -x` in script, wrapper, provider or workflow; gitleaks passes where installed. |
| Actual result | |
| Evidence | `evidence/TC-T07-03.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-04: DDEV Pantheon provider is pull-only and takes a fresh backup

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Plan item | KD-3, KD-11, R16 |
| Mode | static |
| Tag | ckp |
| Preconditions | `.ddev/providers/pantheon.yaml` exists |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | No `#ddev-generated` line; keys `auth_command`, `db_pull_command`, `files_pull_command` present and no key containing `push`; no `backup:restore`, `env:wipe`, `--force`; each pull runs `backup:create ... --element=db\|files --keep-for=30` before `backup:get`; uses `${PANTHEON_SITE:?}`; auth text says personal access token (PAT); no `set -x`. |
| Actual result | |
| Evidence | `evidence/TC-T07-04.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-05: PANTHEON_SITE is meridian-trade in every place

| Field | Value |
|---|---|
| Linked criterion | AC3, AC4 |
| Plan item | KD-4, TH-4 |
| Mode | static |
| Tag | ckp |
| Preconditions | Implementation files exist |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | `.ddev/config.yaml` `web_environment` holds `PANTHEON_SITE=meridian-trade` and no token; `.env.example` has the same value; `openapi.yaml` server variable `site` defaults to `meridian-trade`; technical-design D7 PANTHEON_SITE DDEV column says `.ddev/config.yaml` `web_environment` and the TERMINUS_MACHINE_TOKEN row says PAT and 90 days. |
| Actual result | |
| Evidence | `evidence/TC-T07-05.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-06: deploy-drupal.sh exists and is safe by construction

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-1, SA-2, SA-4 |
| Mode | static |
| Tag | ckp |
| Preconditions | `scripts/deploy-drupal.sh` exists |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}`<br>2. `bash -n scripts/deploy-drupal.sh` |
| Expected result | Executable bash script, syntax valid, shellcheck clean where installed; never force pushes (no `--force`, `-f`, `+` refspec); `git subtree split --prefix=apps/drupal` without `-b`; uses `:refs/heads/master`, `--element=db`, `--keep-for=30`, `workflow:wait --commit`, `env:code-log`, `remote:drush` with updatedb, config:import, cache:rebuild, config:status; options `--ref`, `--dry-run`, `--allow-unmerged`, `-h`; no printenv or echo of the token; smoke check over https with no `-k`/`--insecure` and the marker `user-login-form`; no broker host or call; only Pantheon and GitHub hosts. |
| Actual result | |
| Evidence | `evidence/TC-T07-06.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-07: SSH host key pinning statics and TERMINUS_SSH_COMMAND

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-2, SA-4 |
| Mode | static |
| Tag | ckp |
| Preconditions | Script and `scripts/pantheon_known_hosts` exist |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | `GIT_SSH_COMMAND` has StrictHostKeyChecking=yes, `GlobalKnownHostsFile=/dev/null`, UserKnownHostsFile pointing at `scripts/pantheon_known_hosts`, BatchMode=yes; `TERMINUS_SSH_COMMAND` is exactly `ssh -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR`; `TERMINUS_ALTERNATE_NAMESERVER` is never set; the known-hosts file holds only `[codeserver.dev.<uuid>.drush.in]:2222` key lines, with comments giving SHA256 fingerprint, date, ssh-keyscan, the statement that the app server is deliberately not pinned, and a link to `decision-host-keys.md`; no app server entry and no private key. The three known-hosts-file checks are Blocked ("awaiting L-3") while the file holds no key line; they run once the developer commits the key after the two-day, two-network comparison. |
| Actual result | |
| Evidence | `evidence/TC-T07-07.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-08: ddev deploy-drupal wrapper

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-1 |
| Mode | static |
| Tag | ckp |
| Preconditions | `.ddev/commands/web/deploy-drupal` exists |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | Executable, bash -n valid, DDEV command header, calls `scripts/deploy-drupal.sh` and passes `"$@"`; no `set -x`, `--force`, printenv or token echo; listed in `.ddev/README.md`. |
| Actual result | |
| Evidence | `evidence/TC-T07-08.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-09: deploy-drupal.yml is a thin, guarded, pinned wrapper

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-8, TH-9, SA-7 |
| Mode | static |
| Tag | ckp |
| Preconditions | `.github/workflows/deploy-drupal.yml` exists |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | Parses as YAML; triggers: push to main with the three paths, workflow_dispatch input `ref` default `main`; `concurrency` group `deploy-drupal`, cancel-in-progress false; `permissions: contents: read`; `timeout-minutes: 30`; an `if:` on `vars.PANTHEON_SITE` and a skip step printing `deploy-drupal: not configured (PANTHEON_SITE unset), skipped`; the deploy step runs `scripts/deploy-drupal.sh --ref "$DEPLOY_REF"` with `DEPLOY_REF: ${{ inputs.ref \|\| github.sha }}`, `DEPLOY_SMOKE_BUDGET` and `DEPLOY_SMOKE_HEADER` (`vars.*`) in its `env:`; no `${{` expression of any kind inside a `run:` block; `secrets.*` only in `env:`; every `uses:` pinned by 40-hex SHA and only `actions/*`; `TERMINUS_VERSION: 4.3.3` with SHA-256 `e7ca9bca...bade` verified with `sha256sum --check --strict` (no 3.6.2); `ssh-add -` from stdin; `fetch-depth: 0`; no `--allow-unmerged`, `--force`, `set -x`. |
| Actual result | |
| Evidence | `evidence/TC-T07-09.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-10: Pinned actionlint, yamllint, check-yaml on the workflow

| Field | Value |
|---|---|
| Linked criterion | AC4, C4 |
| Plan item | KD-8, C4 stand-in |
| Mode | static |
| Tag | ckp |
| Preconditions | actionlint installed at the pinned version (Blocked, not Pass, if absent) |
| Steps | 1. `actionlint -version`<br>2. `actionlint .github/workflows/deploy-drupal.yml`<br>3. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | actionlint exits 0 and its version is the one written down in the repo; yamllint clean (also via pre-commit in TC-T07-24). The runner uses `.tools/actionlint` (the repo-documented binary) before `actionlint` on PATH. Missing actionlint is Blocked, never Pass. |
| Actual result | |
| Evidence | `evidence/TC-T07-10.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-11: Harness: --dry-run on a fixture repository

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | TH-1, KD-1 stage 1-2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Fixture repo built by the script; fake terminus, curl, git observers on PATH |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | `--dry-run` exits 0 and prints a 40-hex split SHA whose tree equals `REF:apps/drupal`, it is not HEAD; two runs give the same SHA; `git for-each-ref` is unchanged (no branch or ref created); no terminus, curl, push, ls-remote or fetch call; the output names the target site. |
| Actual result | |
| Evidence | `evidence/TC-T07-11.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-12: Harness: split-tree guard stops before any network step

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | TH-2, KD-7, KD-1 stage 2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | As TC-T07-11 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | For each of `vendor/x`, `web/core/x`, `web/modules/contrib/...`, `web/sites/default/files/x.txt`, `private/x`, `.env`, `*.key`, `*.pem`, `settings.local.php` committed under `apps/drupal` (and pushed to the fixture origin/main): exit 1 (2 tolerated, see Ambiguities A1), no terminus/curl/push call, nothing on the Pantheon bare repo. For each of `composer.json`, `composer.lock`, `pantheon.yml`, `config/sync/system.site.yml` removed: non-zero exit with the same guarantees. |
| Actual result | |
| Evidence | `evidence/TC-T07-12.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-13: Harness: ancestor guard, --allow-unmerged, usage errors

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | SA-2 decision 6, KD-1 stage 1 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | As TC-T07-11 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | A ref not reachable from origin/main exits 2 and calls nothing; with `--allow-unmerged` it exits 0 and prints a warning that mentions merge commit and squash/rebase; missing `origin/main` exits 2 with `git fetch origin`; unknown option, unresolvable ref and empty `PANTHEON_SITE` exit 2; no token and no session exits non-zero without a push; `-h` exits 0 and lists the options and env names. |
| Actual result | |
| Evidence | `evidence/TC-T07-13.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-14: Harness: first deploy runs every stage in order without force

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | TH-3, KD-1, SA-2 decision 5 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | As TC-T07-11, empty bare repo as Pantheon |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | Exit 0; the pushed tree equals `HEAD:apps/drupal`; exactly one `git push` of `<sha>:refs/heads/master` with no force flag or `+`; order: connection:info, backup:create `--element=db --keep-for=30` on `meridian-trade.dev`, env:wake, push, `workflow:wait --commit=<sha>`, `env:code-log --format=json`, updatedb, `config:import -y`, cache:rebuild, config:status; smoke URL `https://dev-meridian-trade.pantheonsite.io/user/login` without `-k`/`--insecure`; the last output line holds the split SHA. |
| Actual result | |
| Evidence | `evidence/TC-T07-14.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-15: Harness: idempotent re-run

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | TH-3, KD-1 stage 4 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | As TC-T07-14 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | Second run exits 0; no `backup:create`, no `git push`; `workflow:wait --commit=<sha> --start=1` and `env:code-log` still run and the output holds "completed successfully for commit"; drush stages and smoke check run; Pantheon master unchanged; split SHA is the last line. Negative re-runs (build failed, `workflow:wait` gives up, no matching workflow): exit 1, no drush, no smoke check, no backup, no push, no "deployed", master unchanged. |
| Actual result | |
| Evidence | `evidence/TC-T07-15.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-16: Harness: a rewind push is rejected and never forced

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | TH-3, SA-2, KD-9 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | As TC-T07-14; bare repo has denyNonFastForwards |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | After deploying a newer commit, deploying an older ancestor of origin/main exits 1; master unchanged; output points to `Roll back code` and `Emergency force push` in `docs/runbooks/deploy.md`; no forced push attempted; no later stage ran. |
| Actual result | |
| Evidence | `evidence/TC-T07-16.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-17: Harness: failed backup stops the deploy before the push

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | SA-2 decision 5, R5 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | As TC-T07-11 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | With `backup:create` exiting 1 the script exits 1, makes no `git push`, nothing arrives on Pantheon. |
| Actual result | |
| Evidence | `evidence/TC-T07-17.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-18: Harness: verification failures exit 1

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | TH-3, SA-4, R5 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | As TC-T07-11. The two smoke-check cases may take up to the 120 s retry budget each |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | `env:code-log` with another newest hash: exit 1, no drush stage. `workflow:wait` failing: exit 1, no drush stage. `workflow:wait` giving up ("giving up waiting", exit 0) or finding no workflow ("not found after 10 attempts", exit 0), so no success notice: exit 1, no drush stage, no "deployed". The fake `workflow:wait` prints `Workflow w1 completed successfully for commit <sha>` on success (Terminus 4.3.3 facts b and c). `config:status` with differences: exit 1, no smoke check. Smoke check with HTTP 200 and an interstitial body (no `user-login-form`): exit 1. Smoke check with HTTP 503: exit 1. |
| Actual result | |
| Evidence | `evidence/TC-T07-18.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-19: Harness: PAT stays out of output; SSH env reaches terminus

| Field | Value |
|---|---|
| Linked criterion | AC2, C6 |
| Plan item | TH-4, TH-5, SA-4 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | As TC-T07-11 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | A fake PAT is received by terminus (as argument or env) and `auth:login` is called, but the script's stdout and stderr never contain it; without a token the script calls `auth:whoami` and no `auth:login`; every terminus call sees `TERMINUS_SSH_COMMAND` exactly as decided and `TERMINUS_ALTERNATE_NAMESERVER` unset. |
| Actual result | |
| Evidence | `evidence/TC-T07-19.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-20: Runbook: owner steps, deploy, rollback, forbidden actions, force push

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Plan item | KD-9, KD-6, KD-7, SA-2, SA-3 |
| Mode | static |
| Tag | ckp |
| Preconditions | `docs/runbooks/deploy.md` exists |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | Template headings (Steps, Verification, Rollback); sections First push, Reinstall Pantheon dev, Pull with `ddev snapshot` first, Roll back code, Restore the database, Emergency force push, Troubleshooting, event log; revert-forward via `git revert` and merge commit (no squash, no rebase); restore with `backup:list`, `backup:restore --element=db --file=<name> --yes`, then cache:rebuild, config:status, smoke check; forbidden: dashboard Restore button, `backup:restore` without `--element`, `--element=all`, `--element=code`; emergency force push owner only, backup first, a commit on main; First push uses `ddev deploy-drupal --ref origin/main --dry-run` for the SHA and `--keep-for=30`; reinstall warns it destroys the dev database and uses `user:login` rather than pasting the password; upstream rule (never apply, by mistake use the emergency push); SFTP mode forbidden; no bare `backup:restore` step; "Last verified" with a date. |
| Actual result | |
| Evidence | `evidence/TC-T07-20.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-21: Runbook: sleep, freeze, limits, interstitial, pre-T31 check

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Plan item | KD-12, SA-6, R9, R10 |
| Mode | static |
| Tag | ckp |
| Preconditions | As TC-T07-20 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | Runbook states: idle sleep about 1 hour and the observed wake time; freeze after 4 months old plus 3 months without Git activity, `530 Site Frozen`, unfreeze from the Sites tab; two Sandbox sites, no custom domains, no automatic backups, edge 59 s and PHP 120 s; the interstitial warning page, the `Deterrence-Bypass` header and the measured result; body size and private files results (or unverified with reason); the pre-T31 check (last Git activity under 60 days or deploy before the window); a pull takes a fresh backup. |
| Actual result | |
| Evidence | `evidence/TC-T07-21.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-22: Documentation follow-ups (D7, D8, NFR, register, ADR-0004, READMEs)

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Plan item | plan step 11, Interfaces touched |
| Mode | static |
| Tag | ckp |
| Preconditions | Documentation step done |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | D8 records the code-server pin, the app-server non-pin, `env:code-log`, the interstitial rule, database backup and revert-forward rollback; the old "machine user unverified" and "pinned in the workflow's known_hosts" sentences are gone; NFR-04 Pantheon row names T10 and T28; ingest body size row has a dated result or unverified with a reason; unverified register has the T07 items closed and an interstitial item; ADR-0004 has a dated follow-up note and no new ADR exists; `scripts/README.md`, `.github/README.md`, `docs/runbooks/README.md` and `local-setup.md` link the new files; `CLAUDE.md` lists `ddev deploy-drupal` and `ddev pull pantheon`; every case id in the script has a case in this file. |
| Actual result | |
| Evidence | `evidence/TC-T07-22.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-23: settings.php: comment-only change, config_sync_directory after the Pantheon include

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Plan item | KD-5 |
| Mode | static |
| Tag | ckp (order) and cka (diff) |
| Preconditions | Implementation done |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | `$settings['config_sync_directory'] = '../config/sync';` is still set, on a line after the `settings.pantheon.php` include, with a nearby comment about the order; against the branch point the diff adds comment lines only (snapshot, skipped by `--regression`). |
| Actual result | |
| Evidence | `evidence/TC-T07-23.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-24: Hygiene: pre-commit, bash -n, earlier regression sets

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Plan item | C4 stand-in |
| Mode | static |
| Tag | ckp |
| Preconditions | `.tools/pre-commit` bootstrapped |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}`<br>2. `ddev quality` (tester attaches the output at execution) |
| Expected result | `pre-commit run --files <every T07 file>` exits 0 (shellcheck, yamllint, check-yaml, gitleaks, check-names); bash -n on script, wrapper and this test script; `T02` to `T06` `run-checks.sh --regression` all exit 0; `ddev quality` exits 0. CI (`ci.yml`) does not exist until T08: this is the recorded stand-in. |
| Actual result | |
| Evidence | `evidence/TC-T07-24.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-25: Simulation only: no broker domain, SDK or order call

| Field | Value |
|---|---|
| Linked criterion | C6, SIM |
| Plan item | ADR-0006, R15 |
| Mode | static |
| Tag | ckp |
| Preconditions | Implementation files exist |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | The broker denylist finds nothing in T07 implementation files nor in the lines T07 adds outside `docs/tests`; hosts named are only Pantheon, GitHub, ddev.site or localhost; no broker package added; nothing tells the reader to push local data to Pantheon. The word "trade" in `meridian-trade` is not a hit (the denylist matches broker names and `kite.trade`); T18 must keep it that way (note R15). |
| Actual result | |
| Evidence | `evidence/TC-T07-25.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-26: Naming

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Plan item | section 0 |
| Mode | static |
| Tag | ckp |
| Preconditions | None |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}`<br>2. `scripts/check-names.sh` |
| Expected result | check-names passes; no old placeholder name in T07 files. |
| Actual result | |
| Evidence | `evidence/TC-T07-26.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-27: Close step: TRACEABILITY and PROGRESS wording (snapshot at close)

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Plan item | SA-7 wording |
| Mode | static |
| Tag | cka |
| Preconditions | Run at close, after `/close-task` |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | R-11 and FR-27 evidence cells hold "T07: AC4 Pass by local deploy (TC-T07-nn); CI run TC-T07-nn Blocked (accepted, owner-run after O-6)" and R-11 stays Open; PROGRESS T07 notes hold "AC4 by local deploy; CI deploy run owed after O-6 (owner-accepted)"; the test report states the SA-1 branch (machine user, local-only, or owner credentials accepted with date). Skipped by `--regression`; Blocked in a normal static run until `T07_CLOSE=1` is set at `/close-task`. |
| Actual result | |
| Evidence | `evidence/TC-T07-27.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-28: Evidence hygiene: no PAT, key, password or env dump in evidence

| Field | Value |
|---|---|
| Linked criterion | C6 |
| Plan item | R7, KD-6, KD-10 |
| Mode | static |
| Tag | ckp |
| Preconditions | After execution (an empty evidence folder passes and the report says so) |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-{n}` |
| Expected result | No private key block, no `TERMINUS_MACHINE_TOKEN=<value>`, no `password: <value>`, no Authorization value and no environment dump in any file under `docs/tests/T07/evidence/`; gitleaks over `docs/tests/T07` passes where installed. The tester also greps evidence for the PAT prefix the owner states, if any. |
| Actual result | |
| Evidence | `evidence/TC-T07-28.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-30: Sandbox site exists on the Composer-managed upstream

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | Facts, KD-7 |
| Mode | live |
| Tag | n/a |
| Preconditions | Gate: `T07_OWNER_OK=1` (owner said in their own message that PAT and key are in place, plan O-3); DDEV running; PAT in web container; RSA key in the ddev ssh agent. Otherwise Blocked |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | `terminus site:info meridian-trade` succeeds; framework is `drupal-composer-managed` (or upstream label "Composer Managed"); plan is sandbox; dev connection mode is git. |
| Actual result | |
| Evidence | `evidence/TC-T07-30.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-31: Discovery: dev branch name and backup:create failure exit code

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-1 stage 5, R5, unverified list |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-30 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | `connection:info --field=git_url` returns an `ssh://codeserver.dev.<uuid>@...drush.in:2222` URL; `git ls-remote` with the pinned known-hosts file lists `refs/heads/master`; `backup:create` against a non-existent environment exits non-zero (exit code recorded). |
| Actual result | |
| Evidence | `evidence/TC-T07-31.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-32: Real deploy: ddev deploy-drupal to Pantheon dev (phase 2)

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | SA-7 phase 2, KD-1 |
| Mode | live |
| Tag | n/a |
| Preconditions | Gate as TC-T07-30 plus `T07_O4_DONE=1` (owner did the one-time force push O-4); `scripts/pantheon_known_hosts` committed |
| Steps | 1. `T07_OWNER_OK=1 T07_O4_DONE=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only` (runs `ddev deploy-drupal --ref task/T07-pantheon-dev --allow-unmerged`) |
| Expected result | Exit 0; last output line is the 40-hex split SHA; a merge-commit warning is printed; a database backup stage appears; the output holds no token, key or `machine-token` text. |
| Actual result | |
| Evidence | `evidence/TC-T07-32.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-33: Independent verification of the real deploy

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | SA-4, KD-1 stage 6 and 9 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | `terminus env:code-log --format=json` newest hash equals the split SHA; `git ls-remote` master equals it; HTTPS GET of `https://dev-meridian-trade.pantheonsite.io/user/login` with certificate verification returns `200 0` and the body holds `user-login-form`; drush `status` bootstraps. |
| Actual result | |
| Evidence | `evidence/TC-T07-33.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-34: Real idempotent re-run

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-1 stage 4, SA-2 decision 5 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | Second `ddev deploy-drupal` of the same ref exits 0; the count of database backups is unchanged; output says the push was skipped and still holds "completed successfully for commit" (the build is confirmed again with `--start=1`). |
| Actual result | |
| Evidence | `evidence/TC-T07-34.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-35: Real rewind rejected, never forced

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | SA-2, KD-9 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32; an older commit touching `apps/drupal` exists on origin/main |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | Deploying an older ancestor of origin/main fails (non-zero; DDEV reports 1), output points to `Emergency force push`; Pantheon master is unchanged. |
| Actual result | |
| Evidence | `evidence/TC-T07-35.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-36: AC5: config:status clean on Pantheon and locally; UUIDs agree

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Plan item | KD-6, TH-7 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32 and the KD-6 reinstall done (TC-T07-39) |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | `terminus remote:drush meridian-trade.dev -- config:status` and `ddev drush config:status` both say "No differences"; the Pantheon and local `system.site` uuid both equal the uuid in `apps/drupal/config/sync/system.site.yml`. |
| Actual result | |
| Evidence | `evidence/TC-T07-36.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-37: config_sync_directory resolves to /code/config/sync on Pantheon

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Plan item | KD-5, TH-7 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | `php:eval 'echo realpath(\Drupal\Core\Site\Settings::get("config_sync_directory"));'` prints `/code/config/sync`. |
| Actual result | |
| Evidence | `evidence/TC-T07-37.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-38: Integrated Composer build facts

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-7, unverified list |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | `settings.pantheon.php` exists on Pantheon (prints 1); a build/sync workflow is listed; the Drupal kernel loads from the docroot (web_docroot honoured without `pantheon.upstream.yml`); the report records the Composer version from the build log and that `require-dev` is installed. |
| Actual result | |
| Evidence | `evidence/TC-T07-38.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-39: Reinstall Pantheon dev from config/sync (destructive, owner-approved)

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Plan item | KD-6, R2, R7 |
| Mode | live |
| Tag | n/a |
| Preconditions | Gate as TC-T07-32 plus `T07_CONFIRM_WIPE=1` (owner approved wipe and reinstall of Pantheon dev, owner facts 2026-11-02; dev holds no project data); optional `T07_OWNER_MAIL` |
| Steps | 1. `T07_OWNER_OK=1 T07_O4_DONE=1 T07_CONFIRM_WIPE=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only` |
| Expected result | Safety backup `--element=db --keep-for=30` succeeds; `env:wipe --yes` exits 0; `site:install --existing-config --yes --account-name=admin` exits 0 without errors; `cache:rebuild` exits 0; `config:status` says "No differences"; the evidence file holds no password value (the generated admin password is redacted at source and again by the runner). If install fails on Pantheon, the KD-6 fallback needs a review note and the case is recorded Fail until then. |
| Actual result | |
| Evidence | `evidence/TC-T07-39.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-40: Host key pinning: wrong key rejected, real key accepted

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | TH-6, KD-2, SA-4 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | With a known-hosts file holding a wrong RSA key for the code server, `git ls-remote` fails with "Host key verification failed" or "REMOTE HOST IDENTIFICATION HAS CHANGED" and a non-zero exit; with the committed `scripts/pantheon_known_hosts` it succeeds and lists refs. |
| Actual result | |
| Evidence | `evidence/TC-T07-40.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-41: Committed code-server key matches ssh-keyscan today

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-2 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-30 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | A SHA256 fingerprint scanned from the code server on port 2222 today appears in the comments of `scripts/pantheon_known_hosts`. Day-2 and second-network scans are TC-T07-52. |
| Actual result | |
| Evidence | `evidence/TC-T07-41.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-42: ddev pull pantheon from a fresh shell pulls database and files

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Plan item | KD-3, KD-11, SA-5, R16 |
| Mode | live |
| Tag | n/a |
| Preconditions | Gate as TC-T07-30 plus `T07_CONFIRM_PULL=1` (the pull replaces the LOCAL database; a snapshot is taken first). Note for the report: `ddev auth pantheon` does not exist in DDEV v1.24.4; AC3 is tested by the owner's updated wording |
| Steps | 1. `T07_OWNER_OK=1 T07_O4_DONE=1 T07_CONFIRM_PULL=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only` |
| Expected result | Snapshot taken; `terminus auth:logout` leaves `auth:whoami` failing (so the provider's `auth_command` is what logs in); `ddev pull pantheon -y` from a clean environment exits 0; local `system.site` uuid equals `config/sync`; `ddev drush config:status` says "No differences"; `web/sites/default/files` exists and the log names files; the pulled database has at least one user. |
| Actual result | |
| Evidence | `evidence/TC-T07-42.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-43: Pull provider: fresh backup, no push, nothing leaked

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Plan item | KD-3, R7 |
| Mode | live |
| Tag | n/a |
| Preconditions | TC-T07-42 ran in the same invocation |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | The pull log shows `backup:create` for db and files before `backup:get`; no `backup:restore`, `env:wipe` or `set -x` trace; no token, key or password text. |
| Actual result | |
| Evidence | `evidence/TC-T07-43.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-44: Sandbox interstitial measurement (GET, POST, /jsonapi, with and without Deterrence-Bypass)

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Plan item | KD-12, SA-6, R10 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32. Optional `T07_BYPASS_VALUE` (default 1) |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | Measured in part 1 at the edge, whatever Drupal is installed: a default `curl` GET (Accept `*/*`) is not the Sandbox warning page; a GET with `Accept: text/html` and no header returns the "Sandbox Environment Notice" page, and `Deterrence-Bypass: 1` removes it; POSTs (also with `Accept: text/html`) are not intercepted; a User-Agent matrix on `/jsonapi` is recorded (a Cloudflare challenge, 403 "Just a moment...", for unknown agents such as python-httpx is a recorded finding for T10 and T21; the header does not remove it). After O-4 on the installed site: with the header `/user/login` is 200 with `user-login-form` and `/jsonapi` is 200/401/403 with a JSON content type. The runbook records the result. |
| Actual result | |
| Evidence | `evidence/TC-T07-44.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-45: Edge body size 8 MB and 9 MB; post_max_size

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Plan item | KD-12, SA-6 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32; warm site |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | POST of 8,388,608 bytes to `/user/login` (no header, nothing changes on the server) is not answered 413 and not a connection failure (design value met); the 9 MB result is recorded with the date (measured in part 1). After O-4: `post_max_size` and `upload_max_filesize` are recorded. |
| Actual result | |
| Evidence | `evidence/TC-T07-45.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-46: Wake time and warm GET latency

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Plan item | KD-12, SA-6, NFR-04 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | `env:wake` exits 0 within 120 s (time recorded, and whether the env was asleep); 20 warm GETs of `/user/login` return no 4xx or 5xx (302 before the site is installed, 200 after; all 200 is asserted after O-4); p50 and p95 recorded; p95 below the 59 s edge timeout (measured in part 1). |
| Actual result | |
| Evidence | `evidence/TC-T07-46.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-47: Private files are not served

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Plan item | KD-12, unverified list |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32 |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | `file_private_path` is `sites/default/files/private`; a probe written to `private://t07-probe.txt` is answered 403 or 404 at `/sites/default/files/private/t07-probe.txt` and its content is absent from the body; the probe is deleted. |
| Actual result | |
| Evidence | `evidence/TC-T07-47.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-48: Database-only restore leaves code untouched (destructive)

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Plan item | TH-8, SA-2 decision 7 |
| Mode | live |
| Tag | n/a |
| Preconditions | Gate as TC-T07-32 plus `T07_CONFIRM_RESTORE=1` (owner approval; dev holds no project data) |
| Steps | 1. `T07_OWNER_OK=1 T07_O4_DONE=1 T07_CONFIRM_RESTORE=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only` |
| Expected result | Backup `--element=db` succeeds (time recorded); `config:set system.site name T07-RESTORE-PROBE` is visible; `backup:restore --element=db --file=<name> --yes` succeeds (time recorded); after `cache:rebuild` the original name is back; `git ls-remote` master and the newest `env:code-log` hash are unchanged; `config:status` clean. |
| Actual result | |
| Evidence | `evidence/TC-T07-48.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-49: O-4 result: Pantheon history replaced by the split of main

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | O-4, KD-7, ADR-0004 |
| Mode | live |
| Tag | n/a |
| Preconditions | As TC-T07-32; `origin/main` fetched |
| Steps | 1. `T07_OWNER_OK=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only`; read block `== TC-T07-{n}` |
| Expected result | The oldest commit reachable from Pantheon `master` is a commit of the `git subtree split` of `origin/main` (no Pantheon upstream root commit remains). |
| Actual result | |
| Evidence | `evidence/TC-T07-49.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-50: CI run: workflow_dispatch of deploy-drupal.yml deploys to Pantheon dev

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | SA-7 phase 3, KD-8, O-5 to O-7 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | O-5 succeeded (or written owner-credentials acceptance); O-6 secrets and variable set; T07 merged to main |
| Steps | 1. Owner: Actions, deploy-drupal, Run workflow on `main`; send the run URL (O-7)<br>2. Tester: read the log (redacted copy in evidence), check code-log SHA, `config:status`, smoke |
| Expected result | Reported as `Blocked (accepted, owner-run after O-6)`; the owner accepts this in writing at T07 close (an agent message is not acceptance). When run: job green, last log line is the split SHA, `env:code-log` newest hash equals it, config:status clean, no token in the log. If deploys are local-only the case becomes "Not run: deploys are local-only by decision". T28 cannot close until Pass (machine-user branch). |
| Actual result | |
| Evidence | `evidence/TC-T07-50.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-51: Addendum: first push-triggered run on main is skipped

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-8, SA-7 condition 4 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | T07 merged to main with `PANTHEON_SITE` unset |
| Steps | 1. Owner sends the Actions run URL for the merge push |
| Expected result | Job green; the skip step prints "deploy-drupal: not configured (PANTHEON_SITE unset), skipped". Not a close condition. |
| Actual result | |
| Evidence | `evidence/TC-T07-51.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-52: Code-server host key stable on day 2 and from a second network

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-2, SA-4 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | Day-1 key committed |
| Steps | 1. `ssh-keyscan -p 2222 <codeserver host> \| ssh-keygen -lf -` on day 2<br>2. Same from a second network (hotspot or GitHub runner) |
| Expected result | SHA256 fingerprints on the three occasions equal the one in `scripts/pantheon_known_hosts`; dates recorded; any difference is raised at review (SA-4 decision 4); "Pantheon publishes no host key list" recorded with the date. |
| Actual result | |
| Evidence | `evidence/TC-T07-52.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-53: O-5: machine user result and terms check

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Plan item | KD-10, SA-1, O-5 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | After part B |
| Steps | 1. Owner: `terminus site:team:add meridian-trade <bot email> [role]`; `terminus site:team:list meridian-trade`<br>2. Owner reads the account and acceptable-use sections |
| Expected result | Report states the branch applied: machine user (role recorded), local-only (exact error, date, command saved), or owner credentials accepted (written acceptance, date); "read, no conflict found" with date. |
| Actual result | |
| Evidence | `evidence/TC-T07-53.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-54: Dashboard upstream-updates notice observed

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Plan item | KD-7, SA-3 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | After O-4 |
| Steps | 1. Owner opens the dashboard for `meridian-trade`; does not click Apply Updates |
| Expected result | Notice text recorded; ignoring it is harmless (next deploy still works). |
| Actual result | |
| Evidence | `evidence/TC-T07-54.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-55: Fresh clone: ddev deploy-drupal --dry-run and pull message

| Field | Value |
|---|---|
| Linked criterion | C7 |
| Plan item | plan DoD C7 |
| Mode | live |
| Tag | n/a |
| Preconditions | DDEV and Docker; no credentials needed; `T07_CONFIRM=1` (it stops this project and starts a clone under the same name) |
| Steps | 1. `T07_CONFIRM=1 docs/tests/T07/run-checks.sh --clean-clone` |
| Expected result | In a fresh clone with no `.env`: `ddev start` exits 0; `ddev deploy-drupal --dry-run --ref HEAD --allow-unmerged` exits 0 and prints a split SHA; git status clean; `PANTHEON_SITE` is `meridian-trade` in the web container; `ddev pull pantheon` without a PAT fails with the PAT message and no token text. |
| Actual result | |
| Evidence | `evidence/TC-T07-55.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-56: AC2 owner-run: PAT dates in the runbook table; PAT works from the global config

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Plan item | O-1, KD-10 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | After O-1 |
| Steps | 1. Owner states creation date by message<br>2. `ddev exec terminus auth:login && ddev exec terminus auth:whoami` |
| Expected result | Runbook table has creation date and expiry (creation plus 90 days) and no value; whoami succeeds; owner confirms no PAT was pasted in chat or a file. |
| Actual result | |
| Evidence | `evidence/TC-T07-56.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-57: C7 owner-run: runbook followed verbatim from a fresh clone

| Field | Value |
|---|---|
| Linked criterion | C7 |
| Plan item | plan DoD C7 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | After the runbook is final |
| Steps | 1. Follow `docs/runbooks/deploy.md` word for word through the dry run and `ddev pull pantheon` |
| Expected result | Each command and output recorded with total time; no step needs knowledge outside the runbook. |
| Actual result | |
| Evidence | `evidence/TC-T07-57.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-58: Terminus 4.3.3 pin agrees in Dockerfile, workflow and runbook

| Field | Value |
|---|---|
| Linked criterion | AC3, AC4, C4 (review finding 14, missing case) |
| Type | Static, automated |
| Preconditions | Repo root |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-58` |
| Expected result | `.ddev/web-build/Dockerfile` has `ARG TERMINUS_VERSION=4.3.3` and the SHA-256 `e7ca9bca...bade`; the workflow has the same version and digest; the runbook names Terminus 4.3.3 and the digest; both build paths verify the file with `sha256sum --check --strict`; the Dockerfile fails the build unless `terminus --version` equals `Terminus ${TERMINUS_VERSION}`; no 3.6.2 remains; each file pins exactly one digest |
| Actual result | |
| Evidence | `evidence/TC-T07-58.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-59: Terminus 4.3.3 in the DDEV web container

| Field | Value |
|---|---|
| Linked criterion | AC3 (review finding 14, missing case) |
| Type | Automated (needs a running DDEV project, no credentials) |
| Preconditions | `ddev start` done |
| Steps | 1. `ddev exec terminus --version`<br>2. `ddev exec 'which -a terminus'`<br>3. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-59` |
| Expected result | Step 1 prints exactly `Terminus 4.3.3`; step 2 prints exactly one path. Blocked if DDEV is not running |
| Actual result | |
| Evidence | `evidence/TC-T07-59.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-60: Harness: DEPLOY_SMOKE_BUDGET validation

| Field | Value |
|---|---|
| Linked criterion | AC4 (review finding 8) |
| Type | Offline harness, negative |
| Preconditions | as TC-T07-11 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-60` (values `abc`, `-5`, `1.5`) |
| Expected result | Exit 2 with a message that names `DEPLOY_SMOKE_BUDGET`; the fake log holds no `terminus`, `curl` or `git push`/`ls-remote` call |
| Actual result | |
| Evidence | `evidence/TC-T07-60.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-61: Harness: run from a subdirectory

| Field | Value |
|---|---|
| Linked criterion | AC4, C7 (review finding 4) |
| Type | Offline harness |
| Preconditions | as TC-T07-11 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-61` |
| Expected result | `--dry-run` started in `apps/drupal/config` prints a split SHA with exit 0; `-h` from `scripts/` exits 0; a full deploy started in `apps/` exits 0 and Pantheon master is set |
| Actual result | |
| Evidence | `evidence/TC-T07-61.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T07-62: Harness: unexpected git_url forms and ssh:// without a pinned key

| Field | Value |
|---|---|
| Linked criterion | AC4, SA-4 (review findings 7 and 11) |
| Type | Offline harness, negative |
| Preconditions | as TC-T07-11 |
| Steps | 1. `docs/tests/T07/run-checks.sh`; read block `== TC-T07-62` (scp-style URL, https URL, `ssh://` with a comment-only known-hosts file, `ssh://` with the file missing) |
| Expected result | Exit 2 in every case; the scp-style and https cases print "unexpected git_url form"; the fake log holds no `env:wake`, `backup:create`, `ls-remote`, `git push` or later stage |
| Actual result | |
| Evidence | `evidence/TC-T07-62.txt` |
| Status | Not run |
| Date | |
| Executed by | |

## Plan ambiguities found while designing

| ID | Ambiguity | How the cases handle it |
|---|---|---|
| A1 | KD-1 says exit 2 is "usage or guard error" and exit 1 is "a deploy or verification step failed", but TH-2 says the split-tree guard (vendor, `.env`) "exits 1 before any network step". | TC-T07-12 accepts 1 or 2 for the tree guard and missing required files, and requires no network call. The review should pick one; if the plan intends exit 1, tighten the test |
| A2 | The smoke-check "wake retry budget 120 s" (KD-1 stage 9) means the two negative smoke cases in TC-T07-18 can each take about two minutes, and the plan gives no override. | The harness runs each with a 200 s timeout. A script flag or env override for the budget would be a cheap improvement |
| A3 | How the token reaches Terminus is not fixed (`auth:login --machine-token=...` puts it in the process list; env var does not). | TC-T07-19 accepts either, only requires that script output never shows it. Reviewer may prefer the env route |
| A4 | The format of `workflow:info:status` and when `workflow:wait` exits non-zero are unverified. | Resolved 2026-11-02 by `docs/tasks/T07/terminus-4.3.3-facts.md` (items b to d): the fake `workflow:wait` prints the 4.3.3 success notice, and the timeout and not-found fakes exit 0 without it. Live proof is L-4 (TC-T07-32 and 34) |
| A5 | "TERMINUS_ALTERNATE_NAMESERVER must be unset": the plan does not say whether the script unsets an inherited value or only never sets it. | TC-T07-07 and 19 check that the script never sets it and that it is unset when the caller did not set it |
| A6 | `ddev pull pantheon` has no `ddev auth pantheon`; the provider's `auth_command` only runs inside the pull. The "fresh shell" is not defined. | TC-T07-42 runs `terminus auth:logout` first, then the pull with `env -i` plus `HOME` and `PATH`, which only proves login happens inside the pull |
| A7 | KD-12 says "record which value works" for the bypass header but the value is unverified; the script's constant depends on the result. | TC-T07-44 tests value `1` (or `T07_BYPASS_VALUE`); if the interstitial still shows, the tester tries other values and logs them |
| A8 | The T07 branch is not on the remote, so `origin/main` does not hold the T07 files until merge; the real deploy needs `--allow-unmerged`, and TC-T07-35 needs an older commit touching `apps/drupal` on origin/main. | Gated: Blocked when no such commit exists |
| A9 | `site:install --existing-config` on Pantheon may fail (KD-6 fallback). | TC-T07-39 records Fail until a review note covers the fallback |
| A10 | The ancestor guard uses `origin/main`, which in a CI checkout with `fetch-depth: 0` exists, but a local clone that never fetched exits 2. | TC-T07-13 covers the missing ref; the runbook should say `git fetch origin` first (TC-T07-20 does not check it) |

## Change log

| Date | Change |
|---|---|
| 2026-11-02 | Initial design (tester, design mode) |
| 2026-11-02 | Part 1 corrections (suspected test defects in `review.md`, "Re-review 2026-11-02"): fake `workflow:wait` prints `Workflow w1 completed successfully for commit <sha>`; timeout and not-found fakes added (TC-T07-18, 15); TC-T07-15 and 34 now expect `workflow:wait --commit=<sha> --start=1` and `env:code-log` on a re-run, with no backup and no push, plus three negative re-run cases; fake `auth:whoami` logged out exits 0 with empty stdout; `GlobalKnownHostsFile=/dev/null` in TC-T07-07 and every live `GIT_SSH_COMMAND`; the fake `git` logs `GIT_SSH_COMMAND` for push and ls-remote and TC-T07-14 asserts it; TC-T07-09 expects Terminus 4.3.3, SHA-256 `e7ca9bca...bade`, `--ref "$DEPLOY_REF"` with the expression in `env:` and no `${{` inside any `run:`; TC-T07-10 uses `.tools/actionlint`; TC-T07-23 regex matches `$settings['config_sync_directory']`; TC-T07-07 known-hosts checks and TC-T07-27 are Blocked (not Fail) until the key is committed and until `T07_CLOSE=1`; new cases TC-T07-58 to 62; TC-T07-44 to 46 split into a part 1 edge measurement and an after-O-4 part. Reason: reviewer's suspected-test-defects tables (check problems, not product defects); plan addendum items 1, 3 and 5; Terminus 4.3.3 facts record. |
| 2026-11-02 | TC-T07-44 expectations rewritten from the measured behaviour: the Sandbox warning page is served for `Accept: text/html` GETs (not for default curl or POST), `Deterrence-Bypass: 1` removes it, and a Cloudflare challenge (403) hits unknown User-Agents regardless of the header. Reason: part 1 measurement (A7 resolved for the header value); the original expectation assumed default curl was intercepted |
