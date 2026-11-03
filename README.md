# Meridian

Simulation-only research agent for NSE (India) equities.

> **Scope guard:** Meridian never places real orders. It contains no broker SDK or
> order-placement code.

Simulation-only research software. It places no orders and gives no investment advice.

Meridian has three parts:

- A Python engine that analyses a watchlist once per trading day.
- Drupal, which stores the records and provides the admin.
- A Next.js dashboard that shows decisions, positions and reports.

## Status

The project is in **Phase 0 (Foundation)**. See `docs/PROGRESS.md` for status and
`docs/TASKS.md` for the full plan.

## Getting started (Phase 0)

You need `git`, Python 3.9 or newer, and `curl`.

```bash
git clone git@github.com:iamPawanSaini/Meridian.git meridian
cd meridian
scripts/bootstrap-dev.sh       # installs pinned pre-commit into .tools/ and the git hooks
.tools/pre-commit run --all-files
```

The Drupal part of the local stack runs in DDEV (Docker and DDEV v1.24 or newer needed). Follow
`docs/runbooks/local-setup.md`: `ddev start`, then `ddev drupal-install`, then `ddev drush uli`.
Since T06 `ddev start` also runs `meridian-postgres`, `meridian-engine` and `meridian-web`
(check with `ddev meridian-status`). `https://meridian.ddev.site:3001` serves a placeholder until
T21.

## Repository layout

| Folder | Purpose |
|---|---|
| `.claude/` | Claude Code agents, workflow commands and hooks |
| `.ddev/` | DDEV configuration and custom commands (from T05) |
| `apps/drupal/` | Drupal 11 Composer root (from T05) |
| `apps/web/` | Next.js dashboard (from T21) |
| `services/engine/` | Python engine `meridian_engine` (from T13) |
| `scripts/` | Repository tooling |
| `docs/` | Plans, architecture, tests, runbooks, templates |
| `.github/workflows/` | CI and scheduled runs (from T08) |

## How work is done

Each task goes through plan, test design, build, review, test and close. Claude Code
subagents do these steps. See `docs/process/WORKFLOW.md` and `CLAUDE.md`.
