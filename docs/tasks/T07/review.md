# T07: Pantheon dev environment and deployment path, Review

| Field | Value |
|---|---|
| Task | T07 |
| Reviewer | technical-architect |
| Date | 2026-11-02 |
| Commit range | `41f630e..ce46a8e` (91d27c4, f2d0d20, 2169ad3, de26400, 8d79ee7, ce46a8e) |
| Plan | `docs/tasks/T07/plan.md` (Approved, Rev 2; addendum 2026-11-02 added by this review) |
| Decisions | `docs/tasks/T07/decision-*.md` (SA-1 to SA-7) |
| Scope of this review | Offline part only (plan work split A, step 7). The live part (part B) has not run: the owner's PAT login fails and the owner is creating a new token |

## What was checked

- **Diff.** I read every changed file in full:
  - `scripts/deploy-drupal.sh`, `scripts/pantheon_known_hosts` and
    `scripts/tests/test_deploy_drupal.py`;
  - `.ddev/commands/web/deploy-drupal`, `.ddev/providers/pantheon.yaml`,
    `.ddev/web-build/Dockerfile` and `.ddev/config.yaml`;
  - `.github/workflows/deploy-drupal.yml`, `.hadolint.yaml`, `.env.example` and `settings.php`;
  - `docs/runbooks/deploy.md`, the D7 and D8 changes and the register in
    `technical-design.md`, the ADR-0004 note, the READMEs, `CLAUDE.md` and `PROGRESS.md`.
- **Tools (read-only, no credentials, no network to Pantheon).**
  - `python3 -m unittest scripts/tests/test_deploy_drupal.py`: 15 tests, OK.
  - `.tools/actionlint` 1.7.12 on `deploy-drupal.yml`: exit 0, no output.
  - shellcheck (pre-commit copy) on the script and the DDEV wrapper: exit 0.
  - hadolint 2.12.1 with the repo `.hadolint.yaml` on `.ddev/web-build/Dockerfile`: exit 0.
    Without the config it reports DL3061 at line 19.
  - `scripts/exceptions_report.py`: exit 0. `.hadolint.yaml` is counted as a config exclude.
  - `docs/tests/T07/run-checks.sh` (static): 22 PASS, 5 FAIL, 29 BLOCKED. Each FAIL is classified
    under "Suspected test defects" below.
  - `docs/tests/T05/run-checks.sh --regression` and `docs/tests/T06/run-checks.sh --regression`:
    the failures the developer reported are reproduced (TC-T05-02, 21, 23 and TC-T06-12).
  - `ddev exec 'which -a terminus; terminus --version'`: a single `/usr/local/bin/terminus`,
    `Terminus 4.3.3`, PHP 8.3.19 and git 2.39.5 in the web container.
- **hadolint pragma probe.** I wrote fixtures in the session scratchpad, not in the repo, and ran
  hadolint 2.12.1 on them:
  - `# hadolint global ignore=DL3061` on its own line suppresses DL3061.
  - The same line followed by a space and `# T07: reason` does **not** suppress it.
  - The standards' documented form `# hadolint ignore=DL3008 # T06: reason` does **not**
    suppress DL3008.
  - `# hadolint ignore=DL3008` with nothing after it does suppress DL3008.
  - So hadolint drops a pragma with trailing text (findings 12 and 13).
- **Simulation only.** I grepped the diff for broker SDK names and broker domains: no hits. The
  only hosts added are `pantheonsite.io`, `drush.in` (via `connection:info`) and `github.com`
  (Terminus release download).
- **Force pushes and tracing.** `--force` appears only in the owner steps of the runbook (O-4
  and the emergency push). It does not appear in the script, the wrapper, the provider or the
  workflow, and none of them use `set -x`.

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `scripts/deploy-drupal.sh:163-167` (skip branch), `:189-191`; `docs/runbooks/deploy.md:154-155`, `:263-265`, `:310`; `technical-design.md` D8 step 4 last sentence | **A re-run can report success for a build that failed or never finished.** When `master` is already at the split SHA, the script skips stages 5 **and** 6, runs drush, and exits 0 with `deployed <sha>`. The runbook sends the owner straight to this path: after a 900 s timeout ("rerun (the push is skipped)", line 310) and after an emergency force push (lines 263-265). Pantheon only deploys an Integrated Composer build that succeeds. If the first build failed or is still running, the app server still serves the **old** code and the old `config/sync`. Then `config:import` and `config:status` are clean against the old tree, the smoke check passes, and the script prints "deployed" for code that is not live. That breaks the script's contract ("0 deployed and verified", KD-1) and D8 step 6. The developer followed plan KD-1 stage 4, so this is a gap in my plan. CODING_STANDARDS "Error handling" says to fail loudly at the point of failure; REVIEW_CHECKLIST section 2 says a correctness "no" is at least Major. | (a) On the skip path, confirm before stage 7 that the Pantheon workflow for `split_sha` on `dev` **finished and succeeded**. If that cannot be confirmed, exit 1 with "build of <sha> not confirmed; check the dashboard workflow log". Pick the mechanism after reading the 4.3.3 source: `workflow:wait --commit=<sha> --start=<epoch>` with a start time early enough to match the earlier workflow, or `terminus workflow:list <site> --format=json` plus `workflow:info:status --id=<id>` filtered by environment and commit. Record the choice and its source line (see finding 10). Keep the `env:code-log` check on this path too. (b) Unit test: a re-run where the fake reports the commit's workflow as failed exits 1 and runs no drush. A re-run where it succeeded still takes no backup and makes no push. (c) Runbook lines 155, 265 and 310 and D8 step 4: say that the re-run still checks the build. (d) Plan addendum item 3 records the change. The tester updates TC-T07-15 (its "no workflow:wait" assertion) and TC-T07-34. | Open |
| 2 | Minor | `scripts/deploy-drupal.sh:143-144` | `terminus auth:whoami` most likely exits **0** when no one is logged in: it logs "You are not logged in." as a notice. This is not verified for 4.3.3. If so, the "no token and no session" guard never fires, and the run fails one step later at `connection:info` with a less helpful message. It is still safe: nothing is pushed. The unit test passes only because the fake exits 1. | Test the output, not the exit code. For example, `who="$(terminus auth:whoami --field=email 2>/dev/null)"` must be non-empty, else `fail "... no Terminus session ..."`. Live item L-2 confirms the logged-out behaviour. Make the fake mimic the real behaviour (exit 0, no email). | Open |
| 3 | Minor | `scripts/deploy-drupal.sh:35` | Strict pinning is incomplete. With `StrictHostKeyChecking=yes`, OpenSSH also accepts a key from the **global** known-hosts file (`/etc/ssh/ssh_known_hosts`, or whatever `GlobalKnownHostsFile` points at). A key there for the code server would override the pin. SA-4 decision 1 pins the code server against `scripts/pantheon_known_hosts` only. | Add `-o GlobalKnownHostsFile=/dev/null` to `GIT_SSH_COMMAND`. Update the TC-T07-08 check and the unit test's expected string. TH-6 (wrong key fails) still applies. | Open |
| 4 | Minor | `scripts/deploy-drupal.sh:30-31`, `:99-111` | The script works only from the repo root. `git subtree` refuses to run below the top level ("You need to run this command from the toplevel of the working tree", `git-sh-setup`, because git-subtree does not set `SUBDIRECTORY_OK`). It also tests `apps/drupal` relative to the current directory. Run from `scripts/` or `docs/`, it exits 1 with "git subtree split failed". The DDEV wrapper and CI happen to start at the root. CODING_STANDARDS "Shell scripts": "Resolve paths from the repo root ... so the script runs from any directory". | After argument parsing: `cd "$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"`. Add a unit test that runs the fixture copy from a subdirectory with `--dry-run`. | Open |
| 5 | Minor | `.github/workflows/deploy-drupal.yml:84` | `${{ inputs.ref \|\| github.sha }}` is expanded inline in `run:`. A dispatch input such as `main"; <command>; echo "` becomes shell code in the step that holds both secrets. Only users with write access can dispatch, so this grants no new privilege today. Still, GitHub's hardening guide and the intent of CODING_STANDARDS "GitHub Actions" (values reach `run:` only through `env:`) say to pass it through `env:`. Plan KD-8 wrote it inline, so this tightens the plan. | `env: DEPLOY_REF: ${{ inputs.ref \|\| github.sha }}` and `run: scripts/deploy-drupal.sh --ref "$DEPLOY_REF"`. Extend the unit test so that no `${{` expression of any kind appears inside `run:`. The tester updates TC-T07-09, which expects the inline string. | Open |
| 6 | Minor | `docs/runbooks/deploy.md:107-113`, `:262` | The O-4 first push and the emergency push run a bare `git push --force` from the web container, without the pinned `GIT_SSH_COMMAND`. Line 112 even offers "or accept the key once after comparing the fingerprint", which is trust on first use. These are the two most sensitive pushes, and they bypass the SA-4 pin. | Give the exact command, for example `ddev exec 'GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/var/www/html/scripts/pantheon_known_hosts -o BatchMode=yes" git push --force <git_url> <split_sha>:refs/heads/master'`. Delete the "accept the key once" alternative. Use the same command in step 3 of "Emergency force push". | Open |
| 7 | Minor | `scripts/deploy-drupal.sh:149-158` | Production code has a test seam: any `git_url` that does not start with `ssh://` skips the "known hosts holds a key" guard and prints "(test setup)". Pantheon returns `ssh://`, and `GIT_SSH_COMMAND` would still pin an scp-style URL, so this is not exploitable today. But fail-closed should not depend on the URL form. | Allow the bypass only for a local path (`/*` or `file://*`, which the fixture uses). Any other non-`ssh://` URL exits 2 with "unexpected git_url form". Add a unit test where the fake returns an `ssh://` URL and `pantheon_known_hosts` holds only comments: exit 2, no `backup:create`, no `git push` (see finding 11). | Open |
| 8 | Minor | `.env.example:68-72`; `scripts/deploy-drupal.sh:211`, `:215`; `.github/workflows/deploy-drupal.yml:80-84` | `DEPLOY_SMOKE_BUDGET` and `DEPLOY_SMOKE_HEADER` are a reasonable change from the plan's "constant in the script" (plan addendum item 5), and D7 lists them. Four problems remain. (1) `.env.example` suggests setting them in `.env`, but `ddev deploy-drupal` runs in the web container, which does not read `.env` (`.ddev/config.yaml` comment, KD-4). (2) The workflow never passes them, so if KD-12 shows the header is needed, CI smoke checks fail while local ones pass. (3) A non-numeric budget hits `set -u` inside `[[ ... -lt ]]` and aborts with an unclear error. (4) Via T06 `env_file`, `.env.example` values are now injected into `meridian-engine` and `meridian-web`. That is harmless, but noted. | Now: validate `budget` with `[[ "$budget" =~ ^[0-9]+$ ]] \|\| fail "DEPLOY_SMOKE_BUDGET must be whole seconds" 2`. In the `.env.example` comment, say where each variable is set for DDEV (`.ddev/config.yaml` `web_environment`, or `ddev exec env VAR=... scripts/deploy-drupal.sh`) and for CI (workflow `env:`). After KD-12, if the header is needed, either hard-code it in the script (the plan's choice) or set it in both `.ddev/config.yaml` and the workflow `env:`, and record which. | Open |
| 9 | Minor | `scripts/deploy-drupal.sh:22-24`; `scripts/README.md:66`; `docs/runbooks/deploy.md:157` | The exit-code text says 2 means "usage error or a ref guard". A missing host-key line also exits 2 (line 154), and so does a missing `PANTHEON_SITE`. Choice A1 (guard = 2) is acceptable and matches plan KD-1 ("2 usage or guard error"), but the documentation does not list these cases. | List them in all three places: "2: usage error, `PANTHEON_SITE` unset, unknown ref, missing `origin/main`, ref not merged, no code server key in `scripts/pantheon_known_hosts`". Note that through `ddev` every failure becomes exit 1 (runbook line 158 already says so). | Open |
| 10 | Minor | `docs/architecture/technical-design.md` unverified register, last T07 row; `.ddev/web-build/Dockerfile:1-5` | The register closes "Terminus `ssh_command` placement, `workflow:wait` failure and timeout exit codes ..." as "read in the Terminus 4.3.3 source and help; see `docs/tasks/T07/`". No file under `docs/tasks/T07/` holds that record. SA-4 relied on the **3.x** placement of `ssh_command` before `-o StrictHostKeyChecking=no`, so the 4.3.3 re-check matters (plan: "the developer confirms"). | Add the source facts, each with file, class or method, the 4.3.3 tag URL and the date, to the runbook "Tool versions" section or to a short `docs/tasks/T07/terminus-4.3.3-facts.md`. Cover: (a) the `SSHBaseCommand` connection string order, with `ssh_command` first; (b) `WaitCommand`: non-zero exit on a failed workflow, "giving up" with exit 0 on timeout, and the default start-time window (`--start`); (c) `LoginCommand`, which takes the token only from `--machine-token` (choice A3); (d) whatever finding 1 relies on. Point the register row at that record. | Open |
| 11 | Minor | `scripts/tests/test_deploy_drupal.py` | No offline test covers the fail-closed host-key guard. The fixture's `git_url` is a local path, so line 153 never runs, and nothing asserts that `git push` uses the strict `GIT_SSH_COMMAND`. The plan's TH-4 checks only the text. | Add the test from finding 7. Also have the fake `git` record `$GIT_SSH_COMMAND` on `push` and `ls-remote`, and assert that it contains `StrictHostKeyChecking=yes` and the fixture's `pantheon_known_hosts` path. | Open |
| 12 | Note | `.hadolint.yaml:1-3` | **Repo-level DL3061 ignore (developer item 1): accepted.** `.ddev/web-build/Dockerfile` must not have `FROM`, because DDEV appends it to its own generated Dockerfile, so the rule cannot be met: this is not relaxing a fixable rule. The in-file alternative fails. A same-line ticket after the pragma makes hadolint 2.12.1 drop the pragma (my probe above). A ticket on a separate line violates the exception policy's "same line" rule. Scope: the ignore applies to every Dockerfile. Today the repo has only this one; the engine Dockerfile arrives in T13. The cost is close to nil, because a real Dockerfile without `FROM` already fails `docker build`. A narrower option exists: split the pre-commit hadolint hook so that only this file gets `--ignore DL3061`, but that is a second config exception, not a cleaner one. Counting: `exceptions_report.py` treats `.hadolint.yaml` as a config file and `ignored:` as an exclude key, so it is counted under "config exclude" with ticket T07 (report exit 0). | Optional wording fix: say it is permanent, so the "exception naming its own task as remover" close-check does not trip, for example `- DL3061  # T07: permanent; DDEV prepends FROM to .ddev/web-build/Dockerfile`. Re-decide in T13 if the engine Dockerfile should keep DL3061 (then use the split-hook option). | n/a |
| 13 | Minor | `docs/standards/CODING_STANDARDS.md:489` (hadolint row of the exception table) | **Standards defect found while reviewing finding 12.** The required hadolint form `# hadolint ignore=DL3008 # T06: reason` does not work with the pinned hadolint 2.12.1: the pragma is dropped and DL3008 is still reported. The same pragma without trailing text works. This answers OQ-T04a-6 and TC-T04a-54 (owner-run, still blocked) in the negative. Today no Dockerfile uses an inline hadolint ignore, so nothing is wrongly suppressed. | The standards say "if a form fails there, a new addendum replaces it; do not invent a local workaround". Route to the solution-architect for a D-4 addendum. A likely form: hadolint suppressions live only in `.hadolint.yaml` `ignored:` with the ticket as a YAML comment, the same as the yamllint rule, and `exceptions_report.py` flags any inline `hadolint ignore`. The T04a tester records this probe as evidence for TC-T04a-54. Not a T07 change. | Ticketed (T04a) |
| 14 | Note | `.ddev/web-build/Dockerfile`; `.github/workflows/deploy-drupal.yml:52-66` | **Terminus 4.3.3 pin (developer item 1, owner requirement): accepted.** It is pinned by version and SHA-256 in both places with the same value. The checksum is checked from a file with `--strict`, the build asserts `terminus --version`, and the phar replaces the DDEV copy at the same path (one `terminus` on PATH, verified). The pin record (version, source, date, upgrade path) is in the Dockerfile, `.ddev/README.md`, the runbook and D8. The download from `github.com` at image build is a new network dependency of `ddev start` after a Dockerfile change, on par with Composer. The workflow choice (4.3.3, not the plan's 3.6.2; developer item 2) is right: the same version runs locally and in CI. | Plan addendum item 1 records it. The tester updates TC-T07-09 and adds a version case (see "Suspected test defects"). | n/a |
| 15 | Note | `.github/workflows/deploy-drupal.yml:31-84` | **Separate `skip` and `deploy` jobs (developer item 4): accepted.** Both use a job-level `if:` on `vars.PANTHEON_SITE` (an unset variable evaluates to `''`). When unconfigured, nothing is checked out or installed and the run is green with the plan's line. Other checks: `permissions: contents: read` at the top; `concurrency: deploy-drupal` with no cancel; `timeout-minutes: 30`; checkout pinned by SHA with `persist-credentials: false` and `fetch-depth: 0`, so `origin/main` exists for the ancestor guard; the key goes to `ssh-add -` from `env:` with no file on disk and no third-party action; no `--allow-unmerged`; secrets never echoed. | Plan addendum item 6. | n/a |
| 16 | Note | `scripts/deploy-drupal.sh:177-190` | **`workflow:wait` handling (developer item 5): accepted, subject to live checks.** A non-zero exit fails the deploy. "giving up" (the timeout, exit 0) is caught with `grep -qi`. `env:code-log` must show the split SHA as the newest `hash`. Dropping `workflow:info:status` is fine if a failed workflow really exits non-zero (live item L-4; record the source per finding 10). | Plan addendum item 2. | n/a |
| 17 | Note | `scripts/deploy-drupal.sh:134-141`; `.ddev/providers/pantheon.yaml:45` | **PAT on argv (developer item 6, A3): accepted.** Terminus takes the token only as `--machine-token`, which DDEV's own provider example does too. While that one process runs, the token is in its argument list. In the web container the same value is already in every process's environment (global `web_environment`). The GitHub runner is a single-tenant VM. On failure, the login output is passed through `redact()` with a literal (quoted) pattern. On success it is discarded. Nothing else prints the token, and the unit test proves it with a marker. A5 (`unset TERMINUS_ALTERNATE_NAMESERVER`) and A10 (`git fetch origin` in the error and the runbook) are correct. | None. The runbook already forbids `env` and `printenv` output in evidence. | n/a |
| 18 | Note | `scripts/pantheon_known_hosts`; `scripts/deploy-drupal.sh:153-154` | **No key yet (developer item 7).** For an `ssh://` URL the script exits 2 before `env:wake`, the backup and the push when the file has no non-comment line, and ssh pins strictly when it does. The file's comments explain the procedure and the deliberate non-pinning of the app server, with the link to SA-4. TC-T07-07 fails until the day-1 key is committed. That is expected, not a defect. | Live: commit the day-1 key with its fingerprint comment, then compare day 2 and a second network (L-3). The key must be committed before any real push, including O-4 (finding 6). | n/a |
| 19 | Note | `CLAUDE.md:66-67` | **CLAUDE.md rows (developer item 8).** The two rows were added by the main session. They are accurate and match the runbook. TC-T07-22 now passes. | None. | n/a |
| 20 | Note | `.ddev/providers/pantheon.yaml` | **Pull-only provider: correct.** It has no `db_push_command` and no `files_push_command`, no `set -x`, and no `#ddev-generated` marker. Every pull takes a fresh `--keep-for=30` backup first. `${PANTHEON_SITE:?}` fails loudly if the site is unset. The auth error text names the PAT and its 90-day expiry. | Tester: do **not** run `ddev push pantheon` against the live site to prove the negative. Confirm from DDEV v1.24.4 source or docs that a provider without push commands pushes nothing, and record the source. | n/a |
| 21 | Note | `scripts/deploy-drupal.sh`, workflow, DDEV command | **Two deploy paths, no shared lock.** A local `ddev deploy-drupal` and a CI run can overlap. Because every push is non-force, the worst case is a rejected push (exit 1), never lost code. | Optional: one runbook sentence ("do not deploy locally while a CI deploy runs"). | n/a |
| 22 | Note | all | Simulation-only rule: no broker SDK, client, domain or order code. All outbound hosts are Pantheon or GitHub, as plan KD-1 and the checklist require. The site name `meridian-trade` is plan risk R15 (note for T18). | None. | n/a |

## Live items for `/test-task` (cannot be judged offline)

Run these only after the owner's own O-3 message. Redact all evidence.

| ID | What to verify | Linked |
|---|---|---|
| L-1 | `terminus auth:login` with the new PAT works in the web container (4.3.3). The output and evidence hold no token, and the PAT prefix grep on `docs/tests/T07/evidence/` is empty | AC2, AC3, R7 |
| L-2 | `terminus auth:whoami` exit code and output when logged out (`auth:logout` first) | Finding 2 |
| L-3 | `connection:info` gives a `ssh://codeserver.dev.<uuid>@...:2222` URL. `git ls-remote` shows `master`. The day-1 key is committed, day 2 and a second network match. TH-6: a wrong key fails with a host key error. The pinned file is used for O-4 | KD-2, findings 3, 6 |
| L-4 | `workflow:wait --commit` returns after the build (not before). Record the "giving up" text on timeout. If a failing build can be produced safely, its exit code; otherwise the source citation (finding 10). Check that the default start window (about now minus 60 s) catches the push's workflow | Findings 1, 16 |
| L-5 | `env:code-log --format=json` lists the newest commit first, and the key is `hash` | Stage 6 |
| L-6 | `backup:create --element=db --keep-for=30` exits 0 and the backup is listed. Note its time | SA-2, TH-8 |
| L-7 | KD-5 sync path `/code/config/sync` and site UUID; KD-7 build facts; KD-6 reinstall (password redacted) | AC1, AC5 |
| L-8 | `remote:drush -- config:status` prints "No differences" on stdout or stderr as captured with `2>&1` | AC5 |
| L-9 | KD-12: interstitial with and without `Deterrence-Bypass`, the marker check, the 8 MB and 9 MB POSTs, the private file probe, wake and warm GET timings | AC6, finding 8 |
| L-10 | Real deploy, then an idempotent re-run with the finding-1 fix: no backup, no push, build still confirmed | AC4, finding 1 |
| L-11 | `ddev pull pantheon` from a fresh shell with no manual login, after `ddev snapshot` | AC3 (KD-11 reading) |
| L-12 | **Split SHA agreement across git versions.** The `--dry-run` split SHA of `origin/main` is the same in the DDEV container (git 2.39.5) and on a different git version (host or CI runner). If they differ, the first CI push after a local deploy is rejected | KD-1, SA-7 |
| L-13 | After O-6 and O-7 (CI run, may be deferred): the phar runs on `ubuntu-24.04`, `git subtree` exists on the runner, the agent socket passes through `GITHUB_ENV`, and the log holds no secret | SA-7 |
| L-14 | gitleaks over the split history pushed to Pantheon | C6 |

## Suspected test defects (tester-owned; not edited here)

Each is a check problem unless the verdict says otherwise. The tester logs each one as a
`DEF-nnn` in `docs/tests/defects.md` and fixes the check.

| Case | Verdict | Reason and fix |
|---|---|---|
| TC-T07-09 | Check problem | Expects Terminus **3.6.2**. The owner required 4.3.3 because 3.6.2 cannot log in with a PAT, and the plan addendum (item 1) records it. Fix: expect `TERMINUS_VERSION: 4.3.3` and the SHA-256 `e7ca9bca…bade`, and that this equals the Dockerfile pin. After finding 5 is fixed, also expect `--ref "$DEPLOY_REF"` with the expression in `env:` instead of the inline string |
| TC-T07-10 | Check problem (minor) | BLOCKED because `actionlint` is not on PATH, although the repo-documented binary is `.tools/actionlint` (`.github/README.md`, `scripts/README.md`). I ran it: 1.7.12, exit 0. Fix: fall back to `.tools/actionlint` |
| TC-T07-23 | Check problem | The regex `config_sync_directory *= *'\.\./config/sync'` cannot match the valid line `$settings['config_sync_directory'] = '../config/sync';`, because `']` sits between the key and `=`. The product is correct: the assignment is at line 45, after the include in step 2, with the KD-5 comment above it. Fix: `config_sync_directory'\] *= *'\.\./config/sync'` |
| TC-T07-24 (via TC-T04a-33) | Check problem | T04a `envsame` (`docs/tests/T04a/run-checks.sh:797`) is tagged `ckp`, but it is a snapshot: it compares `.env.example` variable lines with the T04a base. T07 changes `PANTHEON_SITE` and adds two variables, as the plan and C6 require. The same class was raised as TC-T06-19 in the T06 review. Fix: re-tag `cka`, or limit the invariant to "every variable has a placeholder and no value looks like a secret" |
| TC-T05-02 | Check problem | `allout "$DDEVCFG" 'web_environment' '(api[_-]?key\|secret\|token\|password\|passwd)\s*[:=]\s*\S'` treats the bare key `web_environment` as forbidden. KD-4 requires `web_environment: [PANTHEON_SITE=meridian-trade]` (not a secret), and no secret is present. Fix: check only the `web_environment` values against the secret pattern |
| TC-T05-21 and TC-T06-19 | Check problem | They fail only because they nest the T04a regression (TC-T04a-33 above), and TC-T06-19 also nests the T05 one. The T06 `--regression` summary is 17 PASS, 2 FAIL (TC-T06-12, TC-T06-19). The T05 summary is 21 PASS, 3 FAIL (TC-T05-02, 21, 23) |
| TC-T05-23 and TC-T06-12 | Check problem | "No `providers/pantheon.yaml` (T07)" is a scope snapshot for T05 and T06 but is tagged `ckp`, so it fails once T07 delivers the file. Fix: re-tag `cka` (snapshot), as with the T02 fix in c426c9a |
| TC-T07-07 | Expected, not a defect | The known-hosts key and fingerprint comments are owed by the live step (finding 18). Optionally report BLOCKED with the reason until O-3, so the static run is not red for a known-pending owner step |
| TC-T07-27 | Expected, not a defect | `[at-close]` TRACEABILITY, PROGRESS and SA-1 branch wording, due at `/close-task` |
| TC-T07-15 and TC-T07-34 | Will need a change after finding 1 | They assert that the re-run makes no `workflow:wait`. After the fix, assert instead that the re-run confirms the commit's build (by the chosen mechanism) and still makes no backup and no push. Add a negative re-run case where the build failed: exit 1 and no drush |
| (missing case) | Test gap | No case pins the Terminus version. Add a static case: Dockerfile and workflow use the same version and SHA-256, and the checksum is verified with `--strict`. Add a DDEV case: `ddev exec terminus --version` prints `Terminus 4.3.3` and `which -a terminus` gives one path |
| TC-T07-22 | No defect | The CLAUDE.md rows are now present (ce46a8e). The case passes |
| (missing cases) | Test gap | Cover findings 3, 4 and 7 if fixed: `GlobalKnownHostsFile=/dev/null` in `GIT_SSH_COMMAND`, a run from a subdirectory, and an `ssh://` URL with an empty known-hosts file giving exit 2 with no backup and no push |

## Review checklist summary

- **1 Simulation only:** yes (finding 22).
- **2 C1 to C7:** see the table below.
- **3 Plan adherence:**
  - Yes, with the deviations recorded in the plan addendum: Terminus 4.3.3, the
    `workflow:info:status` drop, separate jobs, exit 2 for the host-key guard, and the env
    variables for the smoke check.
  - New dependency: Terminus 4.3.3 phar. It is MIT licensed, released 2026-08-20, pinned by
    SHA-256, and replaces the 3.6.2 copy already in the image.
  - No scope creep.
- **4 Cross-cutting:**
  - Naming: `deploy-drupal.yml` and `meridian-*` are used, and `check-names` passes within
    TC-T07-24.
  - Error handling: every step fails loudly with its own message, except finding 1 (false
    success) and finding 2 (weak guard).
  - Secrets: none in the repo. Token handling is covered in findings 17 and 8.
  - Pins: the action is pinned by SHA, and Terminus and actionlint by version and SHA-256.
  - Exceptions: one new config exclude (finding 12).
- **5 Tests:**
  - The offline harness is strong: a real `git push` to a bare repo, rewind rejection, call
    order, backup arguments and a token marker.
  - Gaps: findings 1, 2, 7 and 11.
- **6 Shell:**
  - Correct shebang and `set -euo pipefail`; expansions are quoted; `[[ ]]` is used.
  - `mktemp` is paired with a `trap`, and errors go to stderr.
  - `-h` prints usage, and a bad argument exits 2.
  - Exception: finding 4 (resolve from the repo root).
  - `|| true` at lines 118 and 188 is explained by context: `grep` finding nothing is the
    normal case. A short comment would match the standard.

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | Plan e253fc5 (approved) is an ancestor of the first code commit 91d27c4 |
| C2 Review findings resolved | No | Finding 1 (Major) and findings 2 to 11 (Minor) are open; finding 13 is ticketed to T04a |
| C3 Criteria mapped to executed tests | Not yet | Mapping is in `docs/tests/T07/test-cases.md`. Every live case (AC1 and AC3 to AC6) is BLOCKED until the owner's O-3 message. The CI run case needs the owner's written acceptance (SA-7) |
| C4 CI green | Partly | `ci.yml` is T08, a recorded reason. Stand-ins pass: pre-commit on the T07 files (inside TC-T07-24), actionlint 1.7.12, shellcheck, hadolint, the exceptions report and the unit tests. Earlier `--regression` suites fail only on the check defects above. `ddev quality` exit 0 is owed in `/test-task` |
| C5 Docs updated | Partly | Runbook, D7, D8, NFR rows, register, ADR-0004 note, READMEs and CLAUDE.md are done. Findings 6, 8, 9 and 10 need text changes. Live results and `TRACEABILITY.md` come at close |
| C6 No secrets | Yes (offline) | No token or key in the diff. `.env.example` lists the new names with placeholders, and the PAT field is blank. gitleaks on the split history pushed to Pantheon is live item L-14 |
| C7 Clean-checkout works | Not yet | TC-T07-55 (`ddev deploy-drupal --dry-run` in a fresh clone) runs in `/test-task`. Finding 4 affects running the script outside the root |

## Approval

**Changes requested.** Finding 1 (Major) must be fixed in this task before any real deploy
(plan step 10). Fix findings 2 to 11 now, or ticket them with a reason. Findings 3, 6 and 7 touch
host-key pinning and should be fixed before the O-4 push. Finding 13 goes to the
solution-architect (T04a). After the fixes, the tester corrects the check defects above.

A re-review covers:

- the changed lines of `scripts/deploy-drupal.sh`, its tests, the workflow `run:` line and the
  runbook sections named in findings 1, 6, 8 and 9;
- the facts record from finding 10.

The live part is then judged in `/test-task` against items L-1 to L-14.

technical-architect, 2026-11-02.
