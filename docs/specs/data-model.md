# Meridian: Data model

| Field | Value |
|---|---|
| Task | T03 |
| Author | technical-architect |
| Date | 2026-11-01 |
| Status | In review (solution-architect sign-off pending, see `technical-design.md`) |
| Design | [technical-design.md](../architecture/technical-design.md) (D1, D2, D3), [openapi.yaml](../architecture/openapi.yaml) |
| Builds | T09 (Drupal config), T14 (Alembic baseline), T10 and T19 (ingest payloads) |

This file is the field-level reference. Names, enums, ranges and regexes here are the same
in the OpenAPI schemas (`openapi.yaml`). If they ever differ, this file wins and the
contract is fixed. One exception: a Markdown table cell cannot hold `|`, so the `{mode}`
part of an `external_id` regex is written here as `[a-z]{4,5}` with "suffix equals `mode`";
the exact pattern, with `long` or `short`, is the one in `openapi.yaml`. Postgres is the system of
record (ADR-0003). The Drupal copy is a
published projection of it, and it reconciles with it (FR-14).

## Shared value rules

| Rule | Value | Used by |
|---|---|---|
| Symbol | NSE ticker, regex `^[A-Z0-9&-]{1,20}$` (for example `RELIANCE`, `M&M`, `BAJAJ-AUTO`). The benchmark uses `NIFTY50` | All records |
| Mode | One of `long`, `short` | Decision, Position, Watchlist Item |
| Action | One of `BUY`, `AVOID` | Decision |
| Veto reason | One of `llm_veto`, `malformed`, `empty`, `timeout`, `api_error`, `schema_violation`, `budget` (FR-06, NFR-08) | Decision |
| Version label | `rule_version`, `prompt_version`: regex `^[0-9]+\.[0-9]+\.[0-9]+$` (semantic version, set in T16 and T17) | Decision, Daily Run |
| Model name | Regex `^[a-z0-9][a-z0-9.-]{0,63}$` | Decision, Daily Run |
| Rule ID | Regex `^[A-Z][A-Z0-9_-]{1,31}$` (IDs defined in T16 `docs/specs/rules.md`) | Decision |
| Money | INR with 2 decimals (paise); prices with 4 decimals | Position, Price Snapshot |
| Dates | `trade_date` is an IST calendar date (`YYYY-MM-DD`); timestamps are UTC | All |
| `external_id` | Lowercase prefix plus natural key; formats in D3 of the design; maximum 64 characters | All Drupal bundles |
| `source_version` | Positive integer, the Postgres row `version` at enqueue time (D3) | All ingested bundles |
| `payload_hash` | 64 lowercase hex characters, SHA-256 of the item `attributes` serialised with RFC 8785 (JCS). Drupal and the engine each compute it and each compares only its own hashes; they should match, but no runtime rule depends on that (D3) | All ingested bundles |

## Drupal content model

All five types are node bundles in `meridian_core` config (T09). Field machine names are
`field_` plus the name in the first column (for example `field_external_id`), except `title`.
Columns: **Type** is the Drupal field type; **Required** is required on save; **Validation**
is enforced at entity level by constraints (not only by the API, T09); **Indexed** says
whether T09 adds a database index on the field value column; **Visible to** lists the roles
that may read the field through JSON:API and the admin UI.

Roles (FR-16, final list): `administrator`, `analyst` (read and export), `engine-ingest`
(machine name `engine_ingest`, engine client user), `dashboard-read` (machine name
`dashboard_read`, Next.js read client user). "All read roles" means `administrator`,
`analyst` and `dashboard-read`. The `engine-ingest` role reads only Watchlist Items.

Entity access comes first: "Visible to" applies on top of it. `anonymous` and
`authenticated` do not have `access content`, and `hook_node_access()` in `meridian_core`
requires `view meridian records` (Decision, Position, Daily Run, Price Snapshot) or
`view meridian watchlist` (Watchlist Item) to view a node at all (design D6, "Entity
access"). A role not listed in "Visible to" reads neither the entity nor the field.

Uniqueness: `external_id` is unique per bundle. `meridian_core` enforces it at entity level with
the `MeridianUniqueInBundle` constraint on `field_external_id` of every bundle (core
`UniqueField` checks the whole entity type with no bundle condition, read in core 11.4.11, and
the field storage is shared). This is the binding rule. `meridian_ingest` is the only writer of
the four ingested bundles and serialises requests with a lock (design D5), so the check cannot
race for them. A unique database key on (`bundle`, `field_external_id_value`) backs it up
(T09 result: see the design's "Unverified items"). Watchlist `symbol` uniqueness is
entity-level (`MeridianUniqueInBundle` on `field_symbol`). The database backstop for it is the
key on the derived `external_id` (`wl-{symbol}`), because a unique key on the shared
`field_symbol` table is impossible. Nodes are never deleted through the API; records are
unpublished only by an administrator.

Shared status storage: Position and Daily Run share the storage `field_status`. Its allowed
values are the union of both lists, and each bundle accepts only its own list (third-party
setting `meridian_core.allowed_values`, T09).

Permissions matrix: [permissions.md](permissions.md).

Revision note (T09 amendment, 2026-11-04): the Uniqueness text follows
`docs/tasks/T09/decision-uniqueness.md` (DN-11). The conditional fields, the `external_id`
equality rules, the Position's Decision, the `raw_llm_output` shape and the Watchlist `symbol`
rule follow `docs/tasks/T09/decision-field-rules.md` (DN-3 to DN-8). The Postgres checks named
below are for T14 parity.

Entity references: a record carries the `external_id` of the record it points to in the
ingest payload (for example `run_external_id`). `meridian_ingest` resolves it to the target
node and stores an `entity_reference`. An unknown reference is an item error (D3, D4).

### Decision (`decision`)

| Field | Type | Card. | Required | Validation | Indexed | Visible to |
|---|---|---|---|---|---|---|
| `title` | string (core) | 1 | yes | Set by ingest to `{symbol} {mode} {trade_date}`, maximum 255 | no | All read roles |
| `external_id` | string (64) | 1 | yes | Regex `^dec-[0-9]{4}-[0-9]{2}-[0-9]{2}-[A-Z0-9&-]{1,20}-[a-z]{4,5}$`; equals `dec-{trade_date}-{symbol}-{mode}` built from the record's own fields; unique per bundle | yes, unique | All read roles |
| `trade_date` | datetime (date only) | 1 | yes | Valid date, not after today (IST) | yes | All read roles |
| `symbol` | string (20) | 1 | yes | Symbol regex `^[A-Z0-9&-]{1,20}$` | yes | All read roles |
| `mode` | list_string | 1 | yes | Allowed values `long`, `short` | yes | All read roles |
| `score` | decimal (5,2) | 1 | yes | Range 0.00 to 100.00 | yes | All read roles |
| `pre_llm_action` | list_string | 1 | yes | Allowed values `BUY`, `AVOID` | no | All read roles |
| `action` | list_string | 1 | yes | Allowed values `BUY`, `AVOID`; `BUY` only if `pre_llm_action` is `BUY` and `vetoed` is false (FR-05) | yes | All read roles |
| `vetoed` | boolean | 1 | yes | true only if `pre_llm_action` is `BUY` | yes | All read roles |
| `veto_reason` | list_string | 1 | no | Veto reason enum; required when `vetoed` is true, empty otherwise | no | All read roles |
| `rule_hits` | string (32) | unlimited | no | Each value matches rule ID regex; at most 50 values | no | All read roles |
| `rule_version` | string (32) | 1 | yes | Version label regex | no | All read roles |
| `prompt_version` | string (32) | 1 | yes | Version label regex | no | All read roles |
| `model_name` | string (64) | 1 | yes | Model name regex | no | All read roles |
| `inputs_snapshot` | string_long | 1 | yes | Valid JSON object, at most 65,536 bytes | no | `administrator`, `analyst` |
| `raw_llm_output` | string_long | 1 | yes | Valid JSON object, at most 32,768 bytes; `{"status":"not_called"}` when no review ran; a reply that is not a JSON object is stored wrapped in an object (T17); rendered escaped | no | `administrator` only |
| `llm_rationale` | string_long | 1 | no | Plain text, at most 2,000 characters; rendered escaped (RK-02) | no | All read roles |
| `close_price` | decimal (14,4) | 1 | yes | Greater than 0 | no | All read roles |
| `run` | entity_reference (node: `daily_run`) | 1 | yes | Resolved from `run_external_id`; target must exist | yes | All read roles |
| `source_version` | integer | 1 | yes | At least 1; never decreases (D3) | no | `administrator` |
| `payload_hash` | string (64) | 1 | yes | Regex `^[0-9a-f]{64}$`; computed by Drupal | no | `administrator` |

A Decision has no reference to its Position. The Position references the Decision, and
Views use that reverse relationship (this avoids a reference cycle inside one ingest batch).

Provenance (FR-12): `inputs_snapshot`, `raw_llm_output`, `prompt_version`, `model_name` and
`rule_version` are required on every Decision.

### Position (`position`)

| Field | Type | Card. | Required | Validation | Indexed | Visible to |
|---|---|---|---|---|---|---|
| `title` | string (core) | 1 | yes | Set by ingest to `{symbol} {mode} {entry_date}` | no | All read roles |
| `external_id` | string (64) | 1 | yes | Regex `^pos-[A-Z0-9&-]{1,20}-[a-z]{4,5}-[0-9]{4}-[0-9]{2}-[0-9]{2}$`; equals `pos-{symbol}-{mode}-{entry_date}` built from the record's own fields; unique per bundle | yes, unique | All read roles |
| `symbol` | string (20) | 1 | yes | Symbol regex `^[A-Z0-9&-]{1,20}$` | yes | All read roles |
| `mode` | list_string | 1 | yes | Allowed values `long`, `short` | yes | All read roles |
| `status` | list_string | 1 | yes | Allowed values `open`, `closed` | yes | All read roles |
| `entry_date` | datetime (date only) | 1 | yes | Valid date | yes | All read roles |
| `entry_price` | decimal (14,4) | 1 | yes | Greater than 0 | no | All read roles |
| `quantity` | integer | 1 | yes | At least 1 (FR-08) | no | All read roles |
| `stop_price` | decimal (14,4) | 1 | yes | Greater than 0 and below `entry_price` | no | All read roles |
| `target_price` | decimal (14,4) | 1 | yes | Above `entry_price` | no | All read roles |
| `time_stop_date` | datetime (date only) | 1 | no | Required when `mode` is `short`, after `entry_date`; empty for `long` | no | All read roles |
| `exit_date` | datetime (date only) | 1 | no | Required when `status` is `closed`, empty when `open`; after `entry_date` | yes | All read roles |
| `exit_price` | decimal (14,4) | 1 | no | Greater than 0; required when `closed`, empty when `open` | no | All read roles |
| `exit_reason` | list_string | 1 | no | Allowed values `stop`, `gap_stop`, `target`, `time_stop`; required when `closed`, empty when `open` | no | All read roles |
| `costs_total` | decimal (12,2) | 1 | yes | At least 0 (FR-10, both sides) | no | All read roles |
| `realised_pnl` | decimal (14,2) | 1 | no | Any sign; required when `closed`, empty when `open` | no | All read roles |
| `unrealised_pnl` | decimal (14,2) | 1 | no | Any sign; empty when `closed` | no | All read roles |
| `last_mark_price` | decimal (14,4) | 1 | no | Greater than 0 | no | All read roles |
| `last_mark_date` | datetime (date only) | 1 | no | Not before `entry_date` | no | All read roles |
| `r_multiple` | decimal (8,3) | 1 | no | Range -100.000 to 100.000 | no | All read roles |
| `run` | entity_reference (node: `daily_run`) | 1 | yes | Opening run, resolved from `run_external_id` | yes | All read roles |
| `decision` | entity_reference (node: `decision`) | 1 | yes | Opening BUY decision, resolved from `decision_external_id`; the target has `action` `BUY`, the same `symbol` and `mode`, and a `trade_date` on or before `entry_date` | yes | All read roles |
| `source_version` | integer | 1 | yes | At least 1; never decreases | no | `administrator` |
| `payload_hash` | string (64) | 1 | yes | Regex `^[0-9a-f]{64}$`; computed by Drupal | no | `administrator` |

A Position references its opening Daily Run and its BUY Decision by `external_id`.

### Daily Run (`daily_run`)

One node per trade date. A rerun of the date updates the same node (D3).

| Field | Type | Card. | Required | Validation | Indexed | Visible to |
|---|---|---|---|---|---|---|
| `title` | string (core) | 1 | yes | Set by ingest to `Run {trade_date}` | no | All read roles |
| `external_id` | string (64) | 1 | yes | Regex `^run-[0-9]{4}-[0-9]{2}-[0-9]{2}$`; equals `run-{trade_date}`; unique per bundle | yes, unique | All read roles |
| `trade_date` | datetime (date only) | 1 | yes | Valid date | yes | All read roles |
| `run_id` | string (36) | 1 | yes | UUID regex `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$` (latest attempt) | no | All read roles |
| `attempt` | integer | 1 | yes | At least 1 | no | All read roles |
| `status` | list_string | 1 | yes | Allowed values `success`, `failed`, `skipped` | yes | All read roles |
| `skip_reason` | string (255) | 1 | no | Required when `status` is `skipped`; empty when `success`; optional when `failed` (for example `stale_lock`, D2) | no | All read roles |
| `watchlist_source` | list_string | 1 | no | Allowed values `drupal`, `snapshot`, `seed` (FR-01); required when `status` is `success`, optional otherwise | no | All read roles |
| `symbols_total` | integer | 1 | yes | 0 to 50 | no | All read roles |
| `decisions_count` | integer | 1 | yes | At least 0 | no | All read roles |
| `buy_count` | integer | 1 | yes | At least 0, at most `decisions_count` | no | All read roles |
| `veto_count` | integer | 1 | yes | At least 0 | no | All read roles |
| `failure_count` | integer | 1 | yes | At least 0 (per-symbol failures, FR-02) | no | All read roles |
| `virtual_equity` | decimal (16,2) | 1 | no | Greater than 0 (FR-10) | no | All read roles |
| `llm_cost_usd` | decimal (10,4) | 1 | yes | At least 0 (NFR-08) | no | `administrator`, `analyst` |
| `rule_version` | string (32) | 1 | yes | Version label regex | no | All read roles |
| `prompt_version` | string (32) | 1 | yes | Version label regex | no | All read roles |
| `model_name` | string (64) | 1 | yes | Model name regex | no | All read roles |
| `started_at` | timestamp | 1 | yes | UTC | no | All read roles |
| `finished_at` | timestamp | 1 | no | Not before `started_at` | yes | All read roles |
| `source_version` | integer | 1 | yes | At least 1; never decreases | no | `administrator` |
| `payload_hash` | string (64) | 1 | yes | Regex `^[0-9a-f]{64}$`; computed by Drupal | no | `administrator` |

The Drupal copy has no `published` field: publish state lives in Postgres `runs.published`,
because Drupal cannot know whether later batches arrived.

### Price Snapshot summary (`price_snapshot`)

Summary only: the EOD bar of each published trade date for watchlist symbols and the
`NIFTY50` benchmark, used by the dashboard reports (FR-18). Full history stays in Postgres
`prices`. No personal data.

| Field | Type | Card. | Required | Validation | Indexed | Visible to |
|---|---|---|---|---|---|---|
| `title` | string (core) | 1 | yes | Set by ingest to `{symbol} {trade_date}` | no | All read roles |
| `external_id` | string (64) | 1 | yes | Regex `^px-[0-9]{4}-[0-9]{2}-[0-9]{2}-[A-Z0-9&-]{1,20}$`; equals `px-{trade_date}-{symbol}` built from the record's own fields; unique per bundle | yes, unique | All read roles |
| `trade_date` | datetime (date only) | 1 | yes | Valid date | yes | All read roles |
| `symbol` | string (20) | 1 | yes | Symbol regex `^[A-Z0-9&-]{1,20}$` | yes | All read roles |
| `open` | decimal (14,4) | 1 | yes | Greater than 0 | no | All read roles |
| `high` | decimal (14,4) | 1 | yes | At least `open`, `low` and `close` | no | All read roles |
| `low` | decimal (14,4) | 1 | yes | Greater than 0, at most `open` and `close` | no | All read roles |
| `close` | decimal (14,4) | 1 | yes | Greater than 0 | no | All read roles |
| `volume` | integer (big) | 1 | yes | At least 0 | no | All read roles |
| `adjusted` | boolean | 1 | yes | true when split and dividend adjusted (OQ-09, T15) | no | All read roles |
| `source` | list_string | 1 | yes | Allowed values `yfinance`, `stub` | no | `administrator`, `analyst` |
| `source_version` | integer | 1 | yes | At least 1; never decreases | no | `administrator` |
| `payload_hash` | string (64) | 1 | yes | Regex `^[0-9a-f]{64}$`; computed by Drupal | no | `administrator` |

### Watchlist Item (`watchlist_item`)

Drupal is authoritative (FR-01). Administrators manage items in the UI (T12); the engine only
reads them. `external_id` is set by `meridian_core` on save, never by the engine.

| Field | Type | Card. | Required | Validation | Indexed | Visible to |
|---|---|---|---|---|---|---|
| `title` | string (core) | 1 | yes | Display name, maximum 255 | no | All read roles, `engine-ingest` |
| `external_id` | string (64) | 1 | yes | Regex `^wl-[A-Z0-9&-]{1,20}$`, derived from `symbol`; unique per bundle | yes, unique | All read roles, `engine-ingest` |
| `symbol` | string (20) | 1 | yes | Symbol regex `^[A-Z0-9&-]{1,20}$`; unique per bundle; cannot change after creation | yes, unique | All read roles, `engine-ingest` |
| `enabled` | boolean | 1 | yes | Default true. At most 50 enabled items (A-01), checked on save | yes | All read roles, `engine-ingest` |
| `modes` | list_string | 1 to 2 | yes | Allowed values `long`, `short`; no duplicates | no | All read roles, `engine-ingest` |
| `sort_order` | integer | 1 | yes | 0 to 999 | yes | All read roles, `engine-ingest` |
| `notes` | string_long | 1 | no | Plain text, at most 500 characters; never sent to the LLM | no | `administrator`, `analyst` |

## Postgres schema

Plain **Postgres 16** with core types only: no extensions and no vendor-only features, so
the same schema runs on the `meridian-postgres` container and on Neon Free (OQ-01). Every
table has a primary key. All timestamps are `timestamptz` in UTC. Rows that are published to
Drupal carry `version bigint NOT NULL DEFAULT 1`, incremented by the engine on every content
change; it becomes `source_version` (D3). Foreign keys use `ON DELETE RESTRICT`. Constraint
names follow `pk_`, `uq_`, `fk_`, `ck_`, `ix_` prefixes. Migrations are in D2 of the design.

### runs

One row per run attempt. Primary key `run_id`.

| Column | Type | Null | Notes |
|---|---|---|---|
| `run_id` | uuid | NOT NULL | Primary key `pk_runs`; generated by the engine |
| `trade_date` | date | NOT NULL | IST trading date |
| `attempt` | smallint | NOT NULL | `daily` and `run`: 1 for the first attempt of a date, then +1. `publish` and `replay`: always 0 (`ck_runs_attempt`: `attempt = 0` exactly when `command` is `publish` or `replay`). No new attempt after a `success` (design D3) |
| `trigger` | text | NOT NULL | `ck_runs_trigger`: `schedule`, `manual` |
| `command` | text | NOT NULL | `ck_runs_command`: `daily`, `run`, `publish`, `replay` |
| `status` | text | NOT NULL | `ck_runs_status`: `running`, `success`, `failed`, `skipped` |
| `skip_reason` | text | NULL | Required by `ck_runs_skip` when `status = 'skipped'`, and NULL when `status = 'success'` |
| `published` | text | NOT NULL | Default `none`. `ck_runs_published`: `none`, `partial`, `full` (FR-25) |
| `watchlist_source` | text | NULL | `ck_runs_wl_source`: `drupal`, `snapshot`, `seed`; NOT NULL when `status = 'success'` (`ck_runs_wl_source_required`) |
| `rule_version` | text | NOT NULL | |
| `prompt_version` | text | NOT NULL | |
| `model_name` | text | NOT NULL | |
| `llm_input_tokens` | integer | NOT NULL | Default 0 |
| `llm_output_tokens` | integer | NOT NULL | Default 0 |
| `llm_cost_usd` | numeric(10,4) | NOT NULL | Default 0 (NFR-08) |
| `summary` | jsonb | NOT NULL | Default `{}`; counts, equity, failures per symbol |
| `started_at` | timestamptz | NOT NULL | |
| `finished_at` | timestamptz | NULL | Set on a terminal status |
| `version` | bigint | NOT NULL | Default 1 |

Constraints and indexes: partial unique index `uq_runs_date_attempt` on (`trade_date`,
`attempt`) `WHERE attempt > 0`, so compute attempts are unique per date while any number of
`publish` and `replay` rows (`attempt = 0`) can share a date (NFR-15, DEF-002). Postgres
supports partial unique indexes; Alembic declares it with `op.create_index(...,
unique=True, postgresql_where=sa.text("attempt > 0"))`, and SQLAlchemy with
`Index(..., unique=True, postgresql_where=...)`. `ck_runs_attempt` is unchanged;
partial unique index `uq_runs_one_running` on (`status`) `WHERE status = 'running'`, which
backs the concurrency lock (FR-22) in the database; index `ix_runs_trade_date` on
(`trade_date` DESC, `attempt` DESC) for "latest run" reads, which filter `attempt > 0`.
At start, a run marks any `running` row older than 30 min as `failed` with
`skip_reason = 'stale_lock'` before taking the lock (design D2).

### watchlist_snapshots

One snapshot per run that read a watchlist (FR-01). Primary key `snapshot_id`.

| Column | Type | Null | Notes |
|---|---|---|---|
| `snapshot_id` | bigint generated always as identity | NOT NULL | Primary key `pk_watchlist_snapshots` |
| `run_id` | uuid | NOT NULL | Foreign key `fk_wls_run` references `runs(run_id)` |
| `source` | text | NOT NULL | `ck_wls_source`: `drupal`, `snapshot`, `seed` |
| `items` | jsonb | NOT NULL | Array of objects with `symbol`, `modes`, `sort_order` |
| `symbol_count` | smallint | NOT NULL | `ck_wls_count`: 0 to 50 |
| `taken_at` | timestamptz | NOT NULL | Default `now()` |

Constraints and indexes: unique `uq_wls_run` on (`run_id`); index `ix_wls_taken_at` on
(`taken_at` DESC) serves "last snapshot" for the fallback.

### prices

EOD candles, the replay input (FR-13). Primary key (`symbol`, `trade_date`).

| Column | Type | Null | Notes |
|---|---|---|---|
| `symbol` | text | NOT NULL | Symbol regex enforced by `ck_prices_symbol` (`~ '^[A-Z0-9&-]{1,20}$'`) |
| `trade_date` | date | NOT NULL | |
| `open` | numeric(14,4) | NOT NULL | `ck_prices_positive`: open, high, low, close greater than 0 |
| `high` | numeric(14,4) | NOT NULL | `ck_prices_range`: high at least low |
| `low` | numeric(14,4) | NOT NULL | |
| `close` | numeric(14,4) | NOT NULL | |
| `adj_close` | numeric(14,4) | NULL | Adjusted close when the source provides it (OQ-09) |
| `volume` | bigint | NOT NULL | At least 0 |
| `source` | text | NOT NULL | `yfinance` or `stub` |
| `fetched_at` | timestamptz | NOT NULL | |
| `run_id` | uuid | NULL | Foreign key `fk_prices_run` references `runs(run_id)`; the fetching run |
| `version` | bigint | NOT NULL | Default 1 |

Constraints and indexes: primary key `pk_prices` on (`symbol`, `trade_date`) is the unique
rule per symbol and date (a re-fetch is an upsert); index `ix_prices_trade_date` on
(`trade_date`).

### decisions

Primary key `decision_id`. Natural key (`trade_date`, `symbol`, `mode`).

| Column | Type | Null | Notes |
|---|---|---|---|
| `decision_id` | bigint generated always as identity | NOT NULL | Primary key `pk_decisions` |
| `external_id` | text | NOT NULL | `dec-{trade_date}-{symbol}-{mode}`; unique `uq_decisions_external_id` |
| `run_id` | uuid | NOT NULL | Foreign key `fk_decisions_run` references `runs(run_id)`; last attempt that wrote the row |
| `trade_date` | date | NOT NULL | |
| `symbol` | text | NOT NULL | |
| `mode` | text | NOT NULL | `ck_decisions_mode`: `long`, `short` |
| `score` | numeric(5,2) | NOT NULL | `ck_decisions_score`: 0 to 100 |
| `pre_llm_action` | text | NOT NULL | `BUY`, `AVOID` |
| `action` | text | NOT NULL | `ck_decisions_action`: `BUY`, `AVOID`; `ck_decisions_llm_only_veto`: `action = 'BUY'` implies `pre_llm_action = 'BUY'` |
| `vetoed` | boolean | NOT NULL | Default false |
| `veto_reason` | text | NULL | Veto reason enum; NOT NULL when `vetoed` (check `ck_decisions_veto`) |
| `rule_hits` | jsonb | NOT NULL | Array of rule IDs |
| `rule_version` | text | NOT NULL | Provenance (FR-12) |
| `prompt_version` | text | NOT NULL | Provenance (FR-12) |
| `model_name` | text | NOT NULL | Provenance (FR-12) |
| `inputs_snapshot` | jsonb | NOT NULL | Provenance (FR-12): candles, fundamentals, headlines, config used |
| `raw_llm_output` | jsonb | NOT NULL | Provenance (FR-12); `{"status":"not_called"}` when no review ran |
| `llm_rationale` | text | NULL | |
| `close_price` | numeric(14,4) | NOT NULL | |
| `version` | bigint | NOT NULL | Default 1 |
| `created_at` | timestamptz | NOT NULL | |
| `updated_at` | timestamptz | NOT NULL | |

Constraints and indexes: unique `uq_decisions_date_symbol_mode` on (`trade_date`, `symbol`,
`mode`), which makes a rerun of a date an update (FR-24); index `ix_decisions_run_id` on
(`run_id`); index `ix_decisions_date_action` on (`trade_date` DESC, `action`).

Check constraints that mirror the Drupal validations, so a row the engine accepts is never a
predictable 422 at ingest (review finding 8):

- `ck_decisions_symbol`: `symbol ~ '^[A-Z0-9&-]{1,20}$'`.
- `ck_decisions_vetoed`: `vetoed` implies `pre_llm_action = 'BUY'` and `action = 'AVOID'`.
- `ck_decisions_veto`: `veto_reason` is NOT NULL when `vetoed` and NULL otherwise, and is
  one of the veto reason enum values.
- `ck_decisions_pre_llm_action`: `pre_llm_action` in (`BUY`, `AVOID`).
- `ck_decisions_rule_hits`: `jsonb_typeof(rule_hits) = 'array'` and
  `jsonb_array_length(rule_hits) <= 50`.
- `ck_decisions_inputs_size`: `octet_length(inputs_snapshot::text) <= 65536`.
- `ck_decisions_llm_size`: `octet_length(raw_llm_output::text) <= 32768`.
- `ck_decisions_rationale`: `llm_rationale` is NULL or at most 2,000 characters.
- `ck_decisions_close`: `close_price > 0`.
- `ck_decisions_external_id`: `external_id = 'dec-' || to_char(trade_date, 'YYYY-MM-DD') ||
  '-' || symbol || '-' || mode`.
- `ck_decisions_inputs_object`: `jsonb_typeof(inputs_snapshot) = 'object'`;
  `ck_decisions_llm_object`: `jsonb_typeof(raw_llm_output) = 'object'`.

The publisher also validates each outbox row against `openapi.yaml` before sending (design
D4), which catches the version-label and model-name patterns.

### positions

Primary key `position_id`. Natural key (`symbol`, `mode`, `entry_date`).

| Column | Type | Null | Notes |
|---|---|---|---|
| `position_id` | bigint generated always as identity | NOT NULL | Primary key `pk_positions` |
| `external_id` | text | NOT NULL | `pos-{symbol}-{mode}-{entry_date}`; unique `uq_positions_external_id` |
| `opened_run_id` | uuid | NOT NULL | Foreign key `fk_positions_run` references `runs(run_id)` |
| `decision_id` | bigint | NOT NULL | Foreign key `fk_positions_decision` references `decisions(decision_id)` |
| `symbol` | text | NOT NULL | |
| `mode` | text | NOT NULL | `long`, `short` |
| `status` | text | NOT NULL | `ck_positions_status`: `open`, `closed` |
| `entry_date` | date | NOT NULL | |
| `entry_price` | numeric(14,4) | NOT NULL | Greater than 0 |
| `quantity` | integer | NOT NULL | At least 1 |
| `stop_price` | numeric(14,4) | NOT NULL | Below `entry_price` |
| `target_price` | numeric(14,4) | NOT NULL | Above `entry_price` |
| `time_stop_date` | date | NULL | NOT NULL when `mode = 'short'` |
| `exit_date` | date | NULL | |
| `exit_price` | numeric(14,4) | NULL | |
| `exit_reason` | text | NULL | `stop`, `gap_stop`, `target`, `time_stop` |
| `entry_costs` | numeric(12,2) | NOT NULL | At least 0 |
| `exit_costs` | numeric(12,2) | NOT NULL | Default 0 |
| `realised_pnl` | numeric(14,2) | NULL | Set on close |
| `unrealised_pnl` | numeric(14,2) | NULL | |
| `last_mark_price` | numeric(14,4) | NULL | |
| `last_mark_date` | date | NULL | |
| `r_multiple` | numeric(8,3) | NULL | |
| `version` | bigint | NOT NULL | Default 1 |
| `updated_at` | timestamptz | NOT NULL | |

Constraints and indexes: unique `uq_positions_symbol_mode_entry` on (`symbol`, `mode`,
`entry_date`); check `ck_positions_closed`: `status = 'closed'` if and only if `exit_date`,
`exit_price`, `exit_reason` and `realised_pnl` are all NOT NULL, and `unrealised_pnl` is NULL
when `closed`; checks `ck_positions_external_id`: `external_id = 'pos-' || symbol || '-' ||
mode || '-' || to_char(entry_date, 'YYYY-MM-DD')`;
partial index `ix_positions_open` on (`symbol`) `WHERE status = 'open'`; index
`ix_positions_decision` on (`decision_id`). Drupal `costs_total` = `entry_costs` +
`exit_costs`.

Check constraints that mirror the Drupal validations (review finding 8):

- `ck_positions_symbol`: `symbol ~ '^[A-Z0-9&-]{1,20}$'`; `ck_positions_mode`: `mode` in
  (`long`, `short`).
- `ck_positions_prices`: `0 < stop_price`, `stop_price < entry_price` and
  `entry_price < target_price`.
- `ck_positions_quantity`: `quantity >= 1`; `ck_positions_costs`: `entry_costs >= 0` and
  `exit_costs >= 0`.
- `ck_positions_time_stop`: `time_stop_date` is NOT NULL and after `entry_date` when
  `mode = 'short'`, and NULL when `mode = 'long'`.
- `ck_positions_exit`: `exit_date`, when set, is after `entry_date`; `exit_price`, when set,
  is greater than 0; `exit_reason` in (`stop`, `gap_stop`, `target`, `time_stop`).
- `ck_positions_r_multiple`: `r_multiple` is NULL or between -100 and 100.

### outbox

Records waiting for Drupal (D4). Primary key `outbox_id`.

| Column | Type | Null | Notes |
|---|---|---|---|
| `outbox_id` | bigint generated always as identity | NOT NULL | Primary key `pk_outbox`; also the send order |
| `record_type` | text | NOT NULL | `ck_outbox_type`: `daily_run`, `price_snapshot`, `decision`, `position` |
| `external_id` | text | NOT NULL | Drupal `external_id` of the record |
| `payload` | jsonb | NOT NULL | The ingest item `attributes` |
| `payload_hash` | char(64) | NOT NULL | SHA-256 of the canonical payload |
| `source_version` | bigint | NOT NULL | Source row `version` |
| `status` | text | NOT NULL | `ck_outbox_status`: `pending`, `sent`, `dead` |
| `attempts` | integer | NOT NULL | Default 0 |
| `next_attempt_at` | timestamptz | NOT NULL | Default `now()` |
| `last_error` | text | NULL | Last HTTP status and error code |
| `run_id` | uuid | NULL | Foreign key `fk_outbox_run` references `runs(run_id)`; the run that last enqueued or updated the pending row (an in-place update sets it to the new run) |
| `created_at` | timestamptz | NOT NULL | |
| `sent_at` | timestamptz | NULL | Set when `sent` |

Constraints and indexes: partial unique index `uq_outbox_one_pending` on (`record_type`,
`external_id`) `WHERE status = 'pending'` (at most one pending row per record); index
`ix_outbox_drain` on (`next_attempt_at`, `outbox_id`) `WHERE status = 'pending'`; index
`ix_outbox_type_external` on (`record_type`, `external_id`, `outbox_id` DESC) for "last sent
hash" lookups.

### alembic_version

Created by Alembic. Primary key `version_num`.

| Column | Type | Null | Notes |
|---|---|---|---|
| `version_num` | varchar(32) | NOT NULL | Primary key; current revision, for example `0001_baseline` |
