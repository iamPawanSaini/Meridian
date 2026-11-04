# meridian_core

The Meridian content model rules (T09). Simulation only: nothing here touches a broker.

The five node bundles (`decision`, `position`, `daily_run`, `price_snapshot`, `watchlist_item`)
are configuration in `apps/drupal/config/sync`. They are owned by this module with
`dependencies.enforced.module: [meridian_core]`. The module has no `config/install` copy of the
model, only the schema of one third-party setting (`config/schema/meridian_core.schema.yml`).
The field list is `docs/specs/data-model.md`. Roles and permissions are in
`docs/specs/permissions.md`.

## What the module does

| Part | Where |
|---|---|
| Field rules that are not field settings (patterns, JSON documents, decimal scale, uniqueness, immutability, non-decreasing version) | `Plugin/Validation/Constraint/Meridian*` attached in `Hook/FieldConstraintHooks.php` |
| Cross-field rules, one constraint per bundle, and the external ID check | `Meridian*Rules`, `MeridianExternalIdMatches` (added to the node entity type) |
| Shared `field_status` with one value list per bundle (DN-3) | third-party setting `meridian_core.allowed_values`, `MeridianBundleAllowedValues` |
| Unique `external_id` per bundle, with a database key | `MeridianUniqueInBundle`, `Schema/ExternalIdIndex`, `Hook/SchemaHooks`, `meridian_core.install` |
| Watchlist `external_id` derived from the symbol | `Service/WatchlistExternalId`, `Hook/WatchlistHooks` |
| Node and field access (forbidden or neutral, never allowed) | `Hook/AccessHooks` |

Every rule runs on `$entity->validate()`. A violation uses the field machine name as its path
(`field_score`; `field_rule_hits.2` for one value of a multi-value field) and a stable code. The
custom codes are `meridian.*`: `meridian.pattern`, `meridian.max_length`,
`meridian.json_invalid`, `meridian.json_not_object`, `meridian.json_too_large`,
`meridian.decimal_scale`, `meridian.decimal_precision`, `meridian.date_in_future`,
`meridian.duplicate_value`, `meridian.bundle_allowed_values`, `meridian.unique_in_bundle`,
`meridian.immutable`, `meridian.non_decreasing`, `meridian.external_id_mismatch`, and
`meridian.<bundle>.<rule>` for the cross-field rules (for example
`meridian.position.decision_not_buy`). Core rules keep their core codes (required, allowed
values, range, length, count). A rule that reads another field adds nothing when that field is
missing or invalid, so one defect gives one violation.

`save()` does not call `validate()` in Drupal. Every writer must call it (forms do; the ingest
endpoint of T10 must). Only the database key also holds for a bare `save()`.

## Unique external ID: path used (KD-4, DN-10)

The first choice worked, so no fallback was used: a unique key `meridian_external_id_bundle` on
`node__field_external_id (bundle, field_external_id_value)`, not on the revision table.

- It is added when the field storage is created or updated (`field_storage_config_insert` and
  `field_storage_config_update` hooks), and by `hook_install()` when the table already exists.
  It is dropped by `hook_uninstall()`.
- Core drops and recreates the dedicated tables of a field storage without data on a storage
  update, which removes the key. The update hook adds it again. A Kernel test covers it
  (`ExternalIdUniquenessTest::testKeyLifecycle`).
- Collation of the table on DDEV (MariaDB 10.6): `utf8mb4_general_ci`, so the key is case
  insensitive. The patterns fix the letter case of every character, so this cannot cause a false
  duplicate. The entity-level rule compares exactly.
- A unique key on `field_symbol` is impossible (shared storage). The watchlist symbol backstop
  is the key on the derived `wl-{symbol}`.

## Tests

`apps/drupal/README.md`, "Tests". The Kernel tests create the content model from
`config/sync` with `SyncConfigTrait`, so they test the shipped YAML. To run them against another
copy of the config (for a mutation check), set the environment variable `MERIDIAN_SYNC_DIR` to
that directory, or set the protected property `$syncConfigDirectory` in a test class.
`MeridianRecordFactoryTrait` builds one valid record per bundle; each rejection case changes
one value. Kernel tests are slow (about ten seconds per method), so related cases share a method
and the failure message names the case.
