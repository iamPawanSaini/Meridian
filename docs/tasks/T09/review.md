# T09: Content model as configuration, Review

| Field | Value |
|---|---|
| Task | T09 |
| Reviewer | technical-architect |
| Date | 2026-11-04 |
| Commit range | `main..task/T09-content-model` (`51e4404..7abe5fc`; implementation `b3b71cc` to `e993414`) |
| Plan | `docs/tasks/T09/plan.md` (decisions `docs/tasks/T09/decision-*.md`) |
| Test cases | `docs/tests/T09/test-cases.md` (TC-T09-01 to TC-T09-77) |

## Checks run by the reviewer (read-only, 2026-11-04)

| Check | Result |
|---|---|
| `ddev exec -d /var/www/html/apps/drupal vendor/bin/phpunit --testsuite unit` | OK, 25 tests, 217 assertions |
| `ddev exec -d /var/www/html/apps/drupal vendor/bin/phpunit --testsuite kernel` | OK, 46 tests, 1,920 assertions, 10 min 36 s on MariaDB (DDEV) |
| `vendor/bin/phpstan analyse` (level 6, no baseline) | No errors |
| `vendor/bin/phpcs` (Drupal, DrupalPractice) | 67 files, no errors |
| `scripts/check-names.sh` | OK |
| `.tools/pre-commit run --all-files` | All hooks passed (gitleaks, suppressions, actionlint, Spectral and the rest); tree still clean |
| `scripts/check_ci.py` | All rules PASS, including the new rule 2 database parity |
| `scripts/exceptions_report.py` | Passes, but counts **0** `phpcs:disable` (see finding 1) |
| `docker manifest inspect mariadb:10.6.22` | The tag exists on Docker Hub (checked 2026-11-04) |
| Docs regression suites T04a, T05, T06 (`--regression`) | One check fails in each suite, and it is the same check every time: T04a's optional "shellcheck on tracked shell scripts" (`docs/tests/T04a/run-checks.sh:772`). It uses the host `/usr/bin/shellcheck` 0.8.0, which reports SC2015/SC2120 in lines T09 does not change (`docs/tests/T04a/run-checks.sh:806, 879`, `docs/tests/T06/run-checks.sh:525`). The pinned pre-commit shellcheck passes. This is the reviewer's host tooling, not a T09 regression. The coverage-row check passes |

## Judgement of the deviations the developer reported

| # | Deviation | Judgement |
|---|---|---|
| D1 | `MeridianPattern` and `MeridianMaxLength` instead of core `Regex` and `Length` | **Accepted.** Stable `meridian.*` codes, the `/D` modifier in `Patterns::matches()` so a trailing newline never passes (a `$` in core `Regex` lets `"X\n"` through), and control of the per-delta path. Patterns stay in one class (KD-3 intent kept). Recorded here as a departure from the KD-3 table |
| D2 | A pattern check skips a value that is too long | **Accepted.** It follows the KD-3 "one violation per rejection case" rule. It relies on `max_length` being set on every string storage with a pattern; that holds (for example `field_rule_hits` 32 equals the longest `RULE_ID` match) |
| D3 | Path shortened to `field_x`; `MeridianNoDuplicateValues` reports at the list; a bad reference has code `''` | **Accepted in behaviour, not in documentation.** Only the Meridian validators report at `field_x`. Core rules still report at `field_x.0.value` or `field_x.0.target_id`, and the test helper strips that suffix, so the module README is wrong for core rules. See finding 2 |
| D4 | A malformed date gives 2 core violations, TC-T09-13 expects 1 | **Accepted.** Both come from core datetime rules; no Meridian rule adds a third. The test case must change (finding 7) and T10 must handle 2 entries at one path |
| D5 | External-ID mismatch skipped when the immutable check fires | **Accepted.** One change gives one violation; a changed natural-key field with the old ID is still reported as `meridian.external_id_mismatch`, as KD-3 requires |
| D6 | Future `trade_date` allowed on `price_snapshot` and `daily_run` (Q-2) | **Accepted.** The plan rule list has the not-after-today rule only on `decision`. Nothing in the data model asks for it on the other two bundles |
| D7 | Decimal scale, high/low order, short stop and target, date patterns | **Accepted.** "Short" is the short-term mode (`solution-architecture.md`, glossary "Short mode"), and positions are long-only, so stop < entry < target is right for both modes. The Drupal date part of the external-ID patterns is stricter than `openapi.yaml` (month 01 to 12, day 01 to 31). A value the contract allows can therefore get a `meridian.pattern` 422 from Drupal. That is safe, and T14 should use the same strict form for Postgres parity (Note 5) |
| D8 | No pcov in DDEV (Sury key expired), Xdebug coverage in `quality.sh`, pcov in CI | **Accepted** as the plan's own fallback (Risks row "pcov not installable"), documented in `scripts/README.md` accepted difference 6. The CI pcov path is unproven until the live run (Note 7). Side effect: see finding 9 |
| D9 | `phpcs:disable` of the long-array sniff in 10 test files | **Not accepted as is.** See finding 1 |
| D10 | `coverage_gate.py` prepends the Cobertura `<source>` path | **Accepted.** Tests added in `scripts/tests/test_coverage_gate.py`. With more than one `<source>` it falls back to the old behaviour |
| D11 | `SyncConfigTrait` overridable by a property or `MERIDIAN_SYNC_DIR` | **Property accepted; environment variable not.** See finding 3 |
| D12 | Config generated through the Entity API by a throwaway script, then exported with `cex` | **Accepted.** UUIDs are Drupal-generated and the YAML is the `cex` export, so the KD-1 intent ("never hand-written with invented UUIDs") is met. The generator is not committed (`.tools/` is ignored), which is fine because `config/sync` is the source of truth |

## Unique key, collation and MG-1

- **Unique key (KD-4, DN-10 first choice).** `meridian_external_id_bundle` on
  `node__field_external_id (bundle, field_external_id_value)` is the planned placement, not the
  revision table. The `field_storage_config_update` hook is needed and correct: core recreates
  the dedicated table of a storage without data on update. The hook runs after the schema
  change because the listener runs in `preSave()`. `ExternalIdUniquenessTest` covers insert,
  install, storage update, uninstall and a bare `save()`. Collation `utf8mb4_general_ci`
  follows from `case_sensitive: false` on the storage. It is case-insensitive,
  accent-insensitive and PAD SPACE, but every external-ID pattern fixes letter case and allows
  no spaces or accents, so no false duplicate is possible. Path recorded in
  `technical-design.md` (unverified item closed) and in the module README. No Fallback A or B,
  so O-4 does not apply. Two latent limits go in Note 3.
- **MG-1.** The p95 of 50.18 s is **acceptable for closing T09**. DN-9 makes the 15 s level a
  trigger to raise the issue at T10 planning, not a T09 gate. T09 has run and recorded the
  measurement with raw output and the environment, which is what DN-9 asks. The number is
  serious, though. The update pass on its own (p95 33.29 s) is already above the **whole**
  30 s NFR-04 budget for one request. The create pass (21.00 s) uses 70% of it, and both
  figures leave out HTTP, OAuth, hashing, the `external_id` lookup and the lock. **T10 must do
  the following before any T10 coding:**
  1. Profile one 500-item update and split the time between `validate()` and `save()`. Count
     the entity loads per item: `loadUnchanged()` in `MeridianImmutable`,
     `MeridianNonDecreasing` and `MeridianExternalIdMatches`, the query plus `loadMultiple()` in
     `MeridianUniqueInBundle`, `ValidReference`, and the core `loadUnchanged()` in `save()`.
  2. Plan batch-level remedies with expected gains: one stored-entity load per item shared by
     the validators, one uniqueness query per batch, and a check of whether the revision write
     of two large `string_long` fields is the main cost.
  3. Bring a decision on NFR-04 to the solution-architect and owner under D-2, using the
     measured numbers. Options include a lower items-per-request limit, a changed budget, or
     both, and the consequences for the Pantheon 100-item batch, the 59 s edge timeout and the
     130 s lock.
  4. Re-run `mg1_ingest_timing.php` after the changes as the T10 baseline, and confirm on the
     endpoint (T10 AC3).

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `apps/drupal/web/modules/custom/meridian_core/tests/src/Kernel/*.php:5` (9 files), `tests/src/Unit/PatternsTest.php:5` | Ten file-wide `// phpcs:disable Drupal.Arrays.Array.LongLineDeclaration -- T09: ...` lines. `scripts/exceptions_report.py` only matches `phpcs:ignore` (line 38), so it does not see, count or ticket-check these lines. A `phpcs:disable` with no ticket would also pass the gate. The form is not in the per-tool table of CODING_STANDARDS "Exception policy", and a file-wide disable conflicts with "Suppress one rule by its code, never a whole file". REVIEW_CHECKLIST section 4, "Exceptions": the report counts do not match the change | Preferred: remove the 10 lines and add one `<rule ref="Drupal.Arrays.Array.LongLineDeclaration"><exclude-pattern>*/tests/src/*</exclude-pattern></rule>` to `apps/drupal/phpcs.xml.dist`, with a `<!-- T09: one test case per line in test tables -->` comment on the same line as the `<exclude-pattern>` (the scanner's `XML_EXCLUDE` rule reads `phpcs.xml.dist` and needs the ticket on that line). That is one config exclude in a scanned config file. Show that `exceptions_report.py` counts it, that phpcs still passes, and that a long array in `src/` still fails. Alternative: teach the scanner `phpcs:disable`/`phpcs:enable` with tests and add the form to the standards table (a standards change, which needs a recorded decision) | Fixed (`0539f94`, verified in re-review) |
| 2 | Major | `apps/drupal/web/modules/custom/meridian_core/README.md:23-25`; `tests/src/Kernel/MeridianKernelTestBase.php:172-184` | The T10 violation contract (plan "Interfaces touched": "path = field name") is documented wrongly. The README says every violation uses the field machine name as its path, but core rules (required, AllowedValues, Range, Length, Count, datetime, ValidReference) report at `field_x.0.value` or `field_x.0.target_id`. `violationsOf()` removes that suffix, so no test sees the raw path, and a path regression in a Meridian validator would also go unseen. ValidReference and the datetime rules have code `''`, so T10 cannot map them by code. TC-T09-28 expects "Property path is the field machine name in every case", which is true only after normalisation | (a) Add a "Violation contract (T10)" section to the module README listing the raw path forms (`field_x`, `field_x.N`, `field_x.0.value`, `field_x.0.target_id`), the normalisation T10 must apply (the regex in `violationsOf()`), the core codes used (Symfony `NotNull`, `Choice`, `Range`, `Length`, `Count` constants) and the empty-code cases with how to recognise them (constraint class through `getConstraint()`). (b) Add one Kernel test that asserts the **raw** `getPropertyPath()` for one Meridian single-value, one Meridian multi-value, one core value and one reference violation. (c) Point the plan's interface row or `technical-design.md` D5 at the README section. The tester amends the TC-T09-28 wording | Fixed (`309c5a6`, verified in re-review); TC-T09-28 wording stays with finding 7 |
| 3 | Minor | `apps/drupal/web/modules/custom/meridian_core/tests/src/Traits/SyncConfigTrait.php:38` | New environment variable `MERIDIAN_SYNC_DIR` is not in `.env.example` (CLAUDE.md "Secrets"; C6). The plan's C6 reason ("T09 adds no `MERIDIAN_` variable") is now false | Either drop the `getenv()` branch and keep the `$syncConfigDirectory` property (enough for mutation checks in a subclass), or add a commented, test-only `MERIDIAN_SYNC_DIR=` entry to `.env.example`. Update the C6 reason in the test report either way | Fixed (`309c5a6`: environment branch dropped) |
| 4 | Minor | `apps/drupal/scripts/perf/mg1_ingest_timing.php:1, 61, 118-127, 163` | (a) No `declare(strict_types=1);` (CODING_STANDARDS "PHP and Drupal"), and the file is outside the phpcs and PHPStan paths. (b) The script deletes **every** `decision` node in the site and creates `run-2026-11-03`. The header says "run it on a throwaway install", but nothing enforces that. Run by mistake on a site with real data (later DDEV data, or `terminus drush` on Pantheon dev), it destroys records | Add `strict_types`. Before any write, refuse to run (exit 1, one line on stderr) if any `decision` or `daily_run` node exists. Optionally add `scripts/` to `phpcs.xml.dist` and `phpstan.neon.dist` | Fixed (`a0a70b4`; the optional lint scope was not added, which is accepted) |
| 5 | Minor | `MeridianUniqueInBundleValidator.php:55-73`; `tests/src/Kernel/ExternalIdUniquenessTest.php:47` | A duplicate Watchlist symbol gives **two** violations (`field_external_id` and `field_symbol`, both `meridian.unique_in_bundle`). KD-3 says one violation per rejection case, TC-T09-31 says "exactly one violation at `field_external_id`" for each of the five bundles, and the test asserts two | Pick one and record it. (a) Code: on `watchlist_item`, skip the `field_external_id` uniqueness check when the ID equals `wl-{symbol}` and the symbol check already fires (the database key still backs it). Then TC-T09-31 holds. (b) Keep two violations and have the tester amend TC-T09-31 and TC-T09-25 with the reason. (a) is preferred because T12's form would otherwise show two errors for one mistake | Fixed (`d74d07c`, option (a); the one violation is at `field_symbol`) |
| 6 | Minor | `docs/standards/CODING_STANDARDS.md` "Naming (section 0)" | Two approved names do not match the naming rules. The D6/KD-6 permissions (`view meridian records`, and so on) do not "start with `meridian_`". The DN-11 key `meridian_external_id_bundle` does not use the `uq_` prefix. The plan and the decisions fixed both names, and T10 to T12 depend on them, so no rename is wanted | The technical-architect amends the naming section at `/close-task`: Drupal permissions use the D6 names, which contain `meridian`; the `uq_`/`ix_` prefixes apply to Postgres (data-model D2); the Drupal-side key keeps its DN-11 name. No code change | Open (technical-architect, at close) |
| 7 | Minor | `docs/tests/T09/test-cases.md` (TC-T09-13, TC-T09-28, TC-T09-31) | The test cases disagree with the accepted behaviour. TC-T09-13 expects 1 violation for a malformed date (2 core violations with code `''` is accepted, D4), TC-T09-28's path wording (finding 2), and TC-T09-31 (finding 5). Re-review: option (a) was chosen, so TC-T09-31 must now say that the one Watchlist violation is at `field_symbol`, not `field_external_id` | Tester amends the expected results, with a change-log row, before `/test-task` | Open (tester) |
| 8 | Minor | `docs/tests/T05/run-checks.sh:475-476, 621`; `docs/tests/T06/run-checks.sh:1031`; `docs/tests/T05/test-cases.md`, `docs/tests/T06/test-cases.md` | The developer edited tester-owned suites (the plan's "Interfaces touched" row says the tester updates them), and the T05/T06 test-case change logs were not updated. The new T05 check "meridian_core is the only custom module" will fail when T10 adds `meridian_ingest` | Tester reviews and adopts the edits and adds change-log rows to both test-case files. Change the T05 check to "`meridian_core` exists and every custom module is named in section 0", or record that T10 must update it | Open (tester) |
| 9 | Minor | `scripts/quality.sh:189` | The DDEV runner calls `enable_xdebug` and then `trap disable_xdebug EXIT`, so it switches Xdebug **off** even when the developer had it on before (`ddev xdebug on` for a debugging session) | Record the state first (for example `php -m \| grep -qi xdebug`) and only disable on exit if it was off. Or state the side effect in `scripts/README.md` accepted difference 6. Re-run `test_quality_sh.py` | Fixed (`d811637`) |
| 10 | Minor | `apps/drupal/web/modules/custom/meridian_core/tests/src/Unit/PatternsTest.php`, `JsonDocumentValidatorTest.php`, `DecimalScaleValidatorTest.php` | The Unit tests do not name their case IDs (TC-T09-08, TC-T09-09). REVIEW_CHECKLIST section 4 asks that tests name their `TC-Txx-nn`. The Kernel classes do | Add the IDs to the class or method docblocks | Fixed (`d811637`) |
| 11 | Note | `FieldConstraintHooks.php` | The plan (KD-2) asked for `NotNull` attached in code on the required booleans. It is not attached: core `required` already rejects a `NULL` boolean, because `FALSE` is not empty for a boolean item. The Kernel required-field cases cover `field_vetoed`, `field_adjusted` and `field_enabled` | None. Recorded as a harmless departure | n/a |
| 12 | Note | `field.storage.node.field_external_id.yml`, `ExternalIdIndex.php` | Latent limits of the key, both out of T09 scope: (a) the storage is `translatable: true` and the key leaves out `langcode`, so adding a translation of a record would violate it; (b) deleting a field instance marks rows `deleted = 1` in the same table until purge, so re-adding the field could collide. Meridian has no multilingual content and never deletes these fields | None now. T33 lists it under known limitations. A task that enables translation must change the key first | n/a |
| 13 | Note | `MeridianWatchlistItemRulesValidator.php` | The 50-enabled limit is check-then-act with no lock or database backstop, the same class of race as symbol uniqueness. Only administrators write Watchlist Items (T12) | None. T27 reconciliation can report more than 50 enabled items | n/a |
| 14 | Note | `.ddev/config.yaml` (`SIMPLETEST_DB=mysql://db:db@db/db`) | Kernel tests use the DDEV project database with prefixed tables. An aborted run leaves `test*` tables that a `ddev export-db` would include. This is the DDEV-documented practice | None. Could be mentioned in `apps/drupal/README.md` "Tests" | n/a |
| 15 | Note | `.github/workflows/ci.yml:155, 166` | The live CI run has not happened. The `mariadb:10.6.22` tag exists (checked by the reviewer, 2026-11-04). `healthcheck.sh` is in the official image from 10.4 onward, but only the live run proves it. The timeout is now 25 min, against a 10.6 min Kernel suite on DDEV without coverage. Local DDEV is MariaDB 10.6.21 and CI is 10.6.22, which is accepted because rule 2 compares major.minor | The live CI run (TC-T09-62) is a close condition (see C4). T10 re-checks the timeout when it adds Functional tests (about 10 s per Kernel method grows linearly) | Open (close condition) |
| 16 | Note | whole diff | Simulation-only: no broker SDK, client, domain or order code. No new outbound host. The MG-1 script uses no network | None | n/a |
| 17 | Note | `scripts/quality.sh:184` | Re-review: the reflowed comment line is 123 characters, against the 100-character line length used elsewhere. No gate covers shell comment length | Rewrap it when the file is next touched | n/a |
| 18 | Note | `MeridianUniqueInBundleValidator.php` (`d74d07c`) | Re-review: validating a Watchlist Item now runs the symbol uniqueness query twice, once to skip the `external_id` check and once for the symbol constraint. The cost is negligible for at most 50 admin-written items. When `external_id` is a duplicate but the symbol is not (only possible with a mismatched ID), both `meridian.external_id_mismatch` and `meridian.unique_in_bundle` fire. That needs a hand-made ID the derivation never produces | None | n/a |
| 19 | Note | `apps/drupal/composer.lock` (unchanged by T09) | Re-review: `composer audit` reports 12 advisories on 7 Symfony packages (published 2026-11-04), so `audit-drupal` fails on `main` and on this branch alike. This is not caused by the T09 diff (`git diff main...HEAD -- apps/drupal/composer.*` is empty) | Owner decision, see "Re-review" below. It is a C4 condition, not a T09 finding to fix in this diff | Open (owner, C4) |

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | Plan and decisions `51e4404` and test design `d25e46e` come before the first code commit `b3b71cc`. Plan approved by the owner on 2026-11-04 |
| C2 Review findings resolved | Yes, with assigned items (re-review 2026-11-05) | All Blocker and Major findings are fixed. Minor findings 3, 4, 5, 9 and 10 are fixed. Minor findings 6 (technical-architect, at close), 7 and 8 (tester, before `/test-task`) are assigned and open |
| C3 Criteria mapped to executed tests | Pending | All six ACs map to TC-T09 cases. The Kernel and Unit suites pass in the reviewer's run. The test report is written at `/test-task`. AC6 uses the reworded text (owner, O-3) |
| C4 CI green | Pending | Locally: phpstan, phpcs, pre-commit, check-names, check_ci and both PHPUnit suites are green. The developer's last full `ddev quality` log (run start 15:08 IST) failed `docs-regression` on the T04a coverage-row check. That run started before `e993414` (15:48), which is meant to fix it. The failing check (`docs/tests/T04a/run-checks.sh:152`, words `70`, `provisional`, `kernel`) matches the current coverage row. The tester must record a clean `ddev quality` on `7abe5fc` or later, and the live CI run of the `drupal` job (TC-T09-62). **Re-review (2026-11-05): not met, for a reason outside the T09 diff.** On `d347b72`, `ddev quality` gives PASS 12, FAIL 1 because of the upstream Symfony advisories (finding 19), which also fail on `main`. Every T09-specific gate passes. C4 stays unmet until the owner's decision is carried out and recorded (see "Re-review") |
| C5 Docs updated | Partly | `data-model.md`, `technical-design.md` (with revision note 6), `permissions.md`, the READMEs, the runbook and the coverage row are updated. The violation contract (finding 2) was added in `309c5a6`. Open: the naming section (finding 6), and the `TRACEABILITY.md` rows for R-06, R-07 and FR-16 plus SA-1 at `/close-task` |
| C6 No secrets | Yes | gitleaks passes on the tree. The CI `ci-only` password and the DDEV `db:db` URL are throwaway values with comments. `MERIDIAN_SYNC_DIR` was removed (`309c5a6`), so T09 adds no new environment variable and `.env.example` is unchanged, as the plan's C6 reason says |
| C7 Clean-checkout works | Pending | The `ddev drupal-install --force`, `cex`/`cim` round trip is reported by the developer. The tester proves it in TC-T09-48 to TC-T09-51 and TC-T09-77 |

## Re-review (2026-11-05, head `d347b72`)

Fix commits: `0539f94` (F1), `309c5a6` (F2, F3), `a0a70b4` (F4), `d74d07c` (F5), `d811637` (F9,
F10). `d347b72` only records the reviewer's docs-regression row in this file.

| Finding | Verification |
|---|---|
| 1 | All 10 `phpcs:disable` lines are gone (`grep` finds 0). `apps/drupal/phpcs.xml.dist` has one `<exclude-pattern>*/tests/src/*</exclude-pattern> <!-- T09: one test case per line -->` for `Drupal.Arrays.Array.LongLineDeclaration`. `exceptions_report.py` accepts `<!--` as a config-exclude ticket slot and counts it: config exclude 12 to 13, ticket T09 2 to 3. A new test (`test_xml_exclude_needs_a_ticket_in_its_comment`) shows that an exclude with no ticket or an untagged comment fails, and a `T09:` comment passes. The scope check uses phpcs on stdin: a 122-column array fed as `.../meridian_core/src/Demo.php` raises `Drupal.Arrays.Array.LongLineDeclaration` (error), and the same text fed as `.../tests/src/Unit/Demo.php` does not. The exclusion is permanent and cites the task that decided it, which the exception policy allows |
| 2 | The module README now has a "Violation contract (T10)" section with raw paths, codes, the empty-code cases and the normalisation rule. `technical-design.md` D1 points to it. The new `ViolationContractTest` asserts raw `getPropertyPath()` and `getCode()` for ten cases: Meridian single-value, multi-value delta and list-level; core Range (`field_score.0.value`); core Choice (`field_mode.0`); reference (`field_run.0.target_id`, `''`); malformed date (two violations, `''`); entity rule; base field `title.0.value`; required (`field_score`). The README table matches the test. The existing normaliser in `violationsOf()` also handles the `field_mode.0` form |
| 3 | The `getenv('MERIDIAN_SYNC_DIR')` branch was removed; the trait and README name only the property. `grep` finds no other use |
| 4 | `declare(strict_types=1);` added. The script now counts `decision` and `daily_run` nodes before any write and exits 1 with one stderr line if any exist. The unused `$payload` capture was removed. The optional lint scope was not added, which is accepted |
| 5 | `MeridianUniqueInBundleValidator` skips the `field_external_id` check on `watchlist_item` when the symbol is a duplicate. Both tests now expect one violation at `field_symbol`. The query logic moved into `isDuplicate()` with no change in behaviour for the other bundles (still exact, bundle-scoped, own id excluded) |
| 9 | `quality.sh` enables Xdebug and sets the `disable_xdebug` trap only when `php -m` does not list Xdebug, so a debugging session is left as it was. `scripts/README.md` difference 6 updated |
| 10 | `PatternsTest` names TC-T09-08; `JsonDocumentValidatorTest` and `DecimalScaleValidatorTest` name TC-T09-09 |

Reviewer's re-run on `d347b72`:

- phpcs and PHPStan level 6: clean.
- Unit suite: OK, 25 tests, 217 assertions.
- Kernel classes `ViolationContractTest`, `ExternalIdUniquenessTest` and
  `WatchlistItemValidationTest`: OK, 12 tests, 183 assertions.
- `python3 -m unittest discover -s scripts/tests`: OK, 160 tests.
- `scripts/check-names.sh`: OK.
- `exceptions_report.py`: passes.
- `composer audit`: 12 advisories on 7 packages (finding 19).
- `composer.lock` and `composer.json` are unchanged against `main`.

The reviewer did not re-run the full Kernel suite. The other Kernel classes changed only by
losing the `phpcs:disable` comment. `ExternalIdUniquenessTest` covers the refactored uniqueness
validator on all five bundles. The tester runs the whole suite in TC-T09-54.

**Effect of the Symfony advisories on C4.** C4 requires CI green with no new security warning,
and `audit-drupal` now fails on `main` and on this branch. The cause is upstream and not in the
T09 diff, so it is not a T09 finding. It still means C4 **cannot be marked met** until the owner
decides how to handle it. The reviewer's recommendation, in order:

1. Fix it on `main` in a separate, ticketed change (a `DEF-nnn` in `docs/tests/defects.md`, or
   an owner-named task): `composer update` of the affected `symfony/*` packages (and core, if
   the fixed versions need a newer core patch), with the T05 lock and audit checks run. Merge
   it, then rebase T09 and re-run `ddev quality` and CI.
2. Only if no fixed version exists yet: add a temporary `audit.ignore` entry per advisory ID in
   `apps/drupal/composer.json`, citing that `DEF-nnn` under the exception policy. The ticket
   must say what removes the entry and when. C4 is then recorded as met with that exception.

Do not put the dependency bump inside the T09 branch unless the owner chooses that, because it is
outside the T09 scope and would need its own review.

## Approval

**Re-review 2026-11-05: Approved with conditions.** No Blocker or Major finding is open. The
conditions to meet before `/close-task`:

1. **C4.** Carry out the owner's decision on the Symfony advisories (finding 19), recorded with
   a ticket. Then record a clean `ddev quality` on the final head and a green live CI run of
   the `drupal` job (TC-T09-62, finding 15).
2. **Finding 7 and 8 (tester).** Amend TC-T09-13, TC-T09-28 and TC-T09-31; adopt the T05/T06
   suite edits with change-log rows; make the "only custom module" check survive T10.
3. **Finding 6 (technical-architect, at close).** Amend the naming section of
   `CODING_STANDARDS.md`.
4. **C3, C5, C7.** Test report with evidence for every AC (including the full Kernel suite and
   the config round trip TC-T09-48 to TC-T09-51); `TRACEABILITY.md` rows for R-06, R-07 and
   FR-16; SA-1 requested.
5. **MG-1.** The four T10 actions in "Unique key, collation and MG-1" go into the T10 plan
   before T10 coding.

technical-architect, 2026-11-05.

### Original verdict (2026-11-04)

**Changes requested.** Two Major findings are open: finding 1 (suppressions invisible to the
exception gate) and finding 2 (the T10 violation contract is documented wrongly and untested in
raw form). Both are small to fix. After they are fixed, and Minor findings 3 to 10 are fixed or
ticketed, the reviewer expects to approve with these conditions: a clean `ddev quality` on the
final head, a green live CI run of the `drupal` job (C4), and the T10 MG-1 actions above written
into the T10 plan before T10 coding. MG-1 at 50.18 s does not block T09 under DN-9.

technical-architect, 2026-11-04.
