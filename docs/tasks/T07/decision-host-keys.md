# T07: Solution-architect decision on SSH host key pinning (SA-4)

| Field | Value |
|---|---|
| Task | T07 |
| Author | solution-architect |
| Date | 2026-11-02 |
| Answers | `docs/tasks/T07/plan.md` (Draft), "Decisions needed from solution-architect", SA-4; KD-2, R3, R4, TH-6 |
| Related | technical-design D8 step 3 ("The Pantheon SSH host key is pinned"); `decision-rollback.md` |

## Context

The plan pins host keys for both the code server (`git push`) and the app server
(`terminus remote:drush`) in `scripts/pantheon_known_hosts`, with strict checking. SA-4 asks for
a fallback if the app server key changes.

Facts checked:

- Pantheon says users "will be prompted to confirm connections following a container
  migration, which is part of regular maintenance" (S1). So the **app server host key is
  expected to change** during normal operation, without notice.
- Pantheon publishes no host key list and no API that returns host keys, as far as found
  (**unverified**: no such page or Terminus command was found on 2026-11-02).
- Terminus 3.x builds the drush SSH command as: configured `ssh_command`, then `-T user@host -p
  port -o "StrictHostKeyChecking=no" -o "AddressFamily inet"` (S2). The configured command comes
  first, so with OpenSSH's first-value-wins rule an option placed in `TERMINUS_SSH_COMMAND`
  overrides Terminus's `StrictHostKeyChecking=no`. The plan's mechanism works; strict pinning of
  the app server is possible, but it would break at every container migration.
- Terminus replaces the host name with an IP address only when `TERMINUS_ALTERNATE_NAMESERVER`
  is set (S2). Do not set it, or the pinned names stop matching.

## Decision

**Option (a), with an out-of-band check.** Pin the **code server** strictly. Do **not** pin the
**app server**. Verify the deploy result over channels that are authenticated by TLS.

1. `scripts/pantheon_known_hosts` holds the code server key line(s) only
   (`[codeserver.dev.<site-uuid>.drush.in]:2222`). `GIT_SSH_COMMAND` keeps
   `-o StrictHostKeyChecking=yes -o UserKnownHostsFile=<repo>/scripts/pantheon_known_hosts
   -o BatchMode=yes`.
2. `TERMINUS_SSH_COMMAND` is `ssh -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o
   LogLevel=ERROR`. This states openly that the app server is not pinned, keeps runs
   deterministic (no stale entry in a home `known_hosts`), and does not pretend otherwise.
3. **Out-of-band verification after the push** (new stage, between plan stages 5 and 6):
   `terminus env:code-log meridian-trade.dev --format=json` (Pantheon API over HTTPS) must show
   the split SHA as the newest commit. The final smoke check (stage 8) is HTTPS with certificate
   verification and checks a Drupal marker in the body (see `decision-scope.md`, item on the
   sandbox interstitial).
4. **If the code server key also changes** (seen in the two-day comparison of KD-2, or as a
   later deploy failure): the deploy stops (fail closed). The owner fetches the new key from
   two networks (owner machine, and a GitHub-hosted runner or a phone hotspot), compares the
   SHA256 fingerprints, and commits the new line through a reviewed pull request. If it changes
   more than once in 90 days, the technical-architect may drop code server pinning too, and
   step 3 becomes the only integrity check; record that as a review finding with dates.
5. TH-6 changes: the negative test applies to `git push` only (wrong code server key must fail
   with a host key error). For `remote:drush`, a test asserts that `TERMINUS_SSH_COMMAND` is set
   exactly as in step 2 and that `TERMINUS_ALTERNATE_NAMESERVER` is unset.

## Reasons

1. **Deploys must not break during routine Pantheon maintenance** (S1). Option (c) would turn
   each container migration into a failed deploy and a manual key update with nothing to compare
   the new key against.
2. **The code push carries the payload that matters.** A rogue code server could accept a push
   and report success; pinning blocks that, and the code server is not described as migrating.
3. **The drush channel carries no secret.** SSH public-key authentication does not reveal the
   private key, and the drush commands (`updatedb`, `config:import`, `cache:rebuild`,
   `config:status`) contain no secrets. A rogue app server could at most fake drush output.
   Step 3 and the TLS smoke check catch a faked result, because they do not depend on SSH.
4. **Option (b) has no source.** No Pantheon API that returns host keys was found.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| (b) Fetch the app server key per run through an authenticated Terminus call | No such API found (unverified); `ssh-keyscan` at run time is trust-on-first-use and adds nothing over not pinning |
| (c) Strict pinning of both, update the file on change | Breaks at every container migration (S1); each update is an unverifiable key swap |
| No pinning at all (Terminus default for both) | The `git push` path can be pinned cheaply, and it matters most |
| `StrictHostKeyChecking=accept-new` with a cached file | Breaks on the first migration in the same way as (c), or must be cleared, which is the same as no pinning |

## Consequences

- Plan R3 is resolved for drush (no pinning by design); R4 applies to the code server only.
- D8 step 3 text changes (below).
- `scripts/pantheon_known_hosts` holds a comment that says the app server is deliberately not
  pinned and why, with a link to this file.
- One more Terminus API call per deploy (stage 3 above), negligible time.

## Unverified items and how T07 verifies them

| Item | How T07 verifies |
|---|---|
| Code server key stays stable | `ssh-keyscan -p 2222` on two different days (KD-2) and once from a second network; record fingerprints and dates |
| App server key changes after a container migration | Not forced; record any change seen during T07 with the date |
| `env:code-log` newest `hash` equals the pushed split SHA right after `workflow:wait` | First real deploy (plan step 10) |
| Pantheon publishes host keys anywhere | Re-check docs search at review; record "none found" with date |

## Wording changes proposed for `docs/TASKS.md` (owner's document: propose only)

None.

## Technical-design and ADR follow-ups (technical-architect applies in plan step 11)

- **D8 step 3.** Replace "The Pantheon SSH host key is pinned in the workflow's `known_hosts`
  (T07 records it)." with:

  ```text
  The Pantheon code server host key is pinned in `scripts/pantheon_known_hosts` with strict
  checking. The app server (drush) is not pinned, because Pantheon changes it at container
  migrations; after the push, `terminus env:code-log` (HTTPS) must show the split SHA, and the
  smoke check is HTTPS (docs/tasks/T07/decision-host-keys.md).
  ```

- **Unverified register.** Close "SSH host key" with the fingerprint, dates and this decision.
- **ADR-0004.** No change.

## Sources (all checked 2026-11-02)

- S1: [SSH keys](https://docs.pantheon.io/ssh-keys) ("Last Reviewed 2026-09-22"): prompt to
  confirm connections after a container migration, "part of regular maintenance"
- S2: [Terminus 3.x source, `SSHBaseCommand.php`](https://github.com/pantheon-systems/terminus/blob/3.x/src/Commands/Remote/SSHBaseCommand.php)
  (`getConnectionString()`, `lookupHostViaAlternateNameserver()`), branch `3.x` as of the check
  date; the plan's installed Terminus is 3.6.2, so the developer confirms the same code in that
  tag
- S3: [terminus env:code-log](https://docs.pantheon.io/terminus/commands/env-code-log): output
  field `hash`

## Open questions

- None for the owner. If the code server key changes during T07, raise it at review (step 4).
