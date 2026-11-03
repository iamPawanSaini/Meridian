# T07: Solution-architect decision on rollback and pre-deploy backups (SA-2)

| Field | Value |
|---|---|
| Task | T07 |
| Author | solution-architect |
| Date | 2026-11-02 |
| Answers | `docs/tasks/T07/plan.md` (Draft), "Decisions needed from solution-architect", SA-2; KD-1 stage 5, KD-9, R8 |
| Related | technical-design D8; ADR-0004; T29 (backup and restore drill); `decision-ci-credentials.md` (ADR-0004 note) |

## Context

D8 says "Rollback is a manual dispatch with the previous good ref". With a non-force push the
split of an older ref is an ancestor of Pantheon `master`, so the push is a rewind and is
rejected (plan KD-9). The plan proposes revert-forward plus a database restore, and asks
whether every deploy should take a database backup.

Two Pantheon facts shape the answer:

- The **dashboard Restore button restores code, database and files together**, "resets the
  codebase" to the backup's state, is destructive and is queued (S1). A code reset on Pantheon
  `master` is a Pantheon-side change, so the next non-force push from GitHub would be rejected
  or would rewind it (exact behaviour unverified).
- `terminus backup:restore <site>.<env>` takes `--element` (`all`, `code`, `files`,
  `database`, `db`) and `--file`. **Without `--element` it restores the most recent backup of
  any type** (S2). `backup:create` takes `--element` and `--keep-for` (days; default 365, S3).
  Sandbox sites have no automatic backups; manual backups are available on all sites (S4, S5).

## Decision

1. **Accept revert-forward as the only normal code rollback.** `git revert` the bad change on
   a task branch, merge it to `main` with a merge commit, deploy `main` (workflow or
   `ddev deploy-drupal`). Config-only rollbacks are the same: the reverted `config/sync` is
   re-imported by the deploy.
2. **Database rollback is a database-only restore** of the pre-deploy backup, by file name:
   `terminus backup:restore meridian-trade.dev --file=<name>_database.sql.gz --yes` (amended
   2026-11-03, DEF-011: the original "both options, `--element=db --file`" is refused by Terminus
   4.3.3 with "You cannot specify a file and an element at the same time"), the
   file name taken from `terminus backup:list meridian-trade.dev --element=db`. After it:
   `cache:rebuild`, `config:status`, and the smoke check.
3. **Forbidden on Pantheon dev:** the dashboard Restore button, `backup:restore` without
   `--file` of a `_database.sql.gz` backup, and `--element=all` or `--element=code`. Reason:
   they reset code on Pantheon, which breaks the non-force deploy path. The runbook
   says this in a warning box.
4. **Force push is an owner-only emergency step**, documented with the exact command, used only
   when a revert cannot reach `main` in time. Steps: backup (`--element=db`), push the split of
   a commit **that is on `main`** with `git push --force`, run stages 6 to 8 of the script by
   hand, then record the event in the runbook log. Because the rewind target is an ancestor of
   later `main` splits, the next normal deploy fast-forwards again.
5. **Every deploy that pushes takes a database backup first** (stage 5), with
   `--element=db --keep-for=30`. A failed backup fails the deploy (exit 1) before the push. An
   idempotent re-run that skips the push (plan KD-1 stage 4) takes no new backup.
6. **Deploy only commits that are, or will become, ancestors of `main` through a merge
   commit.** A deploy of a task-branch commit (T07 phase 2) is fine only if that branch is
   merged with a merge commit. A squash or rebase merge gives `main` new SHAs, so its split
   no longer descends from Pantheon `master` and the next non-force push is rejected. The
   script should refuse a `--ref` that is not an ancestor of `origin/main` unless an explicit
   `--allow-unmerged` flag is given (technical-architect to decide the exact guard).
7. **Test the restore once in T07.** The runbook claims a procedure, so T07 runs it once on
   dev (dev holds no project data): create a backup, change one config value with drush,
   restore with decision 2, check the value is back and that `terminus env:code-log
   meridian-trade.dev` and `git ls-remote` of `master` are unchanged (code untouched). The
   full drill with timings stays in T29.

## Reasons

1. Revert-forward keeps one linear history that GitHub and Pantheon agree on, uses the reviewed
   path, and needs no new privilege.
2. A database-only restore is the only restore that does not touch code (S1, S2).
3. The 30-day retention covers the T31 window and later investigation, without keeping a year
   of backups by default (S3). The database is small at this stage, so the extra time per
   deploy is small; T07 records it (unverified until measured).
4. Decision 6 prevents a failure that the non-force rule would otherwise create silently at
   the first squash merge.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| Keep D8 "dispatch the previous good ref" | Rejected by the non-force push (KD-9); would need force on every rollback |
| Force-push rollback as the normal path | Rewrites Pantheon history routinely and removes the "manual commit fails loudly" guard |
| Dashboard Restore | Resets code too (S1); breaks the deploy path |
| No backup per deploy, rely on scheduled backups | Sandbox has no automatic backups (S5) |
| Backup with default retention (365 days) | Keeps old data far longer than needed; storage limits on Sandbox unverified |

## Consequences

- KD-1 stage 5 adds `--keep-for=30`; stage 1 adds the ancestor guard (decision 6).
- The runbook has sections "Roll back code", "Restore the database", "Emergency force push",
  with the warnings of decision 3.
- T08 must keep merge commits for pull requests that touch `apps/drupal` (no squash or rebase
  merge), or the deploy guard of decision 6 must restrict deploys to `main`. This is a T08
  input; record it in the T08 plan.
- A deploy now takes longer by the backup time; measured in T07.

## Unverified items and how T07 verifies them

| Item | How T07 verifies |
|---|---|
| `--element=db` restore leaves code untouched | Decision 7 restore test |
| A dashboard or code restore creates a Pantheon-side change that breaks the next non-force push | Not tested (forbidden by policy); stays unverified, which is why it is forbidden |
| Backup and restore time for the current database | Timed in decision 7; recorded in the runbook |
| Limits on the number or storage of manual backups on Sandbox | Not stated in S4 or S5; record "none observed" with date |
| `backup:create` exit code when the backup fails | Developer checks with a stub and one real run; record in plan R5 style |

## Wording changes proposed for `docs/TASKS.md` (owner's document: propose only)

None. AC6 already asks for the rollback procedure in `docs/runbooks/deploy.md`.

## Technical-design and ADR follow-ups (technical-architect applies in plan step 11)

- **D8.** Replace "Rollback is a manual dispatch with the previous good ref (T07 documents it in
  `docs/runbooks/deploy.md`)." with:

  ```text
  Rollback is revert-forward: revert on a branch, merge to `main` with a merge commit, deploy.
  Every deploy that pushes first takes a database backup (`--element=db --keep-for=30`); a
  database rollback restores that backup with `--element=db --file=...` only. Code restores
  on Pantheon and the dashboard Restore button are not used. A force push is an owner-only
  emergency step (`docs/runbooks/deploy.md`; `docs/tasks/T07/decision-rollback.md`).
  ```

- **D8 step list.** Step 2 changes from `git subtree split ... -b pantheon-deploy` to the
  plan's `git subtree split` with no `-b` (plan KD-1), and a step "database backup" is added
  before the push.
- **ADR-0004.** ADR-0004 does not state the rollback mechanism, so its decision is unchanged.
  The dated follow-up note in `decision-ci-credentials.md` mentions revert-forward; no other
  ADR change and no new ADR.

## Sources (all checked 2026-11-02)

- S1: [Restore from backup](https://docs.pantheon.io/guides/backups/restore-from-backup):
  dashboard Restore resets code, database and files; destructive; queued
- S2: [terminus backup:restore](https://docs.pantheon.io/terminus/commands/backup-restore)
- S3: [terminus backup:create](https://docs.pantheon.io/terminus/commands/backup-create)
  (`--keep-for` default 365 days)
- S4: [Backups](https://docs.pantheon.io/guides/backups): manual backups free on all sites,
  kept one or six months from the dashboard
- S5: [Site Hosting Plans](https://docs.pantheon.io/guides/account-mgmt/plans/site-plans)
  ("Last Reviewed 2026-07-27"): "Downgrading to a Sandbox site will disable automatic backups"

## Open questions

- None for the owner. The technical-architect decides the exact ancestor guard (decision 6).
