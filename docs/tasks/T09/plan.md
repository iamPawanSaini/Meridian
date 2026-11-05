# T09: Content model as configuration, Plan

| Field | Value |
|---|---|
| Task | T09 |
| Author | technical-architect |
| Date | 2026-11-04 (revision 2: solution-architect decisions folded in) |
| Branch | `task/T09-content-model` |
| Status | Approved (owner, 2026-11-04) |
| Covers | R-06, R-07 (FR-12, FR-16; design D1, D6; data-model "Drupal content model") |
| Depends on | T03 (In test), T05 (In test). The owner accepted starting T09 with both in test on 2026-11-04, as for T07 and T08. Recorded here; re-confirm at `/close-task` that neither changed the content model, roles or install path in the meantime |
| Decisions | [decision-roles-and-access.md](decision-roles-and-access.md) (DN-1, DN-2), [decision-field-rules.md](decision-field-rules.md) (DN-3 to DN-8), [decision-measurement-scope.md](decision-measurement-scope.md) (DN-9), [decision-uniqueness.md](decision-uniqueness.md) (DN-10, DN-11), all solution-architect, 2026-11-04 |

## Goal

Build the five Meridian node bundles (`decision`, `position`, `daily_run`, `price_snapshot`,
`watchlist_item`) as configuration in `apps/drupal/config/sync`, owned by a new custom module
`meridian_core`. The module enforces every validation rule in the T03 data model, as amended by
the T09 decisions, at entity level: constraints that run on `$entity->validate()`, not only in
the T10 API. It enforces a unique `external_id` per bundle with a database backstop, defines the
Meridian permissions and the four roles, and limits entity and field access as design D6
requires. The site installs from config with no diff and round-trips with `cex` and `cim`.
PHPUnit Kernel tests prove every accept and reject rule. This gives T10 (ingest), T11 (read API)
and T12 (admin UI) a fixed, tested model. T09 also switches on the Drupal test step in
`scripts/quality.sh` and CI (KD-3 in T08), and runs the NFR-04 part of measurement gate MG-1.

## Scope

- New module `apps/drupal/web/modules/custom/meridian_core` (name per section 0; checked by
  `scripts/check-names.sh`).
- Core modules enabled in `core.extension.yml`: `datetime`, `options`, `meridian_core`
  (`node`, `field`, `text`, `user` are already on). No contrib module. No JSON:API, REST,
  Simple OAuth or Basic Auth (T10, T11).
- Config in `config/sync`: 5 node types, field storages, field instances (with the
  `meridian_core.allowed_values` third-party setting on the two `field_status` instances),
  default form and view displays, 4 roles, and the permission change for `anonymous` and
  `authenticated`.
- `meridian_core` config schema for the third-party setting
  (`config/schema/meridian_core.schema.yml`).
- Validation: field settings, core constraints attached in code, and custom constraint plugins
  (KD-3).
- Unique `external_id` per bundle: `MeridianUniqueInBundle` plus a unique database key, with the
  DN-10 fallbacks.
- Permissions (`meridian_core.permissions.yml`), roles as config, node view, update, delete and
  create access, and field view access (DN-2).
- Permissions matrix document `docs/specs/permissions.md` (six roles, DN-1).
- Test harness: `apps/drupal/phpunit.xml.dist`, MariaDB 10.6 service and pcov in the CI
  `drupal` job, `check_ci.py` rule 2 database parity, removal of the PHPStan empty-tree guard
  and of the `component-drupal-tests` line in `quality/expected-skips.txt`.
- PHPUnit Unit and Kernel tests; first measured Drupal coverage figure.
- MG-1 NFR-04 entity-layer measurement with the DN-9 parameters, recorded in
  `technical-design.md`.
- Spec text changes assigned to the technical-architect by the decision files (step 11).

## Non-goals

- Ingest endpoint, OAuth, consumers, service users, scope allowlist, the ingest lock, audit log,
  payload hash computation, reference resolution from `*_external_id`, the stored JSON
  serialisation (T10).
- JSON:API, `jsonapi.settings:read_only`, the 401 request subscriber for `/jsonapi/*` and
  `/api/meridian/*`, cache tags, `/api/meridian/v1/me` (T11, T22). Listing filters: T09 adds no
  node grants module, so entity queries and Views are not filtered by the T09 hooks (DN-2
  consequence 1; T11 and T12 handle it).
- Views, CSV export, admin form layout, Watchlist management UI, read-only `symbol` on the
  edit form, limiting the `status` exposed filter options, "admin may only unpublish" form
  restrictions, field `edit` access (T12). T09 ships default form and view displays only, so
  that `cim` is complete.
- PHPUnit Functional tests. T09 adds none, so the `check_ci.py` rule 6 tripwire stays green and
  the heavier-set jobs stay with T10 (`docs/tasks/T08/decision-heavier-set.md`).
- Seed data, the 5,000-record seed and the NFR-05 read measurement (moved to T11 by DN-9).
- Postgres check constraints that mirror the amended Drupal rules (T14; the data-model text is
  amended in T09, step 11). The LLM reply wrapper (T17). Position opening tests (T18).
- Any broker code, SDK or domain (ADR-0006). Nothing in T09 touches an external host.

## Key design choices

### KD-1 Config lives in `config/sync` only

`docs/standards/CODING_STANDARDS.md` ("PHP and Drupal"): "Configuration lives in
`apps/drupal/config/sync`". `meridian_core` has **no** `config/install` copy of the content
model, so there is one source and no drift. Ownership is expressed with
`dependencies.enforced.module: [meridian_core]` on each `node.type.*` (field and display config
depends on the node type, so it follows). The module's only shipped config file is its schema
(`config/schema/meridian_core.schema.yml`). Kernel tests do not read `config/sync` by
themselves, so a test trait `SyncConfigTrait` (in `meridian_core/tests/src/Traits/`) creates the
named config entities from `config/sync` through `FileStorage` and the entity storage
(`createFromStorageRecord()` then `save()`, in dependency order). Kernel tests therefore test the
shipped YAML, not a copy. Rejected: module `config/install` plus a parity test (two copies). If
the trait proves unworkable, that fallback is used and recorded in the review.

Config is produced by the UI or `drush field:create` and exported with `ddev drush cex`. YAML is
never hand-written with invented UUIDs. The third-party setting may be added by hand to the
exported field YAML, then checked by `cim` and `config:status`.

### KD-2 Field types and settings (per `docs/specs/data-model.md`, as amended)

Machine names are `field_<name>`. Storage is shared across bundles where the name repeats
(`field_external_id`, `field_trade_date`, `field_symbol`, `field_mode`, `field_status`,
`field_run`, `field_rule_version`, `field_prompt_version`, `field_model_name`,
`field_source_version`, `field_payload_hash`); a shared storage has identical storage settings
in every bundle.

**`field_status` (DN-3).** One shared `list_string` storage. Storage `allowed_values` are the
union, in this order: `open`, `closed`, `success`, `failed`, `skipped`. Each instance carries
its subset as config in `third_party_settings.meridian_core.allowed_values`:
`position` `[open, closed]`, `daily_run` `[success, failed, skipped]`. The generic constraint
`MeridianBundleAllowedValues` reads the setting from any field instance that has it, and rejects
any other value at path `field_status` with code `meridian.bundle_allowed_values`. The config
schema for `field.field.*.*.*.third_party.meridian_core` (a sequence of strings under
`allowed_values`) is in `meridian_core`, so config validation and `cim` accept it.

Type mapping: `string (n)` = `string` with `max_length: n`; `string_long` = `string_long`;
`list_string` = `options` list with `allowed_values` in storage config; `decimal (p,s)` =
`decimal` with `precision`/`scale`; `integer (big)` = `integer` with `size: big`; `datetime (date
only)` = `datetime` with `datetime_type: date`; `timestamp` = core `timestamp`;
`entity_reference (node: X)` = `entity_reference`, `target_type: node`, handler
`default:node`, `target_bundles: [X]`; `boolean` = `boolean`. Cardinality 1 unless stated:
`field_rule_hits` unlimited (-1), `field_modes` 2.

Node type settings for all five: `new_revision: true` (D3 "new revision" on update),
`preview_mode: 0`, `display_submitted: false`, published by default (records are only ever
unpublished by an administrator).

Per bundle, the fields are exactly the rows of the data-model tables:

| Bundle | Fields (`field_` prefix omitted; (R) = required) |
|---|---|
| `decision` | `title` (R), `external_id` (R) string 64, `trade_date` (R) date, `symbol` (R) string 20, `mode` (R) list, `score` (R) decimal(5,2), `pre_llm_action` (R) list, `action` (R) list, `vetoed` (R) boolean, `veto_reason` list, `rule_hits` string 32 unlimited, `rule_version` (R) string 32, `prompt_version` (R) string 32, `model_name` (R) string 64, `inputs_snapshot` (R) string_long, `raw_llm_output` (R) string_long, `llm_rationale` string_long, `close_price` (R) decimal(14,4), `run` (R) ref daily_run, `source_version` (R) integer, `payload_hash` (R) string 64 |
| `position` | `title` (R), `external_id` (R), `symbol` (R), `mode` (R), `status` (R) list (subset `open`, `closed`), `entry_date` (R) date, `entry_price` (R) decimal(14,4), `quantity` (R) integer, `stop_price` (R) decimal(14,4), `target_price` (R) decimal(14,4), `time_stop_date` date, `exit_date` date, `exit_price` decimal(14,4), `exit_reason` list, `costs_total` (R) decimal(12,2), `realised_pnl` decimal(14,2), `unrealised_pnl` decimal(14,2), `last_mark_price` decimal(14,4), `last_mark_date` date, `r_multiple` decimal(8,3), `run` (R) ref daily_run, `decision` (R) ref decision, `source_version` (R), `payload_hash` (R) |
| `daily_run` | `title` (R), `external_id` (R), `trade_date` (R), `run_id` (R) string 36, `attempt` (R) integer, `status` (R) list (subset `success`, `failed`, `skipped`), `skip_reason` string 255, `watchlist_source` list, `symbols_total` (R) integer, `decisions_count` (R) integer, `buy_count` (R) integer, `veto_count` (R) integer, `failure_count` (R) integer, `virtual_equity` decimal(16,2), `llm_cost_usd` (R) decimal(10,4), `rule_version` (R), `prompt_version` (R), `model_name` (R), `started_at` (R) timestamp, `finished_at` timestamp, `source_version` (R), `payload_hash` (R) |
| `price_snapshot` | `title` (R), `external_id` (R), `trade_date` (R), `symbol` (R), `open` (R) decimal(14,4), `high` (R) decimal(14,4), `low` (R) decimal(14,4), `close` (R) decimal(14,4), `volume` (R) integer big, `adjusted` (R) boolean, `source` (R) list, `source_version` (R), `payload_hash` (R) |
| `watchlist_item` | `title` (R), `external_id` (R), `symbol` (R), `enabled` (R) boolean default true, `modes` (R) list cardinality 2, `sort_order` (R) integer, `notes` string_long |

"Required" on a boolean means the value must be present (true or false). Core `required` alone
does not guarantee that for programmatic saves, so `NotNull` on the value property is attached in
code for every required boolean (`vetoed`, `adjusted`, `enabled`).

**Indexes ("Indexed: yes").** Core field types already index some columns (list, datetime,
entity reference: **verify** per type in core 11.4.11). For every "yes" field whose type has no
default index (expected: `score`, `symbol`, `vetoed`, `enabled`, `sort_order`, `finished_at`,
`external_id`), the storage config gets `indexes: { value: [value] }`. The structure test
asserts an index exists on each "yes" column (exact index names **verify**). "no" means T09
adds nothing; core default indexes stay.

### KD-3 Where each rule is enforced

Three mechanisms, chosen per rule. Every violation uses the field machine name as the property
path, and every custom rule sets a stable code (`meridian.<bundle>.<rule>` or
`meridian.<constraint>`), so T10 can map violations to JSON pointers and error codes without
parsing messages. **One violation per rejection case** (decision-field-rules.md preamble): a
rule that reads another field or entity returns without a violation when that input is missing
or invalid, because the input's own rule already reports it.

| Mechanism | Rules | Where |
|---|---|---|
| Field settings (config) | required; `max_length` of `string`; `allowed_values` of lists; integer and decimal `min`/`max`; decimal precision/scale; cardinality; `target_bundles`; `datetime_type`; the `field_status` subsets (third-party setting) | `field.storage.*`, `field.field.*` YAML |
| Core constraints attached in code | `Regex` on the value property (external_id pattern per bundle, symbol, version labels, model name, rule ID per `rule_hits` item, `run_id` UUID, `payload_hash`); `Length` max for `llm_rationale` (2,000) and `notes` (500) (string_long has no `max_length`); `Count` max 50 for `rule_hits`; `NotNull` for required booleans; core `ValidReference` comes with entity references | `#[Hook('entity_bundle_field_info_alter')]` in `src/Hook/FieldConstraintHooks.php`; patterns in one `src/Validation/Patterns.php` class of constants |
| Custom field constraints | `MeridianBundleAllowedValues` (DN-3); `MeridianJsonDocument` (valid JSON, `objectOnly: true` on both `inputs_snapshot` and `raw_llm_output`, `maxBytes` = UTF-8 byte length of the stored string, DN-7); `MeridianDecimalScale` (rejects more fractional or integer digits than precision/scale, so MariaDB never silently rounds or raises an out-of-range error that would be a 500 instead of a 422); `MeridianDateNotAfterToday` (IST, `datetime.time` injected); `MeridianNoDuplicateValues` (`modes`); `MeridianUniqueInBundle` (KD-4); `MeridianImmutable` (`external_id` on all bundles; `symbol` on `watchlist_item`, DN-8); `MeridianNonDecreasing` (`source_version`, against `loadUnchanged()`) | `src/Plugin/Validation/Constraint/`, attached in the same hook |
| Custom entity constraints (cross-field) | `MeridianExternalIdMatches` (all bundles, DN-5); one rules constraint per bundle: `MeridianDecisionRules`, `MeridianPositionRules`, `MeridianDailyRunRules`, `MeridianPriceSnapshotRules`, `MeridianWatchlistItemRules` | `src/Plugin/Validation/Constraint/`, added to the node entity type by `#[Hook('entity_type_alter')]`; each validator returns at once for other bundles and adds violations `atPath()` the offending field |

"Greater than 0" on decimals is the field `min` set to the smallest unit of the scale (0.0001 for
scale 4, 0.01 for scale 2), which is equivalent once `MeridianDecimalScale` rejects extra
digits. Inclusive ranges use `min`/`max` directly.

**External ID consistency (DN-5).** `MeridianExternalIdMatches` builds the D3 format from the
entity's own fields and compares strings; a difference is one violation at `field_external_id`,
code `meridian.external_id_mismatch`. It replaces the separate "Decision suffix equals `mode`"
and "Daily Run date equals the date in `external_id`" rules. `title` is not checked.

| Bundle | `external_id` must equal |
|---|---|
| `decision` | `dec-{trade_date}-{symbol}-{mode}` |
| `position` | `pos-{symbol}-{mode}-{entry_date}` |
| `daily_run` | `run-{trade_date}` |
| `price_snapshot` | `px-{trade_date}-{symbol}` |
| `watchlist_item` | `wl-{symbol}` (KD-5) |

With `MeridianImmutable` on `external_id`, the natural-key fields cannot change after creation;
an attempt reports `meridian.external_id_mismatch`.

**Position's Decision (DN-6).** `MeridianPositionRules` reads the target through the field
item's `entity` property (not by loading by ID), so it also works for an unsaved Decision that
T10 resolves from the same batch. Four conditions, one violation each at `field_decision`, with
codes `meridian.position.decision_not_buy`, `meridian.position.decision_symbol_mismatch`,
`meridian.position.decision_mode_mismatch`, `meridian.position.decision_after_entry` (target
`trade_date` must be on or before `entry_date`). A missing or wrong-bundle target adds nothing
(`ValidReference` reports it).

**Conditional fields (DN-4, as decided).**

| Bundle | Condition | Rule |
|---|---|---|
| `position` | `status` = `closed` | `exit_date`, `exit_price`, `exit_reason`, `realised_pnl` required; `unrealised_pnl` empty |
| `position` | `status` = `open` | `exit_date`, `exit_price`, `exit_reason`, `realised_pnl` empty; `unrealised_pnl`, `last_mark_price`, `last_mark_date` optional |
| `position` | `mode` = `short` / `long` | `time_stop_date` required and after `entry_date` / empty |
| `daily_run` | `status` = `skipped` | `skip_reason` required; `watchlist_source` optional |
| `daily_run` | `status` = `success` | `skip_reason` empty; `watchlist_source` required |
| `daily_run` | `status` = `failed` | `skip_reason` optional (for example `stale_lock`, D2); `watchlist_source` optional |
| `decision` | `vetoed` true / false | `veto_reason` required / empty |

Rule list (the tester derives `TC-T09-nn` from it; "Field" = field settings):

| Bundle | Rule | Mechanism |
|---|---|---|
| all | `external_id` regex (exact `(long\|short)` form from `openapi.yaml`); max 64; unique in bundle; immutable; equals the D3 format from own fields | Regex, Field, `MeridianUniqueInBundle`, `MeridianImmutable`, `MeridianExternalIdMatches` |
| all ingested | `source_version` at least 1 and never decreases; `payload_hash` `^[0-9a-f]{64}$` | Field `min: 1`, `MeridianNonDecreasing`, Regex |
| all with them | `symbol` `^[A-Z0-9&-]{1,20}$`; `rule_version`, `prompt_version` `^[0-9]+\.[0-9]+\.[0-9]+$`; `model_name` `^[a-z0-9][a-z0-9.-]{0,63}$`; `title` max 255 | Regex, core |
| `decision` | `trade_date` not after today in `Asia/Kolkata` | `MeridianDateNotAfterToday` |
| `decision` | `mode` in {long, short}; `pre_llm_action`, `action` in {BUY, AVOID}; `veto_reason` in the 7-value enum | Field |
| `decision` | `score` 0.00 to 100.00, scale 2; `close_price` > 0 | Field, `MeridianDecimalScale` |
| `decision` | `action` BUY only if `pre_llm_action` BUY and not `vetoed`; `vetoed` only if `pre_llm_action` BUY; `veto_reason` required iff `vetoed` | `MeridianDecisionRules` |
| `decision` | `rule_hits` each matches rule ID regex, at most 50 | Regex, Count |
| `decision` | `inputs_snapshot` JSON object at most 65,536 bytes; `raw_llm_output` JSON object at most 32,768 bytes; `llm_rationale` at most 2,000 characters | `MeridianJsonDocument`, Length |
| `decision` | `run` targets an existing `daily_run` | Field `target_bundles`, `ValidReference` |
| `position` | `status` in {open, closed}; `exit_reason` in {stop, gap_stop, target, time_stop}; `mode` | Field, `MeridianBundleAllowedValues` |
| `position` | `entry_price`, `exit_price`, `last_mark_price` > 0; `stop_price` > 0 and < `entry_price`; `target_price` > `entry_price`; `quantity` at least 1; `costs_total` at least 0; `r_multiple` -100.000 to 100.000; scale on every decimal | Field, `MeridianDecimalScale`, `MeridianPositionRules` |
| `position` | conditional fields per the DN-4 table; `exit_date` after `entry_date`; `last_mark_date` not before `entry_date`; Decision target per DN-6 | `MeridianPositionRules` |
| `position` | `run` targets `daily_run`, `decision` targets `decision` | Field, `ValidReference` |
| `daily_run` | `run_id` UUID regex (lowercase); `attempt` at least 1; `status` in {success, failed, skipped}; `skip_reason` max 255 and per DN-4; `watchlist_source` in {drupal, snapshot, seed} and per DN-4; `symbols_total` 0 to 50; counts at least 0; `buy_count` at most `decisions_count`; `virtual_equity` > 0; `llm_cost_usd` at least 0; `finished_at` not before `started_at` | Field, Regex, `MeridianBundleAllowedValues`, `MeridianDailyRunRules` |
| `price_snapshot` | `open`, `close` > 0; `low` > 0 and at most `open` and `close`; `high` at least `open`, `low`, `close`; `volume` at least 0; `source` in {yfinance, stub} | Field, `MeridianPriceSnapshotRules` |
| `watchlist_item` | `external_id` set by `meridian_core` (KD-5); `symbol` unique in bundle and immutable; at most 50 enabled items; `modes` 1 to 2 values, no duplicates, in {long, short}; `sort_order` 0 to 999; `notes` at most 500 characters; `enabled` default true | `MeridianWatchlistItemRules`, `MeridianUniqueInBundle`, `MeridianImmutable`, `MeridianNoDuplicateValues`, Field, Length |

### KD-4 Unique `external_id` per bundle, including concurrent saves (DN-10, DN-11)

Fact (core 11.4.11, `UniqueFieldValueValidator.php`, read 2026-11-04 by both architects): core
`UniqueField` queries the whole entity type with no bundle condition, and uses `LIKE` when not
case-sensitive. The storages are shared, so:

1. **Entity level (binding rule).** `MeridianUniqueInBundle`: exact, case-sensitive comparison
   (not `LIKE`), `condition('type', bundle)`, `accessCheck(FALSE)`, excluding the entity's own
   id. On `field_external_id` for all five bundles and on `field_symbol` for `watchlist_item`.
2. **Database backstop, first choice.** A unique key `meridian_external_id_bundle` on
   `node__field_external_id (bundle, field_external_id_value)`. Not on the revision table. Added
   by `#[Hook('field_storage_config_insert')]` (the dedicated table exists after
   `FieldStorageConfig::preSaveNew()`, **verify**) and by `hook_install()` when the table already
   exists; dropped by `hook_uninstall()`. Logic in `src/Schema/ExternalIdIndex.php`
   (`ensure()`, `drop()`, `exists()`). Record the actual table collation on DDEV (**verify**);
   the regexes fix letter case, so a case-insensitive collation cannot cause false duplicates.
3. **"Cannot be kept" test (DN-10).** Any of: the key is missing after `site:install
   --existing-config`, after `cim` onto a clean site, or after a field storage update or cache
   rebuild; the key makes `cim`, `config:status` or `drush updatedb` fail or report a change;
   core's entity schema checks report the field table as changed.
4. **Fallback A (no new decision needed).** `hook_schema()` table `meridian_external_id`
   (primary key `bundle`, `external_id`; column `nid`). `hook_node_insert` inserts the row
   inside the node save transaction (`SqlContentEntityStorage::save()`), so a duplicate raises
   and the whole save rolls back. `hook_node_delete` removes the row. No update path, because
   `external_id` is immutable. `ExternalIdIndex` keeps its interface; the same Kernel tests apply.
5. **Fallback B (only if A fails).** No database backstop; `MeridianUniqueInBundle` plus the T10
   lock is the rule. The main session tells the owner at T09 close (O-4). Mitigations are owned
   elsewhere: the engine watchlist reader de-duplicates by symbol with a warning (T13), and T27
   reconciliation reports duplicate watchlist symbols.
6. **Concurrency.** `MeridianUniqueInBundle` is check-then-act. For the four ingested bundles
   T10's lock serialises writers (D5). `watchlist_item` has no lock; the database backstop on the
   derived `external_id` (`wl-{symbol}`) rejects the second of two concurrent creates of one
   symbol with an `EntityStorageException`. A unique key on `field_symbol` is impossible (shared
   storage, Decisions repeat symbols, no partial index in MariaDB).
7. `save()` does not call `validate()` in Drupal. Every writer must call `validate()`: forms do;
   T10 must. The database backstop is the only rule that also holds for a bare `save()`, and the
   tests prove it.

The chosen path (key, A or B) and its evidence are recorded in the T09 review and in the
technical-design "Unverified items" row.

### KD-5 Watchlist `external_id` derivation

`meridian_core` sets `field_external_id = 'wl-' . symbol` in `#[Hook('node_create')]` (when a
symbol is given) and in `#[Hook('node_presave')]` (safety net), through one service
`WatchlistExternalId::derive()` that T12's form entity builder will also call before
validation. `MeridianExternalIdMatches` rejects a mismatch. `symbol` is immutable after creation
(DN-8, path `field_symbol`): to replace a symbol, an administrator disables the item and creates
a new one.

### KD-6 Roles are created as config in T09 (DN-1)

Reasons: (1) data-model and D6 fix the roles and their permissions, and `cim` on a clean site
must recreate everything (AC4); (2) FR-16's measure is "100% of cells in the T09 permissions
matrix pass tests", which needs real roles; (3) T10 assigns `engine_ingest` to `svc_engine`, T11
`dashboard_read` to `svc_dashboard`, T12 builds Views on `analyst`, so creating them later would
block three tasks.

| AC wording | Machine name | Label |
|---|---|---|
| admin | `administrator` (`is_admin: true`; new, the `minimal` profile has none) | Administrator |
| analyst-read | `analyst` | Analyst |
| engine-ingest | `engine_ingest` | Engine ingest |
| (FR-16, D6) | `dashboard_read` | Dashboard read |

`anonymous` and `authenticated` lose `access content` (today both have it in `config/sync`) and
get no Meridian permission.

Permissions in `meridian_core.permissions.yml` (D6 names): `view meridian records`,
`view meridian watchlist`, `view meridian inputs`, `view meridian raw llm output`
(`restrict access: true`), `administer meridian records` (`restrict access: true`),
`ingest meridian records`, `export meridian records` (defined now, used by T12 Views).

| Role | Permissions |
|---|---|
| `administrator` | all (`is_admin`) |
| `analyst` | `access content`, `view meridian records`, `view meridian inputs`, `view meridian watchlist`, `export meridian records` |
| `engine_ingest` | `access content`, `ingest meridian records`, `view meridian watchlist` |
| `dashboard_read` | `access content`, `view meridian records`, `view meridian watchlist` |
| `authenticated`, `anonymous` | none |

**Matrix cells (FR-16, DN-1).** Six roles (the four above plus `anonymous`, `authenticated`).
A cell is one of: role by permission (7 Meridian permissions plus `access content` and
`bypass node access`; granted or not, and no extra permission on any role); role by bundle by
operation (`view`, `create`, `update`, `delete`) through the entity access API; role by
restricted field (view). HTTP cells of the D6 matrix are not T09 cells; `permissions.md` links to
D6 and names T10, T11, T22, T30.

### KD-7 Entity and field access (DN-2)

- `#[Hook('node_access')]`, `view` on the five bundles: **forbidden** without the bundle's
  permission (`view meridian records`; `watchlist_item`: `view meridian watchlist`), otherwise
  **neutral**, never "allowed", so core's published check still hides unpublished records.
- `update` and `delete` on the five bundles: **forbidden** for every account without `bypass
  node access` (administrators bypass node access hooks).
- `#[Hook('node_create_access')]`: **forbidden** for the five bundles without `bypass node
  access`.
- `#[Hook('entity_field_access')]`, `view` only: **forbidden** without the field's permission,
  otherwise **neutral**:

  | Field | Permission |
  |---|---|
  | `decision.raw_llm_output` | `view meridian raw llm output` |
  | `decision.inputs_snapshot`, `daily_run.llm_cost_usd`, `price_snapshot.source`, `watchlist_item.notes` | `view meridian inputs` |
  | `source_version`, `payload_hash` (four ingested bundles) | `administer meridian records` |

  Field `edit` is not restricted in T09 (T12).
- Every access result carries `cachePerPermissions()`.
- Limitation, stated in `permissions.md`: core alters node queries only when a module
  implements `hook_node_grants`, so entity queries and Views are not filtered by these hooks.
  T12 sets View access to the Meridian permission; T11 confirms JSON:API collections omit
  inaccessible entities. T09 adds no node grants.
- `meridian_ingest` (T10) writes through the Entity API with no access check.

### KD-8 Test infrastructure (T08 hand-over notes)

- `apps/drupal/phpunit.xml.dist`: bootstrap `web/core/tests/bootstrap.php`; suites `unit` and
  `kernel` over `web/modules/custom/*/tests/src/{Unit,Kernel}`; `<source>` includes
  `web/modules/custom` and excludes `tests`. No database URL in the file.
- `SIMPLETEST_DB`: in CI set in the `drupal` job env to the service container
  (`mysql://root:<ci-only value>@127.0.0.1:3306/meridian_test`, a throwaway value for an
  ephemeral container, not a secret; confirm gitleaks does not flag it). In DDEV use the
  web container value if DDEV sets one (**verify**), otherwise `quality.sh` exports
  `SIMPLETEST_DB=${SIMPLETEST_DB:-mysql://db:db@db/db}` for the `ddev` runner only.
- CI `drupal` job: `services: mariadb` with image `mariadb:10.6.<patch>` (exact tag, matching
  `ddev-dbserver` MariaDB 10.6 and `pantheon.yml` `database.version: 10.6`; SQLite is not
  allowed, `decision-native-quality.md`), health check, and setup-php `coverage: pcov`
  (was `none`, T08 plan).
- `scripts/check_ci.py` rule 2 gains: `.ddev/config.yaml` `database.type`/`version`,
  `pantheon.yml` `database.version` and the ci.yml `mariadb` service image major.minor are equal;
  fixtures and tests in `scripts/tests/test_check_ci.py`.
- pcov in DDEV: add `php8.3-pcov` (or the DDEV-documented form) through
  `webimage_extra_packages` in `.ddev/config.yaml` (**verify**), so `ddev quality` produces the
  same Cobertura XML as CI.
- `scripts/quality.sh`: remove the "phpstan: not run, no custom PHP yet (T09)" guard;
  `quality/expected-skips.txt`: delete the `component-drupal-tests` line (the step then runs and
  the 70% gate on `web/modules/custom/meridian_` applies).

## Steps

0. **Branch.** Wait until `task/T08-review-fixes` (it changes `ci.yml`, `quality.sh`,
   `test_check_ci.py`, `test_quality_sh.py` and `.github/README.md`) is merged to `origin/main`;
   then `git fetch origin` and create `task/T09-content-model` from up-to-date `origin/main`.
   Local `main` is behind `origin/main` (40 commits): do not branch from it. See O-2.
1. **Module skeleton and patterns.** `meridian_core.info.yml` (`core_version_requirement:
   ^11.1`, dependencies `drupal:node`, `drupal:options`, `drupal:datetime`, `drupal:user`),
   `meridian_core.permissions.yml`, `config/schema/meridian_core.schema.yml`,
   `src/Validation/Patterns.php`, Unit test `PatternsTest`; enable `datetime`, `options`,
   `meridian_core` in `core.extension.yml`.
2. **Test harness.** KD-8. `ddev quality` and `scripts/quality.sh --group core` pass.
3. **Content model config.** Five node types, storages, fields (with the `field_status` union and
   subsets), default form and view displays (KD-2). `SyncConfigTrait`; Kernel
   `ContentModelStructureTest`.
4. **Field constraints.** Hook class, core constraints, `MeridianBundleAllowedValues`,
   `MeridianJsonDocument`, `MeridianDecimalScale`, `MeridianDateNotAfterToday`,
   `MeridianNoDuplicateValues`; tests.
5. **Entity rules.** `MeridianExternalIdMatches` and the five `Meridian*Rules` constraints
   (DN-4, DN-5, DN-6); per-bundle Kernel tests.
6. **Lifecycle rules.** `MeridianImmutable` (`external_id`, watchlist `symbol`),
   `MeridianNonDecreasing`, watchlist derivation (KD-5) and the 50-enabled limit; tests.
7. **Uniqueness.** `MeridianUniqueInBundle`, `ExternalIdIndex` with the unique key first, then
   Fallback A or B per KD-4 if the "cannot be kept" test fires; install, uninstall and
   field-storage-insert hooks; `ExternalIdUniquenessTest`. Record the path and the collation.
8. **Roles and access.** Role config, `anonymous`/`authenticated` change, access hooks (KD-7),
   `PermissionsMatrixTest`, `docs/specs/permissions.md` (six roles, the neutral rule, the listing
   limitation, link to the D6 HTTP matrix).
9. **Round trip.** `ddev drupal-install --force` (it fails on any `config:status` difference);
   `ddev drush cex --yes` then `git status --porcelain apps/drupal/config/sync` is empty;
   `ddev drush cim --yes` reports no changes; `ddev drush config:status` shows "No differences".
   The fresh install from config is the "cim on a clean site" (`site:install
   --existing-config` is a config import onto an empty database). Also check the unique key (or
   Fallback A table) exists after this install path.
10. **MG-1, NFR-04 entity-layer part (DN-9).** `apps/drupal/scripts/perf/mg1_ingest_timing.php`
    via `ddev drush php:script` on a throwaway install (nothing written to `config/sync`):
    - Bundle `decision`, all referencing one Daily Run created first (not timed).
    - About 8 KB per Decision split across `inputs_snapshot` and `raw_llm_output` (JSON objects),
      so 500 items total about 4 MB.
    - Create pass: 500 new Decisions. Update pass: the same 500 with a changed field and a new
      revision. Each pass is one transaction, `validate()` on every entity, 0 violations
      asserted.
    - 5 runs, each starting with no Decisions (deletion not timed). Xdebug off.
    - Record the PHP and MariaDB versions, whether pcov is loaded, and the host (WSL2, CPU, RAM).
    - Output: raw per-run timings for both passes and the p95. With 5 runs the p95 is the slowest
      run; the output says so.
    - If create plus update p95 is above 15 s, the technical-architect raises it at T10 planning,
      before T10 coding.
11. **Docs.** Each spec file gets a dated revision note citing the decision file.
    - `docs/specs/data-model.md` (decision-field-rules.md "Summary of data-model edits" and
      decision-uniqueness.md DN-11):
      - Replace the "Uniqueness" paragraph with the DN-11 text.
      - Add under "Drupal content model": "Position and Daily Run share the storage
        `field_status`. Its allowed values are the union of both lists, and each bundle accepts
        only its own list (third-party setting `meridian_core.allowed_values`, T09)".
      - Position: `exit_date`, `exit_price`, `exit_reason`, `realised_pnl` "required when
        `closed`, empty when `open`" (exact DN-4 wording); `decision` Validation per DN-6;
        `external_id` "equals `pos-{symbol}-{mode}-{entry_date}` built from the record's own
        fields".
      - Daily Run: `skip_reason` and `watchlist_source` per DN-4; move "equals the date in
        `external_id`" from `trade_date` to `external_id` as "equals `run-{trade_date}`".
      - Decision: `external_id` "equals `dec-{trade_date}-{symbol}-{mode}` built from the
        record's own fields" (replaces "suffix equals `mode`"); `raw_llm_output` per DN-7.
      - Price Snapshot: `external_id` "equals `px-{trade_date}-{symbol}` built from the record's
        own fields".
      - Watchlist Item: `symbol` "Symbol regex `^[A-Z0-9&-]{1,20}$`; unique per bundle; cannot
        change after creation".
      - Postgres (for T14 parity): the `ck_positions_closed` "if and only if" text;
        `runs.skip_reason` and `runs.watchlist_source` notes (`ck_runs_wl_source_required`);
        `ck_decisions_external_id`, `ck_positions_external_id`; `ck_decisions_inputs_object` and
        `ck_decisions_llm_object`.
    - `docs/architecture/technical-design.md`:
      - D1 first bullet and "Sole writer" bullet: the DN-11 text (`MeridianUniqueInBundle`,
        unique key, the only backstop for concurrent admin creates of one watchlist symbol).
      - D1 field-visibility bullet: "`inputs_snapshot`, `llm_cost_usd`, Price Snapshot `source`
        and Watchlist Item `notes` need `view meridian inputs` (administrator and analyst)".
      - "Unverified items" row for the unique index: closed with the result, date and the DN-10
        path used.
      - "NFR numbers": NFR-04 DDEV row gets "T09 runs the entity-layer part (500 Decisions of
        about 8 KB, create and update, 5 runs); T10 confirms on the endpoint"; NFR-05 row
        becomes "Measured in T11 with 5,000 seeded nodes (D-2 authority moved to T11 by
        `docs/tasks/T09/decision-measurement-scope.md`); T30 confirms"; the MG-1 result with
        date and raw output is added below the table.
    - `docs/specs/permissions.md` (new), linked from `docs/specs/README.md`, data-model and D6.
    - `CODING_STANDARDS.md` coverage: the first measured Drupal value.
    - `apps/drupal/README.md` and `docs/runbooks/local-setup.md`: how to run the Drupal tests
      (`ddev exec -d /var/www/html/apps/drupal vendor/bin/phpunit --testsuite kernel`) and what
      `SIMPLETEST_DB` is.
    - `.github/README.md` and `scripts/README.md`: database service, pcov, parity rule.
12. **Gate.** `ddev quality` and CI green; `scripts/check-names.sh` clean.

Commit per step, messages `T09: ...`.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| Bundles and field machine names (`config/sync`) | New, per data-model; `field_status` shared with per-bundle subsets | T10 ingest mapping, T11 JSON:API filters (`field_*`), T12 Views, T19 publisher, T21+ dashboard, `openapi.yaml` `WatchlistResource` |
| Third-party setting `meridian_core.allowed_values` and its config schema | New | T12 (exposed filter options), future value changes |
| Constraint violation paths and codes | New: path = field name; codes `meridian.*` (including `meridian.external_id_mismatch`, `meridian.bundle_allowed_values`, the four `meridian.position.decision_*`) | T10 422 `errors[].path` and `code` |
| Validation of a Position against an unsaved Decision through `->entity` | New | T10 batch ordering (validate the Position after the Decision is attached) |
| `WatchlistExternalId::derive()` service | New | T12 form entity builder |
| `ExternalIdIndex` service; unique key `meridian_external_id_bundle` (or Fallback A table `meridian_external_id`) | New | T10 (duplicate insert raises `EntityStorageException`), T27 reconciliation |
| Permissions (`meridian_core.permissions.yml`) | New, 7 permissions | T10 scopes, T11, T12, T22 |
| Roles `administrator`, `analyst`, `engine_ingest`, `dashboard_read`; anonymous/authenticated lose `access content` | New / changed config | T10 service users, T11, T12, T22, T30 |
| Node and field access hooks (neutral, not allowed; no listing filter) | New | T11 JSON:API, T12 Views access, T22 |
| `docs/specs/permissions.md` | New | T10, T11, T12, T22, T30 |
| `docs/specs/data-model.md`, `technical-design.md` text | Amended (step 11) | T10, T11, T12, T14, T17, T18, T19 |
| `apps/drupal/phpunit.xml.dist`, `quality.sh` drupal steps, `expected-skips.txt` | New / changed | `ddev quality`, CI, T10 Functional tests |
| `ci.yml` `drupal` job (MariaDB service, pcov, `SIMPLETEST_DB`) and `check_ci.py` rule 2 | Changed | CI, T10 heavier set |
| `.ddev/config.yaml` (pcov package) | Changed | every developer |
| Earlier docs-regression suites (T05 lines 475, 476, 621; T06 line 1031 expect the SKIP and no module) | Tester updates them | `docs-regression` step |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Unique key on the dedicated field table conflicts with core field storage or the cim order | Medium | Low | KD-4 "cannot be kept" test; Fallback A decided in advance (DN-10) |
| Kernel tests cannot load `config/sync` cleanly through `SyncConfigTrait` (dependency order, `enforced` deps, third-party schema) | Medium | Medium | Build the trait first in step 3; fallback module `config/install` plus a parity test, recorded in the review |
| Third-party setting rejected by config validation or lost on a UI field edit | Low | Medium | Ship the schema in step 1; structure test checks the subset; `config:status` in step 9 |
| CI database or pcov setup differs from DDEV (extensions, MariaDB patch) | Medium | Medium | `check_ci.py` parity rule; both runs recorded in the test report (T08 condition 5) |
| pcov not installable in `ddev-webserver` as planned | Low | Medium | Fall back to Xdebug coverage mode in DDEV only, documented in `scripts/README.md` "Accepted differences" |
| Drupal coverage below 70% | Low | Low | Unit plus Kernel only; if below, ask for a decision (T04a D-1), no untracked excludes |
| Earlier docs-regression suites fail because the SKIP and "no module" checks no longer hold | Certain | Low | Tester updates T05 and T06 suites in this task |
| MG-1 p95 above 15 s | Unknown | Medium | Raised at T10 planning before T10 coding (DN-9) |
| Removing `access content` from anonymous breaks login or the install command | Low | Medium | `/user/login` needs no permission; step 9 install and `drush uli` prove it |
| Read roles see Meridian nodes through listings, because hooks do not filter queries | Certain without T11/T12 work | Medium | Documented in `permissions.md`; T12 View access, T11 collection test (DN-2) |
| IST "today" boundary flakes | Medium | Low | `datetime.time` stub with fixed instants either side of IST midnight |
| Task grows beyond M (access hooks, CI database, MG-1, spec edits) | Medium | Low | Commit per step; spec text is given verbatim in the decision files |
| T08 review fixes not merged when T09 starts | Medium | Medium | Step 0 and O-2 |

## Test hooks needed

- `SyncConfigTrait`: install named config from `config/sync` in Kernel tests.
- `MeridianRecordFactoryTrait`: one valid baseline entity per bundle (0 violations), plus
  `withValue(field, value)` mutation, so each rejection case changes exactly one thing and
  yields exactly one violation.
- Fixed clock: a `TimeInterface` stub registered over `datetime.time` in `register()`.
- Assertion helper: violations as a list of `(propertyPath, code)` pairs, compared exactly.
- Stable violation codes for every custom rule (KD-3).
- `ExternalIdIndex::exists()` and a raw `save()` without `validate()` for the race backstop.
- `docs/specs/permissions.md` tables in a parseable Markdown form (role, permission, value) so a
  docs suite can compare them with the `user.role.*.yml` files.
- MG-1 script prints raw per-run timings, p95 and the environment facts.

Planned Kernel and Unit classes (namespace `Drupal\Tests\meridian_core\...`):

| Class | Type | Covers |
|---|---|---|
| `PatternsTest` | Unit | each regex: accept `RELIANCE`, `M&M`, `BAJAJ-AUTO`, `NIFTY50`; reject lowercase, 21 characters, space, dot; version, model, rule ID, UUID, hash, each external_id pattern |
| `JsonDocumentValidatorTest`, `DecimalScaleValidatorTest` | Unit | invalid JSON, array, string and number when an object is required; byte limits at limit and limit + 1 with multibyte characters; extra fraction or integer digits |
| `ContentModelStructureTest` | Kernel | AC1: every bundle and field against an expected table copied from the amended data-model: type, cardinality, required, max length, allowed values, `field_status` union on the storage and subset on each instance, precision/scale, min/max, target bundles, `new_revision`; indexes on "yes" columns |
| `DecisionValidationTest` | Kernel | baseline valid; missing each required field; external_id regex; external_id mismatch on date, symbol and mode; trade_date tomorrow IST rejected, today accepted, IST-midnight boundary; symbol; mode `longg`; score -0.01, 100.01, 50.123 rejected, 0 and 100 accepted; action `SELL`/`buy`; BUY with pre AVOID; BUY with vetoed; vetoed with pre AVOID; vetoed without reason; reason without veto; bad reason; rule_hits bad item and 51 items; bad versions and model name; inputs_snapshot invalid, array, 65,537 bytes; raw_llm_output invalid, array, 32,769 bytes, `{"status":"not_called"}` accepted; rationale 2,001 characters; close_price 0; run to missing node and to wrong bundle; title 256 |
| `PositionValidationTest` | Kernel | required fields; external_id regex and mismatch; status `success` rejected (bundle subset); entry_price 0; quantity 0; stop 0, stop = entry, stop > entry; target = entry; short without time stop; time stop not after entry; long with time stop; closed without exit date, price, reason, realised P&L each; open with exit date, price, reason, realised P&L each; exit date not after entry; exit price 0; bad exit reason; costs -0.01; unrealised P&L when closed; mark price 0; mark date before entry; r_multiple ±100.001 rejected and ±100 accepted; refs wrong bundle; Decision AVOID, other symbol, other mode, dated after entry (one code each); Decision dated on entry accepted; unsaved Decision through `->entity` |
| `DailyRunValidationTest` | Kernel | required fields; external_id regex and mismatch; status `open` rejected (bundle subset); run_id uppercase or malformed; attempt 0; skipped without reason; success with reason; failed with `stale_lock` accepted and without reason accepted; reason 256; success without source; skipped and failed without source accepted; bad source; symbols_total -1 and 51; negative counts; buy_count > decisions_count; virtual_equity 0; llm_cost -0.0001; finished before started |
| `PriceSnapshotValidationTest` | Kernel | required fields; external_id regex and mismatch; open 0; close 0; low 0; low > open; low > close; high < open, < low, < close; volume -1; bad source |
| `WatchlistItemValidationTest` | Kernel | external_id derived on create and presave; mismatch rejected; symbol regex; duplicate symbol in bundle rejected while a Decision with that symbol is accepted; symbol change rejected at `field_symbol`; 51st enabled rejected, 51st disabled accepted, re-save of an enabled item at 50 accepted; modes empty, duplicate, bad value, 3 values; sort_order -1 and 1000; notes 501; enabled defaults true |
| `LifecycleRulesTest` | Kernel | external_id change rejected on every bundle; natural-key field change rejected as `meridian.external_id_mismatch`; source_version 0 rejected, equal and higher accepted, lower rejected |
| `ExternalIdUniquenessTest` | Kernel | AC3: duplicate external_id in the same bundle rejected by `validate()`; exact comparison (no `LIKE` wildcard match); updating the same node accepted; key (or Fallback A table) exists after config install (field-storage path) and after module install with an existing table (install path); bare `save()` of a duplicate throws `EntityStorageException` and leaves no node; key removed on uninstall |
| `PermissionsMatrixTest` | Kernel | AC6 and FR-16: six roles from `config/sync` against the 9 permissions (exact set, no extras); view, create, update, delete per role and bundle; an unpublished record hidden from `analyst`, `dashboard_read`, `engine_ingest`; field view per role for each restricted field; cache contexts per permissions |

## Decisions needed from solution-architect

None open. DN-1 to DN-11 are answered in the four decision files listed in the header. All
recommendations were accepted except DN-4, where the solution-architect decided that a `failed`
Daily Run may carry `skip_reason`, and that `watchlist_source` is required only on `success`.
The plan applies all eleven answers.

Solution-architect item at close:

- **SA-1** `docs/architecture/solution-architecture.md`: in the NFR-05 row, change
  "provisional until the T09 measurement gate" to "provisional until the T11 measurement
  (`docs/tasks/T09/decision-measurement-scope.md`)", and add one Amendments row (date, T09,
  NFR-05, pointer change). The solution-architect owns this file, so the main session asks for
  it at `/close-task`.

Owner items (main session):

- **O-1** Dependencies T03 and T05 are In test; the owner accepted starting T09 on 2026-11-04.
- **O-2** Start after `task/T08-review-fixes` is merged to `origin/main` (step 0). If T09 must
  start earlier, branch from `origin/main` and rebase on the merge before review; expect
  conflicts in `ci.yml`, `quality.sh` and `scripts/tests/`.
- **O-3** `docs/TASKS.md` T09 AC6 (owner's document, proposed only): replace "Permissions matrix
  documented (admin, analyst-read, engine-ingest)" with "Permissions matrix documented and
  tested for `administrator`, `analyst`, `engine_ingest`, `dashboard_read`, `anonymous` and
  `authenticated` (FR-16)". If it is not changed, the test report records this reading on the
  AC6 case.
- **O-4** Only if KD-4 Fallback B is used: the owner is told at close that concurrent admin
  creates of one watchlist symbol have no database backstop.
- Note: NFR-05's final value is now set in T11, not T09 (DN-9).

## Definition of done

- [ ] All task acceptance criteria in `docs/TASKS.md` met:
  - [ ] AC1 bundles and fields equal the amended data-model, exported in `config/sync`
  - [ ] AC2 every rule in KD-3 enforced through `validate()`
  - [ ] AC3 unique `external_id` per bundle at entity level, plus the database backstop (key or
    Fallback A), or Fallback B with O-4
  - [ ] AC4 `cex` after install shows no diff; install from config recreates everything
  - [ ] AC5 Kernel tests cover every rule, including each rejection case
  - [ ] AC6 `docs/specs/permissions.md` written for six roles and tested by
    `PermissionsMatrixTest` (O-3 reading)
- [ ] MG-1 NFR-04 entity-layer result recorded in `technical-design.md` with raw output
- [ ] Step 11 text changes in `data-model.md` and `technical-design.md` made, with dated revision
  notes; D1 unverified item (unique index) closed with the DN-10 path used
- [ ] SA-1 requested at close
- [ ] First measured Drupal coverage recorded; at least 70% or a decision recorded
- [ ] C1: Plan exists and was reviewed before coding started
- [ ] C2: Code reviewed; findings resolved
- [ ] C3: Every criterion maps to an executed test case with evidence
- [ ] C4: CI green, no new lint, type or security warnings (phpcs, PHPStan level 6, no baseline)
- [ ] C5: Docs and traceability updated (R-06, R-07, FR-16 rows)
- [ ] C6: No secrets; `.env.example` unchanged with reason: T09 adds no `MERIDIAN_` variable;
  `SIMPLETEST_DB` is a test-runner variable set by CI and DDEV, documented in
  `apps/drupal/README.md`
- [ ] C7: Works from a clean checkout with `ddev start`, `ddev drupal-install`, `ddev quality`
