# Meridian: project memory for Claude Code

## Goal

Meridian is a **simulation-only** research agent for NSE (India) equities.

- A Python engine (`services/engine`, package `meridian_engine`) runs once per trading day.
  It fetches data, scores the watchlist, asks Claude for an analyst review, simulates
  positions and publishes results.
- Drupal 11 (`apps/drupal`, headless, Pantheon dev) stores and manages the records.
- Next.js (`apps/web`, `meridian-web`, Vercel dev) is the authenticated dashboard.

The full task plan is in `docs/TASKS.md`. Status is in `docs/PROGRESS.md`.

## Non-negotiable rule: simulation only

This project **never places real orders**.

- Do not add any broker SDK, broker API client or order-placement code.
- Do not reference broker trading domains, even in tests or config.
- Any future broker work is a separate project with its own regulatory review (T33).
- If a request would add live-trading capability, stop and ask the user.

## Naming (section 0 of `docs/TASKS.md`)

| Item | Name |
|---|---|
| DDEV project | `meridian` (`https://meridian.ddev.site`) |
| Python package / engine service | `meridian_engine` (`services/engine`) |
| Drupal custom modules | `meridian_ingest`, `meridian_core` |
| Next.js app | `meridian-web` (`apps/web`) |
| Docker services | `meridian-postgres`, `meridian-engine`, `meridian-web` |
| Workflows | `ci.yml`, `daily-run.yml`, `deploy-drupal.yml` |

Never use the old placeholder names. `scripts/check-names.sh` enforces this.

## Repository layout

```text
.claude/agents/     subagents: solution-architect, technical-architect, developer, tester
.claude/commands/   per-task loop commands (/plan-task ... /close-task)
.claude/hooks/      hook scripts (path guards for subagents)
.ddev/              DDEV config and custom commands (from T05/T06)
apps/drupal/        Drupal Composer root (docroot web/, config/sync)
apps/web/           Next.js dashboard
services/engine/    Python engine, tests, Dockerfile, Alembic
scripts/            repo tooling (bootstrap, checks, demos)
docs/               all project documentation (see below)
.github/workflows/  CI, daily run, Drupal deploy
```

## Commands

| Purpose | Command |
|---|---|
| Install dev tooling and git hooks | `scripts/bootstrap-dev.sh` |
| Run all pre-commit checks | `.tools/pre-commit run --all-files` |
| Check for stale placeholder names | `scripts/check-names.sh` |
| Demonstrate secret scanning | `scripts/demo-secret-scan.sh` |
| Start the local stack | `ddev start` (clone on the WSL2 Linux filesystem; see `docs/runbooks/local-setup.md`) |
| Install Drupal from `config/sync` | `ddev drupal-install` (`--force` reinstalls and drops the local database) |
| Admin login link | `ddev drush uli` |
| Run in the engine or web container | `ddev engine <cmd>`, `ddev next <cmd>` (T06) |
| Local Postgres | `ddev pg psql`, `ddev pg dump [FILE]`, `ddev pg restore FILE --yes` (T06) |
| State and health of the five services | `ddev meridian-status` (T06) |
| Full quality suite | `ddev quality` (runs in DDEV; `scripts/quality.sh` is the single implementation) |
| Coding standards and review checklist | `docs/standards/CODING_STANDARDS.md`, `docs/standards/REVIEW_CHECKLIST.md` |

## Per-task loop (`docs/process/WORKFLOW.md`)

The **main session orchestrates**. Subagents cannot call each other.

1. `/plan-task Txx`: `technical-architect` writes `docs/tasks/Txx/plan.md`.
2. `/design-tests Txx`: `tester` writes `docs/tests/Txx/test-cases.md` (`TC-Txx-nn`).
3. `/implement-task Txx`: `developer` builds on branch `task/Txx-slug`.
4. `/review-task Txx`: `technical-architect` writes `docs/tasks/Txx/review.md`.
5. `/test-task Txx`: `tester` writes `docs/tests/Txx/test-report.md` with evidence.
6. `/close-task Txx`: update `PROGRESS.md`, `TRACEABILITY.md` and the docs.

Every task must also meet the common criteria C1 to C7 in `docs/TASKS.md` section 3.3.
Commit messages start with the task ID, for example `T10: add ingest upsert endpoint`.

## Where documents live

| What | Where |
|---|---|
| Task status board | `docs/PROGRESS.md` |
| Requirement to evidence matrix | `docs/TRACEABILITY.md` |
| Architecture, diagrams, OpenAPI | `docs/architecture/` |
| Decisions | `docs/adr/ADR-000x-*.md` |
| Rules and data model | `docs/specs/` |
| Task plans and reviews | `docs/tasks/Txx/` |
| Test cases, reports, defects | `docs/tests/` |
| Runbooks | `docs/runbooks/` |
| Templates | `docs/templates/` |
| Coding standards | `docs/standards/` |

## Secrets

- Secrets come only from environment variables. Never commit `.env`.
- Add every new variable name to `.env.example` with a placeholder value.
- gitleaks runs as a pre-commit hook. Never bypass it with `--no-verify`.
