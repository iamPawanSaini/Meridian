# T07: Solution-architect decision on CI credentials for Pantheon (SA-1)

| Field | Value |
|---|---|
| Task | T07 |
| Author | solution-architect |
| Date | 2026-11-02 |
| Answers | `docs/tasks/T07/plan.md` (Draft), "Decisions needed from solution-architect", SA-1; KD-10 |
| Related | technical-design D7 (`TERMINUS_MACHINE_TOKEN`, `PANTHEON_DEPLOY_KEY`), D8; ADR-0004; plan O-1, O-5, O-6, R6; `decision-scope.md` (SA-7) |

## Context

D7 says `PANTHEON_DEPLOY_KEY` belongs to a dedicated Pantheon machine user that is a member of
`meridian-trade` only. The plan asks whether the same machine user should also own the CI
Terminus token, what to do if a Sandbox site cannot add a team member, and whether a second
Pantheon account fits Pantheon's terms.

## New fact that changes the plan: tokens now expire after 90 days

Since **2026-09-30** Pantheon no longer issues machine tokens. New tokens are **Personal Access
Tokens (PATs)** that **expire 90 days after creation**; after that `terminus auth:login` fails.
Existing machine tokens keep working and do not expire, but none can be created. The Terminus
flag `--machine-token` accepts both. Pantheon recommends PATs for "bot users" that run Terminus
from a CI server and says the stored CI secret must be rotated periodically (sources S1 to S3).

Consequences for T07, whatever the answer to SA-1:

1. O-1 creates a **PAT** (Personal Settings, Personal Access Tokens), not a machine token. The
   Pantheon page notes that tokens cannot be generated in Microsoft Edge (S2).
2. The variable name `TERMINUS_MACHINE_TOKEN` **stays** (DDEV provider, Terminus and D7 use it).
   Its description becomes "Pantheon personal access token (PAT, formerly machine token)".
3. The runbook records the creation date and the expiry date (creation plus 90 days) of every
   PAT in use, without the value, and a rotation step: create the new PAT, replace it in every
   store (global DDEV config, GitHub Secrets), run `terminus auth:whoami`, revoke the old one.
4. Before the T31 live-simulation window starts, any PAT that expires within the window plus
   7 days is rotated first. The daily engine run does not use Terminus, so an expired PAT
   breaks deploys and `ddev pull pantheon`, not the daily run.

## Decision

1. **(a) Yes.** The required CI design is one **machine user** that owns **both** CI
   credentials: its own PAT (`TERMINUS_MACHINE_TOKEN` in GitHub Secrets) and its own RSA key
   (`PANTHEON_DEPLOY_KEY`). It is a member of `meridian-trade` only, with the lowest role that
   can push to dev and run drush there (Developer if Sandbox offers it, otherwise the default
   team-member role). It creates no sites of its own.
2. **(b) If a Sandbox site cannot add the machine user, deploys stay local-only**
   (`ddev deploy-drupal` with the owner's credentials on the owner's machine). The workflow
   `deploy-drupal.yml` is still merged with its "not configured, skipped" guard, and
   `PANTHEON_SITE` stays unset in GitHub Variables, so it never runs a deploy. The owner's
   credentials do **not** go into GitHub Secrets by default.
3. Putting the owner's PAT and a key on the owner's account into GitHub Secrets is allowed only
   as an **explicit owner risk acceptance**, written by the owner in their own message and
   recorded in the T07 test report (or a later task's), naming: a CI-only RSA key (not the
   owner's workstation key), a PAT used for nothing else, its expiry date, and the revocation
   step. An agent message is not that acceptance.
4. **(c) Terms of service.** No clause found prohibits a second account used for automation,
   and Pantheon's own PAT documentation describes "bot users" running Terminus from CI (S2).
   The clauses that do apply, and the rules T07 follows because of them:
   - Section 1.4(b) of the WebOps Services Agreement forbids use "intended to avoid incurring
     fees or exceeding usage limits or quotas" (S4). The machine user must **never create
     sandbox sites** (each account gets two, S5). Its only purpose is access to
     `meridian-trade`.
   - Section 1.3 requires accurate registration data and adequate control of credentials
     (S4). Register the machine user with a mailbox the owner controls (for example a plus
     address of the owner's address) and a name that says it is the Meridian CI bot.
   - Status: **partly unverified.** The agreement page is very long and only its first part
     was read; the Acceptable Use Policy was not read. This is not legal advice. How T07
     verifies: the owner reads the account and acceptable-use sections before creating the
     account (O-5) and records "read, no conflict found" with the date in the T07 test report.

## Reasons

1. **Blast radius.** A PAT "provides the same access as your username and password" (S1), so
   the owner's PAT in GitHub reaches every site and workspace of the owner, including site
   deletion. A machine user that belongs to one site limits a leak to that site, whose only
   data is a dev database that can be rebuilt from `config/sync`.
2. **One identity per pipeline.** The key and the token of one account means one place to
   revoke and one audit trail in the Pantheon dashboard ("who pushed").
3. **Local-only is the simplest safe fallback.** Meridian has one owner and few Drupal deploys.
   `ddev deploy-drupal` runs the same script as the workflow (plan KD-1), so nothing is lost
   in correctness; only the automatic trigger on merge is lost. It adds no new secret store.
4. **PAT expiry limits, but does not remove, the risk.** A 90-day token in GitHub is better
   than a non-expiring one, but 90 days of full account access is still too wide to be the
   default.
5. **Cost.** A second Pantheon account is free (Silver plan USD 0 per month, S5), so NFR-09
   holds.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| Owner PAT and owner key in GitHub Secrets by default | Account-wide access in CI (reason 1). Allowed only by explicit owner risk acceptance (decision 3) |
| Machine user for the SSH key only, owner PAT for Terminus | Two identities, and the wide credential is the token, so the main risk stays |
| Transfer site ownership to the machine user | The owner would then depend on the bot account to manage the site; harder recovery if the bot account is locked |
| Ask the owner to keep a legacy machine token for CI | None can be created after 2026-09-30 (S3) |
| Self-hosted runner on the owner's machine | Adds a long-running service and a runner token; not simpler than local-only |

## Consequences

- O-5 becomes: create the machine user account (no sites), invite it with `terminus
  site:team:add meridian-trade <bot email> [role]` or the dashboard Team page, create its RSA
  key and its PAT, record both dates. If the invite fails on Sandbox, record the exact error,
  the date and the command in `docs/tests/T07/evidence/`, and decision 2 applies.
- O-6 and O-7 happen only if O-5 succeeds or the owner gives the acceptance in decision 3.
- The T07 test report states which branch applied: "machine user", "local-only", or "owner
  credentials accepted (date)".
- Plan R6 mitigation text becomes: "machine user, or local-only deploys; owner credentials in
  CI only with written owner acceptance".

## Unverified items and how T07 verifies them

| Item | Status | How T07 verifies |
|---|---|---|
| A Sandbox site can add a team member (second account) | Unverified. `site:team:add` exists with no plan restriction stated (S6); the Teams page does not say whether Sandbox sites can add members (S7) | O-5 attempt; evidence is the command output or dashboard screenshot with date |
| Role names on a Sandbox site team, and whether "Developer" exists there | Unverified. The Teams page describes Developer as deploy-to-Dev only (S7), but plan scope is not stated | `terminus site:team:list meridian-trade` after the invite; record the role |
| Machine user can push to dev and run `remote:drush` | Unverified | The phase 3 CI run (plan) or one local run with the bot key and PAT loaded |
| No ToS clause against automation accounts | Partly unverified (decision 4) | Owner reads the terms and AUP and records the date |

## Wording changes proposed for `docs/TASKS.md` (owner's document: propose only)

T07, criterion 2. Current text:

```text
- [ ] Terminus machine token setup documented; token never committed (secret scan passes)
```

Proposed text:

```text
- [ ] Terminus personal access token (PAT, formerly machine token) setup and 90-day rotation documented; token never committed (secret scan passes)
```

## Technical-design and ADR follow-ups (technical-architect applies in plan step 11)

- **D7, `TERMINUS_MACHINE_TOKEN` row.** Meaning: "Pantheon personal access token (PAT,
  formerly machine token; expires 90 days after creation). CI: the machine user's PAT".
- **D7, paragraph under the matrix.** Replace "Whether a Sandbox site can add such a machine
  user is **unverified** (T07)." with the T07 result, and add: "If no machine user is possible,
  Drupal deploys are local-only (`ddev deploy-drupal`) and GitHub holds no Pantheon secret
  (`docs/tasks/T07/decision-ci-credentials.md`)."
- **Unverified register.** Close "machine user on Sandbox" with the result and date.
- **ADR-0004.** Its decision says "The Terminus machine token lives only in GitHub Actions
  secrets." That is no longer accurate (local deploys use the owner's PAT in the global DDEV
  config). Add a dated follow-up note, no new ADR (the decision, subtree split and push, is
  unchanged):

  ```text
  Follow-up (2026-11-02, T07): Pantheon tokens are personal access tokens that expire after
  90 days. CI uses a machine user's PAT in GitHub Secrets; local deploys and `ddev pull
  pantheon` use the owner's PAT in the global DDEV config. If no machine user is possible,
  deploys are local-only. Rollback is revert-forward (docs/tasks/T07/decision-rollback.md).
  ```

## Sources (all checked 2026-11-02)

- S1: [Creating and Revoking Machine Tokens](https://docs.pantheon.io/machine-tokens) (page now
  covers PATs; "Last Reviewed 2026-09-21")
- S2: [Personal Access Tokens](https://docs.pantheon.io/personal-access-tokens) ("Last Reviewed
  2026-09-21"): 90-day expiry, bot users in CI, Edge limitation
- S3: [Release note: personal access tokens](https://docs.pantheon.io/release-notes/2026/09/personal-access-tokens)
  (2026-09-30)
- S4: [Pantheon legal: WebOps Services Agreement v39.2, effective 2025-09-16](https://legal.pantheon.io/)
  (sections 1.3, 1.4, 14; first part of the page read only)
- S5: [Pantheon pricing](https://pantheon.io/plans/pricing) and
  [Site Hosting Plans](https://docs.pantheon.io/guides/account-mgmt/plans/site-plans) ("Last
  Reviewed 2026-07-27": "two Sandbox sites for all user accounts")
- S6: [terminus site:team:add](https://docs.pantheon.io/terminus/commands/site-team-add)
- S7: [Teams](https://docs.pantheon.io/guides/account-mgmt/workspace-sites-teams/teams) ("Last
  Reviewed 2026-09-15")
- S8: [SSH keys](https://docs.pantheon.io/ssh-keys) ("Last Reviewed 2026-09-22"): keys belong
  to user accounts; RSA or 256-bit ECDSA, no ed25519

## Open questions

- Owner decides at O-5 time: create the machine user (recommended), or stay local-only.
- Owner records the PAT expiry dates in the runbook table (no values).
