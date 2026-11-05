# Meridian: Permissions matrix

| Field | Value |
|---|---|
| Task | T09 |
| Author | developer (from `docs/tasks/T09/decision-roles-and-access.md`, DN-1 and DN-2) |
| Date | 2026-11-04 |
| Source of truth | `apps/drupal/config/sync/user.role.*.yml`, `meridian_core.permissions.yml`, `AccessHooks` |
| Tested by | `PermissionsMatrixTest` (Kernel, `apps/drupal/web/modules/custom/meridian_core/tests/src/Kernel`) |

This is the FR-16 matrix of the content model. It covers six roles: `administrator`, `analyst`,
`engine_ingest`, `dashboard_read`, `anonymous` and `authenticated`. A cell is one of three kinds:
a role by permission, a role by bundle by operation, or a role by restricted field. The HTTP
cells of the design D6 matrix (401, 403, 405, scopes) are not T09 cells. They are in
[technical-design.md, D6](../architecture/technical-design.md) and are tested in T10 (ingest
scopes), T11 (read API), T22 (dashboard login) and T30 (end to end).

## Roles

| Role | Machine name | Used by |
|---|---|---|
| Administrator | `administrator` (`is_admin`, holds every permission) | People who manage the site |
| Analyst | `analyst` | Read and export in the admin UI |
| Engine ingest | `engine_ingest` | The `svc_engine` service user (T10) |
| Dashboard read | `dashboard_read` | The `svc_dashboard` service user (T11) |
| Anonymous | `anonymous` | Not logged in. Holds no permission |
| Authenticated | `authenticated` | Any logged-in user. Holds no permission (it loses `access content`) |

## Permissions

`meridian_core.permissions.yml` defines seven permissions. `view meridian raw llm output` and
`administer meridian records` are marked `restrict access`.

## Role by permission

Nine permissions per role (the seven Meridian ones, `access content` and `bypass node access`).
The administrator holds all of them through `is_admin`. No role has a permission that is not in
this table.

| role | permission | value |
|---|---|---|
| administrator | access content | yes |
| administrator | bypass node access | yes |
| administrator | view meridian records | yes |
| administrator | view meridian watchlist | yes |
| administrator | view meridian inputs | yes |
| administrator | view meridian raw llm output | yes |
| administrator | administer meridian records | yes |
| administrator | ingest meridian records | yes |
| administrator | export meridian records | yes |
| analyst | access content | yes |
| analyst | bypass node access | no |
| analyst | view meridian records | yes |
| analyst | view meridian watchlist | yes |
| analyst | view meridian inputs | yes |
| analyst | view meridian raw llm output | no |
| analyst | administer meridian records | no |
| analyst | ingest meridian records | no |
| analyst | export meridian records | yes |
| engine_ingest | access content | yes |
| engine_ingest | bypass node access | no |
| engine_ingest | view meridian records | no |
| engine_ingest | view meridian watchlist | yes |
| engine_ingest | view meridian inputs | no |
| engine_ingest | view meridian raw llm output | no |
| engine_ingest | administer meridian records | no |
| engine_ingest | ingest meridian records | yes |
| engine_ingest | export meridian records | no |
| dashboard_read | access content | yes |
| dashboard_read | bypass node access | no |
| dashboard_read | view meridian records | yes |
| dashboard_read | view meridian watchlist | yes |
| dashboard_read | view meridian inputs | no |
| dashboard_read | view meridian raw llm output | no |
| dashboard_read | administer meridian records | no |
| dashboard_read | ingest meridian records | no |
| dashboard_read | export meridian records | no |
| anonymous | access content | no |
| anonymous | bypass node access | no |
| anonymous | view meridian records | no |
| anonymous | view meridian watchlist | no |
| anonymous | view meridian inputs | no |
| anonymous | view meridian raw llm output | no |
| anonymous | administer meridian records | no |
| anonymous | ingest meridian records | no |
| anonymous | export meridian records | no |
| authenticated | access content | no |
| authenticated | bypass node access | no |
| authenticated | view meridian records | no |
| authenticated | view meridian watchlist | no |
| authenticated | view meridian inputs | no |
| authenticated | view meridian raw llm output | no |
| authenticated | administer meridian records | no |
| authenticated | ingest meridian records | no |
| authenticated | export meridian records | no |

## Role by bundle by operation

Through the entity access API, for a published record. `create`, `update` and `delete` are
`forbidden` by `AccessHooks` for every account without `bypass node access`, so only the
administrator can change a record in the UI. `meridian_ingest` (T10) writes through the Entity
API with no access check.

| role | bundle | operation | value |
|---|---|---|---|
| administrator | decision | view | yes |
| administrator | decision | create | yes |
| administrator | decision | update | yes |
| administrator | decision | delete | yes |
| administrator | position | view | yes |
| administrator | position | create | yes |
| administrator | position | update | yes |
| administrator | position | delete | yes |
| administrator | daily_run | view | yes |
| administrator | daily_run | create | yes |
| administrator | daily_run | update | yes |
| administrator | daily_run | delete | yes |
| administrator | price_snapshot | view | yes |
| administrator | price_snapshot | create | yes |
| administrator | price_snapshot | update | yes |
| administrator | price_snapshot | delete | yes |
| administrator | watchlist_item | view | yes |
| administrator | watchlist_item | create | yes |
| administrator | watchlist_item | update | yes |
| administrator | watchlist_item | delete | yes |
| analyst | decision | view | yes |
| analyst | decision | create | no |
| analyst | decision | update | no |
| analyst | decision | delete | no |
| analyst | position | view | yes |
| analyst | position | create | no |
| analyst | position | update | no |
| analyst | position | delete | no |
| analyst | daily_run | view | yes |
| analyst | daily_run | create | no |
| analyst | daily_run | update | no |
| analyst | daily_run | delete | no |
| analyst | price_snapshot | view | yes |
| analyst | price_snapshot | create | no |
| analyst | price_snapshot | update | no |
| analyst | price_snapshot | delete | no |
| analyst | watchlist_item | view | yes |
| analyst | watchlist_item | create | no |
| analyst | watchlist_item | update | no |
| analyst | watchlist_item | delete | no |
| engine_ingest | decision | view | no |
| engine_ingest | decision | create | no |
| engine_ingest | decision | update | no |
| engine_ingest | decision | delete | no |
| engine_ingest | position | view | no |
| engine_ingest | position | create | no |
| engine_ingest | position | update | no |
| engine_ingest | position | delete | no |
| engine_ingest | daily_run | view | no |
| engine_ingest | daily_run | create | no |
| engine_ingest | daily_run | update | no |
| engine_ingest | daily_run | delete | no |
| engine_ingest | price_snapshot | view | no |
| engine_ingest | price_snapshot | create | no |
| engine_ingest | price_snapshot | update | no |
| engine_ingest | price_snapshot | delete | no |
| engine_ingest | watchlist_item | view | yes |
| engine_ingest | watchlist_item | create | no |
| engine_ingest | watchlist_item | update | no |
| engine_ingest | watchlist_item | delete | no |
| dashboard_read | decision | view | yes |
| dashboard_read | decision | create | no |
| dashboard_read | decision | update | no |
| dashboard_read | decision | delete | no |
| dashboard_read | position | view | yes |
| dashboard_read | position | create | no |
| dashboard_read | position | update | no |
| dashboard_read | position | delete | no |
| dashboard_read | daily_run | view | yes |
| dashboard_read | daily_run | create | no |
| dashboard_read | daily_run | update | no |
| dashboard_read | daily_run | delete | no |
| dashboard_read | price_snapshot | view | yes |
| dashboard_read | price_snapshot | create | no |
| dashboard_read | price_snapshot | update | no |
| dashboard_read | price_snapshot | delete | no |
| dashboard_read | watchlist_item | view | yes |
| dashboard_read | watchlist_item | create | no |
| dashboard_read | watchlist_item | update | no |
| dashboard_read | watchlist_item | delete | no |
| anonymous | decision | view | no |
| anonymous | decision | create | no |
| anonymous | decision | update | no |
| anonymous | decision | delete | no |
| anonymous | position | view | no |
| anonymous | position | create | no |
| anonymous | position | update | no |
| anonymous | position | delete | no |
| anonymous | daily_run | view | no |
| anonymous | daily_run | create | no |
| anonymous | daily_run | update | no |
| anonymous | daily_run | delete | no |
| anonymous | price_snapshot | view | no |
| anonymous | price_snapshot | create | no |
| anonymous | price_snapshot | update | no |
| anonymous | price_snapshot | delete | no |
| anonymous | watchlist_item | view | no |
| anonymous | watchlist_item | create | no |
| anonymous | watchlist_item | update | no |
| anonymous | watchlist_item | delete | no |
| authenticated | decision | view | no |
| authenticated | decision | create | no |
| authenticated | decision | update | no |
| authenticated | decision | delete | no |
| authenticated | position | view | no |
| authenticated | position | create | no |
| authenticated | position | update | no |
| authenticated | position | delete | no |
| authenticated | daily_run | view | no |
| authenticated | daily_run | create | no |
| authenticated | daily_run | update | no |
| authenticated | daily_run | delete | no |
| authenticated | price_snapshot | view | no |
| authenticated | price_snapshot | create | no |
| authenticated | price_snapshot | update | no |
| authenticated | price_snapshot | delete | no |
| authenticated | watchlist_item | view | no |
| authenticated | watchlist_item | create | no |
| authenticated | watchlist_item | update | no |
| authenticated | watchlist_item | delete | no |

## Role by restricted field (view)

`yes` means the field may be viewed. Field `edit` is not restricted by T09 (T12). A
`watchlist_item` has no `source_version` or `payload_hash`.

| bundle | field | permission | administrator | analyst | engine_ingest | dashboard_read | anonymous | authenticated |
|---|---|---|---|---|---|---|---|---|
| decision | field_raw_llm_output | view meridian raw llm output | yes | no | no | no | no | no |
| decision | field_inputs_snapshot | view meridian inputs | yes | yes | no | no | no | no |
| daily_run | field_llm_cost_usd | view meridian inputs | yes | yes | no | no | no | no |
| price_snapshot | field_source | view meridian inputs | yes | yes | no | no | no | no |
| watchlist_item | field_notes | view meridian inputs | yes | yes | no | no | no | no |
| decision | field_source_version | administer meridian records | yes | no | no | no | no | no |
| decision | field_payload_hash | administer meridian records | yes | no | no | no | no | no |
| position | field_source_version | administer meridian records | yes | no | no | no | no | no |
| position | field_payload_hash | administer meridian records | yes | no | no | no | no | no |
| daily_run | field_source_version | administer meridian records | yes | no | no | no | no | no |
| daily_run | field_payload_hash | administer meridian records | yes | no | no | no | no | no |
| price_snapshot | field_source_version | administer meridian records | yes | no | no | no | no | no |
| price_snapshot | field_payload_hash | administer meridian records | yes | no | no | no | no | no |

## Rules the hooks follow

1. **Neutral, not allowed.** `hook_node_access` returns `forbidden` or `neutral`, never
   `allowed`. A view is forbidden without the bundle permission (`view meridian records`, or
   `view meridian watchlist` for a Watchlist Item) and neutral otherwise. Neutral keeps the core
   published check, so a record that an administrator unpublished stays hidden from `analyst`,
   `dashboard_read` and `engine_ingest`. Field view is forbidden without the field permission and
   neutral otherwise.
2. **Cache.** Every result carries the cache context `user.permissions`.
3. **No listing filter.** Core alters node queries only when a module implements
   `hook_node_grants`, and T09 adds none. Entity queries and Views are therefore **not** filtered
   by these hooks. T12 sets view access of every Meridian View to the Meridian permission, with a
   test that `engine_ingest` (which has `access content`) is denied. T11 confirms that JSON:API
   collections leave out inaccessible entities.
4. **Administrators bypass the node hooks** (`bypass node access`). T12 limits what the admin
   forms offer (an administrator may only unpublish the four ingested bundles).
