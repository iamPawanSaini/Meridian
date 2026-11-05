# T09: Content model as configuration, Test report

| Field | Value |
|---|---|
| Task | T09 |
| Build or commit | `83ed38fc225bc3dd4d30bce87cc0e9b42589ffed` (`task/T09-content-model`, "T09: set In test after re-review"), plus the tester's uncommitted files under `docs/tests/` |
| Environment | Linux 6.18 WSL2 (Intel Core i5-1135G7, 8 logical CPUs, 7.6 GiB RAM), DDEV v1.24.4 (docker 28.1.1), MariaDB 10.6.21, PHP 8.3.19, Drupal core 11.4.11, PHPUnit 11.5.57, Symfony 7.4.23 packages (`composer audit` clean). No pcov in DDEV (Xdebug coverage in `ddev quality`); CI not yet run |
| Date | 2026-11-05 |
| Executed by | tester (execute mode) |
| Test cases | `docs/tests/T09/test-cases.md` (TC-T09-01 to TC-T09-77), results and evidence names filled in per case |
| Evidence | `docs/tests/T09/evidence/` |

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T09-01 | AC1, C5 | Pass | `evidence/TC-T09-01.txt` |
| TC-T09-02 | AC1 | Pass | `evidence/TC-T09-02.txt` |
| TC-T09-03 | AC1 | Pass | `evidence/TC-T09-03-kernel.txt` |
| TC-T09-04 | AC1, AC2 | Pass | `evidence/TC-T09-04.txt` |
| TC-T09-05 | AC1 | Pass | `evidence/TC-T09-05-datamodel-indexed.txt` |
| TC-T09-06 | AC1, AC4 | Pass | `evidence/TC-T09-06.txt` |
| TC-T09-07 | AC1, AC5 | Pass | `evidence/TC-T09-07.txt` |
| TC-T09-08 | AC2, AC5 | Pass | `evidence/TC-T09-08.txt` |
| TC-T09-09 | AC2, AC5 | Pass | `evidence/TC-T09-09.txt` |
| TC-T09-10 | AC2, AC5 | Pass | `evidence/TC-T09-10-kernel.txt` |
| TC-T09-11 | AC2, AC5 | Pass | `evidence/TC-T09-11-kernel.txt` |
| TC-T09-12 | AC2, AC5 | Pass | `evidence/TC-T09-12-kernel.txt` |
| TC-T09-13 | AC2, AC5 | Pass | `evidence/TC-T09-13-kernel.txt` |
| TC-T09-14 | AC2, AC5 | Pass | `evidence/TC-T09-14-kernel.txt` |
| TC-T09-15 | AC2, AC5 | Pass | `evidence/TC-T09-15-kernel.txt` |
| TC-T09-16 | AC2, AC5 | Pass | `evidence/TC-T09-16-kernel.txt` |
| TC-T09-17 | AC2, AC5 | Pass | `evidence/TC-T09-17-kernel.txt` |
| TC-T09-18 | AC2, AC5 | Pass | `evidence/TC-T09-18-kernel.txt` |
| TC-T09-19 | AC2, AC5 | Pass | `evidence/TC-T09-19-kernel.txt` |
| TC-T09-20 | AC2, AC5 | Pass | `evidence/TC-T09-20-kernel.txt` |
| TC-T09-21 | AC2, AC5 | Pass | `evidence/TC-T09-21-kernel.txt` |
| TC-T09-22 | AC2, AC5 | Pass | `evidence/TC-T09-22-kernel.txt` |
| TC-T09-23 | AC2, AC5 | Pass | `evidence/TC-T09-23-kernel.txt` |
| TC-T09-24 | AC2, AC5 | Pass | `evidence/TC-T09-24-kernel.txt` |
| TC-T09-25 | AC2, AC3, AC5 | Pass | `evidence/TC-T09-25-kernel.txt` |
| TC-T09-26 | AC2, AC5 | Pass | `evidence/TC-T09-26-kernel.txt` |
| TC-T09-27 | AC2, AC5 | Pass | `evidence/TC-T09-27-kernel.txt` |
| TC-T09-28 | AC2, AC5 | Pass | `evidence/TC-T09-28-static.txt` |
| TC-T09-29 | AC2, AC3 | Pass | `evidence/TC-T09-29.txt` |
| TC-T09-30 | AC5 | Pass | `evidence/TC-T09-30.txt` |
| TC-T09-31 | AC3, AC5 | Pass | `evidence/TC-T09-31-kernel.txt` |
| TC-T09-32 | AC3 | Pass | `evidence/TC-T09-32-kernel.txt` |
| TC-T09-33 | AC3 | Pass | `evidence/TC-T09-33-kernel.txt` |
| TC-T09-34 | AC3 | Pass | `evidence/TC-T09-34.txt` |
| TC-T09-35 | AC3 | Pass | `evidence/TC-T09-35-kernel.txt` |
| TC-T09-36 | AC3, AC4 | Pass | `evidence/TC-T09-36.txt` |
| TC-T09-37 | AC3, AC4, C5 | Pass | `evidence/TC-T09-37.txt` |
| TC-T09-38 | AC6 | Pass | `evidence/TC-T09-38.txt` |
| TC-T09-39 | AC6 | Pass | `evidence/TC-T09-39.txt` |
| TC-T09-40 | AC6 | Pass | `evidence/TC-T09-40-kernel.txt` |
| TC-T09-41 | AC6 | Pass | `evidence/TC-T09-41-kernel.txt` |
| TC-T09-42 | AC6 | Pass | `evidence/TC-T09-42-kernel.txt` |
| TC-T09-43 | AC6 | Pass | `evidence/TC-T09-43-kernel.txt` |
| TC-T09-44 | AC6 | Pass | `evidence/TC-T09-44-kernel.txt` |
| TC-T09-45 | AC6, C5 | Pass | `evidence/TC-T09-45-parity.txt` |
| TC-T09-46 | AC6, AC4 | Pass | `evidence/TC-T09-46.txt` |
| TC-T09-47 | AC6, C7 | Blocked | none |
| TC-T09-48 | AC4, C7 | Pass | `evidence/TC-T09-48.txt` |
| TC-T09-49 | AC4 | Pass | `evidence/TC-T09-49.txt` |
| TC-T09-50 | AC4 | Pass | `evidence/TC-T09-50.txt` |
| TC-T09-51 | AC4 | Pass | `evidence/TC-T09-51.txt` |
| TC-T09-52 | AC4 | Pass | `evidence/TC-T09-52.txt` |
| TC-T09-53 | AC5, C4 | Pass | `evidence/TC-T09-53.txt` |
| TC-T09-54 | AC5, C4 | Pass | `evidence/TC-T09-54.txt` |
| TC-T09-55 | AC5 | Pass | `evidence/TC-T09-55.txt` |
| TC-T09-56 | C4, AC5 | Pass | `evidence/TC-T09-56.txt` |
| TC-T09-57 | C4 | Pass | `evidence/TC-T09-77-ddev-quality-clean-clone.txt` |
| TC-T09-58 | C4 | Pass | `evidence/TC-T09-58.txt` |
| TC-T09-59 | C4, AC5 | Pass | `evidence/TC-T09-59.txt` |
| TC-T09-60 | C4 | Pass | `evidence/TC-T09-60.txt` |
| TC-T09-61 | C6 | Pass | `evidence/TC-T09-61.txt` |
| TC-T09-62 | C4, AC5 | Pass | `evidence/TC-T09-62-live-ci.txt` |
| TC-T09-63 | C3, C4 | Pass | `evidence/TC-T09-63-static.txt` |
| TC-T09-64 | C3, C5 | Pass | `evidence/TC-T09-64.txt` |
| TC-T09-65 | C4, C6 | Pass | `evidence/TC-T09-65.txt` |
| TC-T09-66 | C3, C5 | Pass | `evidence/TC-T09-66.txt` |
| TC-T09-67 | C3 | Pass | `evidence/TC-T09-67.txt` |
| TC-T09-68 | C5 | Pass | `evidence/TC-T09-68.txt` |
| TC-T09-69 | AC1, C5 | Pass | `evidence/TC-T09-69.txt` |
| TC-T09-70 | C5, C7 | Pass | `evidence/TC-T09-70.txt` |
| TC-T09-71 | AC6, C5 | Blocked | `evidence/TC-T09-71.txt` |
| TC-T09-72 | C1 | Pass | `evidence/TC-T09-72.txt` |
| TC-T09-73 | C2 | Pass | `evidence/TC-T09-73.txt` |
| TC-T09-74 | C3 | Pass | `evidence/TC-T09-74.txt` |
| TC-T09-75 | C4 | Pass | `evidence/TC-T09-77-ddev-quality-clean-clone.txt` |
| TC-T09-76 | C6 | Pass | `evidence/TC-T09-76.txt` |
| TC-T09-77 | C7 | Pass | `evidence/TC-T09-77.txt` |

Totals: 75 pass, 0 fail, 2 blocked, 0 not run (77 cases).

Counts by status come from the Status rows of `test-cases.md`. A Pass has a non-empty evidence file
(checked in `evidence/TC-T09-74.txt`). The Blocked cases are not passes.

### Status per acceptance criterion

| Criterion | Status | Basis |
|---|---|---|
| AC1 Content types and fields as the T03 spec, exported in `config/sync` | Pass | TC-01 to 07 and 69. Field sets equal the amended data-model for all five bundles (21, 24, 22, 13 and 7 fields with title); structure test and two mutations confirm it |
| AC2 Validation enforced | Pass | TC-04, 08 to 29 verified every rule with exact (path, code) lists. TC-12 and TC-17 passed on retest after DEF-012 was fixed in e51ec08 |
| AC3 Unique `external_id` per type at entity level | Pass | TC-25, 29, 31 to 37: `validate()` rejects duplicates on all five bundles; the database key `meridian_external_id_bundle` stops a bare `save()` and a concurrent Watchlist create; the key survives install, `cim`, `cr`, `updatedb` and uninstall is tested |
| AC4 `cex` shows no diff after install; `cim` on a clean site recreates everything | Pass | TC-06, 36, 37, 46, 48 to 52: install from config, `cex` identical, two `cim` runs idle, `sql:drop` then `site:install --existing-config` reproduces config/sync byte for byte, drift and a deleted role are restored by `cim` |
| AC5 Kernel tests cover every validation rule and each rejection | Pass | Suites pass (Kernel 47 tests; Unit 25 tests; Decision and Position classes re-run after e51ec08: 198 and 155 assertions), all seven suite mutations and the structure mutations are detected (TC-55). Live CI: green on the PR and on main (TC-62). DEF-012 is fixed and retested |
| AC6 Permissions matrix documented and tested for the six roles (FR-16) | Pass for the matrix, two items open | TC-38 to 46: 54 role-by-permission, 120 role-by-bundle-by-operation and 78 field cells are asserted and equal `permissions.md` and the role YAML. Open: TC-47 (owner browser check, Blocked) and TC-71 (SA-1 hand-off, Blocked) |
| C1 Plan before code | Pass | TC-72 |
| C2 Review findings resolved | Pass | TC-73: no Blocker or Major open. Findings 7 and 8 were closed by the tester on 2026-11-05; finding 6 is for `/close-task` |
| C3 Criteria mapped to executed tests | Pass | TC-63, 64, 66, 67, 74 |
| C4 CI green, no new warnings | Met | Local gates are clean: `ddev quality` PASS 13 FAIL 0 SKIP 6 on the committed head (clean clone), pre-commit, phpstan, phpcs, composer audit, check_ci. Live CI is green on PR run 42029185375 and main run 42030675309, and pcov loads in CI (TC-62) |
| C5 Docs and traceability | Mostly | TC-01, 37, 45, 68 to 70 Pass. Open for `/close-task`: TRACEABILITY evidence links, SA-1 (TC-71), finding 6 (naming section) |
| C6 No secrets | Pass | TC-61, 65, 76. `.env.example` unchanged; the review's `MERIDIAN_SYNC_DIR` removal confirmed |
| C7 Clean checkout works | Pass for the Linux side | TC-77 ran every documented command from a fresh clone. Open: the Windows browser check (owner, TC-47 and TC-77) |

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| DEF-012 Non-numeric and non-integer inputs are untested and give several violations (TC-12, TC-17) | Low | Retest passed (fix e51ec08) |
| DEF-013 pcov is not available in the DDEV web container (TC-56, TC-59); review deviation 8 | Low | Won't fix (review deviation 8 accepted; cases amended and re-judged Pass) |
| DEF-014 A full `ddev quality` takes over an hour (each docs suite nests `ddev quality`) | Low | Open: proposed for a separate ticket after T09; owner decision pending |

## Work the review assigned to the tester (done before execution)

- DEF-013 follow-up: TC-T09-56 and TC-T09-59 are amended (DDEV may use Xdebug coverage, CI must use
  pcov)
  with a Change log row and re-judged Pass on the existing evidence.

- F7: TC-T09-13 (malformed date: two core violations `field_trade_date.0` and
  `field_trade_date.0.value`,
  both with code `''`), TC-T09-28 (raw paths and codes are checked in `ViolationContractTest` and
  the
  README section "Violation contract (T10)"; the helper shortens core paths) and TC-T09-31 (a
  duplicate
  Watchlist symbol gives one violation at `field_symbol`, code `meridian.unique_in_bundle`) are
  amended,
  each with a Change log row (the file had none; the table is new at the end of `test-cases.md`).
- F8: the developer's edits to `docs/tests/T05/run-checks.sh` lines 475, 476 and 621 and
  `docs/tests/T06/run-checks.sh` line 1031 are adopted, with Change log rows in both test-case
  files. The
  "only custom module" check is rewritten as "`meridian_core` exists and every custom module is
  named in
  section 0" (`meridian_core`, `meridian_ingest`), so T10 does not break it. As first written it cut
  field 5 of the path (always `custom`), so it could never match; it is now field 6. TC-T09-63
  wording
  follows.

## Observations (not defects)

1. **Time of `ddev quality`.** One full run takes 1 h 31 min on this machine (clean clone). It runs
   the
   Kernel suite once under Xdebug itself and then the docs-regression step, in which T04a, T05 and
   T06
   each start a nested `ddev quality` (T05 and T06 also re-run T04a). DEF-014 has a suggested fix.
   Run by
   hand, the same suites are worse: the recursion guard is set only by `scripts/docs_regression.sh`.
   For TC-T09-63 and 64 the tester therefore took the T04a to T07 results from the docs-regression
   step of
   the clean-clone `ddev quality` instead of starting T05 and T06 by hand (same `--regression`
   command).
2. **First `ddev quality` in the main tree failed, by the tester's fault.** It ran while two tester
   helper
   scripts (written after the run started) carried an unticketed `noqa` and an unticketed ignore
   text; the
   "Meridian suppressions cite a ticket" hook and `exceptions_report.py` failed, which failed the
   nested
   pre-commit in T04a, T05, T06 and T07 (`evidence/TC-T09-75-ddev-quality.txt`, the first 12 steps
   passed).
   The files were fixed and `pre-commit --all-files`, `exceptions_report.py` and `scripts/quality.sh
   --group
   core` pass again; the clean-clone run on the committed head is the clean record.
3. **DDEV was found stopped** once during the mutation runs (the tester had killed nested docs
   suites by
   hand). The affected mutation runs were re-run in four parallel copies (`evidence/TC-T09-55.txt`).
   No
   repository file was affected.
4. **Xdebug state.** While `ddev quality` runs, Xdebug is on in the shared web container. A plain
   Kernel
   run started at that time failed with 30 "Xdebug step debug time-out" errors
   (`evidence/TC-T09-77-kernel-clean-clone-attempt1.txt`); the run after `ddev quality` ended
   passed. Do not
   run Kernel tests by hand while `ddev quality` runs, and note that a developer with `ddev xdebug
   on`
   (debug mode) will see the same errors.
5. **MG-1.** The tester's re-run gave p95 70.10 s (create 22.3 to 23.3 s, update 40.8 to 46.8 s),
   against
   the developer's 50.18 s on 2026-11-04. Both are far above the 15 s warning level; the 40 percent
   spread
   means the T10 baseline needs controlled conditions. DN-9 makes this a trigger for T10 planning,
   not a
   gate. The four T10 actions in the review are unchanged.
6. **TC-T09-03 count.** The case text says 24 fields for `daily_run`; the amended data-model has 22
   with
   `title`, and the config matches it.
7. **Expected "prints nothing" greps.** TC-T09-53 step 2 matches the comment line that names the
   `SIMPLETEST_DB` variable, and TC-T09-65 step 4 matches the README sentence "nothing here touches
   a
   broker". Neither is a URL, a broker domain or code. Passed on intent; the next design pass can
   tighten the patterns.
8. **Position changes cascade.** For a Position, changing `symbol` or `mode` with the old external
   ID
   gives the `field_external_id` mismatch and, at `field_decision`, the DN-6 symbol or mode mismatch
   (the tests assert both). T10 should expect two entries. A future `trade_date` is accepted on
   `price_snapshot` and `daily_run` (plan question Q-2, review D6).
9. **Coverage figure.** `CODING_STANDARDS.md` now records 94.1 percent (465 of 494 lines), the
   value measured in TC-T09-56.
10. **Clone left on disk.** The clean clone `~/meridian-clean-t09` could not be removed by the
    tester
    (outside the write area). Its DDEV project is deleted; remove the folder by hand.
11. **Local requirements.** `drush core:requirements` shows "Public files directory: Not fully
    protected"
    (DDEV nginx, not related to T09).

## Coverage notes

- Not run by the tester: TC-T09-47 (owner browser check), the Windows part of TC-T09-77, SA-1 of
  TC-T09-71. TC-T09-62 was judged on API results and owner-pasted excerpts (see Live CI evidence).
- Mutation checks ran in copies of `apps/drupal` inside the DDEV container; no production file was
  edited.
  Detected: score max 101, `short2` in `field_mode`, `MeridianUniqueInBundle` removed,
  `MeridianImmutable` removed, `daily_run` status subset removed, `vetoed` made optional, analyst
  granted
  `view meridian raw llm output`, unique key not created, `field_symbol` max length 21, a deleted
  field.
  The `NotNull` mutation is the `required` flag instead, because `NotNull` is not attached (review
  note 11).
- TC-T09-35's optional tester script was not duplicated: the Kernel test is the same scenario.
- TC-T09-60 step 2 used `unittest` (pytest is not installed on the host); 36 tests pass.
- Coverage: 94.1 percent line coverage of `web/modules/custom/meridian_` (465 of 494 lines),
  threshold 70
  percent, 72 tests (25 Unit, 47 Kernel), 2154 assertions, 0 failures, from the Cobertura file of
  the
  clean-clone run. Branch coverage is not measured.
- Test helpers added under `docs/tests/T09/`: `parity_check.py` (TC-45), `mutations.sh`,
  `indexed_fields.py`,
  `split_evidence.py` (cuts the Kernel run into per-case extracts) and the read-only probes
  `probe_nonnumeric.php`, `probe_duplicate.php`, `probe_create_run.php`.

## Steps for the owner

**TC-T09-62 (live CI)** is done: see "Live CI evidence" below.

**TC-T09-47 and the Windows part of TC-T09-77 (administrator in a browser).**

1. In WSL, in the project, run `ddev start` (if it is not running), then `ddev drush uli`. The site
   was
   reinstalled with `ddev drupal-install --force` at the end of testing, so it is empty and the
   admin
   password is a throwaway.
2. Open the one-time link in the Windows browser, then open `/admin/structure/types`,
   `/admin/people/roles` and `/admin/people/permissions`.
3. Send full-page screenshots of the three pages. Expected: five content types (Decision, Position,
   Daily
   Run, Price Snapshot, Watchlist Item); roles Administrator, Analyst, Engine ingest, Dashboard read
   plus
   Anonymous and Authenticated; the permissions page lists the Meridian group with seven
   permissions. A
   partial screenshot is not enough.

## Live CI evidence (TC-T09-62, TC-T09-75, CI part of TC-T09-59)

Source: `evidence/TC-T09-62-live-ci.txt` (GitHub API job and step results, plus log excerpts pasted
by
the owner). Read on 2026-11-05.

Observed:

- PR run 42029185375 (head 3d17dca) and main run 42030675309 (merge 69ed15e): every job succeeded
  (core, web, drupal, engine, docs, `ci-ok`). In `drupal`, "Initialize containers" and the step "Run
the
  quality suite (group drupal)" succeeded.
- `php -m` in the toolchain step lists pcov (PHP 8.3.36, Composer 2.11.1).
- The drupal group printed PASS build-drupal, component-drupal, component-drupal-tests and
  audit-drupal (PASS 4 FAIL 0 SKIP 0).
- The artifact `reports-drupal` (9384 B) exists.

Not observed (job logs and artifact downloads need authentication):

- The MariaDB version in the service container log (only that the containers initialised).
- The PHPUnit test counts (so equality with the DDEV 25 and 47 is not confirmed).
- The coverage percentage and the contents of the Cobertura file. The 70% floor is inferred from
  `component-drupal-tests` PASS, which enforces it.
- Warning counts in CI.

TC-T09-62 and TC-T09-75 are judged Pass on this evidence, with those gaps stated. The CI part of
TC-T09-59 (pcov loads in CI) is observed.

## Sign-off

**Not signed off.** No case fails. Two are Blocked: TC-T09-47 (owner screenshots pending; the
Windows part of TC-T09-77 is open for the same reason) and TC-T09-71 (SA-1 at close). No Critical,
High or Medium defect is open. The product behaviour under test is verified and CI is green.
Sign-off needs the owner's browser screenshots and SA-1. tester, 2026-11-05.
