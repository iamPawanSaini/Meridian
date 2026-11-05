# T09: Content model as configuration, Test cases

| Field | Value |
|---|---|
| Task | T09 |
| Author | tester |
| Date | 2026-11-04 |
| Criteria source | `docs/TASKS.md` T09 (AC1 to AC6 in the order listed there; AC6 as reworded 2026-11-04) and section 3.3 (C1 to C7) |
| Design inputs | `docs/tasks/T09/plan.md` (rev 2, Approved 2026-11-04); `decision-roles-and-access.md` (DN-1, DN-2), `decision-field-rules.md` (DN-3 to DN-8), `decision-measurement-scope.md` (DN-9), `decision-uniqueness.md` (DN-10, DN-11); `docs/specs/data-model.md`; `docs/tests/master-test-plan.md`; `docs/standards/` |
| Written from | criteria and design documents only. No implementation existed when this file was written |

Criteria:

- AC1: Content types and fields exactly as in the T03 spec, exported as config in `config/sync`
- AC2: Validation enforced: mode in {long, short}, action in {BUY, AVOID}, score 0 to 100,
  required fields, numeric ranges
- AC3: Unique `external_id` enforced per type at entity level (not only in the API)
- AC4: `ddev drush cex` after install shows no diff; `cim` on a clean site recreates everything
- AC5: PHPUnit kernel tests cover every validation rule, including each rejection case
- AC6: Permissions matrix documented and tested for `administrator`, `analyst`,
  `engine_ingest`, `dashboard_read`, `anonymous` and `authenticated` (FR-16)
- C1 to C7: common criteria, `docs/TASKS.md` section 3.3

"The data-model" below means `docs/specs/data-model.md` **as amended by T09 step 11**. Where the
plan and the amended data-model differ, the amended data-model wins for field lists, and the
plan's KD-3 rule table wins for rules. Any difference is a defect or a plan question, not a
reason to change an expected result.

## How to run

Shorthand used in the cases:

| Name | Command |
|---|---|
| `PU` | `ddev exec -d /var/www/html/apps/drupal vendor/bin/phpunit` |
| `PU-K` | `PU --testsuite kernel` |
| `PU-U` | `PU --testsuite unit` |
| `PU-F <Class>` | `PU --testsuite kernel --filter <Class>` |
| `PU-V` | `PU --testsuite kernel --testdox` (the evidence for coverage-of-rules cases: test names are read and mapped to the rules) |
| `EVD` | `docs/tests/T09/evidence/TC-T09-nn.txt`, written with `2>&1 \| tee` |

Rules that apply to every case:

- **Mapping rule for test-reading cases (AC5).** The tester does not trust a green suite alone.
  For each validation case below, run `PU-V`, then list which test method (data-provider case or
  method name) covers each rule named in the case. A rule with no test, or a test that asserts
  only "has violations" without the exact `(propertyPath, code)` pair, is a Fail (defect:
  insufficient coverage). The plan's own helper (`(propertyPath, code)` list, compared exactly,
  one violation per rejection) is the expected style.
- **Sensitivity check (mutation-style, tester-run, throwaway).** For the cases marked "MUT", the
  tester temporarily weakens one rule in a scratch copy (for example loosens `max` to 101 on
  `field_score`, or deletes a constraint attachment) and confirms the matching test fails. The
  scratch copy is made in `$WORK` (a temp dir) or by `git stash`-free copy of the module outside
  the repository; production files in the repository are never edited by the tester. If the
  Drupal tree cannot be copied in time, the case records "MUT not run" and the reason; it does
  not pass on that part.
- Modes: **static** (reads files), **ddev run** (needs the DDEV stack up and the site installed),
  **host run** (no DDEV), **live CI** (a GitHub Actions run; the tester reads the logs the owner
  sends, because `gh` is not installed), **owner-run** (needs the owner or a Windows browser),
  **deferred** (cannot be run in T09; reason given).
- BLOCKED means the case cannot run here. It is not a pass. FAIL is a mismatch with the
  expected result and is a defect. A missing file makes every dependent check FAIL.
- Result vocabulary in reports: Pass, Fail, Blocked, Not run.
- Raw output goes to `EVD`. Fake credentials are not written to evidence.
- Destructive DDEV cases (`ddev drupal-install --force`) run after the non-destructive ones, and
  the order is in "Execution order" at the end.
- Violation codes are part of the contract with T10. Any case that names a code expects that
  exact string.

## Criterion coverage

(Full table at the end of this file: "Criterion coverage table".)

## Cases

---

## Group A: Module, config and structure (AC1)

### TC-T09-01: Module skeleton, names and core extension list

| Field | Value |
|---|---|
| Linked criterion | AC1, C5 |
| Mode | static |
| Preconditions | T09 implementation committed on `task/T09-content-model` |
| Steps | 1. `ls apps/drupal/web/modules/custom/meridian_core` 2. `cat apps/drupal/web/modules/custom/meridian_core/meridian_core.info.yml` 3. `grep -nE '^\s+(datetime\|options\|node\|field\|text\|user\|meridian_core):' apps/drupal/config/sync/core.extension.yml` 4. `scripts/check-names.sh` |
| Expected result | Module dir is exactly named `meridian_core`; info.yml has `core_version_requirement: ^11.1` (or tighter within 11) and dependencies `drupal:node`, `drupal:options`, `drupal:datetime`, `drupal:user`; `core.extension.yml` lists `datetime`, `options`, `meridian_core` (plus the previously enabled `node`, `field`, `text`, `user`); no contrib module added; no `jsonapi`, `rest`, `basic_auth`, `simple_oauth` module enabled; `check-names.sh` exits 0 |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-02: Content model config lives in `config/sync` only (KD-1)

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Mode | static |
| Preconditions | as TC-T09-01 |
| Steps | 1. `ls apps/drupal/config/sync \| grep -E '^(node.type\|field.storage.node\|field.field.node\|core.entity_(form\|view)_display.node\|user.role)'` 2. `find apps/drupal/web/modules/custom/meridian_core -path '*config/install*' -type f` 3. `find apps/drupal/web/modules/custom/meridian_core/config -type f` 4. `grep -n 'enforced' -A3 apps/drupal/config/sync/node.type.*.yml` |
| Expected result | Exactly 5 `node.type.*` files (`decision`, `position`, `daily_run`, `price_snapshot`, `watchlist_item`) and no other node type. Step 2 prints nothing (no `config/install` copy). Step 3 lists only `schema/meridian_core.schema.yml`. Each of the 5 node types has `dependencies.enforced.module: [meridian_core]`. `config/sync` holds 4 new `user.role.*` files: `administrator`, `analyst`, `engine_ingest`, `dashboard_read`. Every config file passes `yamllint` (pre-commit) and has a `uuid` that is not a hand-invented pattern (all distinct, valid v4) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-03: Field storages and instances equal the data-model, bundle by bundle

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Mode | ddev run (Kernel) plus static cross-check |
| Preconditions | Site installable; Kernel harness works (TC-T09-54) |
| Steps | 1. `PU-F ContentModelStructureTest --testdox 2>&1 \| tee EVD` 2. Static cross-check by the tester: for each bundle list `ls apps/drupal/config/sync/field.field.node.<bundle>.*.yml` and compare the set of field names with the data-model tables (the plan KD-2 table is the reading aid) |
| Expected result | The test passes. The field set per bundle is **exactly** the data-model rows, no extra and no missing field: `decision` 21 fields (title, external_id, trade_date, symbol, mode, score, pre_llm_action, action, vetoed, veto_reason, rule_hits, rule_version, prompt_version, model_name, inputs_snapshot, raw_llm_output, llm_rationale, close_price, run, source_version, payload_hash); `position` 24; `daily_run` 24; `price_snapshot` 13; `watchlist_item` 7 (counts include `title`; the tester recounts from the amended data-model and records any difference). No `body` field is left on any bundle. The test asserts per field: type, cardinality (`rule_hits` -1, `modes` 2, others 1), required flag, `max_length` (external_id 64 or per table, symbol 20, versions 32, model_name 64, run_id 36, skip_reason 255, payload_hash 64, title 255), `decimal` precision and scale (score 5,2; close_price 14,4; entry/stop/target/exit/last_mark 14,4; costs_total 12,2; realised/unrealised 14,2; r_multiple 8,3; virtual_equity 16,2; llm_cost_usd 10,4; open/high/low/close 14,4), `integer` size big on `volume`, `datetime_type: date` on date fields, `timestamp` on `started_at`/`finished_at`, `target_type: node` and `target_bundles` on `run` (daily_run), `decision` (decision), `allowed_values` of each list, min/max settings, `new_revision: true`, `display_submitted: false`, published by default |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-04: Shared `field_status` storage and per-bundle subsets (DN-3)

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2 |
| Mode | static plus ddev run |
| Preconditions | as TC-T09-03 |
| Steps | 1. `cat apps/drupal/config/sync/field.storage.node.field_status.yml` 2. `grep -n 'meridian_core' -B1 -A6 apps/drupal/config/sync/field.field.node.position.field_status.yml apps/drupal/config/sync/field.field.node.daily_run.field_status.yml` 3. `cat apps/drupal/web/modules/custom/meridian_core/config/schema/meridian_core.schema.yml` 4. `ddev drush config:status` |
| Expected result | One storage, type `list_string`, `allowed_values` keys in this order: `open`, `closed`, `success`, `failed`, `skipped`. `position` instance has `third_party_settings.meridian_core.allowed_values: [open, closed]`; `daily_run` has `[success, failed, skipped]`. The schema file declares `field.field.*.*.*.third_party.meridian_core` with a sequence of strings under `allowed_values`. `config:status` says "No differences" (the schema lets config validation accept the setting) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-05: Indexes exist on every "Indexed: yes" column

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Mode | ddev run |
| Preconditions | Site installed |
| Steps | 1. Read the "Indexed" column of the amended data-model for the five bundles and list the "yes" fields. 2. `PU-F ContentModelStructureTest --testdox` (index assertions). 3. For the tester's independent check: `ddev drush sql:query "SHOW INDEX FROM node__field_score"` and the same for `node__field_symbol`, `node__field_vetoed`, `node__field_enabled`, `node__field_sort_order`, `node__field_finished_at`, `node__field_external_id`, `node__field_mode`, `node__field_status`, `node__field_trade_date`, `node__field_run` |
| Expected result | Every "yes" field has an index on its value column (or target id for references) in the dedicated table, found in the SHOW INDEX output, and the Kernel test asserts the same. Fields marked "no" are not required to have one (core defaults tolerated). The tester records the exact index names (plan: "verify") in the report |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-06: Default form and view displays exist for all bundles

| Field | Value |
|---|---|
| Linked criterion | AC1, AC4 |
| Mode | static |
| Preconditions | as TC-T09-02 |
| Steps | 1. `ls apps/drupal/config/sync/core.entity_form_display.node.*.default.yml apps/drupal/config/sync/core.entity_view_display.node.*.default.yml` 2. For each bundle, check every field of the bundle appears in `content` or `hidden` of both displays |
| Expected result | 5 form displays and 5 view displays (`default` mode). No field of any bundle is missing from either display, so `cim` is complete. No Views, no JSON:API config, no extra form mode |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-07: No field is invented or left out (negative structure control)

| Field | Value |
|---|---|
| Linked criterion | AC1, AC5 |
| Mode | ddev run, MUT |
| Preconditions | scratch copy of `config/sync` in `$WORK` |
| Steps | 1. In the scratch copy remove `field.field.node.decision.field_score.yml` and its display entries, or change `max_length` of `field_symbol` from 20 to 21. 2. Point the Kernel structure test at the scratch config (if the trait has a configurable directory) or apply the change in a scratch checkout. 3. `PU-F ContentModelStructureTest` |
| Expected result | The structure test fails and names the bundle and field. If the test does not fail, the structure test does not check exactness: Fail (defect). If the trait cannot be redirected, record "MUT not run: trait path fixed" and the case is Blocked |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group B: Pure-unit rules (AC2, AC5)

### TC-T09-08: Patterns unit test covers each regex, accept and reject

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | host/ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-U --testdox 2>&1 \| tee EVD` 2. Map test names to the list in Expected |
| Expected result | Suite passes. Tests exist for each pattern, accepting and rejecting: **symbol** accepts `RELIANCE`, `M&M`, `BAJAJ-AUTO`, `NIFTY50`, 20 chars; rejects lowercase, 21 characters, empty, space, dot, underscore. **Version label** accepts `0.0.1`, `1.2.3`, `10.20.30`; rejects `1.2`, `1.2.3.4`, `v1.2.3`, `1.2.x`, leading/trailing space. **Model name** accepts `claude-sonnet-5-5`, `a`, 64 chars with dots; rejects uppercase, leading `.` or `-`, 65 chars. **Rule ID** accepts `R1_A`, `ABC`, 32 chars; rejects lowercase, 1 char, 33 chars, leading digit. **UUID** (`run_id`) accepts lowercase v4; rejects uppercase, missing hyphens, 35 and 37 characters. **payload_hash** accepts 64 lowercase hex; rejects uppercase, 63 and 65 chars, `g`. **external_id** per bundle: `dec-2026-11-04-RELIANCE-long`, `pos-RELIANCE-short-2026-11-04`, `run-2026-11-04`, `px-2026-11-04-RELIANCE`, `wl-RELIANCE` accepted; mode `longg`, `LONG`, missing mode, invalid month 13, wrong prefix, uppercase prefix, trailing newline rejected. Anchors hold: a string with a valid value followed by `\n` or garbage is rejected (no `$` newline leak) |
| Evidence | `EVD` and the mapping in the report |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-09: JSON document and decimal scale validators (unit)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | host/ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-U --filter 'JsonDocument\|DecimalScale' --testdox 2>&1 \| tee EVD` |
| Expected result | JSON validator: invalid JSON (`{`), a JSON array, a JSON string, a number, `null` each rejected when an object is required; `{}` and `{"a":1}` accepted; byte limits tested at limit (accepted) and limit + 1 (rejected) with multibyte (UTF-8, for example 3-byte characters, so bytes differ from characters); the limit is measured in bytes. Empty string handled as defined by the plan (required rule reports it, not this validator: no second violation). Decimal scale validator: more fractional digits than the scale rejected (for example 50.123 with scale 2), more integer digits than `precision - scale` rejected, `0`, `-0.01`, exact max accepted, string and numeric input forms handled, no rounding |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group C: Decision rules (AC2, AC5)

All Group C to G cases run `PU-F <Class> --testdox` and then apply the mapping rule. Each
rejection case must yield **exactly one** violation, at the stated path, with the stated code
where the plan gives one.

### TC-T09-10: Decision baseline valid and each required field rejected

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox 2>&1 \| tee EVD` |
| Expected result | Baseline Decision: 0 violations. For each required field (title, external_id, trade_date, symbol, mode, score, pre_llm_action, action, vetoed, rule_version, prompt_version, model_name, inputs_snapshot, raw_llm_output, close_price, run, source_version, payload_hash) an emptied/missing value gives exactly one violation at that field path. Optional fields (veto_reason when not vetoed, rule_hits, llm_rationale) empty are accepted. `vetoed` null (not false) is rejected by the `NotNull` constraint; `vetoed` false accepted. `source_version` 0 and -1 rejected |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-11: Decision enums, mode and action (AC2 named rules)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run, MUT |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` 2. MUT: in a scratch copy add `short2` to `field_mode` allowed values and re-run |
| Expected result | `mode` accepts `long`, `short`; rejects `longg`, `LONG`, `''`, `buy`, null-equivalent. `action` and `pre_llm_action` accept `BUY`, `AVOID`; reject `SELL`, `buy`, `HOLD`. `veto_reason` accepts each of the 7 values (`llm_veto`, `malformed`, `empty`, `timeout`, `api_error`, `schema_violation`, `budget`) and rejects `other`, `LLM_VETO`. Each rejection is one violation at the field path (a mode rejection may also mismatch the external_id if the id was built from it: the test must change both consistently, or the test expectation lists exactly the plan's one-violation outcome). MUT: the mode test fails |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-12: Decision score boundaries and scale

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run, MUT |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` 2. MUT: change `field_score` max to 101 in a scratch copy |
| Expected result | `score` -0.01 rejected, 100.01 rejected, 50.123 rejected (scale), 1000 rejected (precision), non-numeric rejected; 0, 0.00, 100, 100.00, 50.5 accepted. Each rejection is one violation at `field_score`. MUT: the 100.01 test fails |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-13: Decision `trade_date` not in the future (IST boundary)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Fixed-clock `TimeInterface` stub registered over `datetime.time` |
| Steps | 1. `PU-F DecisionValidationTest --testdox` |
| Expected result | With the clock fixed: `trade_date` tomorrow (IST) rejected at `field_trade_date`; today (IST) accepted; yesterday accepted. Boundary pair either side of IST midnight: UTC 18:29:59 on day D (IST 23:59:59 on D) accepts D and rejects D+1; UTC 18:30:00 on day D (IST 00:00:00 on D+1) accepts D+1 and rejects D+2. The test uses fixed instants (no `sleep`, no real clock). Malformed date strings rejected as one violation. External_id is rebuilt consistently so only the date violation appears |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-14: Decision cross-field rules (action, veto)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` |
| Expected result | Truth table, each row tested with exact path and code: `action` BUY with `pre_llm_action` AVOID rejected; `action` BUY with `vetoed` true rejected; `vetoed` true with `pre_llm_action` AVOID rejected; `vetoed` true without `veto_reason` rejected at `field_veto_reason`; `veto_reason` set while `vetoed` false rejected; accepted rows: (pre BUY, action BUY, not vetoed), (pre BUY, action AVOID, vetoed true with reason), (pre AVOID, action AVOID, not vetoed), (pre BUY, action AVOID, not vetoed, i.e. LLM said avoid). A rule that reads another field returns no second violation when the input is itself invalid (for example `pre_llm_action` = `SELL` gives only the list violation) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-15: Decision text, JSON, rule_hits, version and length rules

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` |
| Expected result | Each tested as accept at limit, reject at limit + 1 where a limit exists, one violation each: `rule_hits` bad item (`lower`) rejected, a 51st item rejected (50 accepted), a bad item among valid ones reports the item path (delta `field_rule_hits.<n>`); `rule_version`/`prompt_version` `1.2`, `v1.2.3` rejected; `model_name` `Claude` rejected; `inputs_snapshot` invalid JSON, JSON array, 65,537 bytes rejected, 65,536 accepted; `raw_llm_output` invalid JSON, array, 32,769 bytes rejected, 32,768 accepted, `{"status":"not_called"}` accepted; multibyte string at the byte limit; `llm_rationale` 2,001 characters rejected, 2,000 accepted; `title` 256 rejected, 255 accepted; `payload_hash` uppercase or 63 chars rejected; `symbol` `reliance` and 21 chars rejected; `close_price` 0 and -1 rejected, 0.0001 accepted, 5 decimals rejected (scale) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-16: Decision `run` reference rules

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` |
| Expected result | `run` pointing at a node ID that does not exist rejected at `field_run`; `run` pointing at a node of the wrong bundle (for example another `decision`) rejected at `field_run`; `run` pointing at a `daily_run` accepted. One violation each |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group D: Position rules

### TC-T09-17: Position required fields, enums, numeric ranges

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PositionValidationTest --testdox 2>&1 \| tee EVD` |
| Expected result | Baseline open long Position: 0 violations. Each required field removed gives one violation (title, external_id, symbol, mode, status, entry_date, entry_price, quantity, stop_price, target_price, costs_total, run, decision, source_version, payload_hash). `status` `success` rejected (bundle subset, code `meridian.bundle_allowed_values`, path `field_status`); `status` `skipped` rejected; `open` and `closed` accepted. `exit_reason` accepts `stop`, `gap_stop`, `target`, `time_stop`, rejects `manual`. `mode` per Group C. `entry_price` 0 and `exit_price` 0 and `last_mark_price` 0 rejected, 0.0001 accepted; `quantity` 0 and -1 rejected, 1 accepted; non-integer rejected; `costs_total` -0.01 rejected, 0 accepted, 3 decimals rejected; `r_multiple` 100.001 and -100.001 rejected, 100 and -100 accepted, 4 decimals rejected; every decimal's scale tested at least once |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-18: Position price ordering and time stop by mode

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PositionValidationTest --testdox` |
| Expected result | `stop_price` 0 rejected; `stop_price` equal to `entry_price` rejected; `stop_price` above `entry_price` rejected (each one violation at `field_stop_price`); stop below entry accepted. `target_price` equal to `entry_price` rejected, below rejected, above accepted (path `field_target_price`). Short position without `time_stop_date` rejected; short with `time_stop_date` equal to `entry_date` rejected; before `entry_date` rejected; after accepted. Long position with `time_stop_date` set rejected; long without accepted. When `entry_price` is missing or invalid the ordering rules add no second violation |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-19: Position open/closed conditional fields (DN-4)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PositionValidationTest --testdox` |
| Expected result | `closed` without `exit_date`, without `exit_price`, without `exit_reason`, without `realised_pnl`: four separate cases, one violation each at the missing field; `closed` with `unrealised_pnl` set rejected at `field_unrealised_pnl`; a complete closed Position accepted. `open` with `exit_date`, `exit_price`, `exit_reason`, `realised_pnl` each set: four cases, one violation each; `open` with `unrealised_pnl`, `last_mark_price`, `last_mark_date` all set accepted; `open` with none of them accepted. `exit_date` equal to or before `entry_date` rejected, after accepted (path `field_exit_date`). `last_mark_date` before `entry_date` rejected, equal accepted |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-20: Position references and Decision checks (DN-6)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PositionValidationTest --testdox` |
| Expected result | `run` targeting a non-`daily_run` and `decision` targeting a non-`decision` bundle rejected at the field path (core `ValidReference`/target bundles); missing target ID rejected; in these cases the DN-6 rules add **no** second violation. Against a valid Decision target, one violation at `field_decision` each, with these exact codes: AVOID decision gives `meridian.position.decision_not_buy`; other symbol gives `meridian.position.decision_symbol_mismatch`; other mode gives `meridian.position.decision_mode_mismatch`; Decision `trade_date` after `entry_date` gives `meridian.position.decision_after_entry`; Decision dated on `entry_date` accepted; earlier accepted. An **unsaved** Decision attached via `->entity` is validated against (all four conditions, accepted when valid) without an entity load by ID |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group E: Daily Run rules

### TC-T09-21: Daily Run fields, enums and ranges

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DailyRunValidationTest --testdox 2>&1 \| tee EVD` |
| Expected result | Baseline success run: 0 violations. Each required field removed gives one violation. `run_id` uppercase UUID, malformed, 35 characters rejected, lowercase UUID accepted. `attempt` 0 rejected, 1 accepted. `status` `open` and `closed` rejected (code `meridian.bundle_allowed_values`, path `field_status`); `success`, `failed`, `skipped` accepted. `watchlist_source` accepts `drupal`, `snapshot`, `seed`, rejects `file`. `symbols_total` -1 and 51 rejected, 0 and 50 accepted. `decisions_count`, `buy_count`, `veto_count`, `failure_count` -1 rejected, 0 accepted. `buy_count` greater than `decisions_count` rejected at `field_buy_count`, equal accepted. `virtual_equity` 0 and -1 rejected, 0.01 accepted, empty accepted. `llm_cost_usd` -0.0001 rejected, 0 accepted, 5 decimals rejected. `finished_at` before `started_at` rejected at `field_finished_at`, equal accepted, empty accepted. `skip_reason` 256 chars rejected, 255 accepted. Version labels and model name per Group C |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-22: Daily Run conditional fields (DN-4)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DailyRunValidationTest --testdox` |
| Expected result | `skipped` without `skip_reason` rejected at `field_skip_reason`; `skipped` with reason accepted, with or without `watchlist_source`. `success` with `skip_reason` rejected; `success` without `watchlist_source` rejected at `field_watchlist_source`; `success` with source and no reason accepted. `failed` with `skip_reason` `stale_lock` accepted; `failed` without reason accepted; `failed` without `watchlist_source` accepted |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group F: Price Snapshot and Watchlist Item

### TC-T09-23: Price Snapshot rules

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PriceSnapshotValidationTest --testdox 2>&1 \| tee EVD` |
| Expected result | Baseline: 0 violations. Each required field removed: one violation (title, external_id, trade_date, symbol, open, high, low, close, volume, adjusted, source, source_version, payload_hash); `adjusted` null rejected (NotNull), false accepted. `open` 0 and `close` 0 rejected; `low` 0 rejected; `low` above `open` rejected, above `close` rejected, equal to both accepted; `high` below `open`, below `low`, below `close` rejected (each one violation at `field_high`), equal accepted; `volume` -1 rejected, 0 accepted, a value above 2^31 accepted (big int); `source` `yfinance`, `stub` accepted, `google` rejected; decimals with 5 fractional digits rejected. `trade_date` future: the plan applies `MeridianDateNotAfterToday` to `decision` only, so the test records the observed behaviour for `price_snapshot` and `daily_run` and the tester flags it as a plan question Q-2 if it is accepted without a documented rule |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-24: Watchlist Item field rules

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F WatchlistItemValidationTest --testdox 2>&1 \| tee EVD` |
| Expected result | Baseline: 0 violations. `symbol` regex failures (lowercase, 21 characters) rejected; `modes` empty rejected, `[long]`, `[short]`, `[long, short]` accepted, `[long, long]` rejected by the duplicate rule, `[long, flat]` rejected, 3 values rejected (cardinality); `sort_order` -1 and 1000 rejected, 0 and 999 accepted; `notes` 501 characters rejected, 500 accepted; `enabled` defaults to true on a new entity; `enabled` null rejected (NotNull); `title` 256 rejected |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-25: Watchlist `external_id` derivation, symbol immutability, 50-enabled limit

| Field | Value |
|---|---|
| Linked criterion | AC2, AC3, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F WatchlistItemValidationTest --testdox` |
| Expected result | A new Watchlist Item created with only a symbol gets `external_id` `wl-{symbol}` (both on `node_create` and on `node_presave`); a supplied external_id that differs is rejected as `meridian.external_id_mismatch` at `field_external_id`; the `WatchlistExternalId::derive()` service returns the same value. Changing `symbol` on a saved item is rejected at `field_symbol` (DN-8) and is the only violation. 50 enabled items: the 51st enabled rejected; the 51st **disabled** accepted; re-saving an existing enabled item when 50 are enabled accepted; enabling a 51st by edit rejected; disabling then enabling again counts correctly |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group G: Cross-cutting rules

### TC-T09-26: `external_id` matches the natural key on every bundle (DN-5)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-K --testdox 2>&1 \| tee EVD` and map the mismatch tests |
| Expected result | For every bundle and for every natural-key field, a change of that field with the old `external_id` yields exactly one violation at `field_external_id` with code `meridian.external_id_mismatch`. Decision: `trade_date`, `symbol`, `mode`. Position: `symbol`, `mode`, `entry_date`. Daily Run: `trade_date`. Price Snapshot: `trade_date`, `symbol`. Watchlist: `symbol`. `title` change alone: 0 violations (title is not checked). When a natural-key field is itself missing/invalid, there is no extra mismatch violation. Regex failure of the id and a mismatch do not double up (one violation per case) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-27: Immutability and non-decreasing `source_version`

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F LifecycleRulesTest --testdox 2>&1 \| tee EVD` |
| Expected result | `external_id` change on a saved entity rejected on each of the five bundles (code `meridian.immutable`, or `meridian.external_id_mismatch` for natural-key changes); saving an unchanged entity accepted; `source_version` equal and higher than the stored value accepted, lower rejected at `field_source_version`; creating with 1 accepted; new revision preserves the rule; uses `loadUnchanged()` so a stale in-memory copy cannot bypass it |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-28: Violation path and code contract for T10

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | static plus ddev run |
| Preconditions | Test classes exist |
| Steps | 1. `grep -rn "meridian\.\(external_id_mismatch\|bundle_allowed_values\|position\.decision_\)" apps/drupal/web/modules/custom/meridian_core/src apps/drupal/web/modules/custom/meridian_core/tests` 2. `PU-K --testdox` 3. Tester reads the assertion helper |
| Expected result | The codes `meridian.external_id_mismatch`, `meridian.bundle_allowed_values`, `meridian.position.decision_not_buy`, `meridian.position.decision_symbol_mismatch`, `meridian.position.decision_mode_mismatch`, `meridian.position.decision_after_entry` appear in both source and tests. Every custom constraint (JSON, decimal scale, date-not-after-today, no-duplicate-values, unique-in-bundle, immutable, non-decreasing, each bundle rules) has a stable `meridian.*` code asserted in at least one test. The helper compares the full `(propertyPath, code)` list exactly (not `count() > 0`). Property path is the field machine name in every case |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-29: Rules fire on `validate()`, not only through forms or the API

| Field | Value |
|---|---|
| Linked criterion | AC2, AC3 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `grep -rn "validate()" apps/drupal/web/modules/custom/meridian_core/tests/src/Kernel` 2. `grep -rnE "Request\|Controller\|jsonapi\|HttpKernel\|BrowserTestBase" apps/drupal/web/modules/custom/meridian_core/tests` |
| Expected result | Kernel tests call `$entity->validate()` directly on entities built in code. Step 2: no Request/controller/JSON:API/Functional class (T09 adds no Functional tests). This proves the rules are entity-level, not API-level |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-30: Rule coverage cross-check against the plan rule list (AC5 audit)

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Mode | static |
| Preconditions | Cases TC-T09-08 to 27 executed |
| Steps | 1. Build a table: every row of the plan KD-3 "Rule list" (22 rows) and the DN-4 conditional table (7 rows) against the test method that covers it, from the `PU-V` output. 2. Add the Kernel test class list: `ContentModelStructureTest`, `DecisionValidationTest`, `PositionValidationTest`, `DailyRunValidationTest`, `PriceSnapshotValidationTest`, `WatchlistItemValidationTest`, `LifecycleRulesTest`, `ExternalIdUniquenessTest`, `PermissionsMatrixTest` and Unit `PatternsTest`, `JsonDocumentValidatorTest`, `DecimalScaleValidatorTest` |
| Expected result | Every row has at least one named test; every named class exists and runs (not skipped, not marked incomplete: the output has no `S` or `I`); the table is stored in `EVD`. Any rule row without a test is a Fail with the rule named |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group H: Unique `external_id` (AC3)

### TC-T09-31: Duplicate `external_id` in the same bundle rejected by `validate()`

| Field | Value |
|---|---|
| Linked criterion | AC3, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox 2>&1 \| tee EVD` |
| Expected result | For each of the five bundles: a second entity with the same `external_id` in the same bundle fails `validate()` with exactly one violation at `field_external_id` and code `meridian.unique_in_bundle`; the first save is accepted; the message does not include another record's data. Updating the same node (same external_id, other field changed, new revision) accepted (own id excluded). Unpublished duplicate still counted (`accessCheck(FALSE)`) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-32: Exact, case-sensitive comparison (no `LIKE` wildcards)

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` |
| Expected result | Entity A has a stored `external_id` that differs from B only by a `%` or `_` wildcard position (for example `wl-A_B` vs `wl-AXB` where the regex permits, otherwise set through a bare `save()` in the test fixture) and B is **not** reported duplicate; two ids differing only in letter case are treated as distinct by the validator (the format regexes make this a regex matter, so the test builds the case by bare save and checks the unique-in-bundle constraint alone, not the full entity validation). The query has `condition('type', bundle)` |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-33: Same `external_id` across different bundles is allowed; same symbol across bundles allowed

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` 2. `PU-F WatchlistItemValidationTest --testdox` |
| Expected result | Because the D3 formats differ per bundle, a cross-bundle collision cannot occur with valid data. The test therefore builds the collision explicitly: two nodes of different bundles with an identical `external_id` string, saved with bare `save()`, **both succeed** (the unique key is `(bundle, external_id)`, not `external_id` alone) and `MeridianUniqueInBundle` does not flag either. A Watchlist Item `RELIANCE` is accepted while Decisions with symbol `RELIANCE` exist, and a second Watchlist Item `RELIANCE` is rejected (symbol unique in bundle, path `field_symbol`) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-34: Database backstop: bare `save()` of a duplicate throws and leaves no node

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Mode | ddev run |
| Preconditions | Harness works; MariaDB-backed Kernel run (not SQLite) |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` 2. `ddev drush sql:query "SHOW INDEX FROM node__field_external_id WHERE Key_name='meridian_external_id_bundle'"` (if the key path was used) or `ddev drush sql:query "SHOW CREATE TABLE meridian_external_id"` (Fallback A) |
| Expected result | A duplicate entity is saved **without** calling `validate()`; `save()` throws `\Drupal\Core\Entity\EntityStorageException` (or its parent chain), the node count of that bundle is unchanged, no orphan row in `node_field_data`, `node__field_external_id`, or (Fallback A) `meridian_external_id`, and the transaction is rolled back. The unique key lists columns `bundle`, `field_external_id_value` in that order, `Non_unique = 0`, and is not on the revision table. Under Fallback B the case is recorded as "no backstop" and the owner item O-4 is raised, not passed |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-35: Backstop covers concurrent watchlist creates of one symbol

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` 2. Tester script (in `tests/` only, throwaway): two entities for the same symbol are both validated while neither is saved (both pass `validate()`), then both saved in sequence |
| Expected result | Both pass `validate()` (check-then-act race reproduced); the second `save()` throws `EntityStorageException` because of the derived `wl-{symbol}` key; exactly one node exists afterwards |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-36: Backstop exists on each install path and is removed on uninstall

| Field | Value |
|---|---|
| Linked criterion | AC3, AC4 |
| Mode | ddev run |
| Preconditions | Harness works; install path available |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` 2. After `ddev drupal-install --force` (TC-T09-48): `ddev drush sql:query "SHOW INDEX FROM node__field_external_id"` 3. After a cache rebuild: `ddev drush cr` then repeat step 2 4. `ddev drush updatedb --no-cache-clear` then repeat step 2 |
| Expected result | Key (or Fallback A table) present after config install (field-storage path), after module install with the table already existing (install path), after `drush cr`, after `drush updatedb` with "No pending updates", and after a field storage update. Key removed after module uninstall (`hook_uninstall`). Entity schema check (`ddev drush entity:updates` if present, or the status report) shows no "mismatched entity/field definitions" caused by the key |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-37: DN-10 "cannot be kept" test and the recorded path

| Field | Value |
|---|---|
| Linked criterion | AC3, AC4, C5 |
| Mode | ddev run plus static |
| Preconditions | TC-T09-36 and TC-T09-48 to 50 run |
| Steps | 1. `ddev drush cim --yes`, `ddev drush config:status`, `ddev drush updatedb --no-cache-clear`, `ddev drush status-report` (or `ddev drush core:requirements --severity=2`) 2. `grep -n "Unverified items" -A30 docs/architecture/technical-design.md \| grep -in "unique"` 3. read the T09 review file for the path statement |
| Expected result | None of the commands fails or reports a change or an error caused by the key. The technical-design "Unverified items" row for the unique index is closed with the date, the chosen path (key / Fallback A / Fallback B) and the table collation recorded. If Fallback B was used the O-4 message to the owner is recorded and TC-T09-34 and 35 are marked as "no backstop", not Pass |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group I: Permissions and access (AC6, FR-16)

### TC-T09-38: Permissions are defined exactly as the plan lists

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | static |
| Preconditions | Implementation committed |
| Steps | 1. `cat apps/drupal/web/modules/custom/meridian_core/meridian_core.permissions.yml` |
| Expected result | Exactly 7 permissions: `view meridian records`, `view meridian watchlist`, `view meridian inputs`, `view meridian raw llm output` (`restrict access: true`), `administer meridian records` (`restrict access: true`), `ingest meridian records`, `export meridian records`. No other permission and no `bypass`-style grant defined by the module |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-39: Role config: six-role permission sets, exact, no extras

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | static plus ddev run |
| Preconditions | Config exported |
| Steps | 1. `grep -n "permissions:" -A12 apps/drupal/config/sync/user.role.{administrator,analyst,engine_ingest,dashboard_read,anonymous,authenticated}.yml` 2. `PU-F PermissionsMatrixTest --testdox 2>&1 \| tee EVD` |
| Expected result | `administrator`: `is_admin: true`. `analyst`: exactly `access content`, `view meridian records`, `view meridian inputs`, `view meridian watchlist`, `export meridian records`. `engine_ingest`: exactly `access content`, `ingest meridian records`, `view meridian watchlist`. `dashboard_read`: exactly `access content`, `view meridian records`, `view meridian watchlist`. `anonymous` and `authenticated`: **no** `access content` and no Meridian permission (any permissions list is empty or contains only non-Meridian core items that the doc names; the tester records the list). The test asserts the exact set per role (no extra permission), not just containment. 4 new role files, `weight` values distinct |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-40: Matrix cells: role by permission (9 permissions)

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | For each of the six roles and each of the 9 permissions (the 7 Meridian ones plus `access content` and `bypass node access`) the test asserts granted or not, 54 cells. `administrator` has all (via `is_admin`); `bypass node access` is held by `administrator` only. Count of asserted cells is at least 54 (the tester counts data-provider rows) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-41: Matrix cells: role by bundle by operation

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | 6 roles x 5 bundles x 4 operations = 120 cells asserted through `$node->access($op, $account)`. Expected pattern: `view` allowed for `administrator`; for `analyst` and `dashboard_read` allowed on `decision`, `position`, `daily_run`, `price_snapshot` (permission `view meridian records`) and on `watchlist_item` (`view meridian watchlist`); `engine_ingest` allowed on `watchlist_item` only and **not** on the four records (it lacks `view meridian records`); `anonymous` and `authenticated` denied on all. `create`, `update`, `delete`: denied for every role except `administrator` (bypass). Published nodes in the view cells |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-42: Unpublished records are hidden; hooks never grant (neutral rule)

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | An unpublished record of each bundle is not viewable by `analyst`, `dashboard_read`, `engine_ingest`; it is viewable by `administrator` (bypass). The access hook returns Forbidden or Neutral, never Allowed (test asserts `isNeutral()`/`isForbidden()` on the hook result where it can read it). A role with an extra, unrelated `access content` only (no Meridian permission) does not see Meridian nodes |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-43: Field view access for restricted fields

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | Per role, `view` access on each restricted field as the plan KD-7 table says: `decision.raw_llm_output` needs `view meridian raw llm output` (only `administrator` has it; `analyst` denied); `decision.inputs_snapshot`, `daily_run.llm_cost_usd`, `price_snapshot.source`, `watchlist_item.notes` need `view meridian inputs` (`administrator`, `analyst` allowed; `dashboard_read`, `engine_ingest` denied); `source_version` and `payload_hash` on the four ingested bundles need `administer meridian records` (administrator only). Unrestricted fields (for example `decision.score`) viewable by `dashboard_read`. A `watchlist_item` has no `source_version`/`payload_hash` so there is no cell. Field `edit` is **not** restricted in T09 (tested as not forbidden by this module: documented non-goal) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-44: Access results carry permission cache context

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | Node access results (view/update/delete/create) and field access results from the module report cache context `user.permissions` (`cachePerPermissions()`) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-45: Permissions matrix document and docs/test parity

| Field | Value |
|---|---|
| Linked criterion | AC6, C5 |
| Mode | static (docs suite) |
| Preconditions | `docs/specs/permissions.md` written |
| Steps | 1. `test -f docs/specs/permissions.md` 2. `grep -n "permissions.md" docs/specs/README.md docs/specs/data-model.md docs/architecture/technical-design.md` 3. Parse the role/permission table in `permissions.md` and compare with `user.role.*.yml` (docs suite `docs/tests/T09/run-checks.sh`, written in execute mode; the parser reads the table format promised by the plan "role, permission, value") |
| Expected result | The document exists, covers six roles (names exact), lists the nine permissions, the bundle/operation cells, the restricted-field cells, states the "neutral not allowed" rule, the listing limitation (no node grants; queries and Views not filtered; T11 and T12 handle it), the HTTP cells being non-T09 with a link to D6 naming T10, T11, T22, T30. Linked from `docs/specs/README.md`, `data-model.md` and D6. The parsed table equals the exported role YAML cell by cell. Mutation: change one cell in a scratch copy of the doc and the parity check fails |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-46: Removing `access content` does not break login or install

| Field | Value |
|---|---|
| Linked criterion | AC6, AC4 |
| Mode | ddev run |
| Preconditions | Site installed |
| Steps | 1. `ddev drush uli` 2. `curl -s -o /dev/null -w "%{http_code}\n" https://meridian.ddev.site/user/login` 3. `curl -s -o /dev/null -w "%{http_code}\n" https://meridian.ddev.site/` 4. `curl -s -o /dev/null -w "%{http_code}\n" https://meridian.ddev.site/node/1` |
| Expected result | Install and `drush uli` succeed; `/user/login` returns 200; the front page and a node URL do not expose Meridian content to anonymous (403 or 404, not 200 with record data) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-47: Administrator login in a browser (owner)

| Field | Value |
|---|---|
| Linked criterion | AC6, C7 |
| Mode | owner-run (Windows browser) |
| Preconditions | Site installed; owner has the one-time link |
| Steps | 1. Agent runs `ddev drush uli`; owner opens the link in the Windows browser. 2. Owner opens `/admin/structure/types` and `/admin/people/roles` and `/admin/people/permissions` 3. Owner screenshots each page in full |
| Expected result | Five content types listed (Decision, Position, Daily Run, Price Snapshot, Watchlist Item); roles page lists Administrator, Analyst, Engine ingest, Dashboard read plus Anonymous and Authenticated; the permissions page shows the Meridian group with the 7 permissions. A partial screenshot is insufficient: the case stays Blocked until full pages are sent. The tester cannot accept evidence on the owner's behalf |
| Evidence | owner screenshots stored under `evidence/` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group J: Config round trip (AC4)

### TC-T09-48: Fresh install from config succeeds with no drift

| Field | Value |
|---|---|
| Linked criterion | AC4, C7 |
| Mode | ddev run (destructive for the local database) |
| Preconditions | `ddev start` ok; implementation committed; tree clean |
| Steps | 1. `ddev drupal-install --force 2>&1 \| tee EVD` 2. `ddev drush config:status` |
| Expected result | Install exits 0 (the command fails on any `config:status` difference); `config:status` prints "No differences between DB and sync directory."; the five node types, 4 new roles, fields, displays exist: `ddev drush config:get node.type.decision` etc. exit 0; `ddev drush role:list` shows the six roles |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-49: `cex` after install shows no diff

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Mode | ddev run |
| Preconditions | TC-T09-48 passed |
| Steps | 1. `git status --porcelain apps/drupal/config/sync > $WORK/before.txt` 2. `ddev drush cex --yes 2>&1 \| tee EVD` 3. `git status --porcelain apps/drupal/config/sync` 4. `git diff --stat apps/drupal/config/sync` |
| Expected result | `cex` reports no changes ("There are no changes to export" or an unchanged file set); step 3 output is identical to `before.txt` (empty on a clean tree); step 4 empty. In particular the `field_status` third-party setting and the role files are not rewritten |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-50: `cim` reports no changes and is idempotent

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Mode | ddev run |
| Preconditions | TC-T09-49 passed |
| Steps | 1. `ddev drush cim --yes 2>&1 \| tee EVD` 2. `ddev drush cim --yes` (second time) 3. `ddev drush config:status` 4. `ddev drush updatedb --no-cache-clear` |
| Expected result | Both `cim` runs print "There are no changes to import."; `config:status` "No differences"; `updatedb` "No pending updates"; the unique key (or Fallback A table) still present |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-51: `cim` onto a clean site recreates everything

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Mode | ddev run (destructive) |
| Preconditions | TC-T09-50 passed; a DB dump taken first: `ddev pg dump` is Postgres only, so use `ddev export-db --file=$WORK/pre.sql.gz` |
| Steps | 1. `ddev drush sql:drop --yes` (empty database) 2. `ddev drush site:install --existing-config --yes 2>&1 \| tee EVD` (the same path `ddev drupal-install` uses) 3. `ddev drush config:status` 4. `ddev drush cex --destination=$WORK/cex-after --yes` (to a temp directory, not the repo) 5. `diff -r apps/drupal/config/sync $WORK/cex-after` 6. `ddev drush sql:query "SHOW INDEX FROM node__field_external_id"` 7. `ddev drush php:eval "print count(\Drupal\node\Entity\NodeType::loadMultiple());"` |
| Expected result | Install exits 0; no differences; the exported directory equals `config/sync` (only diff output allowed: none, besides `core.extension` ordering if identical); 5 node types; all roles; key or Fallback A table present; `drush uli` works. Nothing in the repository changes (`git status --porcelain` empty) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-52: Drift detection (negative control for AC4)

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Mode | ddev run |
| Preconditions | TC-T09-51 passed |
| Steps | 1. `ddev drush config:set field.field.node.decision.field_score description "x" --yes` (changes active config only) 2. `ddev drush config:status` 3. `ddev drush cim --yes` 4. `ddev drush config:status` |
| Expected result | Step 2 reports `field.field.node.decision.field_score` as "Only in DB"/different; `cim` restores it; step 4 "No differences". Proves `config:status` is a real check and `cim` re-applies the model. Also: delete a role (`ddev drush role:delete dashboard_read`) then `cim` recreates it (roles come from config). The repo tree stays clean |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group K: Test infrastructure, quality gate, CI (AC5, C4)

### TC-T09-53: `phpunit.xml.dist` and suites

| Field | Value |
|---|---|
| Linked criterion | AC5, C4 |
| Mode | static plus ddev run |
| Preconditions | Implementation committed |
| Steps | 1. `cat apps/drupal/phpunit.xml.dist` 2. `grep -n "SIMPLETEST_DB\|mysql://\|sqlite" apps/drupal/phpunit.xml.dist` 3. `PU --list-suites` |
| Expected result | Bootstrap `web/core/tests/bootstrap.php`; suites `unit` and `kernel` over `web/modules/custom/*/tests/src/{Unit,Kernel}`; no `functional` suite; `<source>` includes `web/modules/custom` and excludes tests; step 2 prints nothing (no DB URL in the file; no sqlite) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-54: Whole Kernel and Unit suite passes on MariaDB with no skips

| Field | Value |
|---|---|
| Linked criterion | AC5, C4 |
| Mode | ddev run |
| Preconditions | Site installed |
| Steps | 1. `ddev exec 'echo $SIMPLETEST_DB'` 2. `ddev exec mysql --version` 3. `PU-U 2>&1 \| tee EVD` 4. `PU-K 2>&1 \| tee -a EVD` |
| Expected result | `SIMPLETEST_DB` is a MariaDB (`mysql://`) URL (set by DDEV or exported by `quality.sh`); MariaDB 10.6; both suites exit 0; summary shows 0 failures, 0 errors, 0 skipped, 0 risky, 0 incomplete; deprecation count 0 (or the same as the baseline recorded); test counts recorded in the report |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-55: Rejection tests fail when a rule is removed (suite sensitivity)

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Mode | ddev run, MUT |
| Preconditions | TC-T09-54 passed; scratch copy of the module in `$WORK` mounted or a scratch worktree |
| Steps | 1. Mutations, one at a time, each followed by `PU-K` on the scratch: (a) loosen `field_score` max to 101; (b) remove `MeridianUniqueInBundle` from `field_external_id`; (c) drop the `field_status` third-party subset for `daily_run`; (d) remove the `NotNull` on `vetoed`; (e) remove `MeridianImmutable` from `field_external_id`; (f) grant `analyst` the permission `view meridian raw llm output`; (g) make the DB key not be created |
| Expected result | Each mutation fails at least one named test; the failing test name is recorded. A mutation that leaves the suite green is a Fail (coverage gap) naming the rule. If a scratch copy cannot be built, the case is Blocked, not Pass |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-56: Coverage report with pcov, the 70% gate and the first measured figure

| Field | Value |
|---|---|
| Linked criterion | C4, AC5 |
| Mode | ddev run |
| Preconditions | pcov installed in the web container |
| Steps | 1. `ddev exec php -m \| grep -i pcov` 2. `ddev quality 2>&1 \| tee EVD` 3. `ls quality/ apps/drupal/*coverage* 2>/dev/null`; read the Cobertura path used by `scripts/quality.sh` 4. `python3 scripts/coverage_gate.py` against the Drupal Cobertura file and `quality/coverage-thresholds.json` 5. `grep -n "Drupal custom" docs/standards/CODING_STANDARDS.md` |
| Expected result | pcov loaded; `component-drupal-tests` ran (a PASS line, not SKIP); the gate reports line coverage of `web/modules/custom/meridian_` at or above 70%, otherwise T04a D-1 decision recorded (no untracked excludes); `CODING_STANDARDS.md` states the first measured value (replaces "provisional until first measured in T09"). The percentage is recorded in the report. Coverage excludes `tests/` and no `@codeCoverageIgnore` or `<exclude>` is added to lift the figure (grep shows none that are untracked) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-57: `quality.sh` guard and expected-skips line removed; `ddev quality` green

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Mode | static plus ddev run |
| Preconditions | Implementation committed |
| Steps | 1. `grep -n "no custom PHP yet\|empty-tree\|T09" scripts/quality.sh` 2. `grep -n "component-drupal-tests" quality/expected-skips.txt` 3. `ddev quality 2>&1 \| tee EVD` 4. `scripts/quality.sh --group core` 5. `python3 -m pytest scripts/tests -q` (host) |
| Expected result | Steps 1 and 2 print nothing relevant (guard and line removed); `ddev quality` exit 0; `PASS component-drupal` and `PASS component-drupal-tests`; PHPStan level 6 ran on the custom module with no baseline and no unticketed ignore; phpcs Drupal and DrupalPractice clean; engine and web steps behave as before; no unexpected SKIP; pytest suites pass (including updated `test_quality_sh.py`). `git status --porcelain` empty afterwards |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-58: Static analysis negative controls on the new module

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Mode | ddev run (scratch) |
| Preconditions | TC-T09-57 passed |
| Steps | 1. In a scratch copy of the module add (a) a PHPStan type error (return string from `: int`) and (b) a PHPStan ignore comment without a ticket and (c) a phpcs violation (tabs). 2. Run `ddev exec -d /var/www/html/apps/drupal vendor/bin/phpstan analyse` and `vendor/bin/phpcs` against the scratch |
| Expected result | Each is reported; this closes the T05 note that the PHPStan type-error and unticketed-ignore parts of TC-T04a-49 "stay with T09". Repository files untouched |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-59: CI `drupal` job definition: MariaDB service, pcov, SIMPLETEST_DB

| Field | Value |
|---|---|
| Linked criterion | C4, AC5 |
| Mode | static |
| Preconditions | `.github/workflows/ci.yml` updated |
| Steps | 1. `grep -n "mariadb\|pcov\|SIMPLETEST_DB\|coverage:" .github/workflows/ci.yml` 2. `grep -n "database" -A3 .ddev/config.yaml pantheon.yml apps/drupal/pantheon.yml 2>/dev/null` 3. `grep -n "pcov" .ddev/config.yaml` |
| Expected result | The `drupal` job has `services: mariadb` with image `mariadb:10.6.<patch>` (an exact tag, not `latest`, not `10`), a health check, setup-php `coverage: pcov` (not `none`), and `SIMPLETEST_DB` pointing at the service (`mysql://...@127.0.0.1:3306/...`); no sqlite; `.ddev/config.yaml` has `database: type mariadb, version 10.6` and installs pcov via `webimage_extra_packages` or the documented form; `pantheon.yml` `database.version: 10.6`. All three agree on 10.6 |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-60: `check_ci.py` rule 2 database parity, positive and negative

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Mode | host run |
| Preconditions | Updated `scripts/check_ci.py` and tests |
| Steps | 1. `python3 scripts/check_ci.py` 2. `python3 -m pytest scripts/tests/test_check_ci.py -q 2>&1 \| tee EVD` 3. In `$WORK` copy `ci.yml`, change the service image to `mariadb:10.11.5`, run `check_ci.py` against the copy (via the script's path argument or the tests' fixtures) 4. Repeat for `.ddev` version 10.11 and `pantheon.yml` 10.4 |
| Expected result | Step 1 exit 0; test file passes and contains cases for: all three equal (pass), CI differs (fail), DDEV differs (fail), Pantheon differs (fail), service missing (fail), image `latest` or unversioned (fail). Steps 3 and 4 exit non-zero and name the mismatching file. Rule 6 (no Functional tests tripwire) still green |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-61: Secret scan of the CI database URL

| Field | Value |
|---|---|
| Linked criterion | C6 |
| Mode | host run |
| Preconditions | Implementation committed |
| Steps | 1. `.tools/pre-commit run --all-files 2>&1 \| tee EVD` 2. `grep -rn "mysql://" .github apps/drupal/phpunit.xml.dist scripts docs/runbooks` |
| Expected result | All hooks pass including gitleaks (the throwaway CI-only DB value is not flagged, or the allowlisting is a documented, narrow rule, not `--no-verify`); step 2 shows only throwaway/placeholder values with no real credential; no `.env` committed; `.env.example` unchanged |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-62: Live CI run of the `drupal` job on MariaDB

| Field | Value |
|---|---|
| Linked criterion | C4, AC5 |
| Mode | live CI / owner-run |
| Preconditions | Branch pushed and a PR open (owner action; no `gh` here) |
| Steps | 1. Owner sends the Actions run URL and the full logs of the `drupal` job (service container start, `php -m`, phpunit output, coverage step) and the artifact list 2. Tester reads the logs |
| Expected result | The run is green; log shows MariaDB 10.6.x started and healthy, pcov loaded, Unit and Kernel suites with the same test counts as the DDEV run (TC-T09-54), the coverage gate with the same line coverage within rounding, and the Cobertura XML in the uploaded artifacts. The two runs (DDEV and CI) are both recorded in the report (T08 condition 5). Without the owner's logs the case is Blocked |
| Evidence | owner-supplied logs stored in `evidence/` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group L: Docs-regression and earlier suites

### TC-T09-63: Earlier T05 and T06 suites updated for the new state

| Field | Value |
|---|---|
| Linked criterion | C3, C4 |
| Mode | static plus host run |
| Preconditions | Tester editing is limited to `docs/tests/` |
| Steps | 1. Update `docs/tests/T05/run-checks.sh` lines 475 (phpunit.xml.dist absent), 476 (no custom module exists) and 621 (SKIP of `component-drupal-tests`), and `docs/tests/T06/run-checks.sh` line 1031 (same SKIP check), with a Change log row in `docs/tests/T05/test-cases.md` and `docs/tests/T06/test-cases.md` dated with the reason (T09 supersedes the "until T09" note, TC-T05-19 and the T05/T06 walk-through expectations). 2. `docs/tests/T05/run-checks.sh --regression` 3. `docs/tests/T06/run-checks.sh --regression` 4. `grep -n "phpunit.xml.dist is absent\|no custom module\|SKIP component-drupal-tests\|SKIP\\\\s+component-drupal-tests" docs/tests/T05/run-checks.sh docs/tests/T06/run-checks.sh` |
| Expected result | The old checks now assert the new state (phpunit.xml.dist present; `meridian_core` is the only custom module; `component-drupal-tests` shows PASS, not SKIP); step 4 finds none of the old expectations; both regression runs exit 0 with the same pass counts or higher (counts recorded, no check removed silently: each replaced check is listed with the reason in the Change log). The `cka`/`ckp` tag choice is recorded. A check is changed only to reflect the T09 state change in the plan, never to hide a failure |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-64: Docs suites of earlier tasks still pass after T09 text edits

| Field | Value |
|---|---|
| Linked criterion | C3, C5 |
| Mode | host run |
| Preconditions | TC-T09-63 done |
| Steps | 1. `for t in T04 T04a T05 T06 T07 T08; do ls docs/tests/$t/run-checks.sh 2>/dev/null; done` 2. Run each in `--regression` (or default) mode: `docs/tests/<T>/run-checks.sh --regression 2>&1 \| tee EVD` 3. `.tools/pre-commit run --all-files` |
| Expected result | Every earlier suite that exists returns exit 0 in regression mode; any new failure is a defect against T09 (not an excuse to edit the old suite) unless it is exactly one of the four known lines in TC-T09-63. T08 checks on `quality.sh`, `expected-skips.txt`, `check_ci.py` and `ci.yml` pass against the changed files |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-65: No Functional tests, no broker, no external host

| Field | Value |
|---|---|
| Linked criterion | C4, C6 |
| Mode | static |
| Preconditions | Implementation committed |
| Steps | 1. `find apps/drupal/web/modules/custom -type d -name Functional` 2. `python3 scripts/check_ci.py` (rule 6) 3. `scripts/check-names.sh` 4. `grep -rniE "zerodha\|kite\|upstox\|angel\|dhan\|fyers\|broker\|place_?order" apps/drupal/web/modules/custom apps/drupal/config/sync apps/drupal/scripts docs/specs/permissions.md` 5. `grep -rnE "https?://" apps/drupal/web/modules/custom apps/drupal/scripts` |
| Expected result | Step 1 prints nothing; check_ci rule 6 and names check exit 0; step 4 prints nothing; step 5 prints only the schema/documentation namespace URIs that Drupal itself uses (if any), recorded; no order-placement code, no SDK, no broker domain |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group M: MG-1 NFR-04 entity-layer measurement (DN-9)

### TC-T09-66: MG-1 script exists and follows the DN-9 parameters

| Field | Value |
|---|---|
| Linked criterion | C3, C5 |
| Mode | static |
| Preconditions | Implementation committed |
| Steps | 1. `ls apps/drupal/scripts/perf/mg1_ingest_timing.php` 2. Read the script against `decision-measurement-scope.md` and plan step 10 |
| Expected result | Script exists; targets `decision` only; creates one Daily Run first (untimed); 500 Decisions of about 8 KB each (`inputs_snapshot` and `raw_llm_output` JSON objects, about 4 MB total); a create pass and an update pass (changed field, new revision), each in one transaction; `validate()` on every entity with 0 violations asserted (abort otherwise); 5 runs, each starting with no Decisions (deletion untimed); Xdebug off check; prints PHP, MariaDB, pcov loaded, host (OS, CPU, RAM), raw per-run timings for both passes, the p95 (stated as the slowest of 5), and the sum. No write to `config/sync`. Uses no network |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-67: MG-1 measurement run, p95 within NFR-04

| Field | Value |
|---|---|
| Linked criterion | C3 |
| Mode | ddev run (throwaway install) |
| Preconditions | Throwaway DB state (`ddev drupal-install --force` afterwards restores the site); Xdebug off (`ddev xdebug status` reports disabled) |
| Steps | 1. `ddev xdebug status` 2. `ddev drush php:script apps/drupal/scripts/perf/mg1_ingest_timing.php 2>&1 \| tee EVD` 3. `git status --porcelain` 4. `ddev drupal-install --force` (restore) |
| Expected result | Output shows 5 runs with create and update times, 0 violations, the environment facts, p95 labelled as the slowest run; the combined create + update p95 is 15 s or less (NFR-04). If above 15 s the case is Fail for NFR-04 only in the sense that it is reported, and the plan says the technical-architect raises it at T10 planning before T10 coding: the report records Pass-with-finding or Fail as the criteria state; the tester does not change the threshold. Step 3 shows no tracked file changed; the site is intact after step 4 |
| Evidence | `EVD` (raw output) |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-68: MG-1 result recorded in `technical-design.md`

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Mode | static |
| Preconditions | TC-T09-67 run |
| Steps | 1. `grep -n "NFR-04\|NFR-05\|MG-1" docs/architecture/technical-design.md` 2. Compare the recorded numbers with `evidence/TC-T09-67.txt` |
| Expected result | The NFR-04 DDEV row says T09 runs the entity-layer part (500 Decisions of about 8 KB, create and update, 5 runs) and T10 confirms on the endpoint; the NFR-05 row says measured in T11 with 5,000 seeded nodes (authority moved to T11 by `decision-measurement-scope.md`), T30 confirms; the MG-1 result with date and raw output sits below the table; numbers equal the evidence file |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group N: Documentation and traceability (C5)

### TC-T09-69: Data-model amendments (plan step 11)

| Field | Value |
|---|---|
| Linked criterion | AC1, C5 |
| Mode | static |
| Preconditions | Step 11 done |
| Steps | 1. `grep -n "meridian_core.allowed_values\|share the storage\|DN-11\|2026-11-04\|ck_positions_closed\|ck_runs_wl_source_required\|ck_decisions_external_id\|ck_positions_external_id\|ck_decisions_inputs_object\|ck_decisions_llm_object\|built from the record" docs/specs/data-model.md` 2. Read the Uniqueness paragraph |
| Expected result | The data-model has a dated revision note citing the decision files; the Uniqueness paragraph carries the DN-11 text; Position and Daily Run `field_status` shared-storage note present; Position closed/open conditional wording; `decision` Validation per DN-6; the four `external_id` "equals ... built from the record's own fields" statements; Daily Run `skip_reason`/`watchlist_source` per DN-4 with `trade_date` text moved to `external_id`; Watchlist `symbol` unique and immutable; Decision `raw_llm_output` per DN-7; the Postgres parity notes. The T09 config (TC-T09-03) matches this amended text |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-70: Technical-design, README and runbook updates

| Field | Value |
|---|---|
| Linked criterion | C5, C7 |
| Mode | static |
| Preconditions | Step 11 done |
| Steps | 1. `grep -n "view meridian inputs\|meridian_external_id\|MeridianUniqueInBundle" docs/architecture/technical-design.md` 2. `grep -n "SIMPLETEST_DB\|--testsuite kernel" apps/drupal/README.md docs/runbooks/local-setup.md` 3. `grep -n "mariadb\|pcov\|parity" .github/README.md scripts/README.md` 4. `grep -n "T09" docs/PROGRESS.md docs/TRACEABILITY.md` 5. `grep -n "R-06\|R-07\|FR-16" docs/TRACEABILITY.md` |
| Expected result | D1 bullets updated (DN-11 text, field-visibility sentence with `view meridian inputs`); READMEs and runbook explain how to run Drupal tests and what `SIMPLETEST_DB` is; `.github/README.md` and `scripts/README.md` describe the DB service, pcov and the parity rule; `PROGRESS.md` shows T09 status; `TRACEABILITY.md` rows R-06, R-07 and FR-16 point to T09 test cases and evidence. Markdown passes markdownlint (pre-commit) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-71: AC6 wording and SA-1 hand-offs (deferred to close)

| Field | Value |
|---|---|
| Linked criterion | AC6, C5 |
| Mode | deferred to `/close-task` (owner and solution-architect items) |
| Preconditions | Task being closed |
| Steps | 1. `grep -n "Permissions matrix" docs/TASKS.md` 2. `grep -n "T11 measurement" docs/architecture/solution-architecture.md` |
| Expected result | `docs/TASKS.md` T09 AC6 carries the reworded text (six roles) as given in the criteria, so O-3 is resolved and the report needs no "reading" note. SA-1: the NFR-05 row says "provisional until the T11 measurement" and the Amendments table has a dated row. If SA-1 is not done at close the case is Blocked (not a T09 code failure) and listed in the report as an open hand-off |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Group O: Common criteria

### TC-T09-72: C1 plan exists and was reviewed before coding

| Field | Value |
|---|---|
| Linked criterion | C1 |
| Mode | static |
| Preconditions | none |
| Steps | 1. `git log --format='%h %ad %s' --date=iso -- docs/tasks/T09/plan.md` 2. `git log --reverse --format='%h %ad %s' --date=iso -- apps/drupal/web/modules/custom/meridian_core \| head -3` |
| Expected result | The plan status is Approved (2026-11-04) and its first commit precedes the first `meridian_core` commit; decision files are committed before code |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-73: C2 code reviewed and findings resolved

| Field | Value |
|---|---|
| Linked criterion | C2 |
| Mode | static |
| Preconditions | `/review-task T09` done |
| Steps | 1. `ls docs/tasks/T09/review.md` 2. `grep -n "Verdict\|Open\|Blocker\|Major" docs/tasks/T09/review.md` |
| Expected result | The review exists, verdict is approved (or approved with conditions that are closed), no open blocker or major finding, and the KD-4 path (key, A or B) and the SyncConfigTrait outcome are recorded |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-74: C3 every criterion maps to an executed case with evidence

| Field | Value |
|---|---|
| Linked criterion | C3 |
| Mode | static |
| Preconditions | Execute mode complete |
| Steps | 1. For each case ID in this file `ls docs/tests/T09/evidence/TC-T09-nn*.txt` 2. Check `test-report.md` lists a status for each case |
| Expected result | Every case that is Pass has a non-empty evidence file; each AC1 to AC6 and C1 to C7 has at least one Pass (or an explicit Blocked/deferred reason in the report); no Fail or Blocked case is signed off ("Not signed off" with the reason otherwise) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-75: C4 full quality suite, pre-commit, and CI green

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Mode | ddev run plus live CI |
| Preconditions | Tree clean |
| Steps | 1. `ddev quality 2>&1 \| tee EVD` 2. `.tools/pre-commit run --all-files 2>&1 \| tee -a EVD` 3. `scripts/check-names.sh` 4. CI run: see TC-T09-62 |
| Expected result | All three exit 0; no new lint, type or security warning compared with the T08 baseline (the counts of warnings are recorded); CI green by TC-T09-62; no a phpcs ignore comment, a PHPStan ignore comment or a baseline added without a ticket comment (grep shows none, or each carries a ticket) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-76: C6 secrets and `.env.example`

| Field | Value |
|---|---|
| Linked criterion | C6 |
| Mode | static |
| Preconditions | Implementation committed |
| Steps | 1. `git diff origin/main --stat -- .env.example` 2. `git ls-files \| grep -E '(^\|/)\.env$'` 3. `grep -rn "MERIDIAN_" apps/drupal/web/modules/custom apps/drupal/scripts` 4. `.tools/pre-commit run gitleaks --all-files` |
| Expected result | `.env.example` unchanged (plan: no new `MERIDIAN_` variable; `SIMPLETEST_DB` is a test-runner variable documented in `apps/drupal/README.md`); no `.env` tracked; any `MERIDIAN_` variable found in step 3 is listed in `.env.example`; gitleaks passes |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T09-77: C7 clean checkout works with documented commands

| Field | Value |
|---|---|
| Linked criterion | C7 |
| Mode | ddev run (clean clone) plus owner-run for the Windows side |
| Preconditions | A fresh clone of the branch on the WSL2 Linux filesystem (not `/mnt/c`), `ddev` installed |
| Steps | 1. `git clone <repo> $WORK/clean && cd $WORK/clean && git checkout task/T09-content-model` 2. `ddev start` 3. `ddev drupal-install` 4. `ddev quality` 5. `ddev exec -d /var/www/html/apps/drupal vendor/bin/phpunit --testsuite kernel` 6. Only commands from `apps/drupal/README.md` and `docs/runbooks/local-setup.md` are used; any other command is a docs defect |
| Expected result | All steps exit 0 using only the documented commands; the Drupal tests run and pass from a clean checkout. The clean clone uses a differently named DDEV project directory, so the tester records the project-name collision handling from the runbook. If a second DDEV project cannot be started the case is Blocked and the owner is asked to run it. Owner-run: `https://meridian.ddev.site` opens in the Windows browser (login from `ddev drush uli`) |
| Evidence | `EVD` |
| Actual result | |
| Status | Not run |
| Date | |
| Executed by | |

---

## Execution order

1. Static and host cases: 01, 02, 06, 08, 09, 28, 29, 38, 53, 59, 60, 61, 63, 64, 65, 66,
   69, 70, 72, 73, 76.
2. DDEV, non-destructive: 03, 04, 05, 10 to 27, 30 to 35, 39 to 46, 54, 55, 56, 57, 58.
3. Destructive (drops the local DB): 48 to 52, then 36 and 37 (key checks after each install
   path), then 67 (MG-1, reinstall afterwards).
4. Owner or live CI: 47, 62, 77 (Windows part).
5. Close-time: 68, 71, 74, 75.

## Criterion coverage table

| Criterion | Test cases |
|---|---|
| AC1: Content types and fields exactly as the T03 spec, exported in `config/sync` | TC-T09-01, 02, 03, 04, 05, 06, 07, 69 |
| AC2: Validation enforced (mode, action, score 0 to 100, required fields, numeric ranges) | TC-T09-04, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29 |
| AC3: Unique `external_id` per type at entity level (and the DB backstop) | TC-T09-25, 29, 31, 32, 33, 34, 35, 36, 37 |
| AC4: `cex` after install shows no diff; `cim` on a clean site recreates everything | TC-T09-06, 36, 37, 46, 48, 49, 50, 51, 52 |
| AC5: Kernel tests cover every validation rule, including each rejection case | TC-T09-03, 07, 08, 09, 10 to 27, 28, 29, 30, 31, 53, 54, 55, 56, 59, 62 |
| AC6: Permissions matrix documented and tested for the six roles (FR-16) | TC-T09-38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 71 |
| C1: Plan reviewed before coding | TC-T09-72 |
| C2: Code reviewed, findings resolved | TC-T09-73 |
| C3: Every criterion maps to an executed case with evidence | TC-T09-63, 64, 66, 67, 74 |
| C4: CI green, no new lint, type or security warnings | TC-T09-53, 54, 56, 57, 58, 59, 60, 62, 63, 64, 65, 75 |
| C5: Docs and traceability updated (R-06, R-07, FR-16) | TC-T09-01, 37, 45, 68, 69, 70, 71 |
| C6: No secrets; `.env.example` handled | TC-T09-61, 65, 76 |
| C7: Works from a clean checkout with documented commands | TC-T09-47, 70, 77 |

Plan-driven coverage not tied to a single criterion:

| Plan item | Test cases |
|---|---|
| KD-1 config only in `config/sync`, `SyncConfigTrait` loads shipped YAML | TC-T09-02, 03, 07, 54 |
| KD-3 violation paths and codes | TC-T09-11 to 28 |
| DN-3 field_status subsets | TC-T09-04, 17, 21 |
| DN-4 conditional fields | TC-T09-19, 22 |
| DN-5 external_id consistency | TC-T09-26 |
| DN-6 Position's Decision | TC-T09-20 |
| DN-8 watchlist symbol immutable | TC-T09-25 |
| DN-9 MG-1 NFR-04 | TC-T09-66, 67, 68 |
| DN-10, DN-11 uniqueness | TC-T09-31 to 37, 69 |
| KD-7 access hooks | TC-T09-41, 42, 43, 44 |
| KD-8 test infrastructure | TC-T09-53, 54, 56, 59, 60 |
| Earlier docs-regression updates (T05 475, 476, 621; T06 1031) | TC-T09-63, 64 |

## Case count

77 cases, TC-T09-01 to TC-T09-77.

| Mode | Cases |
|---|---|
| Static or host only | 01, 02, 06, 08, 09, 28, 29, 38, 53, 59, 60, 61, 63, 64, 65, 66, 69, 70, 72, 73, 76 |
| DDEV run | 03, 04, 05, 07, 10 to 27, 30 to 37, 39 to 46, 48 to 52, 54 to 58, 67 |
| Owner-run or live CI | 47, 62, 77 (Windows browser part) |
| Deferred to close | 68, 71, 74, 75 |
| Tester MUT (sensitivity) | 07, 11, 12, 45, 55, 58 |
