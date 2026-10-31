# ADR-0004: Monorepo with subtree deploy of apps/drupal to Pantheon

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-11-01 |
| Deciders | solution-architect (author), technical-architect (reviewer, T02 sign-off) |

## Context

The project keeps the engine, Drupal, Next.js, DDEV config, docs and workflows in one
repository (`docs/TASKS.md` section 4). One task can then change the contract and both sides
of it in one reviewed commit, and the traceability matrix points at one history.

Pantheon builds each site from its own Git repository, and that repository's root must be
the Drupal Composer root. In our monorepo the Composer root is `apps/drupal` (docroot `web/`).
Vercel can build a sub-directory (`apps/web`) of a monorepo directly.

Details of Pantheon's build (Integrated Composer and the dev branch name) are **unverified**
here. T07 confirms them against the Pantheon docs.

## Decision

We keep a **single monorepo** on GitHub as the only place developers commit. `deploy-drupal.yml`
deploys Drupal:

1. Run `git subtree split --prefix=apps/drupal` to produce a branch whose root is the Drupal
   Composer root.
2. Push that split branch to the Pantheon site's Git remote. This updates the dev
   environment.
3. Run config import with Terminus and drush. The workflow wakes the environment first,
   because Pantheon containers sleep when idle.

The Pantheon repository is a **deploy target only**. Nobody commits to it by hand. The
Terminus machine token lives only in GitHub Actions secrets.

Vercel builds `apps/web` from the same repository. The engine image builds from
`services/engine`.

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
|---|---|---|---|
| Separate repository for Drupal | Native Pantheon workflow | Cross-component changes span repos. Two histories to trace. Contract drift | Loses atomic changes and one traceability history |
| Pantheon repository as the primary for everything | No deploy step | Pantheon expects a Drupal root, so the engine, Next.js and docs do not fit. Pantheon is not the review platform | Breaks the monorepo layout and the PR review loop |
| Build artifact push (Composer install in CI, push vendor to Pantheon) | Full control of the build | Large pushes. Duplicates what Pantheon's build may already do | More complex than needed. Kept as fallback if T07 finds the subtree push insufficient |
| `git filter-repo` mirror instead of subtree | Clean history | Rewrites history on every run. Heavier tooling | The subtree split is simpler and built into Git |

## Consequences

- Positive: One source of truth, atomic cross-component commits, and one place for review,
  CI and secrets. DDEV uses `composer_root: apps/drupal` locally, the same layout as the
  deploy.
- Negative: The split cost grows with history (acceptable at this size). The Pantheon
  remote history differs from GitHub's. A manual commit on Pantheon would be overwritten (by
  policy, never do this).
- Follow-ups: T05 (layout matches `pantheon.yml`), T07 (deploy path, Integrated Composer
  check, rollback, sleep behaviour in `docs/runbooks/deploy.md`), T08 (CI), T28 (deployed
  dev).
