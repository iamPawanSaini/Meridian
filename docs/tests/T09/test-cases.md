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
| Evidence | `evidence/TC-T09-01.txt` |
| Actual result | meridian_core dir with info.yml (core ^11.1; deps datetime, node, options, user); core.extension.yml lists datetime, options, meridian_core plus node, field, text, user; no jsonapi, rest, basic_auth, simple_oauth, serialization; composer.json unchanged against main; check-names.sh exit 0. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-02: Content model config lives in `config/sync` only (KD-1)

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Mode | static |
| Preconditions | as TC-T09-01 |
| Steps | 1. `ls apps/drupal/config/sync \| grep -E '^(node.type\|field.storage.node\|field.field.node\|core.entity_(form\|view)_display.node\|user.role)'` 2. `find apps/drupal/web/modules/custom/meridian_core -path '*config/install*' -type f` 3. `find apps/drupal/web/modules/custom/meridian_core/config -type f` 4. `grep -n 'enforced' -A3 apps/drupal/config/sync/node.type.*.yml` |
| Expected result | Exactly 5 `node.type.*` files (`decision`, `position`, `daily_run`, `price_snapshot`, `watchlist_item`) and no other node type. Step 2 prints nothing (no `config/install` copy). Step 3 lists only `schema/meridian_core.schema.yml`. Each of the 5 node types has `dependencies.enforced.module: [meridian_core]`. `config/sync` holds 4 new `user.role.*` files: `administrator`, `analyst`, `engine_ingest`, `dashboard_read`. Every config file passes `yamllint` (pre-commit) and has a `uuid` that is not a hand-invented pattern (all distinct, valid v4) |
| Evidence | `evidence/TC-T09-02.txt` |
| Actual result | 5 node.type files and no other; no config/install copy; only config/schema/meridian_core.schema.yml; dependencies.enforced.module [meridian_core] on all 5; 6 user.role files (4 new: administrator, analyst, engine_ingest, dashboard_read); 214 UUIDs in config/sync, all valid v4 and distinct; yamllint passes. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-03: Field storages and instances equal the data-model, bundle by bundle

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Mode | ddev run (Kernel) plus static cross-check |
| Preconditions | Site installable; Kernel harness works (TC-T09-54) |
| Steps | 1. `PU-F ContentModelStructureTest --testdox 2>&1 \| tee EVD` 2. Static cross-check by the tester: for each bundle list `ls apps/drupal/config/sync/field.field.node.<bundle>.*.yml` and compare the set of field names with the data-model tables (the plan KD-2 table is the reading aid) |
| Expected result | The test passes. The field set per bundle is **exactly** the data-model rows, no extra and no missing field: `decision` 21 fields (title, external_id, trade_date, symbol, mode, score, pre_llm_action, action, vetoed, veto_reason, rule_hits, rule_version, prompt_version, model_name, inputs_snapshot, raw_llm_output, llm_rationale, close_price, run, source_version, payload_hash); `position` 24; `daily_run` 24; `price_snapshot` 13; `watchlist_item` 7 (counts include `title`; the tester recounts from the amended data-model and records any difference). No `body` field is left on any bundle. The test asserts per field: type, cardinality (`rule_hits` -1, `modes` 2, others 1), required flag, `max_length` (external_id 64 or per table, symbol 20, versions 32, model_name 64, run_id 36, skip_reason 255, payload_hash 64, title 255), `decimal` precision and scale (score 5,2; close_price 14,4; entry/stop/target/exit/last_mark 14,4; costs_total 12,2; realised/unrealised 14,2; r_multiple 8,3; virtual_equity 16,2; llm_cost_usd 10,4; open/high/low/close 14,4), `integer` size big on `volume`, `datetime_type: date` on date fields, `timestamp` on `started_at`/`finished_at`, `target_type: node` and `target_bundles` on `run` (daily_run), `decision` (decision), `allowed_values` of each list, min/max settings, `new_revision: true`, `display_submitted: false`, published by default |
| Evidence | `evidence/TC-T09-03-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`), `evidence/TC-T09-03-datamodel-crosscheck.txt`, `evidence/TC-T09-03-extras.txt` |
| Actual result | ContentModelStructureTest passes (4 tests, in the 47-test run). Independent cross-check of field.field files against data-model.md: decision 21 (with title), position 24, daily_run 22, price_snapshot 13, watchlist_item 7; no extra or missing field, no body field; new_revision true and display_submitted false on all 5; rule_hits cardinality -1, modes 2; volume size big; date fields datetime_type date; run targets daily_run. Note: the case text says daily_run 24; the amended data-model has 22 (the tester recounted, as the case allows). MUT in TC-T09-07. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-04: Shared `field_status` storage and per-bundle subsets (DN-3)

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2 |
| Mode | static plus ddev run |
| Preconditions | as TC-T09-03 |
| Steps | 1. `cat apps/drupal/config/sync/field.storage.node.field_status.yml` 2. `grep -n 'meridian_core' -B1 -A6 apps/drupal/config/sync/field.field.node.position.field_status.yml apps/drupal/config/sync/field.field.node.daily_run.field_status.yml` 3. `cat apps/drupal/web/modules/custom/meridian_core/config/schema/meridian_core.schema.yml` 4. `ddev drush config:status` |
| Expected result | One storage, type `list_string`, `allowed_values` keys in this order: `open`, `closed`, `success`, `failed`, `skipped`. `position` instance has `third_party_settings.meridian_core.allowed_values: [open, closed]`; `daily_run` has `[success, failed, skipped]`. The schema file declares `field.field.*.*.*.third_party.meridian_core` with a sequence of strings under `allowed_values`. `config:status` says "No differences" (the schema lets config validation accept the setting) |
| Evidence | `evidence/TC-T09-04.txt` |
| Actual result | One list_string storage, allowed values open, closed, success, failed, skipped in that order; position subset [open, closed], daily_run subset [success, failed, skipped]; schema file declares field.field.*.*.*.third_party.meridian_core; config:status says no differences. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-05: Indexes exist on every "Indexed: yes" column

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Mode | ddev run |
| Preconditions | Site installed |
| Steps | 1. Read the "Indexed" column of the amended data-model for the five bundles and list the "yes" fields. 2. `PU-F ContentModelStructureTest --testdox` (index assertions). 3. For the tester's independent check: `ddev drush sql:query "SHOW INDEX FROM node__field_score"` and the same for `node__field_symbol`, `node__field_vetoed`, `node__field_enabled`, `node__field_sort_order`, `node__field_finished_at`, `node__field_external_id`, `node__field_mode`, `node__field_status`, `node__field_trade_date`, `node__field_run` |
| Expected result | Every "yes" field has an index on its value column (or target id for references) in the dedicated table, found in the SHOW INDEX output, and the Kernel test asserts the same. Fields marked "no" are not required to have one (core defaults tolerated). The tester records the exact index names (plan: "verify") in the report |
| Evidence | `evidence/TC-T09-05-datamodel-indexed.txt`, `evidence/TC-T09-05-live.txt`, `evidence/TC-T09-05-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | All 27 'Indexed: yes' fields of the amended data-model have an index in the live database (names field_<name>_value, field_run_target_id and field_decision_target_id; plus the unique key meridian_external_id_bundle); ContentModelStructureTest 'Indexed columns' passes. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-06: Default form and view displays exist for all bundles

| Field | Value |
|---|---|
| Linked criterion | AC1, AC4 |
| Mode | static |
| Preconditions | as TC-T09-02 |
| Steps | 1. `ls apps/drupal/config/sync/core.entity_form_display.node.*.default.yml apps/drupal/config/sync/core.entity_view_display.node.*.default.yml` 2. For each bundle, check every field of the bundle appears in `content` or `hidden` of both displays |
| Expected result | 5 form displays and 5 view displays (`default` mode). No field of any bundle is missing from either display, so `cim` is complete. No Views, no JSON:API config, no extra form mode |
| Evidence | `evidence/TC-T09-06.txt` |
| Actual result | 5 default form displays and 5 default view displays; every field of every bundle appears in content or hidden of both; no Views, JSON:API config or extra display mode. Kernel 'Displays cover every field' passes. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-07: No field is invented or left out (negative structure control)

| Field | Value |
|---|---|
| Linked criterion | AC1, AC5 |
| Mode | ddev run, MUT |
| Preconditions | scratch copy of `config/sync` in `$WORK` |
| Steps | 1. In the scratch copy remove `field.field.node.decision.field_score.yml` and its display entries, or change `max_length` of `field_symbol` from 20 to 21. 2. Point the Kernel structure test at the scratch config (if the trait has a configurable directory) or apply the change in a scratch checkout. 3. `PU-F ContentModelStructureTest` |
| Expected result | The structure test fails and names the bundle and field. If the test does not fail, the structure test does not check exactness: Fail (defect). If the trait cannot be redirected, record "MUT not run: trait path fixed" and the case is Blocked |
| Evidence | `evidence/TC-T09-07.txt`, `evidence/TC-T09-55.txt` |
| Actual result | MUT (copy in the DDEV container): field_symbol max_length 20 to 21 fails testBundlesAndFieldsEqualTheDataModel; deleting field.field.node.decision.field_score.yml fails testBundlesAndFieldsEqualTheDataModel and testStatusUnionAndSubsets. The copy of config/sync was used (no trait change needed). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-08.txt` |
| Actual result | Unit suite OK (25 tests, 217 assertions); PatternsTest has accept and reject lists for symbol, version label, model name, rule ID, UUID, payload hash, date and the five external IDs, including trailing newline, wrong month, wrong prefix and uppercase prefix. Mapped to every item of the expected result. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-09: JSON document and decimal scale validators (unit)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | host/ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-U --filter 'JsonDocument\|DecimalScale' --testdox 2>&1 \| tee EVD` |
| Expected result | JSON validator: invalid JSON (`{`), a JSON array, a JSON string, a number, `null` each rejected when an object is required; `{}` and `{"a":1}` accepted; byte limits tested at limit (accepted) and limit + 1 (rejected) with multibyte (UTF-8, for example 3-byte characters, so bytes differ from characters); the limit is measured in bytes. Empty string handled as defined by the plan (required rule reports it, not this validator: no second violation). Decimal scale validator: more fractional digits than the scale rejected (for example 50.123 with scale 2), more integer digits than `precision - scale` rejected, `0`, `-0.01`, exact max accepted, string and numeric input forms handled, no rounding |
| Evidence | `evidence/TC-T09-09.txt` |
| Actual result | 8 tests, 61 assertions OK: JSON invalid, array, string, number, null rejected; {} and objects accepted; byte limits at limit and limit + 1 with 3-byte characters (strlen 100, mb_strlen below 100) and the 65,536 and 32,768 limits; empty value adds nothing; decimal scale: too many fraction digits, too many integer digits, accepted forms (string, int, float), no rounding. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-10-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testBaselineAndRequiredFields passes: baseline 0 violations; all 18 required fields give exactly one (path, REQUIRED) pair; optional veto_reason, rule_hits, llm_rationale empty accepted; vetoed false accepted and NULL rejected; source_version 0 and -1 rejected (TOO_LOW). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-11: Decision enums, mode and action (AC2 named rules)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run, MUT |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` 2. MUT: in a scratch copy add `short2` to `field_mode` allowed values and re-run |
| Expected result | `mode` accepts `long`, `short`; rejects `longg`, `LONG`, `''`, `buy`, null-equivalent. `action` and `pre_llm_action` accept `BUY`, `AVOID`; reject `SELL`, `buy`, `HOLD`. `veto_reason` accepts each of the 7 values (`llm_veto`, `malformed`, `empty`, `timeout`, `api_error`, `schema_violation`, `budget`) and rejects `other`, `LLM_VETO`. Each rejection is one violation at the field path (a mode rejection may also mismatch the external_id if the id was built from it: the test must change both consistently, or the test expectation lists exactly the plan's one-violation outcome). MUT: the mode test fails |
| Evidence | `evidence/TC-T09-11-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`), `evidence/TC-T09-11-mutation.txt` |
| Actual result | testEnumerations passes: long and short accepted; longg, LONG, buy rejected; SELL, buy, HOLD rejected for action and pre_llm_action; the 7 veto reasons accepted, other and LLM_VETO rejected; one violation each. MUT short2 in field_mode fails testEnumerations and testExternalId. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-12: Decision score boundaries and scale

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run, MUT |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` 2. MUT: change `field_score` max to 101 in a scratch copy |
| Expected result | `score` -0.01 rejected, 100.01 rejected, 50.123 rejected (scale), 1000 rejected (precision), non-numeric rejected; 0, 0.00, 100, 100.00, 50.5 accepted. Each rejection is one violation at `field_score`. MUT: the 100.01 test fails |
| Evidence | `evidence/TC-T09-12-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`), `evidence/TC-T09-12-mutation.txt`, `evidence/TC-T09-12-probe.txt` |
| Actual result | testScoreAndPrices passes for -0.01, 100.01, 1000 (TOO_HIGH), 50.123 (meridian.decimal_scale), 0, 0.00, 100, 100.00, 50.5. MUT score max 101 fails the 100.01 case. Mismatch: 'non-numeric rejected' has no Kernel test, and the tester's probe shows a non-numeric score ('abc') gives three violations at field_score.0.value (two core 'valid number' codes and one empty-code primitive-type violation), not one. See DEF-012. |
| Status | Fail |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-13: Decision `trade_date` not in the future (IST boundary)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Fixed-clock `TimeInterface` stub registered over `datetime.time` |
| Steps | 1. `PU-F DecisionValidationTest --testdox` |
| Expected result | With the clock fixed: `trade_date` tomorrow (IST) rejected at `field_trade_date`; today (IST) accepted; yesterday accepted. Boundary pair either side of IST midnight: UTC 18:29:59 on day D (IST 23:59:59 on D) accepts D and rejects D+1; UTC 18:30:00 on day D (IST 00:00:00 on D+1) accepts D+1 and rejects D+2. The test uses fixed instants (no `sleep`, no real clock). A malformed date string is rejected with exactly two core datetime violations, `field_trade_date.0` and `field_trade_date.0.value`, both with code `''` (accepted behaviour, review D4; no Meridian rule adds a third; raw paths and the empty code are asserted in `ViolationContractTest`). External_id is rebuilt consistently so only the date violation appears |
| Evidence | `evidence/TC-T09-13-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testTradeDateNotInTheFuture passes with the fixed clock: tomorrow rejected (meridian.date_in_future at field_trade_date), today and yesterday accepted, both IST midnight edges (18:29:59 UTC accepts D and rejects D+1; 18:30:00 UTC accepts D+1 and rejects D+2). A malformed date gives the two core violations (field_trade_date.0 and field_trade_date.0.value, both code ''), as amended on 2026-11-05 (review F7, D4). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-14: Decision cross-field rules (action, veto)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` |
| Expected result | Truth table, each row tested with exact path and code: `action` BUY with `pre_llm_action` AVOID rejected; `action` BUY with `vetoed` true rejected; `vetoed` true with `pre_llm_action` AVOID rejected; `vetoed` true without `veto_reason` rejected at `field_veto_reason`; `veto_reason` set while `vetoed` false rejected; accepted rows: (pre BUY, action BUY, not vetoed), (pre BUY, action AVOID, vetoed true with reason), (pre AVOID, action AVOID, not vetoed), (pre BUY, action AVOID, not vetoed, i.e. LLM said avoid). A rule that reads another field returns no second violation when the input is itself invalid (for example `pre_llm_action` = `SELL` gives only the list violation) |
| Evidence | `evidence/TC-T09-14-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testActionAndVetoRules passes: all rejected rows with exact (path, code) (buy_requires_pre_buy, buy_vetoed, veto_requires_pre_buy, veto_reason_required, veto_reason_forbidden) and the four accepted rows; an invalid pre_llm_action or action gives only the list violation. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-15: Decision text, JSON, rule_hits, version and length rules

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` |
| Expected result | Each tested as accept at limit, reject at limit + 1 where a limit exists, one violation each: `rule_hits` bad item (`lower`) rejected, a 51st item rejected (50 accepted), a bad item among valid ones reports the item path (delta `field_rule_hits.<n>`); `rule_version`/`prompt_version` `1.2`, `v1.2.3` rejected; `model_name` `Claude` rejected; `inputs_snapshot` invalid JSON, JSON array, 65,537 bytes rejected, 65,536 accepted; `raw_llm_output` invalid JSON, array, 32,769 bytes rejected, 32,768 accepted, `{"status":"not_called"}` accepted; multibyte string at the byte limit; `llm_rationale` 2,001 characters rejected, 2,000 accepted; `title` 256 rejected, 255 accepted; `payload_hash` uppercase or 63 chars rejected; `symbol` `reliance` and 21 chars rejected; `close_price` 0 and -1 rejected, 0.0001 accepted, 5 decimals rejected (scale) |
| Evidence | `evidence/TC-T09-15-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testTextAndDocumentRules passes: rule_hits item paths field_rule_hits.<n>, 50 accepted and 51 rejected; version, model name, title, payload_hash, symbol, close_price rules; inputs_snapshot and raw_llm_output at limit and limit + 1 including multibyte; llm_rationale 2,000 and 2,001; not_called accepted. Each case one violation. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-16: Decision `run` reference rules

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DecisionValidationTest --testdox` |
| Expected result | `run` pointing at a node ID that does not exist rejected at `field_run`; `run` pointing at a node of the wrong bundle (for example another `decision`) rejected at `field_run`; `run` pointing at a `daily_run` accepted. One violation each |
| Evidence | `evidence/TC-T09-16-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testRunReference passes: a daily_run accepted; a missing node ID and a node of another bundle give one violation at field_run (empty code, core ValidReference). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-17-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`), `evidence/TC-T09-12-probe.txt` |
| Actual result | Baseline open and closed long Positions valid; every required field gives one violation; status success, skipped, failed rejected with meridian.bundle_allowed_values; exit_reason enum; every decimal scale tested; quantity 0, -1 rejected, 1 accepted; r_multiple, costs_total ranges. Mismatch: 'non-integer rejected' (quantity) has no Kernel test; the tester's probe shows 1.5 and '1.5' are rejected with one empty-code violation and 'abc' with two. See DEF-012. |
| Status | Fail |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-18: Position price ordering and time stop by mode

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PositionValidationTest --testdox` |
| Expected result | `stop_price` 0 rejected; `stop_price` equal to `entry_price` rejected; `stop_price` above `entry_price` rejected (each one violation at `field_stop_price`); stop below entry accepted. `target_price` equal to `entry_price` rejected, below rejected, above accepted (path `field_target_price`). Short position without `time_stop_date` rejected; short with `time_stop_date` equal to `entry_date` rejected; before `entry_date` rejected; after accepted. Long position with `time_stop_date` set rejected; long without accepted. When `entry_price` is missing or invalid the ordering rules add no second violation |
| Evidence | `evidence/TC-T09-18-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testPriceOrderingAndTimeStop passes: stop 0, equal and above entry rejected at field_stop_price; target equal and below rejected at field_target_price; short time stop required, not on or before entry date; long with a time stop rejected; a missing or zero entry price adds no ordering violation. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-19: Position open/closed conditional fields (DN-4)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PositionValidationTest --testdox` |
| Expected result | `closed` without `exit_date`, without `exit_price`, without `exit_reason`, without `realised_pnl`: four separate cases, one violation each at the missing field; `closed` with `unrealised_pnl` set rejected at `field_unrealised_pnl`; a complete closed Position accepted. `open` with `exit_date`, `exit_price`, `exit_reason`, `realised_pnl` each set: four cases, one violation each; `open` with `unrealised_pnl`, `last_mark_price`, `last_mark_date` all set accepted; `open` with none of them accepted. `exit_date` equal to or before `entry_date` rejected, after accepted (path `field_exit_date`). `last_mark_date` before `entry_date` rejected, equal accepted |
| Evidence | `evidence/TC-T09-19-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testOpenAndClosedFields passes: four 'closed without X' cases and four 'open with X' cases one violation each; closed with unrealised_pnl rejected; complete closed accepted; open with all mark fields and with none accepted; exit_date on or before entry date rejected; last_mark_date before entry date rejected, equal accepted. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-20: Position references and Decision checks (DN-6)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PositionValidationTest --testdox` |
| Expected result | `run` targeting a non-`daily_run` and `decision` targeting a non-`decision` bundle rejected at the field path (core `ValidReference`/target bundles); missing target ID rejected; in these cases the DN-6 rules add **no** second violation. Against a valid Decision target, one violation at `field_decision` each, with these exact codes: AVOID decision gives `meridian.position.decision_not_buy`; other symbol gives `meridian.position.decision_symbol_mismatch`; other mode gives `meridian.position.decision_mode_mismatch`; Decision `trade_date` after `entry_date` gives `meridian.position.decision_after_entry`; Decision dated on `entry_date` accepted; earlier accepted. An **unsaved** Decision attached via `->entity` is validated against (all four conditions, accepted when valid) without an entity load by ID |
| Evidence | `evidence/TC-T09-20-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testReferencesAndDecision passes: wrong-bundle and missing run and decision targets give one violation at the field with code '' and no DN-6 violation; decision_not_buy, decision_symbol_mismatch, decision_mode_mismatch and decision_after_entry each one violation at field_decision; dated on or before entry accepted; five unsaved-Decision cases (via ->entity) behave the same. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-21-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | DailyRunValidationTest::testRequiredFieldsAndLists and testNumbersAndTimes pass: baseline valid; each required field one violation; run_id, attempt, status subset (open, closed rejected with meridian.bundle_allowed_values), watchlist_source, symbols_total 0 to 50, counts, buy_count above decisions_count, virtual_equity, llm_cost_usd, finished_at before started_at; version labels and model name. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-22: Daily Run conditional fields (DN-4)

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F DailyRunValidationTest --testdox` |
| Expected result | `skipped` without `skip_reason` rejected at `field_skip_reason`; `skipped` with reason accepted, with or without `watchlist_source`. `success` with `skip_reason` rejected; `success` without `watchlist_source` rejected at `field_watchlist_source`; `success` with source and no reason accepted. `failed` with `skip_reason` `stale_lock` accepted; `failed` without reason accepted; `failed` without `watchlist_source` accepted |
| Evidence | `evidence/TC-T09-22-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testConditionalFields passes: skipped without reason rejected at field_skip_reason; skipped with reason accepted with or without source; success with a reason rejected; success without source rejected at field_watchlist_source; failed with stale_lock, without reason and without source accepted. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-23-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | PriceSnapshotValidationTest passes (2 tests): required fields, adjusted, OHLC ordering with one violation at field_low or field_high (low_above_open, low_above_close, high_below_open, high_below_low, high_below_close), volume -1/0/above 2^31, source enum, 5-decimal scale. Plan question Q-2 recorded: a future trade_date is accepted on price_snapshot and daily_run (testFutureTradeDateIsNotRestricted, accepted by the review as D6). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-24: Watchlist Item field rules

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F WatchlistItemValidationTest --testdox 2>&1 \| tee EVD` |
| Expected result | Baseline: 0 violations. `symbol` regex failures (lowercase, 21 characters) rejected; `modes` empty rejected, `[long]`, `[short]`, `[long, short]` accepted, `[long, long]` rejected by the duplicate rule, `[long, flat]` rejected, 3 values rejected (cardinality); `sort_order` -1 and 1000 rejected, 0 and 999 accepted; `notes` 501 characters rejected, 500 accepted; `enabled` defaults to true on a new entity; `enabled` null rejected (NotNull); `title` 256 rejected |
| Evidence | `evidence/TC-T09-24-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testFieldRules passes: baseline valid; symbol lowercase and 21 characters rejected; modes [long], [short], [long, short] accepted, [long, long] meridian.duplicate_value, [long, flat] rejected at field_modes.1, 3 values rejected; sort_order -1/1000 rejected, 0/999 accepted; notes 500/501; enabled defaults to true, null rejected; title 256 rejected. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-25: Watchlist `external_id` derivation, symbol immutability, 50-enabled limit

| Field | Value |
|---|---|
| Linked criterion | AC2, AC3, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F WatchlistItemValidationTest --testdox` |
| Expected result | A new Watchlist Item created with only a symbol gets `external_id` `wl-{symbol}` (both on `node_create` and on `node_presave`); a supplied external_id that differs is rejected as `meridian.external_id_mismatch` at `field_external_id`; the `WatchlistExternalId::derive()` service returns the same value. Changing `symbol` on a saved item is rejected at `field_symbol` (DN-8) and is the only violation. 50 enabled items: the 51st enabled rejected; the 51st **disabled** accepted; re-saving an existing enabled item when 50 are enabled accepted; enabling a 51st by edit rejected; disabling then enabling again counts correctly |
| Evidence | `evidence/TC-T09-25-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testExternalIdDerivation passes (wl-{symbol} on node_create and node_presave, a differing supplied ID rejected as meridian.external_id_mismatch, service returns the same value); testSymbolUniqueAndImmutable (symbol change rejected at field_symbol with meridian.immutable, the only violation); testEnabledLimit (51st enabled rejected, 51st disabled accepted, re-save at 50 accepted, enabling a 51st by edit rejected, disable then enable counts correctly). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-26-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | A change of each natural-key field with the old external_id gives exactly one violation at field_external_id with code meridian.external_id_mismatch on every bundle (LifecycleRulesTest::testNaturalKeyChangeIsMismatch, plus the per-bundle tests); title change gives none; a missing or invalid key field adds no mismatch. Note: for a Position, changing symbol or mode also gives a separate DN-6 violation at field_decision (decision_symbol_mismatch, decision_mode_mismatch); the test asserts both. Exactly one violation is at field_external_id, so the case holds. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-27: Immutability and non-decreasing `source_version`

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F LifecycleRulesTest --testdox 2>&1 \| tee EVD` |
| Expected result | `external_id` change on a saved entity rejected on each of the five bundles (code `meridian.immutable`, or `meridian.external_id_mismatch` for natural-key changes); saving an unchanged entity accepted; `source_version` equal and higher than the stored value accepted, lower rejected at `field_source_version`; creating with 1 accepted; new revision preserves the rule; uses `loadUnchanged()` so a stale in-memory copy cannot bypass it |
| Evidence | `evidence/TC-T09-27-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`), `evidence/TC-T09-55.txt` |
| Actual result | LifecycleRulesTest passes (4 tests): changed external_id rejected on all five bundles (meridian.immutable), unchanged accepted, source_version equal and higher accepted, lower rejected at field_source_version (meridian.non_decreasing), also with a new revision; a stale in-memory copy is compared with the stored record. MUT removing MeridianImmutable fails testExternalIdIsImmutable. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-28: Violation path and code contract for T10

| Field | Value |
|---|---|
| Linked criterion | AC2, AC5 |
| Mode | static plus ddev run |
| Preconditions | Test classes exist |
| Steps | 1. `grep -rn "meridian\.\(external_id_mismatch\|bundle_allowed_values\|position\.decision_\)" apps/drupal/web/modules/custom/meridian_core/src apps/drupal/web/modules/custom/meridian_core/tests` 2. `PU-K --testdox` 3. Tester reads the assertion helper |
| Expected result | The codes `meridian.external_id_mismatch`, `meridian.bundle_allowed_values`, `meridian.position.decision_not_buy`, `meridian.position.decision_symbol_mismatch`, `meridian.position.decision_mode_mismatch`, `meridian.position.decision_after_entry` appear in both source and tests. Every custom constraint (JSON, decimal scale, date-not-after-today, no-duplicate-values, unique-in-bundle, immutable, non-decreasing, each bundle rules) has a stable `meridian.*` code asserted in at least one test. The helper compares the full `(propertyPath, code)` list exactly (not `count() > 0`). Property path: the Meridian validators report at the field machine name (`field_x`, list level) or `field_x.N` (delta); core rules report at `field_x.0.value`, `field_x.0.target_id` or `field_x.0`, and the Kernel helper `violationsOf()` shortens these to `field_x`. The raw paths and codes (including the empty-code core cases) are asserted in `ViolationContractTest` and documented in the `meridian_core` README, section "Violation contract (T10)"; the tester checks that the README table equals the test |
| Evidence | `evidence/TC-T09-28-static.txt`, `evidence/TC-T09-28-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | All six named codes appear in src and tests; all 41 meridian.* codes in src are asserted by at least one test (the price_snapshot low_above_/high_below_ codes are built from a suffix and asserted in full in PriceSnapshotValidationTest); assertViolations() compares the full sorted (path, code) list with assertSame. Raw paths and codes: ViolationContractTest (1 test, 10 assertions) and the README section 'Violation contract (T10)', which match; amended wording of 2026-11-05. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-29: Rules fire on `validate()`, not only through forms or the API

| Field | Value |
|---|---|
| Linked criterion | AC2, AC3 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `grep -rn "validate()" apps/drupal/web/modules/custom/meridian_core/tests/src/Kernel` 2. `grep -rnE "Request\|Controller\|jsonapi\|HttpKernel\|BrowserTestBase" apps/drupal/web/modules/custom/meridian_core/tests` |
| Expected result | Kernel tests call `$entity->validate()` directly on entities built in code. Step 2: no Request/controller/JSON:API/Functional class (T09 adds no Functional tests). This proves the rules are entity-level, not API-level |
| Evidence | `evidence/TC-T09-29.txt` |
| Actual result | Kernel tests call $entity->validate() through the base-class helper (the base has the validate() call; ViolationContractTest and ExternalIdUniquenessTest call it directly); no Request, Controller, JSON:API, HttpKernel or BrowserTestBase in the tests (the only grep hits are FixedTime::getRequestTime and a 'jsonapi' config assertion); no Functional directory. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-30: Rule coverage cross-check against the plan rule list (AC5 audit)

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Mode | static |
| Preconditions | Cases TC-T09-08 to 27 executed |
| Steps | 1. Build a table: every row of the plan KD-3 "Rule list" (22 rows) and the DN-4 conditional table (7 rows) against the test method that covers it, from the `PU-V` output. 2. Add the Kernel test class list: `ContentModelStructureTest`, `DecisionValidationTest`, `PositionValidationTest`, `DailyRunValidationTest`, `PriceSnapshotValidationTest`, `WatchlistItemValidationTest`, `LifecycleRulesTest`, `ExternalIdUniquenessTest`, `PermissionsMatrixTest` and Unit `PatternsTest`, `JsonDocumentValidatorTest`, `DecimalScaleValidatorTest` |
| Expected result | Every row has at least one named test; every named class exists and runs (not skipped, not marked incomplete: the output has no `S` or `I`); the table is stored in `EVD`. Any rule row without a test is a Fail with the rule named |
| Evidence | `evidence/TC-T09-30.txt` |
| Actual result | Every KD-3 rule row (19 rows in the plan) and every DN-4 row (7) maps to a named test; all 10 Kernel and 4 Unit classes exist and run with no S or I. Two input-type gaps found (DEF-012), outside the rule rows. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

---

## Group H: Unique `external_id` (AC3)

### TC-T09-31: Duplicate `external_id` in the same bundle rejected by `validate()`

| Field | Value |
|---|---|
| Linked criterion | AC3, AC5 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox 2>&1 \| tee EVD` |
| Expected result | For each of the five bundles: a second entity with the same `external_id` in the same bundle fails `validate()` with exactly one violation with code `meridian.unique_in_bundle`, at `field_external_id` on `decision`, `position`, `daily_run` and `price_snapshot`, and at `field_symbol` on `watchlist_item` (the `external_id` is derived from the symbol, so the symbol check reports the one violation and the `external_id` check is skipped; review finding 5, option (a)); the first save is accepted; the message does not include another record's data. Updating the same node (same external_id, other field changed, new revision) accepted (own id excluded). Unpublished duplicate still counted (`accessCheck(FALSE)`) |
| Evidence | `evidence/TC-T09-31-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`), `evidence/TC-T09-31-message-probe.txt` |
| Actual result | testDuplicateIsRejectedByValidate passes for all five bundles: exactly one violation with meridian.unique_in_bundle, at field_external_id on four bundles and at field_symbol on watchlist_item (amended 2026-11-05, review finding 5); the own node (new revision) is accepted; an unpublished duplicate counts. The message is generic ('Another record of this content type already has this field_external_id.') and holds no data of the other record (probe). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-32: Exact, case-sensitive comparison (no `LIKE` wildcards)

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` |
| Expected result | Entity A has a stored `external_id` that differs from B only by a `%` or `_` wildcard position (for example `wl-A_B` vs `wl-AXB` where the regex permits, otherwise set through a bare `save()` in the test fixture) and B is **not** reported duplicate; two ids differing only in letter case are treated as distinct by the validator (the format regexes make this a regex matter, so the test builds the case by bare save and checks the unique-in-bundle constraint alone, not the full entity validation). The query has `condition('type', bundle)` |
| Evidence | `evidence/TC-T09-32-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`), `evidence/TC-T09-32-static.txt` |
| Actual result | testComparisonIsExact passes: wl-AXB, wl-ABC and wl-AB are not reported duplicates of wl-A_B, wl-abc and wl-A%, the exact values are; static read: the query has condition(bundle) and an exact === comparison after the query (no LIKE). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-33: Same `external_id` across different bundles is allowed; same symbol across bundles allowed

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` 2. `PU-F WatchlistItemValidationTest --testdox` |
| Expected result | Because the D3 formats differ per bundle, a cross-bundle collision cannot occur with valid data. The test therefore builds the collision explicitly: two nodes of different bundles with an identical `external_id` string, saved with bare `save()`, **both succeed** (the unique key is `(bundle, external_id)`, not `external_id` alone) and `MeridianUniqueInBundle` does not flag either. A Watchlist Item `RELIANCE` is accepted while Decisions with symbol `RELIANCE` exist, and a second Watchlist Item `RELIANCE` is rejected (symbol unique in bundle, path `field_symbol`) |
| Evidence | `evidence/TC-T09-33-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testSameValueInAnotherBundleIsAllowed passes (two bundles with the same string, both saved, no unique_in_bundle); a Decision with the symbol RELIANCE does not collide with the Watchlist Item, and a second Watchlist Item RELIANCE is rejected at field_symbol. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-34: Database backstop: bare `save()` of a duplicate throws and leaves no node

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Mode | ddev run |
| Preconditions | Harness works; MariaDB-backed Kernel run (not SQLite) |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` 2. `ddev drush sql:query "SHOW INDEX FROM node__field_external_id WHERE Key_name='meridian_external_id_bundle'"` (if the key path was used) or `ddev drush sql:query "SHOW CREATE TABLE meridian_external_id"` (Fallback A) |
| Expected result | A duplicate entity is saved **without** calling `validate()`; `save()` throws `\Drupal\Core\Entity\EntityStorageException` (or its parent chain), the node count of that bundle is unchanged, no orphan row in `node_field_data`, `node__field_external_id`, or (Fallback A) `meridian_external_id`, and the transaction is rolled back. The unique key lists columns `bundle`, `field_external_id_value` in that order, `Non_unique = 0`, and is not on the revision table. Under Fallback B the case is recorded as "no backstop" and the owner item O-4 is raised, not passed |
| Evidence | `evidence/TC-T09-34.txt` |
| Actual result | testDatabaseKeyRejectsDuplicateSave passes: a bare save of a duplicate throws EntityStorageException and leaves no node, field or revision row; live SHOW INDEX: key meridian_external_id_bundle on (bundle, field_external_id_value), Non_unique 0, absent from node_revision__field_external_id. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-35: Backstop covers concurrent watchlist creates of one symbol

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` 2. Tester script (in `tests/` only, throwaway): two entities for the same symbol are both validated while neither is saved (both pass `validate()`), then both saved in sequence |
| Expected result | Both pass `validate()` (check-then-act race reproduced); the second `save()` throws `EntityStorageException` because of the derived `wl-{symbol}` key; exactly one node exists afterwards |
| Evidence | `evidence/TC-T09-35-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testConcurrentWatchlistCreatesAreStoppedByTheKey passes: both entities validate, the second save throws EntityStorageException, one node exists. The case's optional tester script is the same scenario and was not duplicated. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-36: Backstop exists on each install path and is removed on uninstall

| Field | Value |
|---|---|
| Linked criterion | AC3, AC4 |
| Mode | ddev run |
| Preconditions | Harness works; install path available |
| Steps | 1. `PU-F ExternalIdUniquenessTest --testdox` 2. After `ddev drupal-install --force` (TC-T09-48): `ddev drush sql:query "SHOW INDEX FROM node__field_external_id"` 3. After a cache rebuild: `ddev drush cr` then repeat step 2 4. `ddev drush updatedb --no-cache-clear` then repeat step 2 |
| Expected result | Key (or Fallback A table) present after config install (field-storage path), after module install with the table already existing (install path), after `drush cr`, after `drush updatedb` with "No pending updates", and after a field storage update. Key removed after module uninstall (`hook_uninstall`). Entity schema check (`ddev drush entity:updates` if present, or the status report) shows no "mismatched entity/field definitions" caused by the key |
| Evidence | `evidence/TC-T09-36.txt`, `evidence/TC-T09-36-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | Kernel testKeyLifecycle passes (field-storage path, install path with an existing table, cache rebuild, field storage update, ensure() idempotent, removed on uninstall). Live: the key is present after ddev drupal-install, after the sql:drop and site:install --existing-config of TC-T09-51, after drush cr and after updatedb (No pending updates); entity definition update summary is empty. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-37: DN-10 "cannot be kept" test and the recorded path

| Field | Value |
|---|---|
| Linked criterion | AC3, AC4, C5 |
| Mode | ddev run plus static |
| Preconditions | TC-T09-36 and TC-T09-48 to 50 run |
| Steps | 1. `ddev drush cim --yes`, `ddev drush config:status`, `ddev drush updatedb --no-cache-clear`, `ddev drush status-report` (or `ddev drush core:requirements --severity=2`) 2. `grep -n "Unverified items" -A30 docs/architecture/technical-design.md \| grep -in "unique"` 3. read the T09 review file for the path statement |
| Expected result | None of the commands fails or reports a change or an error caused by the key. The technical-design "Unverified items" row for the unique index is closed with the date, the chosen path (key / Fallback A / Fallback B) and the table collation recorded. If Fallback B was used the O-4 message to the owner is recorded and TC-T09-34 and 35 are marked as "no backstop", not Pass |
| Evidence | `evidence/TC-T09-37.txt` |
| Actual result | cim (no changes), config:status (no differences), updatedb (no pending updates) all clean; the only core:requirements error is 'Public files directory not fully protected' (DDEV environment, not the key). The technical-design 'Unverified items' row is closed on 2026-11-04 with the key path (DN-10 first choice, no fallback) and the collation utf8mb4_general_ci (confirmed live); the review records the path; no O-4 needed. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-38.txt` |
| Actual result | Exactly 7 permissions; view meridian raw llm output and administer meridian records have restrict access; no bypass-style grant in the module. Kernel testPermissionDefinitions asserts the same. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-39: Role config: six-role permission sets, exact, no extras

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | static plus ddev run |
| Preconditions | Config exported |
| Steps | 1. `grep -n "permissions:" -A12 apps/drupal/config/sync/user.role.{administrator,analyst,engine_ingest,dashboard_read,anonymous,authenticated}.yml` 2. `PU-F PermissionsMatrixTest --testdox 2>&1 \| tee EVD` |
| Expected result | `administrator`: `is_admin: true`. `analyst`: exactly `access content`, `view meridian records`, `view meridian inputs`, `view meridian watchlist`, `export meridian records`. `engine_ingest`: exactly `access content`, `ingest meridian records`, `view meridian watchlist`. `dashboard_read`: exactly `access content`, `view meridian records`, `view meridian watchlist`. `anonymous` and `authenticated`: **no** `access content` and no Meridian permission (any permissions list is empty or contains only non-Meridian core items that the doc names; the tester records the list). The test asserts the exact set per role (no extra permission), not just containment. 4 new role files, `weight` values distinct |
| Evidence | `evidence/TC-T09-39.txt`, `evidence/TC-T09-39-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | Role YAML: administrator is_admin true; analyst, engine_ingest, dashboard_read exactly the planned lists; anonymous and authenticated permissions empty (no access content, no Meridian permission); distinct weights 0 to 5. testRoleConfiguration asserts the exact set per role. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-40: Matrix cells: role by permission (9 permissions)

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | For each of the six roles and each of the 9 permissions (the 7 Meridian ones plus `access content` and `bypass node access`) the test asserts granted or not, 54 cells. `administrator` has all (via `is_admin`); `bypass node access` is held by `administrator` only. Count of asserted cells is at least 54 (the tester counts data-provider rows) |
| Evidence | `evidence/TC-T09-40-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testRoleByPermissionCells passes: 54 cells asserted (6 roles by 9 permissions; assertSame(54, $cells)); bypass node access held by administrator only. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-41: Matrix cells: role by bundle by operation

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | 6 roles x 5 bundles x 4 operations = 120 cells asserted through `$node->access($op, $account)`. Expected pattern: `view` allowed for `administrator`; for `analyst` and `dashboard_read` allowed on `decision`, `position`, `daily_run`, `price_snapshot` (permission `view meridian records`) and on `watchlist_item` (`view meridian watchlist`); `engine_ingest` allowed on `watchlist_item` only and **not** on the four records (it lacks `view meridian records`); `anonymous` and `authenticated` denied on all. `create`, `update`, `delete`: denied for every role except `administrator` (bypass). Published nodes in the view cells |
| Evidence | `evidence/TC-T09-41-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testRoleByBundleByOperationCells passes: 120 cells (assertSame(120, $cells)): view per the matrix (engine_ingest only on watchlist_item), create, update, delete only for administrator. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-42: Unpublished records are hidden; hooks never grant (neutral rule)

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | An unpublished record of each bundle is not viewable by `analyst`, `dashboard_read`, `engine_ingest`; it is viewable by `administrator` (bypass). The access hook returns Forbidden or Neutral, never Allowed (test asserts `isNeutral()`/`isForbidden()` on the hook result where it can read it). A role with an extra, unrelated `access content` only (no Meridian permission) does not see Meridian nodes |
| Evidence | `evidence/TC-T09-42-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testUnpublishedRecordsAndNeutralRule passes: an unpublished record of each bundle is hidden from analyst, dashboard_read and engine_ingest and visible to administrator; the hook results are never allowed (neutral or forbidden); a role with only access content sees no Meridian node. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-43: Field view access for restricted fields

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | Per role, `view` access on each restricted field as the plan KD-7 table says: `decision.raw_llm_output` needs `view meridian raw llm output` (only `administrator` has it; `analyst` denied); `decision.inputs_snapshot`, `daily_run.llm_cost_usd`, `price_snapshot.source`, `watchlist_item.notes` need `view meridian inputs` (`administrator`, `analyst` allowed; `dashboard_read`, `engine_ingest` denied); `source_version` and `payload_hash` on the four ingested bundles need `administer meridian records` (administrator only). Unrestricted fields (for example `decision.score`) viewable by `dashboard_read`. A `watchlist_item` has no `source_version`/`payload_hash` so there is no cell. Field `edit` is **not** restricted in T09 (tested as not forbidden by this module: documented non-goal) |
| Evidence | `evidence/TC-T09-43-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testRestrictedFieldCells passes: 13 restricted fields by 6 roles = 78 cells; raw_llm_output administrator only; inputs_snapshot, llm_cost_usd, source, notes administrator and analyst; source_version and payload_hash administrator only; unrestricted field_score viewable by dashboard_read; field edit is not restricted (neutral). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-44: Access results carry permission cache context

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Mode | ddev run |
| Preconditions | Harness works |
| Steps | 1. `PU-F PermissionsMatrixTest --testdox` |
| Expected result | Node access results (view/update/delete/create) and field access results from the module report cache context `user.permissions` (`cachePerPermissions()`) |
| Evidence | `evidence/TC-T09-44-kernel.txt` (extract of `evidence/TC-T09-54-kernel.txt`) |
| Actual result | testCacheContexts passes: view, update, delete, create and field view results carry the cache context user.permissions. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-45: Permissions matrix document and docs/test parity

| Field | Value |
|---|---|
| Linked criterion | AC6, C5 |
| Mode | static (docs suite) |
| Preconditions | `docs/specs/permissions.md` written |
| Steps | 1. `test -f docs/specs/permissions.md` 2. `grep -n "permissions.md" docs/specs/README.md docs/specs/data-model.md docs/architecture/technical-design.md` 3. Parse the role/permission table in `permissions.md` and compare with `user.role.*.yml` (docs suite `docs/tests/T09/run-checks.sh`, written in execute mode; the parser reads the table format promised by the plan "role, permission, value") |
| Expected result | The document exists, covers six roles (names exact), lists the nine permissions, the bundle/operation cells, the restricted-field cells, states the "neutral not allowed" rule, the listing limitation (no node grants; queries and Views not filtered; T11 and T12 handle it), the HTTP cells being non-T09 with a link to D6 naming T10, T11, T22, T30. Linked from `docs/specs/README.md`, `data-model.md` and D6. The parsed table equals the exported role YAML cell by cell. Mutation: change one cell in a scratch copy of the doc and the parity check fails |
| Evidence | `evidence/TC-T09-45-parity.txt`, `evidence/TC-T09-45-mutation.txt`, `evidence/TC-T09-45-links.txt` |
| Actual result | docs/specs/permissions.md exists (six roles, nine permissions, 120 bundle cells, 13 restricted-field rows, neutral rule, listing limitation, HTTP cells pointing to D6 and T10, T11, T22, T30); linked from the specs README, data-model and D6 (grep, evidence). The parser docs/tests/T09/parity_check.py reads 54 permission cells, 120 bundle cells and 13 field rows and finds them equal to the role YAML; MUT: one changed cell (analyst export meridian records) makes it fail (exit 1). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-46: Removing `access content` does not break login or install

| Field | Value |
|---|---|
| Linked criterion | AC6, AC4 |
| Mode | ddev run |
| Preconditions | Site installed |
| Steps | 1. `ddev drush uli` 2. `curl -s -o /dev/null -w "%{http_code}\n" https://meridian.ddev.site/user/login` 3. `curl -s -o /dev/null -w "%{http_code}\n" https://meridian.ddev.site/` 4. `curl -s -o /dev/null -w "%{http_code}\n" https://meridian.ddev.site/node/1` |
| Expected result | Install and `drush uli` succeed; `/user/login` returns 200; the front page and a node URL do not expose Meridian content to anonymous (403 or 404, not 200 with record data) |
| Evidence | `evidence/TC-T09-46.txt` |
| Actual result | drush uli works; /user/login 200; with a published record present anonymous gets 403 on /node/<nid> and on /node/<nid>/revisions, / returns 200 with no record data, /rss.xml 404. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-47: Administrator login in a browser (owner)

| Field | Value |
|---|---|
| Linked criterion | AC6, C7 |
| Mode | owner-run (Windows browser) |
| Preconditions | Site installed; owner has the one-time link |
| Steps | 1. Agent runs `ddev drush uli`; owner opens the link in the Windows browser. 2. Owner opens `/admin/structure/types` and `/admin/people/roles` and `/admin/people/permissions` 3. Owner screenshots each page in full |
| Expected result | Five content types listed (Decision, Position, Daily Run, Price Snapshot, Watchlist Item); roles page lists Administrator, Analyst, Engine ingest, Dashboard read plus Anonymous and Authenticated; the permissions page shows the Meridian group with the 7 permissions. A partial screenshot is insufficient: the case stays Blocked until full pages are sent. The tester cannot accept evidence on the owner's behalf |
| Evidence | none |
| Actual result | Owner-run (Windows browser, full-page screenshots of /admin/structure/types, /admin/people/roles, /admin/people/permissions). Not run by the tester; steps for the owner are in the report. |
| Status | Blocked |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-48.txt` |
| Actual result | ddev drupal-install --force exit 0 (config:status check inside it passed); config:status 'No differences'; the five node types and the four new roles exist; role:list shows the six roles. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-49: `cex` after install shows no diff

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Mode | ddev run |
| Preconditions | TC-T09-48 passed |
| Steps | 1. `git status --porcelain apps/drupal/config/sync > $WORK/before.txt` 2. `ddev drush cex --yes 2>&1 \| tee EVD` 3. `git status --porcelain apps/drupal/config/sync` 4. `git diff --stat apps/drupal/config/sync` |
| Expected result | `cex` reports no changes ("There are no changes to export" or an unchanged file set); step 3 output is identical to `before.txt` (empty on a clean tree); step 4 empty. In particular the `field_status` third-party setting and the role files are not rewritten |
| Evidence | `evidence/TC-T09-49.txt` |
| Actual result | drush cex: 'The active configuration is identical to the configuration in the export directory'; git status and git diff --stat of config/sync empty before and after. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-50: `cim` reports no changes and is idempotent

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Mode | ddev run |
| Preconditions | TC-T09-49 passed |
| Steps | 1. `ddev drush cim --yes 2>&1 \| tee EVD` 2. `ddev drush cim --yes` (second time) 3. `ddev drush config:status` 4. `ddev drush updatedb --no-cache-clear` |
| Expected result | Both `cim` runs print "There are no changes to import."; `config:status` "No differences"; `updatedb` "No pending updates"; the unique key (or Fallback A table) still present |
| Evidence | `evidence/TC-T09-50.txt` |
| Actual result | Both cim runs: 'There are no changes to import'; config:status no differences; updatedb 'No pending updates'; the unique key present. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-51: `cim` onto a clean site recreates everything

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Mode | ddev run (destructive) |
| Preconditions | TC-T09-50 passed; a DB dump taken first: `ddev pg dump` is Postgres only, so use `ddev export-db --file=$WORK/pre.sql.gz` |
| Steps | 1. `ddev drush sql:drop --yes` (empty database) 2. `ddev drush site:install --existing-config --yes 2>&1 \| tee EVD` (the same path `ddev drupal-install` uses) 3. `ddev drush config:status` 4. `ddev drush cex --destination=$WORK/cex-after --yes` (to a temp directory, not the repo) 5. `diff -r apps/drupal/config/sync $WORK/cex-after` 6. `ddev drush sql:query "SHOW INDEX FROM node__field_external_id"` 7. `ddev drush php:eval "print count(\Drupal\node\Entity\NodeType::loadMultiple());"` |
| Expected result | Install exits 0; no differences; the exported directory equals `config/sync` (only diff output allowed: none, besides `core.extension` ordering if identical); 5 node types; all roles; key or Fallback A table present; `drush uli` works. Nothing in the repository changes (`git status --porcelain` empty) |
| Evidence | `evidence/TC-T09-51.txt` |
| Actual result | Dump taken; sql:drop; site:install --existing-config exit 0; config:status no differences; cex to /tmp/cex-after identical to config/sync (diff -r shows only the non-config .htaccess guard file that drush keeps in the real sync directory); key present; 5 node types; six roles; drush uli works; git status of apps empty. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-52: Drift detection (negative control for AC4)

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Mode | ddev run |
| Preconditions | TC-T09-51 passed |
| Steps | 1. `ddev drush config:set field.field.node.decision.field_score description "x" --yes` (changes active config only) 2. `ddev drush config:status` 3. `ddev drush cim --yes` 4. `ddev drush config:status` |
| Expected result | Step 2 reports `field.field.node.decision.field_score` as "Only in DB"/different; `cim` restores it; step 4 "No differences". Proves `config:status` is a real check and `cim` re-applies the model. Also: delete a role (`ddev drush role:delete dashboard_read`) then `cim` recreates it (roles come from config). The repo tree stays clean |
| Evidence | `evidence/TC-T09-52.txt` |
| Actual result | config:set on field_score description: config:status 'Different'; cim restores; config:status clean. After role:delete dashboard_read, config:status lists user.role.dashboard_read and its two actions 'Only in sync dir'; cim recreates them; six roles again; git status clean. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-53.txt` |
| Actual result | phpunit.xml.dist: bootstrap web/core/tests/bootstrap.php, suites unit and kernel over web/modules/custom/*/tests/src/{Unit,Kernel}, no functional suite, source includes web/modules/custom and excludes tests, no DB URL and no sqlite (step 2 matches only the comment line that names the SIMPLETEST_DB variable). --list-suites: kernel (47 tests), unit (25 tests). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-54: Whole Kernel and Unit suite passes on MariaDB with no skips

| Field | Value |
|---|---|
| Linked criterion | AC5, C4 |
| Mode | ddev run |
| Preconditions | Site installed |
| Steps | 1. `ddev exec 'echo $SIMPLETEST_DB'` 2. `ddev exec mysql --version` 3. `PU-U 2>&1 \| tee EVD` 4. `PU-K 2>&1 \| tee -a EVD` |
| Expected result | `SIMPLETEST_DB` is a MariaDB (`mysql://`) URL (set by DDEV or exported by `quality.sh`); MariaDB 10.6; both suites exit 0; summary shows 0 failures, 0 errors, 0 skipped, 0 risky, 0 incomplete; deprecation count 0 (or the same as the baseline recorded); test counts recorded in the report |
| Evidence | `evidence/TC-T09-54.txt`, `evidence/TC-T09-54-kernel.txt` |
| Actual result | SIMPLETEST_DB is the mysql:// URL of the DDEV project database (MariaDB 10.6.21); Unit OK (25 tests, 217 assertions); Kernel OK (47 tests, 1937 assertions, 14 min 43 s with other work running); no skipped, incomplete, risky or deprecation output. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-55: Rejection tests fail when a rule is removed (suite sensitivity)

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Mode | ddev run, MUT |
| Preconditions | TC-T09-54 passed; scratch copy of the module in `$WORK` mounted or a scratch worktree |
| Steps | 1. Mutations, one at a time, each followed by `PU-K` on the scratch: (a) loosen `field_score` max to 101; (b) remove `MeridianUniqueInBundle` from `field_external_id`; (c) drop the `field_status` third-party subset for `daily_run`; (d) remove the `NotNull` on `vetoed`; (e) remove `MeridianImmutable` from `field_external_id`; (f) grant `analyst` the permission `view meridian raw llm output`; (g) make the DB key not be created |
| Expected result | Each mutation fails at least one named test; the failing test name is recorded. A mutation that leaves the suite green is a Fail (coverage gap) naming the rule. If a scratch copy cannot be built, the case is Blocked, not Pass |
| Evidence | `evidence/TC-T09-55.txt` |
| Actual result | All seven mutations detected, each by a named test: (a) score max 101 fails testScoreAndPrices; (b) UniqueInBundle removed fails testDuplicateIsRejectedByValidate, testUnpublishedDuplicateCounts, testComparisonIsExact; (c) daily_run status subset removed fails DailyRunValidationTest::testRequiredFieldsAndLists; (d) vetoed made optional (core required, since NotNull is not attached, review note 11) fails testBaselineAndRequiredFields; (e) MeridianImmutable removed fails testExternalIdIsImmutable; (f) analyst granted raw llm output fails testRoleConfiguration, testRoleByPermissionCells, testRestrictedFieldCells; (g) key not created fails testDatabaseKeyRejectsDuplicateSave, testConcurrentWatchlistCreatesAreStoppedByTheKey, testKeyLifecycle. Also short2 and the TC-07 mutations. Mutations ran in copies inside the DDEV container; no repository file was changed. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-56: Coverage report with pcov, the 70% gate and the first measured figure

| Field | Value |
|---|---|
| Linked criterion | C4, AC5 |
| Mode | ddev run |
| Preconditions | DDEV: Xdebug coverage is acceptable (pcov cannot be installed, review deviation 8); CI: pcov |
| Steps | 1. `ddev exec php -m \| grep -i pcov` (DDEV may print nothing; `ddev quality` then switches Xdebug on for coverage, see `scripts/README.md` difference 6) 2. `ddev quality 2>&1 \| tee EVD` 3. `ls quality/ apps/drupal/*coverage* 2>/dev/null`; read the Cobertura path used by `scripts/quality.sh` 4. `python3 scripts/coverage_gate.py` against the Drupal Cobertura file and `quality/coverage-thresholds.json` 5. `grep -n "Drupal custom" docs/standards/CODING_STANDARDS.md` |
| Expected result | DDEV: pcov or Xdebug coverage in use (Xdebug is accepted, review deviation 8; CI pcov is checked in TC-T09-59 and TC-T09-62); `component-drupal-tests` ran (a PASS line, not SKIP); the gate reports line coverage of `web/modules/custom/meridian_` at or above 70%, otherwise T04a D-1 decision recorded (no untracked excludes); `CODING_STANDARDS.md` states the first measured value (replaces "provisional until first measured in T09"). The percentage is recorded in the report. Coverage excludes `tests/` and no `@codeCoverageIgnore` or `<exclude>` is added to lift the figure (grep shows none that are untracked) |
| Evidence | `evidence/TC-T09-56.txt`, `evidence/TC-T09-77-coverage-clean-clone.txt` |
| Actual result | Re-judged on the existing evidence against the amended text. DDEV uses Xdebug coverage (no pcov, as accepted in review deviation 8; `scripts/README.md` difference 6). `component-drupal-tests` PASS in `ddev quality` (clean clone and main tree); the gate reports 94.1% line coverage of `web/modules/custom/meridian_` (465 of 494 lines; 72 tests, 2154 assertions, 0 failures; threshold 70%); `CODING_STANDARDS.md` states a first measured value (93.9%, now 94.1%); no `codeCoverageIgnore`, the only phpunit exclude is `tests/`. |
| Status | Pass |
| Date | 2026-11-05 (re-judged after the amendment) |
| Executed by | tester (execute mode) |

### TC-T09-57: `quality.sh` guard and expected-skips line removed; `ddev quality` green

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Mode | static plus ddev run |
| Preconditions | Implementation committed |
| Steps | 1. `grep -n "no custom PHP yet\|empty-tree\|T09" scripts/quality.sh` 2. `grep -n "component-drupal-tests" quality/expected-skips.txt` 3. `ddev quality 2>&1 \| tee EVD` 4. `scripts/quality.sh --group core` 5. `python3 -m pytest scripts/tests -q` (host) |
| Expected result | Steps 1 and 2 print nothing relevant (guard and line removed); `ddev quality` exit 0; `PASS component-drupal` and `PASS component-drupal-tests`; PHPStan level 6 ran on the custom module with no baseline and no unticketed ignore; phpcs Drupal and DrupalPractice clean; engine and web steps behave as before; no unexpected SKIP; pytest suites pass (including updated `test_quality_sh.py`). `git status --porcelain` empty afterwards |
| Evidence | `evidence/TC-T09-77-ddev-quality-clean-clone.txt`, `evidence/TC-T09-57.txt`, `evidence/TC-T09-75-ddev-quality.txt` (first run, failed on the tester's files) |
| Actual result | Clean clone of the committed head 83ed38f: ddev quality exit 0, summary PASS 13, FAIL 0, SKIP 6 (build/component/audit for engine and web: the expected skips); PASS component-drupal and component-drupal-tests; PHPStan level 6 with no baseline and phpcs clean inside component-drupal; tree clean afterwards. quality.sh holds no empty-tree guard text; expected-skips.txt has no component-drupal-tests line; scripts/tests (160) and hooks tests (30) pass; scripts/quality.sh --group core passes in the main tree. The first ddev quality in the main tree (with the tester's uncommitted helper scripts) failed docs-regression because two helper lines carried an unticketed noqa and an unticketed ignore text; the tester fixed its own files (not a product defect) and the clean-clone run is the record. pytest is not installed on the host: unittest discover was used. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-58: Static analysis negative controls on the new module

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Mode | ddev run (scratch) |
| Preconditions | TC-T09-57 passed |
| Steps | 1. In a scratch copy of the module add (a) a PHPStan type error (return string from `: int`) and (b) a PHPStan ignore comment without a ticket and (c) a phpcs violation (tabs). 2. Run `ddev exec -d /var/www/html/apps/drupal vendor/bin/phpstan analyse` and `vendor/bin/phpcs` against the scratch |
| Expected result | Each is reported; this closes the T05 note that the PHPStan type-error and unticketed-ignore parts of TC-T04a-49 "stay with T09". Repository files untouched |
| Evidence | `evidence/TC-T09-58.txt` |
| Actual result | PHPStan (level 6, no baseline) on a scratch class with a string returned from an int method reports return.type; a bare PHPStan ignore-next-line comment is reported ('Ignoring all errors on a line is not allowed'); phpcs (Drupal, DrupalPractice) on a scratch class indented with tabs reports errors (exit 2). The real tree stays clean (PHPStan OK, phpcs clean). Scratch files were under docs/tests/T09 and were deleted. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-59: CI `drupal` job definition: MariaDB service, pcov, SIMPLETEST_DB

| Field | Value |
|---|---|
| Linked criterion | C4, AC5 |
| Mode | static |
| Preconditions | `.github/workflows/ci.yml` updated |
| Steps | 1. `grep -n "mariadb\|pcov\|SIMPLETEST_DB\|coverage:" .github/workflows/ci.yml` 2. `grep -n "database" -A3 .ddev/config.yaml pantheon.yml apps/drupal/pantheon.yml 2>/dev/null` 3. `grep -n "pcov" .ddev/config.yaml` (no match is expected) |
| Expected result | The `drupal` job has `services: mariadb` with image `mariadb:10.6.<patch>` (an exact tag, not `latest`, not `10`), a health check, setup-php `coverage: pcov` (not `none`), and `SIMPLETEST_DB` pointing at the service (`mysql://...@127.0.0.1:3306/...`); no sqlite; `.ddev/config.yaml` has `database: type mariadb, version 10.6` and installs pcov via `webimage_extra_packages` or the documented form; `pantheon.yml` `database.version: 10.6`. All three agree on 10.6 |
| Evidence | `evidence/TC-T09-59.txt` |
| Actual result | Re-judged on the existing evidence against the amended text. `ci.yml` drupal job: `mariadb:10.6.22` service with a health check, `coverage: pcov`, `SIMPLETEST_DB` to 127.0.0.1:3306, no sqlite; `.ddev/config.yaml` database mariadb 10.6 with a throwaway `SIMPLETEST_DB`, no pcov (accepted); `pantheon.yml` 10.6; all agree. That pcov really loads in CI is proven only by the live run (TC-T09-62, Blocked). |
| Status | Pass |
| Date | 2026-11-05 (re-judged after the amendment) |
| Executed by | tester (execute mode) |

### TC-T09-60: `check_ci.py` rule 2 database parity, positive and negative

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Mode | host run |
| Preconditions | Updated `scripts/check_ci.py` and tests |
| Steps | 1. `python3 scripts/check_ci.py` 2. `python3 -m pytest scripts/tests/test_check_ci.py -q 2>&1 \| tee EVD` 3. In `$WORK` copy `ci.yml`, change the service image to `mariadb:10.11.5`, run `check_ci.py` against the copy (via the script's path argument or the tests' fixtures) 4. Repeat for `.ddev` version 10.11 and `pantheon.yml` 10.4 |
| Expected result | Step 1 exit 0; test file passes and contains cases for: all three equal (pass), CI differs (fail), DDEV differs (fail), Pantheon differs (fail), service missing (fail), image `latest` or unversioned (fail). Steps 3 and 4 exit non-zero and name the mismatching file. Rule 6 (no Functional tests tripwire) still green |
| Evidence | `evidence/TC-T09-60.txt`, `evidence/TC-T09-60-unittest.txt`, `evidence/TC-T09-60-mutation.txt` |
| Actual result | check_ci.py exit 0, rule 2 'toolchain parity' PASS, rule 6 PASS; test_check_ci.py 36 tests OK, with cases for all three equal, CI differs, DDEV differs, Pantheon differs, service missing or unversioned, type not mariadb; mutations: CI image 10.11.5, DDEV 10.11 and Pantheon 10.4 each give rule 2 FAIL (exit 1) naming the file. (pytest is not installed on the host; the file was run with unittest.) |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-61: Secret scan of the CI database URL

| Field | Value |
|---|---|
| Linked criterion | C6 |
| Mode | host run |
| Preconditions | Implementation committed |
| Steps | 1. `.tools/pre-commit run --all-files 2>&1 \| tee EVD` 2. `grep -rn "mysql://" .github apps/drupal/phpunit.xml.dist scripts docs/runbooks` |
| Expected result | All hooks pass including gitleaks (the throwaway CI-only DB value is not flagged, or the allowlisting is a documented, narrow rule, not `--no-verify`); step 2 shows only throwaway/placeholder values with no real credential; no `.env` committed; `.env.example` unchanged |
| Evidence | `evidence/TC-T09-61.txt` |
| Actual result | pre-commit run --all-files: all hooks Passed including the secret scan; the only mysql:// value is the throwaway CI service value in ci.yml (ci-only, commented); no .env tracked; .env.example unchanged against main. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-62: Live CI run of the `drupal` job on MariaDB

| Field | Value |
|---|---|
| Linked criterion | C4, AC5 |
| Mode | live CI / owner-run |
| Preconditions | Branch pushed and a PR open (owner action; no `gh` here) |
| Steps | 1. Owner sends the Actions run URL and the full logs of the `drupal` job (service container start, `php -m`, phpunit output, coverage step) and the artifact list 2. Tester reads the logs |
| Expected result | The run is green; log shows MariaDB 10.6.x started and healthy, pcov loaded, Unit and Kernel suites with the same test counts as the DDEV run (TC-T09-54), the coverage gate with the same line coverage within rounding, and the Cobertura XML in the uploaded artifacts. The two runs (DDEV and CI) are both recorded in the report (T08 condition 5). Without the owner's logs the case is Blocked |
| Evidence | none |
| Actual result | Needs the owner: open a PR from the pushed branch and send the Actions run URL, the full log of the drupal job and the artifact list. gh is not installed here. Steps in the report. |
| Status | Blocked |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

---

## Group L: Docs-regression and earlier suites

### TC-T09-63: Earlier T05 and T06 suites updated for the new state

| Field | Value |
|---|---|
| Linked criterion | C3, C4 |
| Mode | static plus host run |
| Preconditions | Tester editing is limited to `docs/tests/` |
| Steps | 1. Update `docs/tests/T05/run-checks.sh` lines 475 (phpunit.xml.dist absent), 476 (no custom module exists) and 621 (SKIP of `component-drupal-tests`), and `docs/tests/T06/run-checks.sh` line 1031 (same SKIP check), with a Change log row in `docs/tests/T05/test-cases.md` and `docs/tests/T06/test-cases.md` dated with the reason (T09 supersedes the "until T09" note, TC-T05-19 and the T05/T06 walk-through expectations). 2. `docs/tests/T05/run-checks.sh --regression` 3. `docs/tests/T06/run-checks.sh --regression` 4. `grep -n "phpunit.xml.dist is absent\|no custom module\|SKIP component-drupal-tests\|SKIP\\\\s+component-drupal-tests" docs/tests/T05/run-checks.sh docs/tests/T06/run-checks.sh` |
| Expected result | The old checks now assert the new state (phpunit.xml.dist present; `meridian_core` exists and every custom module is named in section 0 (so T10's `meridian_ingest` does not break it); `component-drupal-tests` shows PASS, not SKIP); step 4 finds none of the old expectations; both regression runs exit 0 with the same pass counts or higher (counts recorded, no check removed silently: each replaced check is listed with the reason in the Change log). The `cka`/`ckp` tag choice is recorded. A check is changed only to reflect the T09 state change in the plan, never to hide a failure |
| Evidence | `evidence/TC-T09-63-static.txt`, `evidence/TC-T09-64.txt` |
| Actual result | Static parts: the four lines (T05 475, 476, 621; T06 1031) now assert the T09 state, with Change log rows in the T05 and T06 test-cases; no old expectation remains (step 4 matches only the 'was:' annotations); 475/476 stay cka snapshots, 621 and 1031 are ckp live-quality invariants; bash -n and the pinned shellcheck pass. Line 476 as first written cut field 5 of the path (always 'custom') and was widened to 'meridian_core present and every module named in section 0' so T10's meridian_ingest does not break it. Regression runs: T05 (24 PASS, 0 FAIL, 176 checks) and T06 (19 PASS, 0 FAIL, 93 checks) pass in the docs-regression step of the clean-clone ddev quality. Run by hand each of them starts a nested ddev quality (DEF-014), so the by-hand steps 2 and 3 were replaced by that step, which runs the same --regression command. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-64: Docs suites of earlier tasks still pass after T09 text edits

| Field | Value |
|---|---|
| Linked criterion | C3, C5 |
| Mode | host run |
| Preconditions | TC-T09-63 done |
| Steps | 1. `for t in T04 T04a T05 T06 T07 T08; do ls docs/tests/$t/run-checks.sh 2>/dev/null; done` 2. Run each in `--regression` (or default) mode: `docs/tests/<T>/run-checks.sh --regression 2>&1 \| tee EVD` 3. `.tools/pre-commit run --all-files` |
| Expected result | Every earlier suite that exists returns exit 0 in regression mode; any new failure is a defect against T09 (not an excuse to edit the old suite) unless it is exactly one of the four known lines in TC-T09-63. T08 checks on `quality.sh`, `expected-skips.txt`, `check_ci.py` and `ci.yml` pass against the changed files |
| Evidence | `evidence/TC-T09-64.txt`, `evidence/TC-T09-75-ddev-quality.txt` |
| Actual result | All eight docs suites that exist (T00, T02, T03, T04, T04a, T05, T06, T07) exit 0 in --regression mode in the clean clone (T04a all executed checks passed, 15 blocked as before; T07 31 PASS and 2 blocked as designed). T08 has no run-checks.sh: its tooling is covered by scripts/tests (160 OK), check_ci.py (all rules PASS) and the ci-config and tooling-tests steps. pre-commit --all-files passes. The main-tree run with the tester's helper scripts failed three suites through the nested pre-commit and exceptions checks (cause: the tester's own files, fixed); it is kept as the first run. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-65: No Functional tests, no broker, no external host

| Field | Value |
|---|---|
| Linked criterion | C4, C6 |
| Mode | static |
| Preconditions | Implementation committed |
| Steps | 1. `find apps/drupal/web/modules/custom -type d -name Functional` 2. `python3 scripts/check_ci.py` (rule 6) 3. `scripts/check-names.sh` 4. `grep -rniE "zerodha\|kite\|upstox\|angel\|dhan\|fyers\|broker\|place_?order" apps/drupal/web/modules/custom apps/drupal/config/sync apps/drupal/scripts docs/specs/permissions.md` 5. `grep -rnE "https?://" apps/drupal/web/modules/custom apps/drupal/scripts` |
| Expected result | Step 1 prints nothing; check_ci rule 6 and names check exit 0; step 4 prints nothing; step 5 prints only the schema/documentation namespace URIs that Drupal itself uses (if any), recorded; no order-placement code, no SDK, no broker domain |
| Evidence | `evidence/TC-T09-65.txt` |
| Actual result | No Functional directory; check_ci.py all rules PASS (rule 6 included); check-names OK; the broker-word grep finds one hit, the README sentence 'Simulation only: nothing here touches a broker' (negation, not code); no URL in module or script code. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-66.txt` |
| Actual result | Script present with strict_types; targets decision (plus one untimed daily_run); 500 items, 5 runs; create and update passes in one transaction each; validate() on every entity, abort on a violation; Xdebug-loaded check; refuses to run if decision or daily_run nodes exist; prints PHP, MariaDB, pcov, host, per-run timings, p95 as the slowest of 5; no write to config/sync (only a comment), no network. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-67: MG-1 measurement run, p95 within NFR-04

| Field | Value |
|---|---|
| Linked criterion | C3 |
| Mode | ddev run (throwaway install) |
| Preconditions | Throwaway DB state (`ddev drupal-install --force` afterwards restores the site); Xdebug off (`ddev xdebug status` reports disabled) |
| Steps | 1. `ddev xdebug status` 2. `ddev drush php:script apps/drupal/scripts/perf/mg1_ingest_timing.php 2>&1 \| tee EVD` 3. `git status --porcelain` 4. `ddev drupal-install --force` (restore) |
| Expected result | Output shows 5 runs with create and update times, 0 violations, the environment facts, p95 labelled as the slowest run; the combined create + update p95 is 15 s or less (NFR-04). If above 15 s the case is Fail for NFR-04 only in the sense that it is reported, and the plan says the technical-architect raises it at T10 planning before T10 coding: the report records Pass-with-finding or Fail as the criteria state; the tester does not change the threshold. Step 3 shows no tracked file changed; the site is intact after step 4 |
| Evidence | `evidence/TC-T09-67.txt` |
| Actual result | Pass with finding. Xdebug off; 5 runs, 0 violations; create 22.3 to 23.3 s, update 40.8 to 46.8 s; p95 (slowest of 5) 70.10 s, far above the 15 s warning level of DN-9 (the developer's run on 2026-11-04 gave 50.18 s). DN-9 makes 15 s a trigger to raise at T10 planning, not a T09 gate. No tracked file changed; the site was restored with ddev drupal-install --force. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-68: MG-1 result recorded in `technical-design.md`

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Mode | static |
| Preconditions | TC-T09-67 run |
| Steps | 1. `grep -n "NFR-04\|NFR-05\|MG-1" docs/architecture/technical-design.md` 2. Compare the recorded numbers with `evidence/TC-T09-67.txt` |
| Expected result | The NFR-04 DDEV row says T09 runs the entity-layer part (500 Decisions of about 8 KB, create and update, 5 runs) and T10 confirms on the endpoint; the NFR-05 row says measured in T11 with 5,000 seeded nodes (authority moved to T11 by `decision-measurement-scope.md`), T30 confirms; the MG-1 result with date and raw output sits below the table; numbers equal the evidence file |
| Evidence | `evidence/TC-T09-68.txt`, `evidence/TC-T09-67.txt` |
| Actual result | Pass with finding. technical-design.md: NFR-04 DDEV row says T09 runs the entity-layer part (500 Decisions of about 8 KB, create and update, 5 runs) and T10 confirms; NFR-05 says measured in T11 with 5,000 seeded nodes, T30 confirms; the MG-1 section holds the date, environment and raw output, and its numbers equal its own raw output (p95 50.18 s). Finding: the tester's independent re-run (TC-T09-67) gave 70.10 s (create 23.3 s, update 46.8 s); both are far above 15 s, but the variance (40%) means the T10 baseline needs controlled conditions. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-69.txt` |
| Actual result | data-model.md carries the dated revision note (2026-11-04) citing the decision files, the DN-11 Uniqueness paragraph, the shared field_status note, the ck_* Postgres notes, and the 'equals ... built from the record's own fields' statements for decision, position, price_snapshot and the daily_run (run-{trade_date}); the watchlist wl-{symbol} derivation is in the Uniqueness text. The config matches (TC-T09-03). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-70: Technical-design, README and runbook updates

| Field | Value |
|---|---|
| Linked criterion | C5, C7 |
| Mode | static |
| Preconditions | Step 11 done |
| Steps | 1. `grep -n "view meridian inputs\|meridian_external_id\|MeridianUniqueInBundle" docs/architecture/technical-design.md` 2. `grep -n "SIMPLETEST_DB\|--testsuite kernel" apps/drupal/README.md docs/runbooks/local-setup.md` 3. `grep -n "mariadb\|pcov\|parity" .github/README.md scripts/README.md` 4. `grep -n "T09" docs/PROGRESS.md docs/TRACEABILITY.md` 5. `grep -n "R-06\|R-07\|FR-16" docs/TRACEABILITY.md` |
| Expected result | D1 bullets updated (DN-11 text, field-visibility sentence with `view meridian inputs`); READMEs and runbook explain how to run Drupal tests and what `SIMPLETEST_DB` is; `.github/README.md` and `scripts/README.md` describe the DB service, pcov and the parity rule; `PROGRESS.md` shows T09 status; `TRACEABILITY.md` rows R-06, R-07 and FR-16 point to T09 test cases and evidence. Markdown passes markdownlint (pre-commit) |
| Evidence | `evidence/TC-T09-70.txt` |
| Actual result | technical-design D1 updated (view meridian inputs sentence, MeridianUniqueInBundle, unique key row closed, revision note 6); apps/drupal/README.md and local-setup.md explain the kernel test command and SIMPLETEST_DB; .github/README.md and scripts/README.md describe the MariaDB service, pcov, the DDEV Xdebug difference and the parity rule; PROGRESS.md shows T09 In test; TRACEABILITY.md rows R-06, R-07, FR-16 list T09 and TC-T09-* as Planned. The evidence links in TRACEABILITY.md are a /close-task item (review condition 4). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-71: AC6 wording and SA-1 hand-offs (deferred to close)

| Field | Value |
|---|---|
| Linked criterion | AC6, C5 |
| Mode | deferred to `/close-task` (owner and solution-architect items) |
| Preconditions | Task being closed |
| Steps | 1. `grep -n "Permissions matrix" docs/TASKS.md` 2. `grep -n "T11 measurement" docs/architecture/solution-architecture.md` |
| Expected result | `docs/TASKS.md` T09 AC6 carries the reworded text (six roles) as given in the criteria, so O-3 is resolved and the report needs no "reading" note. SA-1: the NFR-05 row says "provisional until the T11 measurement" and the Amendments table has a dated row. If SA-1 is not done at close the case is Blocked (not a T09 code failure) and listed in the report as an open hand-off |
| Evidence | `evidence/TC-T09-71.txt` |
| Actual result | AC6 part: docs/TASKS.md T09 AC6 carries the six-role wording (done). SA-1 part: solution-architecture.md NFR-05 still says 'provisional until the T09 measurement' (not the T11 measurement) and the Amendments table has no 2026-11-04 row, so SA-1 is an open hand-off, not a T09 code failure. |
| Status | Blocked |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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
| Evidence | `evidence/TC-T09-72.txt` |
| Actual result | Plan commit 51e4404 (2026-11-04 12:06, Approved) and the four decision files precede the first meridian_core commit b3b71cc (13:21). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-73: C2 code reviewed and findings resolved

| Field | Value |
|---|---|
| Linked criterion | C2 |
| Mode | static |
| Preconditions | `/review-task T09` done |
| Steps | 1. `ls docs/tasks/T09/review.md` 2. `grep -n "Verdict\|Open\|Blocker\|Major" docs/tasks/T09/review.md` |
| Expected result | The review exists, verdict is approved (or approved with conditions that are closed), no open blocker or major finding, and the KD-4 path (key, A or B) and the SyncConfigTrait outcome are recorded |
| Evidence | `evidence/TC-T09-73.txt` |
| Actual result | review.md exists; re-review verdict Approved with conditions; findings 1 to 5, 9 and 10 fixed and verified, no Blocker or Major open; KD-4 path (key, no fallback) and the SyncConfigTrait outcome recorded. Open conditions are for close (C4 live CI and clean quality, finding 6, TRACEABILITY, MG-1 in the T10 plan) and are listed in the report; findings 7 and 8 were closed by the tester on 2026-11-05. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-74: C3 every criterion maps to an executed case with evidence

| Field | Value |
|---|---|
| Linked criterion | C3 |
| Mode | static |
| Preconditions | Execute mode complete |
| Steps | 1. For each case ID in this file `ls docs/tests/T09/evidence/TC-T09-nn*.txt` 2. Check `test-report.md` lists a status for each case |
| Expected result | Every case that is Pass has a non-empty evidence file; each AC1 to AC6 and C1 to C7 has at least one Pass (or an explicit Blocked/deferred reason in the report); no Fail or Blocked case is signed off ("Not signed off" with the reason otherwise) |
| Evidence | `evidence/TC-T09-74.txt` |
| Actual result | Checked by script on the final tree: every case with status Pass has at least one non-empty file under evidence/ (see the check in the report); Fail cases are 12, 17, 56, 59 (DEF-012, DEF-013); Blocked cases are 47, 62, 71, 75; the report is Not signed off. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-75: C4 full quality suite, pre-commit, and CI green

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Mode | ddev run plus live CI |
| Preconditions | Tree clean |
| Steps | 1. `ddev quality 2>&1 \| tee EVD` 2. `.tools/pre-commit run --all-files 2>&1 \| tee -a EVD` 3. `scripts/check-names.sh` 4. CI run: see TC-T09-62 |
| Expected result | All three exit 0; no new lint, type or security warning compared with the T08 baseline (the counts of warnings are recorded); CI green by TC-T09-62; no a phpcs ignore comment, a PHPStan ignore comment or a baseline added without a ticket comment (grep shows none, or each carries a ticket) |
| Evidence | `evidence/TC-T09-77-ddev-quality-clean-clone.txt`, `evidence/TC-T09-61.txt` |
| Actual result | The local part passes: ddev quality exit 0 on the committed head (clean clone, PASS 13 FAIL 0 SKIP 6), pre-commit --all-files exit 0 (all hooks Passed), check-names OK; PHPStan 0 errors, phpcs 0 errors, composer audit clean (audit-drupal PASS), no suppression without a ticket (exceptions PASS). Blocked on the CI part: the live CI run (TC-T09-62) needs the owner. |
| Status | Blocked |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-76: C6 secrets and `.env.example`

| Field | Value |
|---|---|
| Linked criterion | C6 |
| Mode | static |
| Preconditions | Implementation committed |
| Steps | 1. `git diff origin/main --stat -- .env.example` 2. `git ls-files \| grep -E '(^\|/)\.env$'` 3. `grep -rn "MERIDIAN_" apps/drupal/web/modules/custom apps/drupal/scripts` 4. `.tools/pre-commit run gitleaks --all-files` |
| Expected result | `.env.example` unchanged (plan: no new `MERIDIAN_` variable; `SIMPLETEST_DB` is a test-runner variable documented in `apps/drupal/README.md`); no `.env` tracked; any `MERIDIAN_` variable found in step 3 is listed in `.env.example`; gitleaks passes |
| Evidence | `evidence/TC-T09-76.txt` |
| Actual result | .env.example unchanged against main and origin/main; no .env tracked; no MERIDIAN_ variable in the module or scripts; gitleaks passes. |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

### TC-T09-77: C7 clean checkout works with documented commands

| Field | Value |
|---|---|
| Linked criterion | C7 |
| Mode | ddev run (clean clone) plus owner-run for the Windows side |
| Preconditions | A fresh clone of the branch on the WSL2 Linux filesystem (not `/mnt/c`), `ddev` installed |
| Steps | 1. `git clone <repo> $WORK/clean && cd $WORK/clean && git checkout task/T09-content-model` 2. `ddev start` 3. `ddev drupal-install` 4. `ddev quality` 5. `ddev exec -d /var/www/html/apps/drupal vendor/bin/phpunit --testsuite kernel` 6. Only commands from `apps/drupal/README.md` and `docs/runbooks/local-setup.md` are used; any other command is a docs defect |
| Expected result | All steps exit 0 using only the documented commands; the Drupal tests run and pass from a clean checkout. The clean clone uses a differently named DDEV project directory, so the tester records the project-name collision handling from the runbook. If a second DDEV project cannot be started the case is Blocked and the owner is asked to run it. Owner-run: `https://meridian.ddev.site` opens in the Windows browser (login from `ddev drush uli`) |
| Evidence | `evidence/TC-T09-77.txt`, `evidence/TC-T09-77-kernel-clean-clone-run2.txt`, `evidence/TC-T09-77-kernel-clean-clone-attempt1.txt`, `evidence/TC-T09-77-ddev-quality-clean-clone.txt` |
| Actual result | Fresh clone of task/T09-content-model (83ed38f) on the Linux filesystem; ddev delete -Oy meridian (runbook step 2) for the other checkout, ddev start, ddev drupal-install, drush uli, ddev meridian-status (five services healthy), scripts/bootstrap-dev.sh, the documented kernel command (OK, 47 tests, 1937 assertions, 9 min 57 s) and ddev quality (PASS 13 FAIL 0 SKIP 6, 1 h 31 min) all exit 0, using only documented commands. The first kernel attempt failed because ddev quality had switched Xdebug on at that moment (30 step-debug timeouts); the re-run after quality finished passed. Owner-run Windows browser check (`https://meridian.ddev.site` opens, login from ddev drush uli) is still open (see the owner steps). |
| Status | Pass |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |

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

## Change log

| Date | Change | Reason |
|---|---|---|
| 2026-11-04 | Initial design | n/a |
| 2026-11-05 | TC-T09-13: a malformed date gives two core violations (`field_trade_date.0`, `field_trade_date.0.value`), both with code `''`, instead of one | Review F7 and deviation D4: both come from core datetime rules; T10 must handle two entries at one path |
| 2026-11-05 | TC-T09-28: path wording changed from "field machine name in every case" to raw path forms plus the helper normalisation; raw paths checked in `ViolationContractTest` and the README section "Violation contract (T10)" | Review F7 and finding 2: core rules report at `field_x.0.value` / `.0.target_id`; `violationsOf()` shortens them |
| 2026-11-05 | TC-T09-31: a duplicate Watchlist symbol gives exactly one violation at `field_symbol` (code `meridian.unique_in_bundle`), not at `field_external_id` | Review F7 and finding 5 option (a), fixed in `d74d07c` |
| 2026-11-05 | TC-T09-63: expected result says "`meridian_core` exists and every custom module is named in section 0" instead of "is the only custom module" | Review F8: the check must survive T10 (`meridian_ingest`) |
| 2026-11-05 | TC-T09-56 and TC-T09-59: DDEV may use Xdebug coverage; pcov is required in CI only (checked in TC-T09-59 statically and TC-T09-62 live). Both re-judged on the existing evidence: Pass | Review deviation 8 (Sury key expired, no pcov in DDEV, plan fallback), treated as the Won't fix decision for DEF-013 |
