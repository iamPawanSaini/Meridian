# T09: Solution-architect decision on `external_id` uniqueness (DN-10, DN-11)

| Field | Value |
|---|---|
| Task | T09 |
| Author | solution-architect |
| Date | 2026-11-04 |
| Answers | `docs/tasks/T09/plan.md` (Draft), "Decisions needed from solution-architect", DN-10, DN-11; KD-4 |
| Related | D1, D3, D5 (`technical-design.md`); `docs/specs/data-model.md` "Uniqueness"; "Unverified items" row "Unique database index on `field_external_id` per bundle" |

## Facts (core 11.4.11 in this repository, read 2026-11-04)

- `UniqueFieldValueValidator::validate()` builds an aggregate query over the whole entity type.
  It has no bundle condition. Because `field_external_id` and `field_symbol` are shared
  storages, core `UniqueField` on the Watchlist `symbol` would collide with Decisions of the
  same symbol. The plan's KD-4 fact holds.
- `SqlContentEntityStorage::save()` opens a transaction around `EntityStorageBase::save()`,
  which runs pre-save, the write and the post-save hooks. A write in `hook_node_insert` is
  therefore inside the same transaction as the node row.

## DN-11: Wording amendments

### Decision

**Approved.** The binding entity-level rule is the custom `MeridianUniqueInBundle`
constraint. It uses an exact, case-sensitive comparison (not core's `LIKE`), adds a `type`
condition, uses `accessCheck(FALSE)`, and excludes the entity's own ID. It applies to
`field_external_id` on all five bundles and to `field_symbol` on `watchlist_item`.

Exact text changes (technical-architect, plan step 11; dated revision notes in both files):

**`docs/specs/data-model.md`, "Uniqueness" paragraph:** replace the paragraph with:

```text
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
```

**`docs/architecture/technical-design.md`, D1:**

- First bullet: replace "enforced at entity level (core `UniqueField` constraint) plus a
  database index added in T09" with "enforced at entity level (`MeridianUniqueInBundle`; core
  `UniqueField` is per entity type) plus a unique database key added in T09".
- "Sole writer" bullet: replace "the entity-level `UniqueField` check" with "the entity-level
  `MeridianUniqueInBundle` check", and "The database unique index stays as defence in depth"
  with "The database unique key stays as defence in depth, and it is also the only backstop
  against two concurrent admin creates of one Watchlist symbol".
- "Unverified items" row "Unique database index on `field_external_id` per bundle": close it
  with the T09 result and date, naming which DN-10 path applies.

### Reasons

1. The data model names a mechanism that cannot do the job on shared storages. Its intent (one
   record per bundle and key, enforced in the entity layer) is unchanged.
2. Exact comparison matches the regexes, which already fix the letter case. `LIKE` would
   treat `_` and `%` in values as wildcards unless escaped, which adds a risk for no benefit.

## DN-10: Fallback if the unique key cannot be kept

### Decision (applies only if plan step 7 fails)

The developer tries the KD-4 key first. "Cannot be kept" means any one of these, shown by a
test or a recorded run:

- the key is missing after `site:install --existing-config`, after `cim` onto a clean site, or
  after a field storage update or cache rebuild;
- the key makes `cim`, `config:status` or `drush updatedb` fail or report a change;
- core's entity schema checks report the field table as changed because of the key.

Then the fallback is, in this order:

1. **Fallback A (preferred): a `meridian_core` shadow table.** `hook_schema()` defines
   `meridian_external_id` with primary key (`bundle`, `external_id`) and a `nid` column.
   `hook_node_insert` inserts the row, which runs inside the node save transaction (fact
   above). A duplicate raises an integrity exception and the whole save rolls back.
   `hook_node_delete` removes the row. The table is never written by updates, because
   `external_id` is immutable. `ExternalIdIndex` keeps its interface (`ensure()`, `exists()`,
   `drop()`), so T10 and T27 still catch `EntityStorageException` the same way. The same
   Kernel tests apply (bare `save()` of a duplicate throws; validate rejects; the key exists
   after both install paths). This table is owned by the module, so field storage changes
   cannot remove it.
2. **Fallback B (only if A also fails):** no database backstop.
   `MeridianUniqueInBundle` plus the T10 ingest lock is the only rule for the ingested
   bundles, which is the binding rule the data model already states. For `watchlist_item`, the
   remaining risk is two administrators saving the same new symbol at the same moment. This is
   accepted, given one or two administrators and at most 50 items, with two mitigations:
   - the engine's watchlist reader (FR-01 lists T13 as the engine task)
     de-duplicates by symbol and logs a warning;
   - T27 reconciliation reports duplicate Watchlist symbols.

The developer records the chosen path, with the evidence, in the T09 review and in the
"Unverified items" row. Using Fallback A needs no new decision. Fallback B needs a note from the
main session to the owner at T09 close, because it leaves a known (small) gap.

### Reasons

1. A shadow table depends only on core APIs that a module owns (`hook_schema`, entity hooks).
   It cannot conflict with core's field storage schema handling, which is the risk named in
   the plan. It keeps the "bare `save()` cannot create a duplicate" guarantee.
2. Fallback B is the documented binding rule. It is acceptable because the race needs two
   concurrent admin saves of one symbol, and the effect (a duplicate watchlist entry) is
   detected downstream.
3. Deciding now, before step 7, lets the developer continue without stopping the task.

### Alternatives considered

| Option | Why not chosen |
|---|---|
| Unique key on `node__field_symbol` | Impossible: shared storage, and Decisions repeat symbols. MariaDB has no partial index |
| Per-bundle storages (`field_decision_external_id`, ...) with their own unique keys | Breaks the `field_<name>` rule and the JSON:API names (`field_external_id`) used by T10, T11 and the engine's watchlist read |
| A lock around watchlist saves | A lock released before commit does not stop the race. One held to commit needs custom transaction handling for one low-risk case |
| Stop the task and ask again | The options are known now; asking later costs a round trip |

### Consequences

- The KD-4 key stays the first choice. Fallback A is an implementation detail behind the same
  service and tests. T10's plan only needs to know that a duplicate insert raises
  `EntityStorageException`.
- Note for step 7: Drupal's MySQL driver creates tables with a case-insensitive collation by
  default (**verify** the actual collation of `node__field_external_id` on DDEV and record it).
  This cannot cause false duplicates, because each `external_id` regex fixes the letter case of
  every character.

## Sources

- Drupal core 11.4.11 in this repository, read 2026-11-04:
  `core/lib/Drupal/Core/Validation/Plugin/Validation/Constraint/UniqueFieldValueValidator.php`
  (no bundle condition; `LIKE` when not case-sensitive),
  `core/lib/Drupal/Core/Entity/Sql/SqlContentEntityStorage.php` (`save()` transaction around
  `parent::save()`)
- `docs/specs/data-model.md` ("Uniqueness"), `docs/architecture/technical-design.md` (D1, D3,
  D5, "Unverified items"), read 2026-11-04

## Open questions

- None now. If Fallback B is used, the owner is told at T09 close.
