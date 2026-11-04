# T09: Solution-architect decision on roles and access scope (DN-1, DN-2)

| Field | Value |
|---|---|
| Task | T09 |
| Author | solution-architect |
| Date | 2026-11-04 |
| Answers | `docs/tasks/T09/plan.md` (Draft), "Decisions needed from solution-architect", DN-1, DN-2; KD-6, KD-7 |
| Related | FR-16, FR-20 (`solution-architecture.md`); D1, D6 (`technical-design.md`); `docs/specs/data-model.md` "Drupal content model"; `docs/TASKS.md` T09 AC6, T10, T11, T12 |

## DN-1: Roles in the acceptance criterion

### Question

AC6 says "Permissions matrix documented (admin, analyst-read, engine-ingest)". FR-16, the data
model and D6 name four roles. Does T09 create and document all four? Does the matrix also cover
`anonymous` and `authenticated`?

### Decision

**Yes to both.**

1. T09 creates four roles as config in `config/sync`, with these mappings to the AC wording:

   | AC wording | Machine name | Label |
   |---|---|---|
   | admin | `administrator` (`is_admin: true`) | Administrator |
   | analyst-read | `analyst` | Analyst |
   | engine-ingest | `engine_ingest` | Engine ingest |
   | (not in the AC; FR-16, D6) | `dashboard_read` | Dashboard read |

2. The permissions are exactly the KD-6 table, which equals D6 "Roles". `anonymous` and
   `authenticated` lose `access content` and get no Meridian permission.
3. `docs/specs/permissions.md` and `PermissionsMatrixTest` cover **six** roles: the four above
   plus `anonymous` and `authenticated`. A "cell" for FR-16 ("100% of cells in the T09
   permissions matrix pass tests") is one of:
   - role by permission (the 7 Meridian permissions plus `access content`, `bypass node
     access`): granted or not, and no extra permission on any role;
   - role by bundle by operation (`view`, `create`, `update`, `delete`): allowed or not, through
     the entity access API;
   - role by restricted field (`raw_llm_output`, `inputs_snapshot`, `llm_cost_usd`,
     `price_snapshot.source`, `watchlist_item.notes`, `source_version`, `payload_hash`): view
     allowed or not.
4. HTTP cells of the D6 authorisation matrix (401, 403, 405, scopes) are **not** T09 cells.
   `permissions.md` links to D6 for them and names the tasks that test them (T10, T11, T22,
   T30).

### Reasons

1. FR-16's measure is a test over the T09 matrix. A matrix without `dashboard_read` would leave
   the Next.js read client (T11) untested at the entity level.
2. The `anonymous` and `authenticated` change is part of T09 config (D6 "Entity access" item 1).
   It is the change most likely to regress, so it needs matrix cells.
3. The AC names are informal labels. The machine names were fixed by T03 and are used by T10,
   T11 and T12.

### Proposed `docs/TASKS.md` text (owner's document: propose only, O-3)

Current:

```text
- [ ] Permissions matrix documented (admin, analyst-read, engine-ingest)
```

Proposed:

```text
- [ ] Permissions matrix documented and tested for `administrator`, `analyst`, `engine_ingest`, `dashboard_read`, `anonymous` and `authenticated` (FR-16)
```

Until the owner changes the text, the test report records this reading in a note on the AC6
case, as in T07 SA-5.

## DN-2: Access code scope, and the visibility of `source` and `notes`

### Question

Do `hook_node_access`, create access and `hook_entity_field_access` belong to T09, with T11
testing the same rules over JSON:API? May `price_snapshot.source` and `watchlist_item.notes` use
`view meridian inputs`?

### Decision

**Yes to both, with three rules on how the hooks return results.**

1. **In T09:** the node access hook, the create access hook and the field access hook in
   `meridian_core`, tested with Kernel tests through the entity access API
   (`$entity->access()`, `$items->access()`, the access control handler's `createAccess()`).
   **In T11:** the same rules over JSON:API (collections and single resources). **In T10, T11,
   T22:** the 401 subscriber, the scope allowlist and the HTTP matrix cells. No change to that
   split.
2. **Return values.**
   - Node `view`: return **forbidden** when the account lacks the bundle's permission and
     **neutral** otherwise. Do not return "allowed". Neutral keeps core's published check, so a
     record an administrator has unpublished stays hidden from `analyst`, `dashboard_read` and
     `engine_ingest`. "Allowed" would make unpublishing useless.
   - Node `update` and `delete` on the five bundles: **forbidden** for every account without
     `bypass node access`. Node `create` on the five bundles: **forbidden** without `bypass node
     access`. Administrators bypass the hooks (`is_admin`). T12 then limits what the admin forms
     offer (unpublish only for ingested bundles). `meridian_ingest` (T10) writes through the
     Entity API with no access check, as KD-7 says.
   - Field `view`: **forbidden** when the account lacks the field's permission, **neutral**
     otherwise. Field `edit` is not restricted in T09 (T12).
   - Every result carries `cachePerPermissions()`, so JSON:API and render caching vary
     correctly.
3. **Field permissions** (final mapping):

   | Field | Permission | Roles that have it |
   |---|---|---|
   | `decision.raw_llm_output` | `view meridian raw llm output` | `administrator` |
   | `decision.inputs_snapshot`, `daily_run.llm_cost_usd`, `price_snapshot.source`, `watchlist_item.notes` | `view meridian inputs` | `administrator`, `analyst` |
   | `source_version`, `payload_hash` (four ingested bundles) | `administer meridian records` | `administrator` |

   This gives exactly the data-model "Visible to" column for every field.

### Reasons

1. Data-model and D6 place `hook_node_access()` and `hook_entity_field_access()` in
   `meridian_core`, the T09 module. FR-16 needs them in place to have a matrix to test. T11,
   T12 and T22 build on them, so leaving them out of T09 would block three tasks.
2. Kernel tests through the access API are the cheapest exact proof. They need no HTTP stack, so
   they keep the T09 rule of no Functional tests (`decision-heavier-set.md` tripwire).
3. `source` and `notes` are listed as "administrator, analyst" in the data model. That is
   exactly the `view meridian inputs` role set. A separate permission per field would add two
   permissions with identical grants and no use. `notes` is "never sent to the LLM": the engine
   role lacks `view meridian inputs`, so JSON:API omits `notes` from the engine's watchlist read.
   That enforces the rule on the Drupal side.

### Alternatives considered

| Option | Why not chosen |
|---|---|
| Document the matrix only in T09 and write the hooks in T11 | FR-16 cells could not be tested in T09; T12 and T11 would both need the hooks first |
| Node `view` returns "allowed" when the permission is present | Unpublished records would become visible to every read role |
| New permissions `view meridian source`, `view meridian notes` | Same grants as `view meridian inputs`; more matrix cells for no difference |

### Consequences

1. **`hook_node_access` does not filter listings.** Core 11.4.11 alters node queries only when a
   module implements `hook_node_grants` (`NodeDatabaseHooks::queryNodeAccessAlter`, read
   2026-11-04). Entity queries and Views are therefore **not** filtered by the T09 hook.
   Specifically:
   - **T12:** every Meridian View must set view access to the Meridian permission (`view meridian
     records`, or `view meridian watchlist` for Watchlist Items). This matters because
     `engine_ingest` has `access content`. T12's role tests include an `engine_ingest` request
     to each View, which must be denied.
   - **T11:** JSON:API checks access on each loaded entity and leaves inaccessible ones out of
     collections (**unverified** for core 11.4.11; T11 confirms with a test in which
     `engine_ingest` lists `node--decision` and gets no record, and the scope allowlist gives
     403 before that).
   - T09 adds no node grants module. Grants would need a `node_access` rebuild and add moving
     parts. The permission on the View is enough.
2. `docs/specs/permissions.md` states the "neutral, not allowed" rule and the listing
   limitation, so that T11 and T12 do not have to rediscover them.
3. **Technical-design D1** (technical-architect, plan step 11): extend the field-visibility
   bullet. Current: "`inputs_snapshot` and `llm_cost_usd` need `view meridian inputs`
   (administrator and analyst)". New: "`inputs_snapshot`, `llm_cost_usd`, Price Snapshot
   `source` and Watchlist Item `notes` need `view meridian inputs` (administrator and
   analyst)".

## Sources

- `docs/specs/data-model.md` ("Drupal content model", "Visible to" columns),
  `docs/architecture/technical-design.md` (D1, D6), `docs/architecture/solution-architecture.md`
  (FR-16, FR-20), `docs/TASKS.md` (T09 to T12), read 2026-11-04
- Drupal core 11.4.11 in this repository, read 2026-11-04:
  `core/modules/node/src/NodeAccessControlHandler.php` (`access()`: `bypass node access` skips
  hooks for non-revision operations; no `access content` gives forbidden),
  `core/modules/node/src/Hook/NodeDatabaseHooks.php` (`queryNodeAccessAlter()` returns early
  without `hook_node_grants` implementations)

## Open questions

- Owner: apply the proposed AC6 wording (O-3), or leave it and rely on the test-report note.
