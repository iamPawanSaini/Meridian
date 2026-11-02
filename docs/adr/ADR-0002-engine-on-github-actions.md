# ADR-0002: Run the engine on GitHub Actions on a schedule

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-11-01 |
| Deciders | solution-architect (author), technical-architect (reviewer, T02 sign-off) |

## Context

The Python engine runs once per trading day after market close (R-01, R-10). A run takes
minutes (NFR-01: p95 at most 15 min on dev). The engine needs Python 3.12, network access
to the data source, the Claude API, Postgres and Drupal, and secrets from a secret store. Hosting
must be free (NFR-09).

GitHub Actions facts (checked 2026-11-01):

- The `schedule` event can be delayed under high load, and some queued jobs may be dropped.
- Schedules run only on the default branch.
- In public repos, scheduled workflows are disabled after 60 days without repository activity.
- The shortest interval is 5 minutes, and an IANA timezone can be set.

Source: [GitHub events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).

Standard runners are free in public repos. Private repos on GitHub Free get USD 12 a month of
included usage ([billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)).
A job can run for at most 6 h ([limits](https://docs.github.com/en/actions/reference/limits)).

## Decision

We run `meridian_engine` as a container or Python job in `daily-run.yml` on GitHub Actions:

- **Schedule:** cron at 16:00 IST (10:30 UTC), Monday to Friday, off the top of the hour.
- **Manual trigger:** `workflow_dispatch`.
- **Concurrency:** a lock so two runs never overlap.
- **Timeout:** 30 min.
- **Secrets:** from GitHub Actions secrets.

The engine is stateless. All state lives in Postgres (ADR-0003), so a delayed, repeated or
manually dispatched run is safe (idempotent, FR-24).

GitHub's schedule is best-effort, so we pair it with:

- A missed-run alert by 19:00 IST (NFR-14).
- A weekly check that the workflow is still enabled.

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
|---|---|---|---|
| Pantheon cron or the Drupal queue | Already hosted | PHP only. Sandbox containers sleep after about 1 h idle ([Pantheon](https://docs.pantheon.io/application-containers), checked 2026-11-01). The engine logic would be tied to Drupal | Wrong runtime and unreliable on a sleeping sandbox |
| Vercel cron plus a serverless function | Same platform as the dashboard | Hobby function max duration is 300 s ([Vercel Hobby](https://vercel.com/docs/plans/hobby), checked 2026-11-01), shorter than a full run. Non-commercial terms | The run does not fit the time limit |
| Small cloud VM or VPS with system cron | Exact timing, full control | Monthly cost, patching and an always-on host to secure | Breaks NFR-09 and adds operations work |
| Owner's local machine cron | Free | Depends on the machine being on. No audit trail | Fails R-10 availability |

## Consequences

- Positive: Free, with logs, artifacts, secrets and manual dispatch built in. The same
  container image runs in DDEV (`meridian-engine`) and CI.
- Negative:
  - The start time is not guaranteed, so data freshness has 2 h of slack (NFR-02).
  - Public repos need activity every 60 days.
  - GitHub outages stop runs.
- Follow-ups: T20 (workflow, holiday skip, alerts), T29 (missed-run alert, runbooks), OQ-03
  (repo visibility, T08), OQ-06 (UTC or IANA timezone, T20). If T31 shows misses, add an
  external trigger (`repository_dispatch`) in a new ADR.
