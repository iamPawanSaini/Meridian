# ADR-0003: Postgres is the system of record; Drupal holds a published copy

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-11-01 |
| Deciders | solution-architect (author), technical-architect (reviewer, T02 sign-off) |

## Context

Every input, output and decision must be stored and reproducible (R-06). The engine needs
relational history (prices, runs, decisions, positions) to simulate and to replay a date
(FR-13). Publishing to Drupal can fail: Drupal can be down, asleep or slow to wake (RK-04).
That failure must never lose records or fail the whole run (T19).

Drupal on Pantheon uses MySQL-compatible storage. Remote database connections fail while the
sandbox container is idle
([Pantheon application containers](https://docs.pantheon.io/application-containers),
checked 2026-11-01). GitHub Actions runners are ephemeral, so no state can live on the
runner.

## Decision

We make **Postgres 16 the system of record** for the engine: runs, prices, decisions (with
full provenance), positions and an **outbox** table. The engine:

1. Writes each run's results to Postgres in one transaction, outbox rows included.
2. Publishes to Drupal through the `meridian_ingest` API by draining the outbox.

**Drupal holds a published copy** for admin browsing and the dashboard. It is never the
source for engine logic, and it is never written back to Postgres.

The one exception is the watchlist:

- **Drupal Watchlist Items are authoritative.** Admins manage them in the Drupal UI (R-07,
  T12).
- **The engine reads them** at run start through a separate read-only watchlist scope
  (ADR-0005). The engine sends a wake request and retries with a bounded backoff.
- **The engine snapshots the list** into the run record in Postgres, so every decision can
  be replayed against the exact watchlist used.
- **If Drupal is still unreachable,** the engine uses the last snapshot in Postgres. If no
  snapshot exists (the very first run), it uses the YAML seed in the engine config.
- **Every run logs and stores the source used:** drupal, snapshot or seed.

Rationale:

- R-07 and T12 put watchlist management in the Drupal admin, so Drupal is the natural
  authority.
- The snapshot fallback keeps the rule that engine runs never fail because Drupal is down
  or asleep (RK-04).
- A YAML-only watchlist would remove the admin UI that T12 requires.

Every published record has a stable external ID, so ingest is an idempotent upsert. A
reconciliation script compares Postgres and Drupal (FR-14).

Locally, Postgres runs as `meridian-postgres` in DDEV. In dev it runs on a free hosted
Postgres. The vendor (Neon or Supabase candidates) is chosen in T03 or T28.

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
|---|---|---|---|
| Drupal database as the only store (engine writes only through the API) | One database | A Drupal outage or sleep blocks or loses engine writes. Replay depends on API shapes. Heavy price history in content entities | Couples engine correctness to a sleeping CMS |
| SQLite file committed or kept as an artifact | Zero hosting | Runners are ephemeral. Committing data bloats the repo (`records/` is git-ignored). No concurrent access | Not durable and not shareable |
| Engine connects directly to the Pantheon database | No extra host | Fails while the container is idle. Bypasses Drupal validation. Breaks least privilege | Unreliable and unsafe |

## Consequences

- Positive: Engine runs never fail because Drupal is down. Publishing is deferred through
  the outbox, which makes it retryable (NFR-15). The watchlist falls back to the last
  snapshot. Replay and audit have one authoritative source.
- Negative:
  - Two databases to back up (NFR-16) and to reconcile. Free Postgres tiers have storage,
    compute or pause limits (RK-10).
  - While Drupal is unreachable, watchlist edits made there take effect only on the first
    run after it is reachable again. The run record shows the source used.
- Follow-ups: T03 (schema, outbox and retry design, watchlist snapshot), T10 (watchlist read
  scope), T12 (Watchlist Item UI), T13 (YAML seed and fallback order), T14 (migrations, idempotency), T19
  (publisher), T27 (reconciliation), T28 (vendor), T29 (backup drill).
