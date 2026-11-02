# ADR-0001: Headless Drupal 11 as content backend with a Next.js dashboard

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-11-01 |
| Deciders | solution-architect (author), technical-architect (reviewer, T02 sign-off) |

## Context

Meridian has two kinds of users:

- The admin side (R-07): browse, filter and export records, with roles.
- The read-only dashboard (R-08): overview, decisions, positions and reports with charts.

All access must be authenticated and least-privilege (R-09). The project must run on free
dev tiers (cost map in `docs/architecture/solution-architecture.md`).

Drupal gives roles, Views, CSV export, an admin UI and JSON:API with little custom code.
The dashboard needs a charting-heavy, accessible UI with a strict asset policy (section 0b
of `docs/TASKS.md`: self-hosted fonts, SVG icons, no third-party hosts). A modern React
framework handles that more easily than a Drupal theme.

Pantheon sandbox containers sleep after about 1 h idle and wake in about 30 s
([Pantheon application containers](https://docs.pantheon.io/application-containers),
checked 2026-11-01). The dashboard must therefore tolerate a cold backend.

## Decision

We use **Drupal 11 headless** on Pantheon as the store for published records and as the admin
UI. The custom modules are:

- `meridian_core`: content model, roles and views.
- `meridian_ingest`: idempotent ingest API.

We build the dashboard as a separate **Next.js** app (`meridian-web`, App Router,
TypeScript, `next-drupal` or an equivalent typed client) on Vercel Hobby:

- It reads Drupal through JSON:API from server-side code only.
- It caches responses in the Next.js data cache with time-based revalidation (interval set
  in T03, for example 300 s).
- After a successful publish, the engine triggers on-demand revalidation by calling a
  `meridian-web` revalidation route authenticated with a shared secret. Drupal cache tags
  keep only Drupal's own caches fresh. They do not invalidate the Next.js cache.
- It shows last-good data with a "data as of" label while Drupal wakes.

Drupal renders no public front end. Only the admin and login pages are served by Drupal.

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
|---|---|---|---|
| Coupled Drupal (Twig theme for the dashboard) | One app, one deploy, no API layer | Charting and the strict asset policy are harder in a Drupal theme. The dashboard would sleep with the sandbox | Weaker UI and the dashboard inherits the full cold start |
| Next.js only, reading Postgres directly (no Drupal) | Fewer moving parts | Roles, admin UI, filtering and CSV export would all be rebuilt by hand. R-07 asks for a Drupal admin | Contradicts R-07 and costs more effort |
| Off-the-shelf BI tool on Postgres | Fast charts | Adds a vendor and its own auth and free-tier limits. No Drupal admin. Weak control over theme and assets | Fails R-07 and the 0b asset rules |

## Consequences

- Positive: The admin features come almost entirely from Drupal configuration. The dashboard
  is fast and themeable, and it stays up while Drupal sleeps (cached data). There is a clear
  read-only API boundary for least privilege.
- Negative: Two apps and two deploys. Auth must work across Drupal and Next.js (ADR-0005).
  The revalidation route and its shared secret need tests, and the secret is one more
  thing to rotate (T03 env matrix, T11, T19, T21).
- Follow-ups: T03 (content model and read contract), T09 to T12 (Drupal), T21 to T26
  (Next.js), T22 (auth).
