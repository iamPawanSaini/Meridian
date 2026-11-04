# T09: Solution-architect decision on field rules (DN-3 to DN-8)

| Field | Value |
|---|---|
| Task | T09 |
| Author | solution-architect |
| Date | 2026-11-04 |
| Answers | `docs/tasks/T09/plan.md` (Draft), "Decisions needed from solution-architect", DN-3 to DN-8; KD-2, KD-3, KD-5 |
| Related | `docs/specs/data-model.md`; `docs/architecture/openapi.yaml`; D1, D2, D3 (`technical-design.md`); `docs/TASKS.md` T09, T10, T14, T17, T18, T19 |

Every rule below runs on `$entity->validate()`. It uses the field machine name as the
violation path and a stable `meridian.*` code (KD-3). A rule that reads another field or entity
returns without a violation when that input is missing or invalid, because the input's own
rule already reports it. So each rejection case produces exactly one violation.

## DN-3: `field_status` on Position and Daily Run

### Decision

**Option (b): one shared `list_string` storage `field_status`, with a per-bundle subset.**

1. The storage `allowed_values` hold the union in this order: `open`, `closed`, `success`,
   `failed`, `skipped`.
2. The bundle subset is **config**, not code. Each field instance carries it as a third-party
   setting:
   - `field.field.node.position.field_status`:
     `third_party_settings.meridian_core.allowed_values: [open, closed]`
   - `field.field.node.daily_run.field_status`:
     `third_party_settings.meridian_core.allowed_values: [success, failed, skipped]`

   `meridian_core` ships the config schema for `field.field.*.*.*.third_party.meridian_core`.
   One generic constraint, `MeridianBundleAllowedValues`, reads the setting and rejects any
   other value at path `field_status` (code `meridian.bundle_allowed_values`). It applies to
   any field instance that has the setting.
3. `ContentModelStructureTest` checks the union on the storage and the subset on each
   instance against the data-model values.

### Reasons

1. Names stay `field_status` on both bundles, as the data model says, so JSON:API attribute
   names and the T11 `status` filter match the spec.
2. Values stay in `config/sync`, so AC1 ("exactly as in the T03 spec, exported as config") can
   be checked from config alone, and `cim` recreates them.
3. The union and the subset are both plain config. A future value is a config change plus the
   matching data-model edit, not a code change.

### Alternatives considered

| Option | Why not chosen |
|---|---|
| (a) `field_position_status`, `field_run_status` | Breaks the `field_<name>` rule and changes JSON:API names that T11, T21 and the OpenAPI read side would carry |
| (c) `allowed_values_function` in code | Values leave config, so AC1 cannot be checked from `config/sync`; the callback gets no entity in Views filters, so it returns the union there anyway |
| Subset as constants in PHP | Works, but splits the content model between YAML and code |

### Consequences

- Admin widgets and Views exposed filters built from the storage show all five values. T12
  limits the exposed filter options per View (Positions: `open`, `closed`; Daily Runs:
  `success`, `failed`, `skipped`). No admin form edits `status` (ingested bundles).
- Core blocks removing an allowed value from a storage that has data. Adding a value is free.
  Any later change to either subset is a data-model amendment first.
- Data-model edit (below): one note under "Drupal content model".

## DN-4: "Required when" versus "empty otherwise"

### Decision

| Bundle | Condition | Rule |
|---|---|---|
| `position` | `status` = `closed` | `exit_date`, `exit_price`, `exit_reason`, `realised_pnl` required; `unrealised_pnl` empty (as specified) |
| `position` | `status` = `open` | `exit_date`, `exit_price`, `exit_reason`, `realised_pnl` **empty**. `unrealised_pnl`, `last_mark_price`, `last_mark_date` optional |
| `daily_run` | `status` = `skipped` | `skip_reason` required. `watchlist_source` optional |
| `daily_run` | `status` = `success` | `skip_reason` **empty**. `watchlist_source` required |
| `daily_run` | `status` = `failed` | `skip_reason` optional. `watchlist_source` optional |

This differs from the plan's recommendation in two places:

- **`skip_reason` may be set on a `failed` run.** D2 marks a stale `running` row `failed`
  with `skip_reason = 'stale_lock'`. The field carries a reason for any terminal status
  except success. Forbidding it on `failed` would turn a valid Postgres row into a predictable
  422.
- **`watchlist_source` is required only on `success`**, not "unless `skipped`". A run can
  fail before it reads the watchlist (for example a config error at start, or a stale lock on
  a crashed run). Postgres `runs.watchlist_source` is nullable for that reason.

### Reasons

1. An open position with an exit price or realised P&L is a contradiction. The model has one
   exit date, price and reason per position (no partial exits), so "iff" is exact.
2. Data-model review finding 8 requires that a row the engine accepts never becomes a
   predictable 422 at ingest. The two Daily Run relaxations follow the Postgres facts in D2.
   The Postgres checks below then match Drupal exactly.
3. FR-01 ("100% of runs record the watchlist source") is an engine requirement, verified on
   Postgres runs (T20, T31). Drupal does not need to police it on failed runs.

### Consequences: spec changes

**Data-model, Position table** (technical-architect, plan step 11):

- `exit_date` Validation: "Required when `status` is `closed`, empty when `open`; after
  `entry_date`".
- `exit_price` Validation: "Greater than 0; required when `closed`, empty when `open`".
- `exit_reason` Validation: "Allowed values `stop`, `gap_stop`, `target`, `time_stop`;
  required when `closed`, empty when `open`".
- `realised_pnl` Validation: "Any sign; required when `closed`, empty when `open`".

**Data-model, Daily Run table:**

- `skip_reason` Validation: "Required when `status` is `skipped`; empty when `success`;
  optional when `failed` (for example `stale_lock`, D2)".
- `watchlist_source` Validation: "Allowed values `drupal`, `snapshot`, `seed` (FR-01);
  required when `status` is `success`, optional otherwise".

**Data-model, Postgres** (for T14 parity, same edit):

- `positions` "Constraints and indexes": replace "check `ck_positions_closed` (closed implies
  exit date, price and reason)" with "check `ck_positions_closed`: `status = 'closed'` if and
  only if `exit_date`, `exit_price`, `exit_reason` and `realised_pnl` are all NOT NULL; and
  `unrealised_pnl` is NULL when `closed`".
- `runs` `skip_reason` Notes: "Required by `ck_runs_skip` when `status = 'skipped'`, and NULL
  when `status = 'success'`".
- `runs` `watchlist_source` Notes: add "NOT NULL when `status = 'success'`
  (`ck_runs_wl_source_required`)".

## DN-5: `external_id` must match the record's own fields

### Decision

**Yes.** For each bundle, `external_id` must equal the D3 format built from the same entity's
fields, compared as strings:

| Bundle | Must equal |
|---|---|
| `decision` | `dec-{trade_date}-{symbol}-{mode}` |
| `position` | `pos-{symbol}-{mode}-{entry_date}` |
| `daily_run` | `run-{trade_date}` |
| `price_snapshot` | `px-{trade_date}-{symbol}` |
| `watchlist_item` | `wl-{symbol}` (KD-5, unchanged) |

One violation at path `field_external_id`, code `meridian.external_id_mismatch`, for every
bundle. It replaces the separate "suffix equals `mode`" and "Daily Run date equals the date in
`external_id`" rules, which are special cases of it. `title` is **not** checked: it is display
text.

### Reasons

1. `external_id` is the idempotency key (D3). A record whose key disagrees with its natural key
   would let a later rerun create a second node for the same date, symbol and mode, which
   breaks FR-24.
2. One rule with one code is simpler for T10's error mapping than three partial rules.

### Consequences

- Together with `MeridianImmutable` on `external_id`, the natural-key fields cannot change
  after creation: Decision `trade_date`, `symbol`, `mode`; Position `symbol`, `mode`,
  `entry_date`; Daily Run `trade_date`; Price Snapshot `trade_date`, `symbol`. This matches D3
  (natural keys never move). An attempted change reports `meridian.external_id_mismatch`.
- Engine side: the engine derives `external_id` from the natural key by construction (D3).
  T14 should add matching checks, so the Postgres mirror rule holds (for example
  `ck_decisions_external_id`: `external_id = 'dec-' || to_char(trade_date, 'YYYY-MM-DD') || '-'
  || symbol || '-' || mode`).
- Data-model edits:
  - Decision `external_id` Validation: replace "suffix equals `mode`" with "equals
    `dec-{trade_date}-{symbol}-{mode}` built from the record's own fields".
  - Position `external_id`: add "equals `pos-{symbol}-{mode}-{entry_date}` built from the
    record's own fields".
  - Price Snapshot `external_id`: add "equals `px-{trade_date}-{symbol}` built from the
    record's own fields".
  - Daily Run: move "equals the date in `external_id`" from `trade_date` to `external_id` as
    "equals `run-{trade_date}`".
  - Postgres `decisions` and `positions`: add the `ck_*_external_id` checks above.

## DN-6: The Position's Decision

### Decision

**Yes to all four.** The Decision referenced by `field_decision` must have:

1. `action` = `BUY`;
2. the same `symbol` as the Position;
3. the same `mode` as the Position;
4. `trade_date` on or before the Position's `entry_date`.

Each failed condition is one violation at path `field_decision`. Codes follow the KD-3
convention (one code per condition, so the tests can tell them apart). The validator reads the
target through the field item's `entity` property, not by loading the node by ID. So the rule
works both for a stored Decision and for an unsaved Decision that T10 resolves from the same
batch. When the target is missing or of the wrong bundle, the rule adds nothing
(`ValidReference` reports it).

### Reasons

1. The data model calls it "Opening BUY decision". Positions open only on BUY (T18 AC1). A
   Position linked to an AVOID decision, or to another symbol or mode, would corrupt the
   decisions-to-positions reports (FR-18).
2. "On or before" fits both entry conventions: entry at the decision's close (same date) or at
   the next session's open (a later date). T18 fixes the convention. T09 must not assume it.

### Consequences

- Postgres cannot express these with a CHECK constraint (they span two tables). The engine
  guarantees them by construction. T18 adds a test that every opened position refers to a BUY
  decision with the same symbol and mode, dated on or before entry.
- T10 must validate the Position after the Decision of the same batch is attached to the
  reference. That is a T10 ordering note, not a T09 change.
- Data-model edit: Position `decision` Validation: "Opening BUY decision, resolved from
  `decision_external_id`; the target has `action` `BUY`, the same `symbol` and `mode`, and a
  `trade_date` on or before `entry_date`".

## DN-7: `raw_llm_output` shape

### Decision

**JSON object only.** `MeridianJsonDocument` runs with `objectOnly: true` on both
`inputs_snapshot` and `raw_llm_output`. Byte limits are the UTF-8 byte length of the stored
string (65,536 and 32,768).

### Reasons

1. `openapi.yaml` already says `type: object`, and every documented value is an object,
   including `{"status":"not_called"}`. "Valid JSON" in the data model is looser than the
   contract, so it is the data model that is imprecise.
2. An object is extensible. The dashboard (T24) and replay can read `status` and other keys
   without type checks.

### Consequences

- **T17:** an LLM reply that is not a JSON object (malformed text, an array, a bare string, an
  empty body) is stored **wrapped** in an object, with the raw text in a string member. The
  decision is still vetoed per FR-06. T17 defines the exact wrapper keys in its prompt and
  schema documents. The reply is kept as received, only wrapped.
- **T10:** the bytes counted are the bytes Drupal stores. T10 records which serialisation it
  stores (the JCS form already computed for `payload_hash` is the natural choice). The T19
  pre-send size check uses the same serialisation.
- Data-model edits:
  - Decision `raw_llm_output` Validation: "Valid JSON object, at most 32,768 bytes;
    `{"status":"not_called"}` when no review ran; a reply that is not a JSON object is stored
    wrapped in an object (T17); rendered escaped".
  - Postgres `decisions` checks: add `ck_decisions_inputs_object`:
    `jsonb_typeof(inputs_snapshot) = 'object'`, and `ck_decisions_llm_object`:
    `jsonb_typeof(raw_llm_output) = 'object'`. The Drupal object rule on `inputs_snapshot` has
    no Postgres mirror today. This closes that gap too.

## DN-8: Watchlist `symbol` after creation

### Decision

**Immutable after creation.** `MeridianImmutable` applies to `field_symbol` on
`watchlist_item` (path `field_symbol`). To replace a symbol, an administrator disables the old
item and creates a new one. A disabled item keeps its symbol, so to bring a symbol back,
re-enable the existing item. T12 shows `symbol` read-only on the edit form.

### Reasons

1. `external_id` (`wl-{symbol}`) is immutable (D1) and must match `symbol` (DN-5), so an edit
   could never pass validation. A clear "symbol cannot change" message is better than an
   `external_id` mismatch.
2. Keeping the old item keeps the history of what the engine read (FR-01 snapshots record
   symbols, not node IDs).

### Consequences

- An administrator (with `bypass node access`) can still delete a never-used item. That frees
  the symbol. T12 decides whether its UI offers delete. The data model says nodes are not
  deleted through the API, which stays true.
- Data-model edit: Watchlist Item `symbol` Validation: "Symbol regex `^[A-Z0-9&-]{1,20}$`;
  unique per bundle; cannot change after creation".

## Summary of data-model edits (technical-architect, plan step 11)

All edits above go into `docs/specs/data-model.md` with a dated revision note ("T09 amendment,
2026-11-04, `docs/tasks/T09/decision-field-rules.md`"). Also add one sentence under "Drupal
content model": "Position and Daily Run share the storage `field_status`. Its allowed values
are the union of both lists, and each bundle accepts only its own list (third-party setting
`meridian_core.allowed_values`, T09)". `openapi.yaml` needs no change. Its patterns and enums
already match, and the conditional rules (DN-4 to DN-6) are not expressible in it. The ingest
422 reports them.

## Sources

- `docs/specs/data-model.md`, `docs/architecture/openapi.yaml` (`DailyRunItem`,
  `DecisionItem`, `PositionItem`), `docs/architecture/technical-design.md` (D2 "Run attempts and
  the lock", D3), `docs/architecture/solution-architecture.md` (FR-01, FR-05, FR-06, FR-24),
  `docs/TASKS.md` (T12, T14, T17, T18), read 2026-11-04

## Open questions

- None for the owner. T14, T17 and T18 inherit the consequences above. Each task's plan should
  cite this file.
