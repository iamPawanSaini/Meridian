# Defect log

Use `docs/templates/defect.md` for each entry. The test levels, the exit criteria and the
severity scale are defined in [`master-test-plan.md`](master-test-plan.md), which is the single
source of the severity meanings. The table in "Triage SLA" repeats those meanings unchanged next
to the triage times. If the two ever differ, the master plan wins.

## Workflow

A failed test case (Fail) creates a defect. A Blocked case does not: Blocked means a tool or an
environment is missing, not that the product is wrong.

States, in order: Open, Triaged, In progress, Fixed, Retest passed, Closed, Reopened, Won't fix.

| State | Moved by | Meaning and next step |
|---|---|---|
| Open | tester | Raised with steps to reproduce, severity and the failing case ID. Goes to Triaged. |
| Triaged | technical-architect | Severity confirmed and an owner chosen. Goes to In progress, or to Won't fix. |
| In progress | developer | Fix being written on the task branch. Goes to Fixed. |
| Fixed | developer | Fix committed; the fix commit is recorded. Goes to Retest passed or Reopened. |
| Retest passed | tester | The tester re-ran the failing case and its neighbours, and stored evidence. Goes to Closed. |
| Closed | main session | Retest evidence is on file and the report is updated. Terminal. |
| Reopened | tester | The retest failed or the defect returned. Goes back to In progress. |
| Won't fix | technical-architect | Accepted without a fix, with a written reason. Critical or High needs a solution-architect decision. Terminal. |

## Rules

- Retest is done by the tester, with evidence stored (output, log or screenshot) and referenced
  in the defect. A developer's own check is not a retest.
- A defect is set to the Closed state only after Retest passed. The main session sets Status to
  Closed at `/close-task` of the task that found the defect. The "Closed" section of this file
  holds entries in Retest passed, Closed or Won't fix; DEF-001 and DEF-002 stay at Retest passed
  until their tasks close.
- Won't fix for a Critical or High defect needs a solution-architect decision, recorded in the
  defect. The technical-architect may decide Medium and Low.
- A Critical or High defect that is open blocks task close and the milestone gate (see "Exit
  criteria" in the master plan).
- A fix is verified against the original steps to reproduce. A regression case is added to the
  task cases when the defect was not already covered.
- Do not edit a script or a check to make a defect disappear. Script defects are logged in the
  Change log of the task's `test-cases.md` (see "Conventions" in the master plan).

## Triage SLA

Time counts working days from the day the defect is Open until it is Triaged. The fix target
counts from Triaged until Fixed. The meanings are those of the master plan.

| Severity | Meaning | Triage within | Fix target |
|---|---|---|---|
| Critical | Data loss, security breach, wrong financial result, or any live-order capability | 4 working hours | 1 working day |
| High | Core function broken with no workaround | 1 working day | 3 working days |
| Medium | Function impaired, workaround exists | 2 working days | before task close, or ticketed in a named later task with technical-architect agreement |
| Low | Cosmetic or documentation issue | 5 working days | before task close or ticketed |

## Defects and review findings

A defect comes from a test: a Fail in a test report. A review finding comes from the
technical-architect's review of a diff in `docs/tasks/Txx/review.md`, with the scale Blocker,
Major, Minor and Note. Review findings are resolved in the same task and are not logged here.
If a review finding is later shown to fail a test case, or is found after review, it becomes a
defect. Blocker and Major findings must be resolved before the test report is signed off; Minor
and Note findings may be ticketed.

## Open

### DEF-009: The Pantheon Sandbox edge challenges requests from non-allowlisted User-Agents (Cloudflare 403)

| Field | Value |
|---|---|
| ID | DEF-009 |
| Severity | Medium (design assumption invalid; workaround exists; blocks nothing in T07, affects T10, T21 and T28) |
| Found in | T07 part 1, TC-T07-44 (`evidence/live-44-*.txt`, `evidence/TC-T07-44.*.txt`) |
| Status | Open |
| Fix commit | |
| Retest result | |

**Steps to reproduce** (run 2026-11-02 from the tester's network; Pantheon dev then held a
dashboard-installed, not yet installed Drupal, so the edge result is independent of our code)

1. `curl -sS -A 'python-httpx/0.27.0' -o /dev/null -w '%{http_code}\n' https://dev-meridian-trade.pantheonsite.io/jsonapi`
2. Repeat with `-H 'Deterrence-Bypass: 1'`, and with the User-Agents `undici`, `python-requests/2.32.3`,
   `meridian-engine/0.1`, `Go-http-client/2.0`, `Mozilla/5.0 (...) Chrome/126.0`, and an empty one.
3. Compare with `curl/8.5.0`, `node` and `Wget/1.21`.

**Expected:** the design (technical design D8, KD-12, plan A7) assumes that the only edge hurdle is
the Sandbox warning page and that the header `Deterrence-Bypass` removes it, so the engine (T10)
and the Next.js server (T21) can call the Drupal API with it.

**Actual:** two separate behaviours. (1) The Sandbox warning page ("Sandbox Environment Notice",
HTTP 200) is served only to GET requests that send `Accept: text/html`; default curl, POST and
JSON requests are not intercepted, and `Deterrence-Bypass: 1` removes the page (the page itself sets
the cookie `Deterrence-Bypass=1`). (2) A Cloudflare managed challenge (HTTP 403, `cf-mitigated:
challenge`, title "Just a moment...") answers every request from the User-Agents `undici`,
`python-httpx`, `python-requests`, `Go-http-client`, `Mozilla/...`, `Python-urllib`, `aiohttp`,
`meridian-engine/0.1` and from an empty User-Agent, with or without the bypass header. `curl`,
`node` and `Wget` pass. A Python engine client would therefore get 403 from a Pantheon Sandbox dev
site. Needs a decision by the technical-architect: a documented User-Agent for the engine, a
different host or plan for T28, or a Pantheon/Cloudflare allowlist request. Not a T07 code change:
the deploy script's smoke check uses curl and is not affected.

### DEF-010: First Pantheon build fails: the split tree has no `.gitignore` for the build output

| Field | Value |
|---|---|
| ID | DEF-010 |
| Severity | High (blocks every Pantheon build, so AC4 and part 2 of T07) |
| Found in | T07 part 2, O-4 (first push of split `2a60eba8574d39928deb7898cc6af185c13be904`, 2026-11-03) |
| Status | Retest passed |
| Fix commit | `f958a5d` (split `7b790a198d06461f39cb813ced2db6716611eb9e`) |
| Retest result | Pass 2026-11-03: fast-forward push `2a60eba..7b790a1`; workflow `79c49794-d75c-11f1-bbb3-123c6bba4b1c` "Sync code on dev" completed successfully for commit 7b790a1 (08:02:02 UTC); local build simulation clean |

**Steps to reproduce**

1. Push the split of `apps/drupal` (any commit before the fix) to Pantheon dev `master`.
2. Watch the Integrated Composer workflow "Sync code on \"dev\"" (workflow
   `f51435ea-d756-11f1-b21d-eebcb0a64446`, 114 s).

**Expected:** the build runs `composer install`, scaffolds Drupal and succeeds (plan KD-7: "the
build succeeded with only `pantheon.yml`").

**Actual:** the workflow fails. The build log (dashboard only; `terminus workflow:info:logs` says
"Workflow operations did not contain any logs") lists the scaffold output as untracked:
`.editorconfig`, `.gitattributes`, `web/.htaccess`, `web/index.php`, `web/autoload.php`,
`web/sites/default/settings.pantheon.php`, `web/sites/default/default.settings.php` and others.

**Cause:** the ignore rules for `apps/drupal` live only in the root `.gitignore`, which does not
travel with `git subtree split`. The split tree had no `.gitignore` (plan line 261, T05 KD-7: "T07
does not add one"). The plan assumption was wrong, not the deploy script.

**Fix:** a tracked `apps/drupal/.gitignore` that lists the build output and every scaffold file (taken
from the root rules for `apps/drupal`), and the root `.gitignore` no longer ignores that file. The
scaffold plugin's gitignore auto mode finds every path already ignored and leaves the file alone.
TC-T07-01 now checks the file on its own in an empty repository (ignored: build output and
scaffold files; kept: owned paths), with negative controls. Plan KD-7 note amended, runbook section
"Ignore rules travel with the split" added.

**Local evidence:** a fresh repository with only the tracked `apps/drupal` files plus the new file,
with the full local `composer install` output copied over it, gives an empty `git status
--porcelain`. Without the file the same setup lists the untracked files from the Pantheon log.

## Closed

### DEF-001: Path guard misparses quoted shell operators

| Field | Value |
|---|---|
| ID | DEF-001 |
| Severity | Medium |
| Found in | T01 (found in use during T02 planning by technical-architect) |
| Status | Retest passed |
| Fix commit | see `git log --grep DEF-001` |
| Retest result | 30/30 guard unit tests pass, incl. new `QuotedShellParsing` class |

**Steps to reproduce**

1. As `technical-architect`, run `grep -rnE "a|b" docs`

**Expected:** allowed (read-only command with a quoted pattern).

**Actual:** blocked with "could not parse shell command safely (No closing quotation)"; the
guard split on `|` before honouring quotes. Quoted `>` (for example `awk '$1 > 5'`) was also
treated as a redirect (T01 review finding 2).

**Fix:** `guard_paths.py` now tokenises with `shlex` (`punctuation_chars`) so quoted text stays
inside one word; operators and redirect targets come from the token stream.

### DEF-002: `uq_runs_date_attempt` collides for a second `publish` or `replay` row on the same date

| Field | Value |
|---|---|
| ID | DEF-002 |
| Severity | Medium |
| Found in | T03, TC-T03-24 (manual Postgres schema review) |
| Status | Retest passed |
| Fix commit | T03 commit (pending, main session) |
| Retest result | 2026-11-01: TC-T03-24 re-run Pass. `evidence/DEF-002-retest.txt` (12/12): repeated publish and replay rows with attempt 0 on one date now insert; duplicate attempt greater than 0 for a date and a second running row are still rejected; `ck_runs_attempt` still enforced. `run-checks.sh` and `check_data_model.py` all PASS. |

**Steps to reproduce**

1. Read `docs/specs/data-model.md`, table `runs`: `attempt` is "always 0" for `publish` and `replay`
   (`ck_runs_attempt`), and `uq_runs_date_attempt` is a plain unique constraint on (`trade_date`,
   `attempt`). Design D2 repeats this ("`publish` and `replay` rows use `attempt = 0`").
2. Model the constraint: `python3 -I` sqlite demo in `docs/tests/T03/evidence/DEF-002-demo.txt`
   (insert two rows with the same `trade_date`, `attempt = 0`).

**Expected:** any number of `publish` and `replay` runs can be recorded for one trade date (NFR-15
expects a manual `publish` dispatch after an outage, and a delayed cron or repeated dispatch can
repeat it), and none of them can fail on a unique violation.

**Actual:** the second `publish` or `replay` row for the same `trade_date` violates
`uq_runs_date_attempt`, so the run cannot even record itself (T14 Alembic baseline and T19/T20 would
hit it).

**Suggested fix (for the author, not applied by the tester):** make the unique rule partial,
`UNIQUE (trade_date, attempt) WHERE attempt > 0` (or give `publish`/`replay` a distinct key), and
update `data-model.md` runs and design D2 accordingly.

### DEF-003: pre-commit hook environment does not build on Python 3.10 (Ubuntu 22.04)

| Field | Value |
|---|---|
| ID | DEF-003 |
| Severity | High (blocks every commit once hooks are installed) |
| Found in | T05 build (main session), first real run of `scripts/bootstrap-dev.sh` hooks |
| Status | Retest passed |
| Fix commit | `git log --grep DEF-003` (T05) |
| Retest result | 2026-11-01 (tester, T05 `/test-task`, HEAD bfb5f7b): Pass. `scripts/bootstrap-dev.sh` passes its Python check and exits 0, installs both hooks, and `.tools/pre-commit run` builds every hook environment and runs all hooks (evidence `docs/tests/T05/evidence/DEF-003-retest.txt`, `TC-T05-24-full.txt`). Note: the script still warns that `PRE_COMMIT_SHA256` is not pinned |

**Steps to reproduce**

1. Ubuntu 22.04, system Python 3.10.12, no pip. Run `scripts/bootstrap-dev.sh` (pre-commit 4.7.0
   zipapp), then `git commit` or `.tools/pre-commit run --all-files`.

**Expected:** the hook environments build.

**Actual:** `ModuleNotFoundError: No module named 'typing_extensions'`. The zipapp bundles
virtualenv 21.14.7, which needs `typing_extensions>=4.16` on Python below 3.11 but is not bundled.
The zipapp shim removes every `site-packages` directory from `sys.path`, so a `pip install --user`
alone does not help, and the Ubuntu 22.04 apt package is 3.10.0.2 (too old). A second failure
followed: with no pinned Node version, nodeenv resolves "latest" and crashes on a pre-release
entry (`invalid literal for int() with base 10: '0-alpha'`).

**Fix:** `bootstrap-dev.sh` fails early with instructions on Python 3.10 without
`typing_extensions>=4.16`; `docs/runbooks/local-setup.md` lists Python 3.11+ (or the workaround);
`.pre-commit-config.yaml` pins `default_language_version: node: 22.14.0`. Owner machine
workaround used on 2026-11-01: `typing_extensions` 4.16.0 placed in a directory outside
`site-packages` and added to `sys.path` through a `.pth` file in the user site. Preferred long-term
fix: Python 3.11 or newer on the dev host, or a pre-commit installed with pip in a venv.

### DEF-004: T04a baseline is not clean under the real hooks (`--all-files`)

| Field | Value |
|---|---|
| ID | DEF-004 |
| Severity | Medium (blocks `ddev quality` exit 0 and TC-T05-21/24/34; does not block commits of other files) |
| Found in | T05 build (main session), first full `.tools/pre-commit run --all-files` on 2026-11-01 |
| Status | Retest passed |
| Fix commit | `623ffdd..c614327` (DEF-004; `git log --grep DEF-004`: e6b3158 plan, 623ffdd path guard, 35517dc scripts, OpenAPI and docs, a89e6e2 test scripts and test docs; c614327 added a fixture exclude). Uncommitted at the second retest: `.markdownlint-cli2.yaml` (fixture exclude removed) and `docs/tests/T03/fixtures/partial-data-model.md` (markdown formatting only), recorded in the T03 Change log |
| State history | Open, In progress (c614327), Fixed (review-def004, Approved with conditions), Reopened (tester retest 2026-11-02), Fixed (fixture exclude removed, fixture reformatted), Retest passed (tester, 2026-11-02, second retest) |
| Retest result | Second retest 2026-11-02 (tester, tree with the fixture exclude removed and the fixture reformatted): Retest passed. `.tools/pre-commit run --all-files` exit 0 and the tree unchanged afterwards; T04a `--regression` TC-T04a-28 now passes. TC-T05-24 and TC-T05-34 pass. TC-T05-21 still fails, but no longer from DEF-004: only the two count checks of TC-T04a-30 fail (T04 119 vs 118, T03 355 vs 354); the extra PASS is the "pre-commit run on T0x files passes" check, which was SKIP at close and now runs. Logged as DEF-005. Evidence: `docs/tests/T05/evidence/retest-def004/`. First retest 2026-11-02 (HEAD c614327): Reopened, the defect as logged was fixed but one case still failed. Verified: `.tools/pre-commit run --all-files` exit 0, tracked tree unchanged; `ddev quality` exit 0 (PASS 6, FAIL 0, SKIP 3); TC-T05-24 and TC-T05-34 now Pass; TC-T04a-37 and TC-T04a-48 Pass. Still failing: TC-T05-21, through its T04a regression check TC-T04a-28, check "markdownlint 'ignores': only TASKS.md and evidence", because c614327 added `docs/tests/T03/fixtures/partial-data-model.md` to `.markdownlint-cli2.yaml` (ticketed, but the test and TC-T04a-28 allow only TASKS.md and evidence). Decision needed: either accept the exclusion and update the TC-T04a-28 expectation through the owner and architect, or remove it. The PASS-count differences in TC-T04a-30 (354 to 355, 118 to 119) are content added since close and are not counted as a failure. Evidence: `docs/tests/T05/evidence/DEF-004-retest-*.txt`, `docs/tests/T05/evidence/retest-def004/`. Earlier row (2026-11-01) (tester, T05 `/test-task`): still reproduces, status stays Open. `TC-T05-24-full.txt` and `TC-T05-34-full.txt` show the same hook failures (ruff check, mypy, shellcheck, yamllint, markdownlint) on T00 to T04a files only. No T05 product file fails. Side effect: `pre-commit run --all-files`, and so `ddev quality`, rewrote 25 tracked T00 to T04a files (fixers); the main session must revert them |

**Steps to reproduce:** after DEF-003's workaround, run `.tools/pre-commit run --all-files` on
`task/T05-ddev-drupal` (39e6f68). Full output: owner-side scratch file, summarised here.

**Expected:** zero violations on the existing code (T04a acceptance criterion "Baseline is clean").
T04a recorded this as owner-run (TC-36) because the hooks could not be installed then.

**Actual:** gitleaks, the Meridian checks and Spectral pass. These fail on files from T00 to T04a:

- ruff check: about 350 findings (mostly E501, E701, E702, E741, SIM115) in `.claude/hooks/*.py`
  and the tester scripts under `docs/tests/T03`, `T04`, `T04a`; ruff format would reformat 21
  files.
- mypy (strict): 2 errors in `.claude/hooks/guard_paths.py` and its test.
- shellcheck: warnings (SC2164, SC2034, ...) in `docs/tests/*/run-checks.sh`.
- yamllint: line-length in `docs/architecture/openapi.yaml` and `.spectral.yaml`.
- markdownlint: MD056 in `docs/tasks/T03/review.md`, MD038 in
  `docs/tasks/T04a/decision-t04a-standards.md` and others.
- trailing-whitespace and mixed-line-ending rewrite committed evidence files under
  `docs/tests/*/evidence/` (evidence must stay byte-exact, so these paths need excluding rather
  than fixing).

The auto-fixes from this run were reverted; nothing outside T05 was changed.

**Test-script shellcheck directives (review-def004 finding 1).** `scripts/exceptions_report.py`
skips `docs/tests/T04a/run-checks.sh`, so its 5 directives are not in the report. All 10
directives in the T00 to T04a test scripts (every one cites T04a):

| File:line | Rule |
|---|---|
| `docs/tests/T00/run-checks.sh:44` | SC2034 |
| `docs/tests/T02/run-checks.sh:8` | SC2329 |
| `docs/tests/T03/run-checks.sh:8` | SC2329 |
| `docs/tests/T04/run-checks.sh:25` | SC2329 |
| `docs/tests/T04/run-checks.sh:66` | SC2016 |
| `docs/tests/T04a/run-checks.sh:34` | SC2329 |
| `docs/tests/T04a/run-checks.sh:68` | SC2016 |
| `docs/tests/T04a/run-checks.sh:359` | SC2016 |
| `docs/tests/T04a/run-checks.sh:602` | SC2016 |
| `docs/tests/T04a/run-checks.sh:655` | SC2016 |

(`docs/tests/T05/run-checks.sh:27` also has one, SC2329,SC2015,SC2016,SC2034, citing T05; it is not
in the review's count of 10. Lines 415 and 446 of the T04a script are test strings, not directives.)

**Suggested fix:** under T04a (it owns the baseline), exclude `docs/tests/*/evidence/` from the
fixer hooks; decide per path whether tester scripts follow the same ruff profile or a relaxed one
(recorded exception with a ticket); fix the rest. `.claude/hooks/*` is protected from subagents,
so the main session applies those changes.

### DEF-005: TC-T04a-30 compares PASS counts with the T03 and T04 close evidence

| Field | Value |
|---|---|
| ID | DEF-005 |
| Severity | Low (test-design defect; made TC-T05-21 and TC-T04a-30 print FAIL) |
| Found in | DEF-004 retest, TC-T05-21, TC-T04a-30 |
| Status | Retest passed |
| Fix commit | Uncommitted at retest: `docs/tests/T04a/run-checks.sh` (TC-T04a-30 rule 1) and the T04a Change log row. Ruling by the main session: a regression check fails on any FAIL line, a non-zero exit or a PASS count below the count at close; SKIP turning into PASS is not a regression |
| State history | Open (tester, 2026-11-02), Fixed (main session ruling and tester script change, 2026-11-02), Retest passed (tester, 2026-11-02) |
| Retest result | 2026-11-02: T04a `--regression` exit 0, no FAIL (`retest-def004/T04a-regression-4.txt`). TC-T04a-30 prints both numbers and passes with PASS now 119 and 355 against 118 and 354 at close. Four negative controls pass: equal and higher accepted, a PASS drop rejected, a FAIL line or non-zero exit rejected. TC-T05-21 passes (`retest-def004/static-run-4.txt`) |

**Steps to reproduce**

1. `docs/tests/T04a/run-checks.sh --regression`
2. See the two FAIL lines under TC-T04a-30: "T04 --regression: PASS now 119, at close 118, exit 0" and
   "T03 : PASS now 355, at close 354, exit 0".

**Expected:** a regression check fails when a check regresses.

**Actual:** both runs exit 0 with no FAIL line. They differ by one PASS each because the check
"pre-commit run on T03/T04 files passes" was SKIP when the stored close evidence was captured (hooks
unavailable) and now passes. The fixed counts in `docs/tests/T04a/run-checks.sh` make an
improvement look like a regression. The DEF-004 review says TC-T04a-30 rule 1 should be judged
against the scripts as of 990e95c, not the counts. Needs a decision by the technical-architect and
owner on how the rule is expressed (for example, no FAIL and exit 0, or refreshed close evidence).
I have not changed the expected result.

### DEF-006: T07 harness predates the build confirmation (review finding 1)

| Field | Value |
|---|---|
| ID | DEF-006 |
| Severity | Low (test-design defect; made TC-T07-13 to 16, 18 and 19 print FAIL) |
| Found in | T07 re-review, TC-T07-13, 14, 15, 16, 18, 19 |
| Status | Retest passed |
| Fix commit | Uncommitted at retest: `docs/tests/T07/run-checks.sh` and the T07 Change log |
| State history | Open (reviewer, 2026-11-02), Fixed (tester, 2026-11-02), Retest passed (tester, 2026-11-02) |
| Retest result | 2026-11-02: static run `evidence/static-part1.txt`: 31 PASS, 0 FAIL, 30 BLOCKED. Negative controls with broken script copies fail the right cases (`evidence/negative-controls-part1.txt`) |

**Steps to reproduce:** `docs/tests/T07/run-checks.sh` at 3794178.

**Expected:** a deploy against the fixture exits 0.

**Actual:** the fake `workflow:wait` printed `workflow done`, but the script (correctly, Terminus
4.3.3 facts b and c) requires `Workflow <id> completed successfully for commit <sha>`. Every
fixture deploy exited 1 and the later checks failed as a cascade. The fake now prints the 4.3.3
notice; timeout and not-found fakes were added; TC-T07-15 and 34 expect `--start=1` and
`env:code-log` on a re-run and have three negative re-run cases.

### DEF-007: Earlier regression suites fail on T07's legitimate changes (snapshots tagged as invariants)

| Field | Value |
|---|---|
| ID | DEF-007 |
| Severity | Low (test-design defect) |
| Found in | T07 review, TC-T04a-33, TC-T05-02, TC-T05-21, TC-T05-23, TC-T06-12, TC-T06-19 |
| Status | Retest passed |
| Fix commit | Uncommitted at retest: `docs/tests/T04a/run-checks.sh`, `docs/tests/T05/run-checks.sh`, `docs/tests/T06/run-checks.sh` and the three Change logs |
| State history | Open (reviewer, 2026-11-02), Fixed (tester, 2026-11-02), Retest passed (tester, 2026-11-02) |
| Retest result | 2026-11-02: `--regression` exits 0 for T02 to T06 and T07 (`evidence/regression-*-part1.txt`, `evidence/part1-rc.txt`): T05 24 PASS 0 FAIL, T06 and T04a green |

**Steps to reproduce:** `docs/tests/T05/run-checks.sh --regression` and the T04a and T06 equivalents
at 3794178.

**Expected:** invariant checks pass after T07; snapshot checks are skipped.

**Actual:** the T04a `.env.example` variable comparison (T07 changes `PANTHEON_SITE` and adds
variables), "no providers/pantheon.yaml" in T05 and T06 (T07 delivers it) and the T05 check that
treated the bare key `web_environment` as forbidden (KD-4 requires
`web_environment: [PANTHEON_SITE=meridian-trade]`) were tagged `ckp`. Fixes: the first two are
re-tagged `cka`; a new invariant checks `.env.example` for secret-shaped values; the T05 check now
inspects only the values under `web_environment`. TC-T05-21 and TC-T06-19 only nest these.

### DEF-008: Remaining T07 check problems found by review and by the first live run

| Field | Value |
|---|---|
| ID | DEF-008 |
| Severity | Low (test-design defect) |
| Found in | T07 review, TC-T07-07, 09, 10, 23, 27; part 1 live run, TC-T07-31, 42 |
| Status | Retest passed |
| Fix commit | Uncommitted at retest: `docs/tests/T07/run-checks.sh`, `docs/tests/T07/test-cases.md` |
| State history | Open (reviewer and tester, 2026-11-02), Fixed (tester, 2026-11-02), Retest passed (tester, 2026-11-02) |
| Retest result | 2026-11-02: static `evidence/static-part1.txt` and live `evidence/live-only-part1.txt` (the first live run, `live-only-part1-run1-before-check-fixes.txt`, showed the two live defects below) |

**Actual and fix, one line each**

- TC-T07-09 expected Terminus 3.6.2 and the inline `${{ inputs.ref }}`; now 4.3.3 with SHA-256
  `e7ca9bca...bade`, `--ref "$DEPLOY_REF"` through `env:`, and no `${{` in any `run:`.
- TC-T07-10 looked only for `actionlint` on PATH; it now uses `.tools/actionlint` first.
- TC-T07-23 regex could not match `$settings['config_sync_directory'] = ...`; fixed.
- TC-T07-07 and the live `GIT_SSH_COMMAND` strings lacked `GlobalKnownHostsFile=/dev/null`; added.
  The known-hosts content checks are Blocked until the key is committed, not Fail.
- TC-T07-27 is Blocked until `T07_CLOSE=1` (it is an at-close snapshot).
- TC-T07-31 (live) read the exit code through `; echo EXIT=$?`, which `ddev exec` never reaches
  after a failing command; it now uses `|| echo "EXIT=$?"`.
- TC-T07-42 (live) tested `web/sites/default/files`; the docroot is `apps/drupal/web`.
- The live gate and the TC-T07-42 precondition called `terminus auth:login` without
  `--machine-token` and tested `auth:whoami` by exit status; Terminus 4.3.3 needs the option, and
  `whoami` exits 0 when logged out (live item L-2 confirmed this).
- New cases: TC-T07-58 to 62 (Terminus pin, version in DDEV, budget, subdirectory, git_url forms).
