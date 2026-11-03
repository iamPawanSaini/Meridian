# T07: Pantheon dev environment and deployment path, Test report

**Part 1 (pre O-4), not signed off.** Part 2 runs after the owner's force push (O-4).

| Field | Value |
|---|---|
| Task | T07 |
| Build or commit | `3794178` on `task/T07-pantheon-dev`, plus uncommitted tester changes (check fixes, new cases, evidence; the tester does not commit) |
| Environment | WSL2 (Linux 6.18.54.1-microsoft-standard-WSL2), DDEV v1.24.4, Docker 28.1.1, Python 3.10.12; host git 2.34.1, web container git 2.39.5, Terminus 4.3.3 (one `/usr/local/bin/terminus`); `.tools/pre-commit`, `.tools/actionlint` 1.7.12 |
| Date | 2026-11-02 (UTC) |
| Executed by | tester |
| Authority | The owner's message of 2026-11-02: "O-3: agents may run Pantheon commands with my credentials for T07" |
| SA-1 branch applied (so far) | Owner credentials, used from the owner's machine only; no machine user exists (O-5 not done) |

## What part 1 did and did not do

Allowed and done: read-only Pantheon commands, `ssh-keyscan`, edge measurements with `curl` against
the public dev URL (GET, and POST to a path that cannot change data), and `ddev pull pantheon`.

Not done, waiting for O-4 (part 2): any push, deploy, wipe, reinstall, restore or CI run.
Pantheon dev still holds the dashboard-installed site (Drupal not installed; every request redirects
to `/core/install.php`), not our code. Every KD-12 number below is labelled with what it reflects.

Pantheon was changed only by `ddev pull pantheon`, which (by design, TC-T07-43) creates two fresh
backups (database and files, `--keep-for=30`) on dev per pull. Two pulls ran (the first run found a
check defect and was repeated), so four backups exist. Nothing on Pantheon's code or database changed.
Local state: the local database and files were overwritten by the pull, then restored from a dump and
archive taken first (scratchpad); `ddev drush config:status` says "No differences", the system.site
UUID equals `config/sync`, the login page answers 200 and `ddev meridian-status` reports OK. The
local snapshots made by TC-T07-42 were deleted.

## Execution

| Run | Command | Result | Evidence |
|---|---|---|---|
| Static and offline harness (the run that counts) | `docs/tests/T07/run-checks.sh` | see "Totals" | `evidence/static-part1.txt` |
| Static, before the later live-script fixes (superseded) | same | 31 PASS, 0 FAIL, 30 BLOCKED | `evidence/static-part1-run0-before-live-script-fixes.txt` |
| T07 `--regression` | `docs/tests/T07/run-checks.sh --regression` | exit 0: 31 PASS, 0 FAIL, 2 BLOCKED (a first run failed once because my own report had a malformed table that the nested T06 pre-commit check linted; fixed and re-run, first run kept) | `evidence/T07-regression-part1.txt`, `evidence/T07-regression-part1-run1-nested-T06-failed-on-report-table.txt` |
| `ddev quality` | `ddev quality` | exit 0: PASS 6, FAIL 0, SKIP 3 (`component-engine`, `component-drupal-tests`, `component-web`) | `evidence/ddev-quality-part1.txt` |
| `pre-commit run --all-files` | `.tools/pre-commit run --all-files` | exit 0 | `evidence/pre-commit-all-part1.txt` |
| T02 to T06 `--regression` | `docs/tests/Txx/run-checks.sh --regression` | all exit 0 (DEF-007) | `evidence/regression-T0*-part1.txt`, `evidence/part1-rc.txt` |
| Live, read-only plus pull | `T07_OWNER_OK=1 T07_CONFIRM_PULL=1 T07_EVIDENCE=1 docs/tests/T07/run-checks.sh --live-only` | TC-T07-30 and 43 Pass; 31, 42, 44, 45, 46 measured in part; rest Blocked | `evidence/live-only-part1.txt`, `evidence/TC-T07-nn.20261102T185155Z.txt` |
| Live, first run (superseded, 2 check defects) | same | TC-T07-31 and 42 FAIL from check defects (DEF-008) | `evidence/live-only-part1-run1-before-check-fixes.txt` |
| Negative controls for the harness | `T07_SKIP_NESTED=1 T07_SCRIPT=<broken copy> docs/tests/T07/run-checks.sh` | each broken copy fails the matching cases | `evidence/negative-controls-part1.txt` |
| Manual read-only live items | scripted `terminus`, `ssh-keyscan`, `curl` | see sections below | `evidence/live-*.txt`, `evidence/host-key-copy1*.txt` |

Negative controls: removing the success-line check and the "giving up" check fails TC-T07-15 and 18;
accepting any `git_url` form fails TC-T07-62; dropping `GlobalKnownHostsFile=/dev/null` fails
TC-T07-14.

## Check fixes made in part 1 (Change log rows are in each `test-cases.md`)

| Fix | Where |
|---|---|
| Fake `workflow:wait` prints `Workflow w1 completed successfully for commit <sha>`; timeout and not-found fakes; fake `auth:whoami` logged out exits 0 with empty stdout | T07 harness |
| TC-T07-15 and 34 expect `workflow:wait --commit=<sha> --start=1` and `env:code-log` on a re-run, no backup, no push; three negative re-run cases (failed, timeout, not found) | T07 |
| `GlobalKnownHostsFile=/dev/null` in TC-T07-07, the harness `GIT_SSH_COMMAND` assertion and every live string | T07 |
| TC-T07-09 expects Terminus 4.3.3, SHA-256 `e7ca9bca...bade`, `--ref "$DEPLOY_REF"` via `env:`, no `${{` in `run:`; TC-T07-10 uses `.tools/actionlint`; TC-T07-23 regex | T07 |
| New cases TC-T07-58 (Terminus pins agree, `--strict`), 59 (`ddev exec terminus --version` = 4.3.3, one path), 60 (budget validation), 61 (subdirectory), 62 (git_url forms, `ssh://` with no key) | T07 |
| TC-T07-07 known-hosts content checks Blocked until the key is committed; TC-T07-27 Blocked until `T07_CLOSE=1` | T07 |
| TC-T04a-33 re-tagged `cka` plus a new secret-shape invariant on `.env.example`; TC-T05-02 checks the `web_environment` values only; TC-T05-23 and TC-T06-12 re-tagged `cka`; TC-T05-21 and TC-T06-19 pass again | T04a, T05, T06 |
| Live script: login with `--machine-token`, `whoami` by stdout, the failure exit read in the same shell command, docroot path for files, TC-T07-44 to 46 split into an edge measurement (part 1) and an installed-site part (after O-4) | T07 |

## Host key, copy 1 (review condition 1, item L-3)

Not written into `scripts/pantheon_known_hosts` (developer-owned; it is committed only after copies
from two days and two networks match).

| Item | Value |
|---|---|
| Taken (UTC) | 2026-11-02T18:02:45Z |
| Network | This machine (WSL2 on the owner's workstation network, home or office line; the tester has no way to name the provider) |
| Host and port | `codeserver.dev.904ad1a6-f47f-4807-af26-a9986348c59d.drush.in`, 2222 (`terminus connection:info meridian-trade.dev --fields=git_host,git_port`) |
| Key types offered | `ssh-rsa` only (ed25519 and ecdsa were requested and not offered); banner `SSH-2.0-Pantheon-SSH` |
| Fingerprint | `SHA256:yPEkh1Amd9WFBSP5syXD5rhUByTjaKBxQnlb5CahZZE` (RSA 2048) |
| Key line | in `evidence/host-key-copy1.txt` (public key; already in `known_hosts` form) |
| Used for | A read-only `git ls-remote` with a temporary pin of this key succeeded; a wrong key failed closed with "REMOTE HOST IDENTIFICATION HAS CHANGED" (`evidence/live-31-discovery.txt`). The committed file was not touched |

The UTC date rolled over only after this machine's local midnight, so the same-day second look is
not copy 2. Copy 2 (the next UTC day, 2026-11-03 from 00:00Z) and copy 3 (second network) are still
owed; the commands are in the last section.

## KD-12 measurements (AC6, review item L-9)

All edge-level results hold whatever Drupal is installed behind the edge. Time: 2026-11-02, 18:03Z
to 18:55Z, from the tester's network. Dev was on the dashboard-installed, not yet installed Drupal.

| Measurement | Result | Reflects |
|---|---|---|
| Sandbox warning page, default `curl` GET (Accept `*/*`), no header | Not intercepted: Drupal's answer (302 to `/core/install.php`) | Edge |
| Same page, GET with `Accept: text/html`, no header | **Intercepted**: HTTP 200, title "Sandbox Environment Notice" (the page sets the cookie `Deterrence-Bypass=1`) | Edge |
| Same GET with the header **`Deterrence-Bypass: 1`** | Passes through to Drupal (302 here). `Deterrence-Bypass: true` also passes for curl; value `1` is the one the page's own cookie uses | Edge |
| POST `/user/login`, POST `/jsonapi`, POST `/jsonapi/node/article`, small bodies, with `Accept: text/html`, with and without the header | **Never intercepted** by the warning page | Edge |
| GET `/jsonapi` and `/`, default curl, with and without header | Not intercepted | Edge |
| User-Agent matrix on `/jsonapi` (no header, and with `Deterrence-Bypass: 1`) | `curl`, `node`, `Wget`: pass. `undici`, `python-httpx`, `python-requests`, `Python-urllib`, `aiohttp`, `Go-http-client`, `Mozilla/5.0...`, `meridian-engine/0.1` and an empty UA: **HTTP 403, Cloudflare managed challenge** (`cf-mitigated: challenge`, title "Just a moment..."). The bypass header does not change it | Edge |
| Body size, POST 8,388,608 bytes and 9,437,184 bytes to `/user/login` | Both answered 302 (not 413, not a connection failure). The 9 MB case also passes, so the limit is above 9 MB here (upper bound not searched) | Edge only; `post_max_size` and `upload_max_filesize` need Drupal after O-4 |
| Cold wake | First request after idle: 15.7 s (GET `/user/login`, 302). `terminus env:wake` on a warm env: 3.7 s to 4.0 s | Edge and platform |
| Warm GET `/user/login` (n=20, default curl) | p50 0.46 s, p95 1.12 s, all 302 | Edge and the not-installed site; re-measure after O-4 for the installed login form |
| Private files probe (needs a file written with drush) | Not run: waits for O-4 | n/a |
| Dev state facts | Connection mode `git`, PHP 8.3, upstream `drupal-composer-managed`, plan Sandbox, framework label `drupal8`; `env:code-log` newest first (key `hash`, 40 hex, 4 entries from the Pantheon upstream); `backup:list` is empty before the pulls | Pantheon |

What this means for the plan:

- The deploy script's smoke check uses plain `curl` (no `Accept: text/html`): it is not intercepted,
  so `DEPLOY_SMOKE_HEADER` can stay empty. Add `Deterrence-Bypass: 1` only for HTML GETs (browsers
  are served the page once and the cookie lasts a day).
- DEF-009 (open, Medium): the Cloudflare challenge on non-allowlisted User-Agents blocks a Python
  engine client (T10) on the Sandbox dev host, with or without the header. Next.js server fetches
  (`node` UA) pass; `undici` does not, so T21 must send an explicit allowed User-Agent or verify.

## Live items from the review (L-1 to L-14)

| Item | Part 1 result | Evidence |
|---|---|---|
| L-1 login with the PAT in the web container | Done: `terminus auth:login --machine-token="$TERMINUS_MACHINE_TOKEN"` exit 0 (output discarded), `whoami` returns an email. The token (and its first 10 characters) appears in no file under `docs/`, `scripts/` or `.github/`; email addresses were redacted. Note: DDEV's git-ignored generated files `.ddev/.ddev-docker-compose-*.yaml` hold the global `web_environment` values, as DDEV does by design; they are not tracked | `evidence/live-L2-whoami.txt` |
| L-2 `auth:whoami` logged out | Confirmed: exit 0, empty stdout, notice "You are not logged in." on stderr | `evidence/live-L2-whoami.txt` |
| L-3 host key | Copy 1 taken. `connection:info` gives `ssh://codeserver.dev.<uuid>@codeserver.dev.<uuid>.drush.in:2222/~/repository.git`; `git ls-remote` with the temporary pin shows `refs/heads/master` (and also `refs/heads/main`, `HEAD`, tags); wrong key rejected (TH-6, early). Two days and second network: owed | `evidence/host-key-copy1*.txt`, `live-31-discovery.txt` |
| L-4 `workflow:wait` | Partly: for a commit that does not exist the command ran 51 s, printed "Workflow with commit ... not found after 10 attempts." and **exited 0** (facts c confirmed). Success notice and re-run matching need a real push: part 2 | `evidence/live-L4-wait-notfound.txt` |
| L-5 `env:code-log` | Newest first, key `hash` (40 hex), plus `datetime`, `author`, `labels`, `message` | `evidence/live-L5-code-log.txt` |
| L-6 `backup:create` | Part 2 (the pull created `--keep-for=30` backups through the provider; listing them with the script's flags is part 2) | n/a |
| L-7, L-8 sync path, build facts, reinstall, config:status on our config | Part 2 (needs our code on dev) | n/a |
| L-9 KD-12 | See above (private files probe: part 2) | `evidence/live-44-*.txt`, `TC-T07-44..46` |
| L-10 deploy and idempotent re-run | Part 2 | n/a |
| L-11 `ddev pull pantheon` from a fresh shell | Done: after `snapshot` and `auth:logout`, `env -i ... ddev pull pantheon -y` logged in through the provider ("Logged in via machine token"), took a fresh backup for the database and for the files, then pulled both; exit 0. Content assertions (UUID, config:status, users) wait for the reinstall | `evidence/TC-T07-42.20261102T185155Z.txt`, `TC-T07-43...` |
| L-12 split SHA across git versions | Pass: host git 2.34.1 and container git 2.39.5 give the same split SHA for `HEAD` (`2a60eba8...`) and `origin/main` (`308a49a3...`) | `evidence/live-L12-split-sha.txt` |
| L-13 CI runner | Part 2 / owner (O-6, O-7) | n/a |
| L-14 gitleaks over the split history | Part 2 | n/a |
| `ddev push pantheon` negative (review finding 20) | Not run (must not run against the live site). The DDEV v1.24.4 behaviour for a provider without push commands is still to be confirmed from its documentation in part 2 | n/a |

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T07-01 to 06, 08 to 26, 28 | AC1 to AC6 static, C4 to C6, SIM | Pass (static and harness) | `evidence/static-part1.txt` |
| TC-T07-07 | SA-4 | Blocked: awaiting L-3 (known-hosts content checks); the strict `GIT_SSH_COMMAND` check passes | `evidence/static-part1.txt` |
| TC-T07-27 | C5 | Blocked: at-close (`T07_CLOSE=1`) | `evidence/static-part1.txt` |
| TC-T07-30 | AC1 | Pass | `evidence/TC-T07-30.20261102T185155Z.txt` |
| TC-T07-31 | KD-1, R5 | Blocked in part: `git_url` form and `backup:create` failure exit Pass; pinned `ls-remote` awaits L-3 | `evidence/TC-T07-31.20261102T185155Z.txt`, `live-31-discovery.txt` |
| TC-T07-42 | AC3 | Blocked in part: pull exit 0, fresh-shell login, files dir Pass; UUID, config:status, users await O-4 | `evidence/TC-T07-42.20261102T185155Z.txt` |
| TC-T07-43 | AC3 | Pass | `evidence/TC-T07-43.20261102T185155Z.txt` |
| TC-T07-44, 45, 46 | AC6 | Measured (edge assertions Pass); installed-site assertions await O-4 | `evidence/TC-T07-44..46.20261102T185155Z.txt` |
| TC-T07-32 to 41 (except 31), 47 to 49 | AC4, AC5, AC6 | Blocked: awaiting O-4 (part 2) (TC-T07-41 also awaits L-3) | n/a |
| TC-T07-50, 51, 53, 54, 57 | AC4, C7 | Blocked: owner-run or CI (O-5 to O-7); TC-T07-50 needs the owner's written acceptance at close | n/a |
| TC-T07-52 | AC4 | Pass (2026-11-03): one RSA fingerprint `SHA256:yPEkh1Am...ZZE` on 2026-11-02 and 2026-11-03 and from a phone hotspot; equals `scripts/pantheon_known_hosts`; no host key list published (Terminus re-checked 2026-11-03); pinned `ls-remote` exit 0 | `evidence/TC-T07-52.20261103T061000Z.txt`, `evidence/host-key-copy1.txt`, `host-key-copy2.txt`, `host-key-copy3-second-network.txt` |
| TC-T07-56 | AC2 | Pass (2026-11-03): runbook PAT row 2026-11-01 / 2027-01-30, `auth:login --machine-token` and `auth:whoami` exit 0 in `ddev exec`, owner confirms no PAT value pasted | `evidence/TC-T07-56.20261103T062710Z.txt` |
| TC-T07-55 | C7 | Blocked: `T07_CONFIRM=1 ... --clean-clone` stops the project's DDEV; runs in part 2 | n/a |
| TC-T07-58 to 62 | AC3, AC4, C4 | Pass | `evidence/static-part1.txt` |

Totals (61 cases): 35 pass, 0 fail, 26 blocked (5 of the blocked ones were measured in part and
their executed checks passed: TC-T07-31, 42, 44, 45, 46), 0 not run.

## Cases waiting for part 2 (O-4 and later)

- Needs the deploy: TC-T07-32 (deploy), 33 (verification), 34 (re-run), 35 (rewind), 36 and 37
  (`config:status`, sync path), 38 (build facts), 40 (host key pinning on push), 48 (database-only
  restore, `T07_CONFIRM_RESTORE=1`), 49 (history replaced).
- Needs the reinstall (`T07_CONFIRM_WIPE=1`): TC-T07-39, then the content assertions of
  TC-T07-42 and the installed-site parts of TC-T07-44 to 47 (including the private files probe).
- Needs the committed host key: TC-T07-07 content checks, TC-T07-40, 41 (key committed
  2026-11-03; TC-T07-52 passed).
- Owner-run or CI: TC-T07-50, 51, 53, 54, 57 (TC-T07-52 and 56 passed 2026-11-03); TC-T07-55
  in a clean clone; TC-T07-27 at close.
- Review conditions 3 and 4: the "completed successfully for commit" line on the first deploy and
  on the re-run (L-4, L-10); the finding-13 ticket stays with the solution-architect.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| DEF-006 T07 harness predates the build confirmation | Low (test design) | Retest passed |
| DEF-007 Earlier regression suites fail on T07's legitimate changes | Low (test design) | Retest passed |
| DEF-008 Remaining T07 check problems (review list and first live run) | Low (test design) | Retest passed |
| DEF-009 Cloudflare challenge for non-allowlisted User-Agents on the Sandbox edge | Medium (design assumption, affects T10, T21, T28) | Open |

## Coverage notes

- No product defect in the T07 deliverables was found in part 1. The deploy script, the workflow
  and the provider behaved as the Terminus 4.3.3 facts record says wherever they could be probed
  without a push (facts c, f and h confirmed live).
- Still unverified until part 2: the success notice and `--start=1` matching on a real workflow
  (review condition 3), the first-deploy "not found after 10 attempts" risk, `config_sync_directory`
  on Pantheon, KD-6 reinstall, restore, the private files path.
- The warm GET latency and wake time are for the not-installed Drupal; the installed login form
  needs a re-measure after O-4.

## Sign-off

**Not signed off.** Part 1 of 2: 0 Fail, 28 Blocked (awaiting O-4, the committed host key, the owner
or CI). DEF-009 is open (Medium, for T10 and T21; it does not block T07 close by the severity rules
but needs a technical-architect decision). Tester, 2026-11-02.

## Host key copies 2 and 3: commands

Copy 2: run on the same machine on the next UTC day (2026-11-03 from 00:00Z), and paste the output:

```bash
date -u +%FT%TZ; ssh-keyscan -p 2222 -t rsa,ecdsa,ed25519 codeserver.dev.904ad1a6-f47f-4807-af26-a9986348c59d.drush.in 2>/dev/null | ssh-keygen -lf -
```

Copy 3: run the same line from a second network (phone hotspot or another site's line) and note
which network it was:

```bash
date -u +%FT%TZ; ssh-keyscan -p 2222 -t rsa,ecdsa,ed25519 codeserver.dev.904ad1a6-f47f-4807-af26-a9986348c59d.drush.in 2>/dev/null | ssh-keygen -lf -
```

Expected on every copy: one line, `2048 SHA256:yPEkh1Amd9WFBSP5syXD5rhUByTjaKBxQnlb5CahZZE ... (RSA)`.
Any other fingerprint, or any extra key type, stops the process (SA-4, decision 4).
