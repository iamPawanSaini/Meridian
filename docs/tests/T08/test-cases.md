# T08: Continuous integration baseline, Test cases

| Field | Value |
|---|---|
| Task | T08 |
| Author | tester |
| Date | 2026-11-03 |
| Criteria source | `docs/TASKS.md` T08 (AC1 to AC5 in the order listed there) and section 3.3 (C1 to C7); `docs/tasks/T08/plan.md` (Approved 2026-11-03); `decision-repo-visibility.md` (SA-1), `decision-native-quality.md` (SA-2), `decision-heavier-set.md` (SA-3) |
| Automation | `docs/tests/T08/run-checks.sh` (harness design note below; written in the test step) |
| Base for snapshot checks | `d935c2f` (T08 branch point, T07 merged) |

Criteria:

- AC1: `ci.yml` runs the full `ddev quality` suite defined in T04a (lint, format check, static
  analysis, type checks, commit and branch naming), plus unit tests per component with coverage
  thresholds, build, secret scan, dependency audit
- AC2: A deliberately failing test blocks merge on a demo pull request (branch protection
  configured)
- AC3: Pipeline total time under 10 minutes on a clean cache
- AC4: Test reports uploaded as workflow artifacts
- AC5: Required secrets listed in `docs/runbooks/ci-secrets.md` (names only)
- C1 to C7: common criteria, `docs/TASKS.md` section 3.3

## How to run

| Command | Covers |
|---|---|
| `docs/tests/T08/run-checks.sh` | Static and offline-harness cases. No network, no GitHub, no DDEV. Local-network, live-CI and owner-run cases are listed as BLOCKED with the reason |
| `docs/tests/T08/run-checks.sh --regression` | Invariant checks only (`ckp`); `cka` snapshot checks are skipped and counted (decision D-5) |
| `T08_NET=1 docs/tests/T08/run-checks.sh --local` | Local-network cases (secret history, audits, bootstrap checksum, clean clone) |
| `T08_DDEV=1 docs/tests/T08/run-checks.sh --ddev` | The DDEV parity case |
| `T08_EVIDENCE=1` | Writes `evidence/TC-T08-nn.<UTC run id>.txt` per case, redacted |

Rules that apply to every case:

- Modes: **static** (reads files), **offline harness** (runs scripts against temp copies, fixtures
  and fake tools on PATH, no network), **local run (network)**, **live CI run** (a GitHub Actions
  run; the tester reads logs and artifacts that the owner sends, because `gh` is not installed and
  the agent cannot open PRs), **owner-run** (the owner acts in GitHub Settings or the UI and sends
  evidence).
- Tags (decision D-5): `ckp` invariant, runs in every static mode including `--regression`; `cka`
  snapshot, true only at close, skipped by `--regression` and counted; `n/a` for live,
  local-network and owner-run cases.
- BLOCKED means the case cannot run here (no network, no DDEV, owner action pending). It is not a
  pass and does not change the exit status; the report lists each one. FAIL is a mismatch with the
  expected result and is a defect. A missing file makes every dependent check FAIL (nothing passes
  vacuously).
- Every negative control creates its faulty input in `$WORK` (a temp dir), never in the
  repository. Fake secret values are built at runtime and never written to a committed or evidence
  file.
- Owner-run cases name the evidence to send. The evidence is the owner's own output (URLs,
  screenshots or copied text); the tester cannot produce or accept it on the owner's behalf. A
  partial screenshot is insufficient evidence, so the case stays Blocked until the whole page is
  sent.
- Statements the plan marks **unverified** (cold/warm timing, the bypass label for a
  personal-account owner, the exact wording of the Actions and fork settings, `--log-opts`
  spelling, `shellcheck` on the runner) are decided by the pass and fail results written in the
  cases; the observed text is recorded either way.
- Result vocabulary in reports: Pass, Fail, Blocked, Not run.

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: `ci.yml` runs the full `ddev quality` suite (lint, format, static analysis, types, commit and branch naming), plus unit tests per component with coverage thresholds, build, secret scan, dependency audit | TC-T08-01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 31, 32, 33, 34, 35, 40, 48, 49, 50, 51, 65, 70 |
| AC2: Deliberately failing test blocks merge on a demo PR (branch protection configured) | TC-T08-02, 14, 52, 53, 54, 55, 56, 57, 67 |
| AC3: Pipeline total time under 10 minutes on a clean cache | TC-T08-58, 59, 60, 61 |
| AC4: Test reports uploaded as workflow artifacts | TC-T08-03, 12, 30, 62, 63, 64 |
| AC5: Required secrets listed in `docs/runbooks/ci-secrets.md` (names only) | TC-T08-32, 39, 42, 43, 66 |
| C1: Plan exists and was reviewed before coding | TC-T08-72 |
| C2: Code reviewed; findings resolved | TC-T08-18, 69, 72 |
| C3: Every criterion maps to an executed case; report has evidence | TC-T08-68, 73 |
| C4: CI green, no new lint, type or security warnings | TC-T08-16, 17, 19, 24, 35, 36, 37, 38, 41, 44, 45, 49, 51, 52 |
| C5: Docs and traceability updated | TC-T08-46, 47, 48, 68, 69 |
| C6: No secrets; `.env.example` updated | TC-T08-20, 21, 22, 23, 36, 37, 38, 43, 44, 46, 64, 65, 66, 67 |
| C7: Works from a clean checkout with documented commands | TC-T08-70, 71 |

Plan-driven coverage (not a criterion on its own; each is covered by the cases named):

| Plan item | Test cases |
|---|---|
| SA-2 condition 1 (no check logic in YAML) | TC-T08-04, 33 |
| SA-2 condition 2 (runner independence) | TC-T08-13 |
| SA-2 condition 3 (toolchain parity) | TC-T08-34, 70 |
| SA-2 condition 4 (accepted differences written down) | TC-T08-48 |
| SA-2 condition 5 (ddev quality stays the local gate) | TC-T08-70 |
| SA-3 (rule 6 tripwire, `.github/README.md` section, master plan note) | TC-T08-40, 47, 48 |
| SA-1 and KD-13 (public checklist and settings) | TC-T08-52, 53, 65, 66, 67 |
| KD-3 expected SKIPs (unlisted, listed-but-ran, bad line) | TC-T08-08, 09, 10, 11 |
| KD-12 `--regression` retrofit for T00 and T03 | TC-T08-16, 17, 18, 19 |
| Simulation-only rule and naming | TC-T08-44, 45 |
| Owner actions O-1 to O-8 | O-1: 65, 66, 67; O-2: 49; O-3, O-4: 52; O-5: 53; O-6: 54, 55, 56; O-7: 59, 60, 61; O-8: 51 |

## Cases

### TC-T08-01: ci.yml shape: name, triggers, runner, concurrency, no excluded features

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-8 |
| Mode | static |
| Tag | ckp |
| Preconditions | `.github/workflows/ci.yml` exists |
| Steps | 1. `grep -nE '^name:\|^on:\|pull_request\|push:\|workflow_dispatch\|branches\|paths\|runs-on\|concurrency\|cancel-in-progress\|^permissions' .github/workflows/ci.yml`<br>2. `grep -nE 'pull_request_target\|schedule:\|paths(-ignore)?:\|heavier-' .github/workflows/ci.yml` |
| Expected result | Step 1: `name: Meridian CI`; triggers `pull_request` (branches main; types opened, synchronize, reopened), `push` (branches main) and `workflow_dispatch`; every job `runs-on: ubuntu-24.04`; concurrency group `ci-${{ github.event.pull_request.number \|\| github.ref }}` with `cancel-in-progress` only for `pull_request`. Step 2: no match at all (no `pull_request_target`, no `schedule`, no path filters, no placeholder `heavier-*` job). Negative control: a temp copy with a `paths:` filter or `schedule:` added makes step 2 match (the check is not vacuous). |
| Actual result | |
| Evidence | `evidence/TC-T08-01.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-02: ci.yml jobs and the ci-ok gate

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2 |
| Plan item | KD-8, KD-10 |
| Mode | static |
| Tag | ckp |
| Preconditions | ci.yml exists |
| Steps | 1. List job ids (`grep -nE '^  [a-z-]+:$' .github/workflows/ci.yml`) and each job's `name:`<br>2. Read the `ci-ok` job: `needs`, `if`, step condition |
| Expected result | Exactly the jobs `core`, `docs`, `drupal`, `engine`, `web`, `ci-ok`; each job id equals its `name:`. `ci-ok` has `needs: [core, docs, drupal, engine, web]`, `if: always()`, and a step that exits 1 when `contains(needs.*.result, 'failure')`, `'cancelled'` or `'skipped'`. No `heavier-*` id in `needs`. Negative control: a temp copy of `ci-ok` without the `skipped` clause, or with a `heavier-x` need, is flagged by this case's grep (and by TC-T08-40 for the latter). |
| Actual result | |
| Evidence | `evidence/TC-T08-02.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-03: Every job calls quality.sh by group, natively, with checkout and artifact settings

| Field | Value |
|---|---|
| Linked criterion | AC1, AC4 |
| Plan item | KD-1, KD-8 |
| Mode | static |
| Tag | ckp |
| Preconditions | ci.yml exists |
| Steps | 1. For each of core, docs, drupal, engine, web: `grep -n 'quality.sh --group' .github/workflows/ci.yml`<br>2. `grep -nE 'QUALITY_RUNNER\|fetch-depth\|persist-credentials\|timeout-minutes\|shell: bash\|if: always\|name: reports-\|retention-days\|if-no-files-found' .github/workflows/ci.yml` |
| Expected result | Each of the five jobs calls `scripts/quality.sh --group <its own id>` once, piped through `tee .tools/reports/quality-<g>.txt` under `shell: bash` (so `pipefail` applies). Each job has `QUALITY_RUNNER: native`, `actions/checkout` with `fetch-depth: 0` and `persist-credentials: false`, `timeout-minutes: 10`, and an `actions/upload-artifact` step with `if: always()`, name `reports-<g>`, `retention-days: 14`, `if-no-files-found: warn`. Negative control: a temp copy where the `engine` job's call is deleted fails the grep count (5 expected). |
| Actual result | |
| Evidence | `evidence/TC-T08-03.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-04: No check logic in YAML (SA-2 condition 1)

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-1, SA-2 c1 |
| Mode | static |
| Tag | ckp |
| Preconditions | ci.yml exists |
| Steps | 1. List every `run:` command in ci.yml<br>2. Compare with the allow list: `scripts/bootstrap-dev.sh`, `scripts/quality.sh --group <g>`, `mkdir`/`tee`-style plumbing, the Composer version echo<br>3. Negative control: in a temp copy add `run: .tools/pre-commit run --all-files` and `run: vendor/bin/phpcs` and repeat step 2 |
| Expected result | Steps 1 and 2: every `run:` command is on the allow list; none invokes ruff, mypy, phpcs, phpstan, gitleaks, composer audit, npm, pytest or markdownlint directly. Step 3: both injected commands are reported as check logic in YAML (the check is not vacuous). Note for the developer: the exact allow list is set by the test script and recorded in the report. |
| Actual result | |
| Evidence | `evidence/TC-T08-04.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-05: quality.sh --list: stable listing of all steps and groups

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `scripts/quality.sh --list; echo rc=$?`<br>2. `scripts/quality.sh --list \| cut -f1 \| sort -u`<br>3. `scripts/quality.sh --list \| cut -f2` and compare with the KD-2 table |
| Expected result | rc=0; every line is `GROUP<TAB>STEP`; groups are exactly core, docs, drupal, engine, web; steps are exactly: pre-commit, branch-name, commit-range, exceptions, assets, tooling-tests, secret-history, ci-config (core); docs-regression (docs); build-drupal, component-drupal, component-drupal-tests, audit-drupal (drupal); build-engine, component-engine, audit-engine (engine); build-web, component-web, audit-web (web); each step in exactly one group; run order preserved (build-drupal first in drupal). The original 9 built-in steps are all still present (none dropped). Listing runs with no network and does not execute any step. |
| Actual result | |
| Evidence | `evidence/TC-T08-05.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-06: --group selection, unknown group, hook exclusion, scope

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none; QUALITY_STEPS fake file for step 4 |
| Steps | 1. `scripts/quality.sh --group engine --group web; echo rc=$?` (all SKIP steps)<br>2. `scripts/quality.sh --group nosuch; echo rc=$?`<br>3. `scripts/quality.sh --list` vs the set of step names printed by a no-argument run (checked in TC-T08-07)<br>4. `QUALITY_STEPS=$f scripts/quality.sh --group core; echo rc=$?`<br>5. `scripts/quality.sh --group; echo rc=$?` |
| Expected result | 1: only the six engine and web steps appear, each as SKIP with a reason; rc=0 (they are all listed in expected-skips); no core, docs or drupal step output. 2: rc=2 and a message naming the unknown group. 4: rc=2 (`--group` not allowed with the test hook). 5: rc=2 (missing argument). Negative: a group name with different case (`Core`) is unknown, rc=2. |
| Actual result | |
| Evidence | `evidence/TC-T08-06.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-07: Full local run: every step runs, SKIPs equal expected-skips.txt exactly

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2, KD-3, plan step 9 |
| Mode | local run (network) |
| Tag | ckp |
| Preconditions | Network available; `scripts/bootstrap-dev.sh` run; Composer dependencies installed |
| Steps | 1. `QUALITY_RUNNER=native scripts/quality.sh 2>&1 \| tee docs/tests/T08/evidence/TC-T08-07.txt; echo rc=${PIPESTATUS[0]}`<br>2. `grep -E '^(SKIP)' ...` and compare the SKIP step names with `quality/expected-skips.txt`<br>3. Compare PASS+FAIL+SKIP count with the number of lines of `--list` |
| Expected result | rc=0; summary `FAIL 0`; the set of SKIP step names equals the set of step names in `quality/expected-skips.txt` exactly (component-drupal-tests, build-engine, component-engine, audit-engine, build-web, component-web, audit-web at T08; no extra, none missing); PASS+SKIP equals the `--list` line count; each SKIP line gives a reason naming the absent manifest. Same run under `ddev quality` is TC-T08-70. |
| Actual result | |
| Evidence | `evidence/TC-T08-07.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-08: expected-skips.txt format and validation

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-3 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | `QUALITY_EXPECTED_SKIPS` test hook |
| Steps | 1. `cat quality/expected-skips.txt`<br>2. Temp file with a line `component-engine` (no ticket): `QUALITY_EXPECTED_SKIPS=$f scripts/quality.sh --group engine; echo rc=$?`<br>3. Temp file with line `nosuch-step  # T99: x`: same command<br>4. Temp file with a line `component-engine  # T13: x` and nothing else for engine |
| Expected result | 1: every non-blank line is `<known step>  # Txx: reason`; 7 lines at T08; each step is a real `--list` step. 2: rc=2 (line without a `# Txx:` ticket). 3: rc=2 (unknown step). 4: `build-engine` and `audit-engine` SKIP are reported as unexpected (see TC-T08-09). |
| Actual result | |
| Evidence | `evidence/TC-T08-08.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-09: Negative control: an unlisted SKIP fails

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-3 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `grep -v '^audit-web' quality/expected-skips.txt > $WORK/skips.txt`<br>2. `QUALITY_EXPECTED_SKIPS=$WORK/skips.txt scripts/quality.sh --group web; echo rc=$?` |
| Expected result | rc=1; output contains `unexpected SKIP: audit-web` and names the missing manifest; the other web steps (still listed) are not flagged. With the real file the same command gives rc=0 (positive control, same run). |
| Actual result | |
| Evidence | `evidence/TC-T08-09.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-10: Negative control: a listed step that actually runs fails

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-3 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copy of the repo files needed by quality.sh (scripts/, quality/, a fake `services/engine/pyproject.toml`) |
| Steps | 1. In the temp copy `touch services/engine/pyproject.toml`<br>2. `scripts/quality.sh --group engine; echo rc=$?` in the temp copy (real expected-skips file, `component-engine` still listed) |
| Expected result | rc=1; output contains `component-engine ran but is listed in quality/expected-skips.txt: remove the line`. The component's own gate also applies at once (it may FAIL or PASS on its own merits; the listed-but-ran message must appear regardless). After deleting the line from the temp file, the message is gone. |
| Actual result | |
| Evidence | `evidence/TC-T08-10.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-11: --group checks only the selected groups against expected-skips

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-3 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. Temp skips file that omits every engine line<br>2. `QUALITY_EXPECTED_SKIPS=$f scripts/quality.sh --group docs` (or `--group drupal`) |
| Expected result | No engine-related failure is reported when engine is not selected; the group's own steps behave normally. (With `--group engine` on the same file the failure appears, so the control is not vacuous.) |
| Actual result | |
| Evidence | `evidence/TC-T08-11.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-12: GITHUB_STEP_SUMMARY table

| Field | Value |
|---|---|
| Linked criterion | AC1, AC4 |
| Plan item | KD-2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `GITHUB_STEP_SUMMARY=$WORK/sum.md scripts/quality.sh --group engine; echo rc=$?; cat $WORK/sum.md`<br>2. Same without the variable, with `ls` of the temp dir<br>3. Same run with a step forced to FAIL via `QUALITY_STEPS` fake file |
| Expected result | 1: the file holds a Markdown table with one row per step and its result; every SKIP row includes its reason; rc unchanged (0). 2: no summary file is created anywhere; stdout identical to step 1. 3: the FAIL row appears and rc=1 (presentation never changes the exit code). The summary contains step names, statuses and reasons only. |
| Actual result | |
| Evidence | `evidence/TC-T08-12.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-13: Runner independence: same --list and SKIPs under native and ddev (SA-2 c2)

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-1, SA-2 c2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | A fake `ddev` first on PATH that records its calls and runs nothing (test hook, `$WORK/bin/ddev`) |
| Steps | 1. `QUALITY_RUNNER=native scripts/quality.sh --list > $WORK/n.txt`<br>2. `PATH=$WORK/bin:$PATH QUALITY_RUNNER=ddev scripts/quality.sh --list > $WORK/d.txt`<br>3. `diff $WORK/n.txt $WORK/d.txt`<br>4. Repeat with `--group engine --group web` and compare the SKIP lines (`grep ^SKIP`)<br>5. `python3 -m unittest scripts.tests.test_quality_sh -v` and confirm a test for this condition is listed and passes |
| Expected result | Step 3: no difference. Step 4: SKIP lines and reasons identical for both runners; the fake ddev log shows only calls for steps that run (none for SKIP). Step 5: a named test covers the condition and passes. Negative control: a temp copy of quality.sh whose manifest test reads `QUALITY_RUNNER` makes step 3 or 4 differ (documented as the fault this case would catch). |
| Actual result | |
| Evidence | `evidence/TC-T08-13.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-14: tooling-tests step runs both suites; a failing test fails it and is named

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2 |
| Plan item | KD-2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copy of the repo with `scripts/tests/test_zz_demo_fail.py` containing one failing unittest |
| Steps | 1. `python3 -m unittest discover -s scripts/tests; echo rc=$?` and `python3 -m unittest discover -s .claude/hooks/tests; echo rc=$?` in the real tree<br>2. In the temp copy run the `tooling-tests` step command (`scripts/quality.sh --group core` with the other core steps allowed to run, or the step command directly) |
| Expected result | 1: both rc=0 and the test count is non-zero (not vacuous: count recorded). 2: the step reports FAIL, the output names `test_zz_demo_fail` and the failure message, and the run exit status is 1. Removing the temp test restores PASS. This is the offline twin of the AC2 demo (TC-T08-54). |
| Actual result | |
| Evidence | `evidence/TC-T08-14.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-15: docs-regression step covers every docs-task suite

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2, KD-12 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Existing `docs/tests/T*/run-checks.sh` |
| Steps | 1. `ls docs/tests/T*/run-checks.sh`<br>2. Run the `docs-regression` step: `scripts/quality.sh --group docs`<br>3. Temp copy with an extra `docs/tests/T99/run-checks.sh` that exits 1 under `--regression`<br>4. Temp copy with a suite that ignores `--regression` and runs a snapshot check that fails |
| Expected result | 2: the log shows one section per script (T00, T02, T03, T04, T04a, T05, T06, T07 at T08), each run with `--regression`, and the step is PASS. 3: step FAIL and the output names `T99/run-checks.sh`. 4: documents that a suite not honouring `--regression` is a defect in that suite (reported, not hidden). BLOCKED and optional-tool SKIP lines inside a suite do not fail the step (confirmed with T07, whose live cases are BLOCKED). No suite is skipped silently: the script count in the log equals the file count from step 1. |
| Actual result | |
| Evidence | `evidence/TC-T08-15.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-16: T00 run-checks.sh accepts --regression

| Field | Value |
|---|---|
| Linked criterion | AC1, C4 |
| Plan item | KD-12, D-5 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Retrofit by the tester (design step); Change log row in `docs/tests/T00/test-cases.md` |
| Steps | 1. `docs/tests/T00/run-checks.sh --regression; echo rc=$?`<br>2. `docs/tests/T00/run-checks.sh; echo rc=$?` (default mode)<br>3. `docs/tests/T00/run-checks.sh --bogus; echo rc=$?`<br>4. Temp copy with `docs/templates/runbook.md` renamed, then step 1 |
| Expected result | 1: rc=0, prints the count of excluded snapshot checks and the reason (decision D-5), no `SKIP` for excluded checks. 2: rc=0. 3: rc=2 and a usage message. 4: rc=1 in `--regression` mode (an invariant failure is not masked). The total number of checks in default mode is not lower than before the retrofit (no check removed; see TC-T08-18). |
| Actual result | |
| Evidence | `evidence/TC-T08-16.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-17: T03 run-checks.sh accepts --regression

| Field | Value |
|---|---|
| Linked criterion | AC1, C4 |
| Plan item | KD-12, D-5 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Retrofit by the tester; Change log row in `docs/tests/T03/test-cases.md` |
| Steps | 1. `docs/tests/T03/run-checks.sh --regression; echo rc=$?`<br>2. `docs/tests/T03/run-checks.sh; echo rc=$?`<br>3. `docs/tests/T03/run-checks.sh --bogus; echo rc=$?`<br>4. Temp copy with `docs/architecture/openapi.yaml` truncated, then step 1 |
| Expected result | Same expectations as TC-T08-16: rc=0, 0 and 2 for steps 1 to 3 and rc=1 for step 4; excluded-count line printed. Checks that depend on text pending a later task (for example the sign-off date line, exact counts such as the 49 planned tests, or named-branch comparisons) may be tagged `cka` only with a recorded justification. |
| Actual result | |
| Evidence | `evidence/TC-T08-17.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-18: Retag review: no check removed or loosened by the T00 and T03 retrofit

| Field | Value |
|---|---|
| Linked criterion | C2, AC1 |
| Plan item | KD-12, D-5 |
| Mode | static |
| Tag | cka |
| Preconditions | Base commit d935c2f available |
| Steps | 1. Count `PASS`/`FAIL` lines of default-mode runs of T00 and T03 at `d935c2f` (via `git stash`-free `git worktree add $WORK/base d935c2f`) and at HEAD<br>2. `git diff d935c2f..HEAD -- docs/tests/T00/run-checks.sh docs/tests/T03/run-checks.sh`<br>3. Read the Change log rows of both `test-cases.md` |
| Expected result | Default-mode check count at HEAD is greater than or equal to the count at base for both suites; the diff shows only added `ckp`/`cka` tagging and the `--regression` parsing, no deleted check and no loosened pattern; every `cka` has a justification naming the later task or reason; each file has a Change log row citing D-5 and T08. The architect reviews the retag at `/review-task`. |
| Actual result | |
| Evidence | `evidence/TC-T08-18.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-19: All docs-task suites pass in --regression mode on the branch

| Field | Value |
|---|---|
| Linked criterion | AC1, C4 |
| Plan item | KD-12 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. For each of T00, T02, T03, T04, T04a, T05, T06, T07: `docs/tests/<T>/run-checks.sh --regression 2>&1 \| tee docs/tests/T08/evidence/TC-T08-19.<T>.txt`<br>2. `grep -c cka` is not needed; record the excluded count printed by each |
| Expected result | Each exits 0; no FAIL line; each prints an excluded-checks count (0 or more) with the D-5 reason; BLOCKED lines are listed but do not change the exit code. A suite failing an invariant is logged as a defect against that suite's task (never retagged to snapshot without the D-5 justification). |
| Actual result | |
| Evidence | `evidence/TC-T08-19.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-20: secret-history step: pinned gitleaks over the full history, redacted report

| Field | Value |
|---|---|
| Linked criterion | AC1, C6 |
| Plan item | KD-4 |
| Mode | local run (network) |
| Tag | ckp |
| Preconditions | `.tools/gitleaks` installed by bootstrap |
| Steps | 1. `grep -n 'gitleaks' scripts/quality.sh` to read the step command<br>2. `scripts/quality.sh --group core 2>&1 \| tee docs/tests/T08/evidence/TC-T08-20.txt` (or the step alone)<br>3. `.tools/gitleaks version`; `python3 -m json.tool .tools/reports/gitleaks.json` |
| Expected result | The command contains `gitleaks git`, `--redact`, `--config .gitleaks.toml`, `--report-format json` and `--report-path .tools/reports/gitleaks.json` and no `--staged`/`--pre-commit`. The step is PASS, `gitleaks version` prints 8.30.1, the report is valid JSON and is `[]` (0 findings in the full history, NFR-10). The report is written under `.tools/reports/`. |
| Actual result | |
| Evidence | `evidence/TC-T08-20.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-21: Negative control: fake secret found and redacted; missing tool fails

| Field | Value |
|---|---|
| Linked criterion | AC1, C6 |
| Plan item | KD-4 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Scratch git repo in `$WORK` with a copy of `.gitleaks.toml`; the fake secret is built at runtime from parts, never typed into a committed file; pattern from `scripts/demo-secret-scan.sh` |
| Steps | 1. In the scratch repo commit a file holding the fake secret, then commit a second change that deletes it (it stays in history)<br>2. Run the exact secret-history command in the scratch repo; `echo rc=$?`<br>3. `grep -c '<fake secret value>' $WORK/gitleaks.json`<br>4. Run the step with `.tools/gitleaks` hidden and no `gitleaks` on PATH (`env -i PATH=/usr/bin:/bin`, temp copy without `.tools`) |
| Expected result | 2: rc=1 and the report lists at least one finding with a rule id (history scan finds the deleted secret, which `--staged` would not). 3: count 0 (the value is redacted in the report). 4: the step FAILs with a missing-tool message (a missing scanner is never a pass). The fake value appears in no committed or evidence file. |
| Actual result | |
| Evidence | `evidence/TC-T08-21.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-22: Tool pins: pre-commit, gitleaks, actionlint with SHA-256

| Field | Value |
|---|---|
| Linked criterion | AC1, C6 |
| Plan item | KD-4 |
| Mode | static |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `grep -nE '^(PRE_COMMIT\|GITLEAKS\|ACTIONLINT)_' scripts/tool-versions.env`<br>2. `grep -n 'rev:' -B1 .pre-commit-config.yaml \| grep -A1 gitleaks`<br>3. Read `scripts/bootstrap-dev.sh` for the checksum comparison and the platform guard |
| Expected result | `PRE_COMMIT_SHA256` is non-empty and 64 hex characters (the open item from T00 closed); `GITLEAKS_VERSION=8.30.1` with a 64-hex `GITLEAKS_SHA256`; `ACTIONLINT_VERSION=1.7.12` with a 64-hex SHA-256; the pre-commit gitleaks `rev` equals the pinned version. Bootstrap compares each download with its SHA-256 and exits non-zero on mismatch, and exits with a clear message on a platform other than Linux x86_64. The source URL and check date of each value are recorded in `.github/README.md` or the pins table. |
| Actual result | |
| Evidence | `evidence/TC-T08-22.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-23: Negative control: bootstrap rejects a wrong checksum

| Field | Value |
|---|---|
| Linked criterion | AC1, C6 |
| Plan item | KD-4 |
| Mode | local run (network) |
| Tag | ckp |
| Preconditions | Network; temp copy of the repo with an empty `.tools/` |
| Steps | 1. In the temp copy change one hex digit of `GITLEAKS_SHA256`<br>2. `scripts/bootstrap-dev.sh; echo rc=$?`<br>3. `ls -l .tools/gitleaks`<br>4. Repeat for `ACTIONLINT_SHA256` and `PRE_COMMIT_SHA256` |
| Expected result | Each run exits non-zero with a checksum-mismatch message; `.tools/<binary>` is not installed (absent or unchanged). With the correct values the same command installs the binary and `.tools/<binary> version` prints the pinned version (positive control). If there is no network, mark Blocked (not Fail). |
| Actual result | |
| Evidence | `evidence/TC-T08-23.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-24: actionlint local hook: configuration, clean on both workflows, rejects a bad workflow

| Field | Value |
|---|---|
| Linked criterion | AC1, C4 |
| Plan item | KD-5 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | `.tools/actionlint` installed |
| Steps | 1. `grep -n 'actionlint' -B2 -A8 .pre-commit-config.yaml`<br>2. `.tools/pre-commit run actionlint --files .github/workflows/ci.yml .github/workflows/deploy-drupal.yml; echo rc=$?`<br>3. Temp copy of ci.yml with an unknown key and an invalid expression (`${{ nosuch.x }}`): run `.tools/actionlint $f; echo rc=$?`<br>4. Temp copy without `.tools/actionlint`: run the hook |
| Expected result | 1: `id: actionlint`, `language: system`, `entry: .tools/actionlint`, `files: ^\.github/workflows/.*\.ya?ml$`. 2: Passed, rc=0 for both files. 3: rc=1 with both errors reported. 4: the hook fails (missing tool), never passes. Record whether `shellcheck` was on PATH and so whether `run:` blocks were checked. |
| Actual result | |
| Evidence | `evidence/TC-T08-24.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-25: audit-drupal step: command, current lock is clean

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2 |
| Mode | local run (network) |
| Tag | ckp |
| Preconditions | Network; Composer installed; `apps/drupal/composer.lock` exists |
| Steps | 1. `grep -n 'composer audit' scripts/quality.sh`<br>2. `cd apps/drupal && composer audit --locked --abandoned=report --no-interaction 2>&1 \| tee ../../docs/tests/T08/evidence/TC-T08-25.txt; echo rc=${PIPESTATUS[0]}` |
| Expected result | Step 1 shows `--locked` and `--abandoned=report`. Step 2: rc=0, `No security vulnerability advisories found`; abandoned packages (if any) are listed but do not fail. If the audit finds an advisory, that is a real finding to report (Fail), not to ignore. |
| Actual result | |
| Evidence | `evidence/TC-T08-25.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-26: Negative control: a known-vulnerable dependency fails the audit

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2 |
| Mode | local run (network) |
| Tag | ckp |
| Preconditions | Network; scratch project in `$WORK` (not under `apps/drupal`) |
| Steps | 1. In the scratch project require a package version with a published advisory (the tester picks one, for example an old release of a Symfony or Drupal core package, and records its advisory ID from `composer audit`); generate a lock with `composer update --no-install --no-audit` and `config.audit.block-insecure=false` if Composer refuses<br>2. `composer audit --locked --abandoned=report --no-interaction; echo rc=$?` |
| Expected result | rc is non-zero and the output names the advisory ID. Then add `config.audit.ignore` with that ID in the object form `{"<ID>": "T99: reason, review by YYYY-MM-DD"}` and rerun: rc=0 (the ignore mechanism works). The vulnerable package name is recorded; the repository files are untouched. If a suitable advisory cannot be found offline, Blocked with the reason (never skipped to Pass). |
| Actual result | |
| Evidence | `evidence/TC-T08-26.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-27: Negative control: audit with no network fails, never passes

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | `unshare -rn` available (else Blocked) |
| Steps | 1. `cd apps/drupal && unshare -rn composer audit --locked --abandoned=report --no-interaction; echo rc=$?`<br>2. The same through the step: `unshare -rn scripts/quality.sh --group drupal; echo rc=$?` |
| Expected result | Both non-zero; the step shows `audit-drupal` FAIL (not SKIP, not PASS). The `scripts/README.md` and `local-setup.md` state that audits need network. If `unshare` is unavailable, Blocked with the reason. |
| Actual result | |
| Evidence | `evidence/TC-T08-27.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-28: exceptions report lists Composer audit.ignore entries

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copy with a composer.json that has an object-form `config.audit.ignore` |
| Steps | 1. Add `"audit": {"ignore": {"CVE-0000-0000": "T99: reason, review by 2027-01-01"}}` under `config` in the temp copy<br>2. `python3 scripts/exceptions_report.py` in the temp copy<br>3. Same on the real tree |
| Expected result | 2: the report lists the entry with its ID, ticket and review date, and the count increases by one. 3: the real tree lists no audit ignore (none are expected at T08). An entry without a `Txx:` ticket or a review date is flagged (reported as a violation), not silently accepted. |
| Actual result | |
| Evidence | `evidence/TC-T08-28.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-29: build-drupal: install and platform check; SKIP when composer.lock is absent

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-2 |
| Mode | local run (network) |
| Tag | ckp |
| Preconditions | Network; PHP and Composer available |
| Steps | 1. `cd apps/drupal && composer install --no-interaction --no-progress && composer check-platform-reqs --lock; echo rc=$?`<br>2. Temp copy without `apps/drupal/composer.lock`: `scripts/quality.sh --group drupal` |
| Expected result | 1: rc=0 and no missing platform requirement. 2: `build-drupal` and `audit-drupal` SKIP with the manifest named; since they are not in expected-skips this is also reported as an unexpected SKIP (rc=1), proving the rule covers the new steps. |
| Actual result | |
| Evidence | `evidence/TC-T08-29.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-30: JUnit and coverage report paths match the artifact list

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-2, KD-8 |
| Mode | static |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `grep -nE 'junit\|coverage' scripts/quality.sh`<br>2. `grep -nA14 'upload-artifact' .github/workflows/ci.yml` |
| Expected result | The component test commands write JUnit XML (`--log-junit junit.xml` for PHPUnit, `--junitxml=junit.xml` for pytest, a JUnit reporter for web) and coverage XML to the paths that ci.yml uploads: `.tools/reports/`, `services/engine/junit.xml` and `coverage.xml`, `apps/drupal/junit.xml` and `coverage.xml`, `apps/web/junit.xml` and `apps/web/coverage/cobertura-coverage.xml`. A path in the workflow with no producer in quality.sh (or the reverse) is a Fail. |
| Actual result | |
| Evidence | `evidence/TC-T08-30.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-31: Coverage floors unchanged; the gate itself is tested in CI

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-9 |
| Mode | static |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `git diff d935c2f..HEAD -- quality/coverage-thresholds.json coverage_gate.py scripts/coverage_gate.py`<br>2. `python3 -m unittest scripts.tests.test_coverage_gate -v`<br>3. `grep -rn 'coverage' scripts/quality.sh \| grep -iE 'threshold\|floor\|--min'` |
| Expected result | 1: no change to the threshold file or the gate script (floors engine scoring/risk 90, engine 85, Drupal custom 70, web 80). 2: tests pass and run inside `tooling-tests` (name appears in the TC-T08-14 test list). 3: no step passes a lowered floor on the command line. |
| Actual result | |
| Evidence | `evidence/TC-T08-31.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-32: check_ci.py: standard library only; passes on the real repo; wired as ci-config

| Field | Value |
|---|---|
| Linked criterion | AC1, AC5 |
| Plan item | KD-6 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `python3 -I scripts/check_ci.py; echo rc=$?`<br>2. `python3 -I -c "import ast; t=ast.parse(open('scripts/check_ci.py').read()); print(sorted({a.name.split('.')[0] for n in ast.walk(t) if isinstance(n,ast.Import) for a in n.names}\|{n.module.split('.')[0] for n in ast.walk(t) if isinstance(n,ast.ImportFrom) and n.module}))"`<br>3. `scripts/quality.sh --list \| grep ci-config`<br>4. `python3 -m unittest scripts.tests.test_check_ci -v` |
| Expected result | 1: rc=0 with one PASS line per rule 1 to 6. 2: only standard-library modules (no yaml). 3: `core<TAB>ci-config` listed. 4: tests pass; fixtures exist under `scripts/tests/fixtures/ci/` for each rule, one passing and one failing (list recorded). |
| Actual result | |
| Evidence | `evidence/TC-T08-32.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-33: check_ci rule 1: group coverage (negative controls)

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-6 rule 1 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copies of ci.yml |
| Steps | 1. Remove the `docs` job's `quality.sh --group docs` call<br>2. Call `--group core` in two jobs<br>3. Add a call to a group that `--list` does not have<br>4. `python3 scripts/check_ci.py --workflows $WORK/wf; echo rc=$?` for each |
| Expected result | Each of 1 to 3 gives rc=1 with a message naming the group (missing, duplicated, unknown). The real ci.yml gives rc=0. The set of groups compared comes from `quality.sh --list` (adding a group there without ci.yml fails). |
| Actual result | |
| Evidence | `evidence/TC-T08-33.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-34: check_ci rule 2: toolchain parity (negative controls)

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-6 rule 2, SA-2 c3 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copies of ci.yml, `.ddev/config.yaml`, `apps/drupal/pantheon.yml`, `.github/README.md` |
| Steps | 1. `php-version: '8.2'` in ci.yml<br>2. `php_version` changed in the DDEV copy, then in the pantheon copy<br>3. `tools: composer:2.0.0` while the README line says another version<br>4. Remove the Composer line from the README copy<br>5. Run `python3 scripts/check_ci.py` on the real tree |
| Expected result | 1 to 4: each rc=1 with a message naming the two values that differ (4 fails for a missing record, not a pass). 5: rc=0 and ci.yml `php-version` equals `php_version` in both config files (record 8.3). The README Composer line carries a date and the output of `ddev exec composer --version` (checked by reading it; it is re-verified on DDEV in TC-T08-70). Python 3.12.16 and Node 22.23.4 rules are asserted as not yet applicable (no engine/web setup step) and become cases at T13 and T21. |
| Actual result | |
| Evidence | `evidence/TC-T08-34.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-35: check_ci rule 3: action pins and comments (negative controls)

| Field | Value |
|---|---|
| Linked criterion | AC1, C4 |
| Plan item | KD-6 rule 3 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copies of workflows |
| Steps | 1. `uses: actions/checkout@v7`<br>2. A 39-hex SHA<br>3. A 40-hex SHA with no `# owner/repo vX.Y.Z` comment on the line above<br>4. A branch ref (`@main`)<br>5. `uses: ./local` (allowed)<br>6. Real tree: `python3 scripts/check_ci.py`; list every `uses:` in `.github/workflows/*.yml` |
| Expected result | 1 to 4: rc=1 naming the line. 5: accepted. 6: rc=0; the third-party actions used in both workflows are only actions/checkout, actions/setup-python, actions/cache, actions/upload-artifact and shivammathur/setup-php, and every one is a 40-hex SHA with a version comment. The `actions/checkout` SHA equals the deploy-drupal.yml SHA (3d3c42e5aac5ba805825da76410c181273ba90b1). |
| Actual result | |
| Evidence | `evidence/TC-T08-35.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-36: Action SHAs verified and recorded (not typed from memory)

| Field | Value |
|---|---|
| Linked criterion | C4, C6 |
| Plan item | KD-8, plan 'Items for the main session' |
| Mode | static |
| Tag | ckp |
| Preconditions | `.github/README.md` written |
| Steps | 1. Read the pins table in `.github/README.md`<br>2. For each action, compare the SHA in ci.yml with the table |
| Expected result | Each action has owner/repo, version, full SHA, source URL (release page) and the date checked; the SHAs in the table equal those in ci.yml. Record in the report that the SHAs were not independently re-fetched by the tester unless network was available (then each SHA is verified against the tag with `git ls-remote https://github.com/<owner>/<repo> refs/tags/<tag>*`, evidence stored). A mismatch is a Fail. |
| Actual result | |
| Evidence | `evidence/TC-T08-36.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-37: check_ci rule 5: least privilege (negative controls)

| Field | Value |
|---|---|
| Linked criterion | C4, C6 |
| Plan item | KD-6 rule 5, KD-8 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copies of workflows |
| Steps | 1. Remove the top-level `permissions:`<br>2. Add `contents: write` to a job without a `# Txx:` comment<br>3. Same with a `# T08: reason` comment<br>4. Real tree: read `permissions` in ci.yml |
| Expected result | 1 and 2: rc=1. 3: accepted. 4: top-level `permissions: {}` and `contents: read` per job; no `write` anywhere in ci.yml; deploy-drupal.yml passes the rule. `check_ci.py` run on the real tree gives rc=0. |
| Actual result | |
| Evidence | `evidence/TC-T08-37.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-38: ci.yml uses no secrets and has no injection-prone expressions

| Field | Value |
|---|---|
| Linked criterion | C6, C4 |
| Plan item | KD-8 |
| Mode | static |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `grep -nE 'secrets\.\|vars\.' .github/workflows/ci.yml`<br>2. `grep -nE '\$\{\{ *github\.(event\|head_ref)' .github/workflows/ci.yml` inside `run:` blocks<br>3. `git diff d935c2f..HEAD -- .env.example` |
| Expected result | 1: no match other than `GITHUB_TOKEN` (and ideally none). 2: no `github.event.*` or `head_ref` expression inside any `run:` (pass them through `env:` if needed). 3: empty diff (no new variable; the report states this for C6). |
| Actual result | |
| Evidence | `evidence/TC-T08-38.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-39: check_ci rule 4: secret and variable names documented, both directions

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Plan item | KD-6 rule 4 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copies of `docs/runbooks/ci-secrets.md` and a workflow |
| Steps | 1. Temp workflow that references `secrets.NEW_UNLISTED_NAME`<br>2. Temp workflow with `vars.NEW_UNLISTED_VAR`<br>3. Workflow with only `secrets.GITHUB_TOKEN`<br>4. Real tree: `python3 scripts/check_ci.py --secrets-doc docs/runbooks/ci-secrets.md`<br>5. Real tree: extract every `secrets.X`/`vars.X` from `.github/workflows/*.yml` and `grep -c` each in ci-secrets.md |
| Expected result | 1 and 2: rc=1 naming the missing name (negative control: the name is absent from the doc). 3: accepted (GITHUB_TOKEN exempt). 4: rc=0. 5: `TERMINUS_MACHINE_TOKEN`, `PANTHEON_DEPLOY_KEY` (secrets) and `PANTHEON_SITE`, `DEPLOY_SMOKE_BUDGET` (variables) are all present, plus `DEPLOY_SMOKE_HEADER` as a variable or as a secret exactly as the workflow now uses it (TC-T08-66). |
| Actual result | |
| Evidence | `evidence/TC-T08-39.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-40: check_ci rule 6: heavier-set tripwire (fixtures and negative controls)

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | KD-6 rule 6, SA-3 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Fixture trees under `scripts/tests/fixtures/ci/` and temp trees built by the case |
| Steps | For each marker, build a temp tree and run `python3 scripts/check_ci.py --root $TREE --workflows $WF`: (a) `apps/drupal/web/modules/custom/x/tests/src/Functional/FooTest.php`; (b) `.../FunctionalJavascript/BarTest.php`; (c) `services/engine/tests/test_x.py` containing `drupal_live`; (d) `apps/web/playwright.config.ts`; (e) `.ddev/commands/web/e2e`<br>Each with a ci.yml that has no `heavier-` job, then with a `heavier-drupal` job, then with `heavier-drupal` listed in `ci-ok` `needs`<br>Controls: a Unit or Kernel test file only; a `*Test.php` in `tests/src/Unit/`; the string `drupal_live` in a non-test directory |
| Expected result | Marker present and no `heavier-` job: rc=1 with `heavier-set tests exist but ci.yml has no heavier-* job (decision-heavier-set.md)`. Marker plus a `heavier-*` job: rc=0. `heavier-*` in `ci-ok` needs: rc=1 (never a required check). Controls (Unit, Kernel, wrong directory): rc=0 (no false positive). The real tree (no marker, no heavier job): rc=0. |
| Actual result | |
| Evidence | `evidence/TC-T08-40.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-41: ci.yml passes actionlint, yamllint and the full pre-commit run

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Plan item | KD-5, plan step 9 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | `.tools/` tools installed |
| Steps | 1. `.tools/actionlint .github/workflows/ci.yml .github/workflows/deploy-drupal.yml; echo rc=$?`<br>2. `.tools/pre-commit run --all-files 2>&1 \| tail -30; echo rc=${PIPESTATUS[0]}` |
| Expected result | Both rc=0, no warnings. All hooks (yamllint, markdownlint, shellcheck, ruff, mypy, gitleaks staged hook, actionlint) report Passed or Skipped (no files); the output is stored. |
| Actual result | |
| Evidence | `evidence/TC-T08-41.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-42: ci-secrets.md: sections, content, and names only

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Plan item | KD-6, plan 'Interfaces touched' |
| Mode | static |
| Tag | ckp |
| Preconditions | `docs/runbooks/ci-secrets.md` exists |
| Steps | 1. Compare headings with `docs/templates/runbook.md` (When to use, Prerequisites, Steps, Verification, Rollback)<br>2. Read the tables of secrets and variables |
| Expected result | All runbook sections present. It states: `ci.yml` uses no secrets (only the read-only `GITHUB_TOKEN`); `deploy-drupal.yml`: secrets `TERMINUS_MACHINE_TOKEN`, `PANTHEON_DEPLOY_KEY`, variables `PANTHEON_SITE`, `DEPLOY_SMOKE_BUDGET`, plus `DEPLOY_SMOKE_HEADER` classified as the owner decided in KD-13 item 2; planned `daily-run.yml` names from technical-design D7 marked `planned, T20`; the merge-method setting and its reason (T04a D-3). Each name appears with where it is set and who rotates it, and no value. |
| Actual result | |
| Evidence | `evidence/TC-T08-42.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-43: ci-secrets.md has no values (negative control for a value-like string)

| Field | Value |
|---|---|
| Linked criterion | AC5, C6 |
| Plan item | AC5 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copy of ci-secrets.md |
| Steps | 1. Scan the real file: `gitleaks dir` (or `.tools/gitleaks detect --no-git --source docs/runbooks/ci-secrets.md --redact`) and `grep -nE '[A-Za-z0-9+/_-]{32,}\|-----BEGIN\|://[^ /]*:[^ /@]*@\|(ghp\|github_pat\|sk-ant)[_-]'`<br>2. Negative control: append `TERMINUS_MACHINE_TOKEN=Zk3...` (a fake 40-character value built at runtime) to a temp copy and rerun step 1 |
| Expected result | Step 1 on the real file: gitleaks 0 findings and no grep match other than the allowed SHA-256 or SHA references if any (each match inspected and listed). Step 2: both the scanner and the grep flag the appended value (the check is not vacuous). No password, token, header value or Pantheon site token text appears. |
| Actual result | |
| Evidence | `evidence/TC-T08-43.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-44: Simulation-only: no broker name, API or trading domain in T08 files

| Field | Value |
|---|---|
| Linked criterion | C4, C6 |
| Plan item | CLAUDE.md simulation rule |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `git diff --name-only d935c2f..HEAD` to list changed files<br>2. `grep -niE "$SIM_BR" <those files> .github/workflows/*.yml quality/expected-skips.txt apps/drupal/composer.json` with the T07 `SIM_BR` pattern<br>3. `git diff d935c2f..HEAD -- apps/drupal/composer.lock composer.json` for any new package; check names against the pattern<br>4. Negative control: a temp copy of an audit allowlist file containing `kite.trade` and `place_order`: rerun step 2 |
| Expected result | 2: no match in any T08 file, in any workflow or in any audit ignore list or allowlist (the T08 test files themselves are excluded because they contain the pattern as data; the exclusion is listed). 3: no new package at all, or none matching. 4: both strings are found (control not vacuous). |
| Actual result | |
| Evidence | `evidence/TC-T08-44.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-45: check-names.sh is clean; naming rules

| Field | Value |
|---|---|
| Linked criterion | C4 |
| Plan item | section 0 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `scripts/check-names.sh; echo rc=$?`<br>2. Negative control: create a temp file containing a stale placeholder name built from two parts and rerun; remove it<br>3. `grep -n 'name:' .github/workflows/ci.yml \| head -1` |
| Expected result | 1: rc=0. 2: rc=1 (control). 3: workflow display name is `Meridian CI`. Workflow file name is `ci.yml`. Job and artifact names use the plan's ids only. |
| Actual result | |
| Evidence | `evidence/TC-T08-45.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-46: README simulation-only notice

| Field | Value |
|---|---|
| Linked criterion | C5, C6 |
| Plan item | KD-13 item 5 |
| Mode | static |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `grep -n 'Simulation-only research software. It places no orders and gives no investment advice.' README.md`<br>2. `.tools/pre-commit run markdownlint --files README.md` |
| Expected result | The exact sentence is in the top-level README.md (first screen: within the first 30 lines); markdownlint passes. A reworded notice is a Fail (the wording is part of the owner's publication checklist). |
| Actual result | |
| Evidence | `evidence/TC-T08-46.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-47: Master test plan heavier-set note and Change log row

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Plan item | KD-14 item 3, SA-3 |
| Mode | static |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `grep -n 'PR-set jobs in' docs/tests/master-test-plan.md`<br>2. `grep -n 'Until the first heavier-set job exists (T10)' docs/tests/master-test-plan.md`<br>3. `grep -n 'Change log' -A6 docs/tests/master-test-plan.md`<br>4. `grep -c 'T08 implements the jobs in' docs/tests/master-test-plan.md` |
| Expected result | Steps 1 to 3 match; the Change log row cites SA-3 and KD-14; step 4 prints 0 (the old sentence is gone). Done by the tester at design time on 2026-11-03. |
| Actual result | |
| Evidence | `evidence/TC-T08-47.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-48: Docs: accepted differences, heavier-set contract, links, standards

| Field | Value |
|---|---|
| Linked criterion | C5, AC1 |
| Plan item | KD-1 c4, KD-14, Scope |
| Mode | static |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `grep -n 'Accepted differences' -A12 scripts/README.md`<br>2. `grep -n 'Adding the heavier set' -A25 .github/README.md`<br>3. `grep -nE 'QUALITY_RUNNER\|QUALITY_EXPECTED_SKIPS\|--group\|--list\|network' scripts/README.md`<br>4. `grep -nE 'gitleaks\|actionlint\|setup-php\|composer' docs/standards/CODING_STANDARDS.md`<br>5. `grep -nE 'bootstrap\|audit\|network' docs/runbooks/local-setup.md`; `grep -n 'ci-secrets' docs/runbooks/README.md`<br>6. `.tools/pre-commit run --files <those docs>` |
| Expected result | 1: three differences (Ubuntu runner against DDEV Debian; setup-php against ddev-webserver extension sets with `composer check-platform-reqs --lock` as the cover; PHP patch level floats) and the sentence that a check passing in only one place is a defect. 2: ids `heavier-<area>`, never in `ci-ok` needs, the four triggers (nightly `schedule` off the hour, `workflow_dispatch`, `push` to main, `pull_request` with label `heavier-set`), `timeout-minutes` 30, artifact `reports-heavier-<area>`, T10/T27 choose DDEV or native. 3 to 5: the new flags, hooks, bootstrap re-run and network need are documented; ci-secrets.md is linked from the runbook index. 6: lint passes; all relative links resolve (link checker run). |
| Actual result | |
| Evidence | `evidence/TC-T08-48.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-49: Live: CI run on the T08 pull request, all jobs green, steps match the suite

| Field | Value |
|---|---|
| Linked criterion | AC1, C4 |
| Plan item | KD-11 step 7, plan step 11 |
| Mode | live CI run |
| Tag | n/a |
| Preconditions | Branch pushed with the owner's go-ahead; PR open (O-2); first run complete |
| Steps | 1. Owner sends the run URL and the downloaded logs (or the five job logs as text)<br>2. Tester: for each job compare the `PASS`/`FAIL`/`SKIP` lines with `scripts/quality.sh --list` for that group<br>3. Compare the SKIP set with `quality/expected-skips.txt` |
| Expected result | Run for event `pull_request`; the six jobs are success; each group's log shows every step of that group exactly once; SKIP set equals expected-skips; `core` shows pre-commit, branch-name, commit-range, exceptions, assets, tooling-tests, secret-history, ci-config; `docs` shows each suite; `drupal` shows build-drupal, component-drupal, audit-drupal as PASS. Any job red is a Fail. |
| Actual result | |
| Evidence | `evidence/TC-T08-49.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-50: Live: branch-name and commit-range work in CI (pull_request)

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Plan item | fact 8, fact 9 |
| Mode | live CI run |
| Tag | n/a |
| Preconditions | Case 49 run available |
| Steps | 1. In the `core` log find the `branch-name` and `commit-range` steps |
| Expected result | branch-name PASS using `GITHUB_HEAD_REF` (`task/T08-ci-baseline`); commit-range PASS with the range `origin/main..HEAD` (no exit 2 shallow-clone error; checkout log shows `fetch-depth: 0`). A shallow-clone error or a skipped step is a Fail. |
| Actual result | |
| Evidence | `evidence/TC-T08-50.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-51: Live: first push run on main after merge (O-8)

| Field | Value |
|---|---|
| Linked criterion | AC1, C4 |
| Plan item | fact 9, risk row 'branch-name on push' |
| Mode | live CI run |
| Tag | n/a |
| Preconditions | T08 merged by merge commit; the push run finished |
| Steps | 1. Owner sends the first `push` run URL on `main` and the logs of `core` |
| Expected result | Event `push`, ref `main`, all six jobs success; `branch-name` PASS and its log shows the branch `main`; `commit-range` PASS. If branch-name fails to see `main`, that is a defect and the plan's fallback (`GITHUB_REF_NAME`) applies. Reported even if the close happens first: C4 requires it. |
| Actual result | |
| Evidence | `evidence/TC-T08-51.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-52: Settings: merge methods and Actions permissions (O-3, O-4)

| Field | Value |
|---|---|
| Linked criterion | AC2, C4 |
| Plan item | KD-10 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | First CI run has reported; repository public (TC-T08-67) |
| Steps | 1. Owner sends screenshots or copied text of Settings, General, Pull Requests<br>2. Settings, Actions, General (workflow permissions, PR creation, allowed actions, fork approval) |
| Expected result | Merge commits on; squash off; rebase off. Workflow permissions: read repository contents and packages; 'Allow GitHub Actions to create and approve pull requests' off; actions limited to GitHub-owned plus `shivammathur/setup-php@<the SHA in .github/README.md>`; fork pull request workflows require approval for all outside collaborators (record the exact label shown, as the plan marks the wording unverified). Anything less strict than the plan is a Fail. |
| Actual result | |
| Evidence | `evidence/TC-T08-52.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-53: Ruleset 'main' configuration (O-5)

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Plan item | KD-10 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | O-3 and O-4 done |
| Steps | 1. Owner sends a screenshot or the rule summary of Settings, Rules, Rulesets, main |
| Expected result | Enforcement Active; bypass list empty; target is the default branch; restrict deletions; block force pushes; require a pull request with 0 approvals and merge method Merge only; require status checks with 'up to date before merging' on, and the only required check is `ci-ok` with source GitHub Actions; linear history off. Required checks listing `core`, `docs` or any other job in addition to `ci-ok` is a deviation to be recorded (not an automatic Fail, but it must be listed). |
| Actual result | |
| Evidence | `evidence/TC-T08-53.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-54: Demo pull request: failing test blocks merge, no bypass offered

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Plan item | KD-11, O-6 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | Ruleset active (TC-T08-53); branch `task/T08-demo-failing-test` pushed with the single commit adding `scripts/tests/test_t08_demo_failure.py`; PR opened by the owner |
| Steps | 1. Owner sends the PR run URL, the failing log lines of `core`, and a screenshot (or copied text) of the whole merge box<br>2. Tester checks the log: `tooling-tests` FAIL naming `test_t08_demo_failure` and the message `T08 demo: deliberately failing test, do not merge`; `ci-ok` FAIL; other jobs unaffected<br>3. Tester checks the merge box evidence |
| Expected result | Pass: the merge box says merging is blocked, the required check `ci-ok` is failing, the merge button is disabled, and no control is offered that merges anyway (no 'Merge without waiting for requirements to be met (bypass rules)' checkbox, no 'Bypass' text, no admin override) for the owner who is the repository admin. Fail: any bypass option is offered, the merge button is enabled, or only part of the merge box is shown (insufficient evidence, Blocked until the whole box is sent). If a bypass is offered AC2 is not met: apply the KD-10 classic-rule fallback ('Do not allow bypassing the above settings') and repeat this case; the case then passes only on the repeat. |
| Actual result | |
| Evidence | `evidence/TC-T08-54.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-55: Demo pull request ends unmerged; the failing test never reaches main

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Plan item | KD-11 step 6 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | Demo PR closed and branch deleted by the owner |
| Steps | 1. `git fetch origin && git merge-base --is-ancestor <demo sha> origin/main; echo rc=$?`<br>2. `git ls-tree -r origin/main --name-only \| grep test_t08_demo_failure`<br>3. Owner sends the PR page showing 'Closed' (not 'Merged') |
| Expected result | Step 1 rc=1 (not an ancestor); step 2 prints nothing; the PR is Closed and not Merged; the remote branch is gone (`git ls-remote --heads origin task/T08-demo-failing-test` empty). The T08 branch itself does not contain the test file (`git ls-tree -r task/T08-ci-baseline --name-only \| grep test_t08_demo_failure` empty). |
| Actual result | |
| Evidence | `evidence/TC-T08-55.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-56: Positive control: the T08 PR is mergeable by merge commit only

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Plan item | KD-11 step 7 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | T08 PR green after review and test |
| Steps | 1. Owner sends the merge box screenshot of the green T08 PR |
| Expected result | `ci-ok` passing; merge button enabled with 'Create a merge commit' only (squash and rebase options absent). A green PR that cannot be merged, or that offers squash or rebase, is a Fail (the ruleset would block good PRs or contradict D-3). |
| Actual result | |
| Evidence | `evidence/TC-T08-56.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-57: ci-ok is a true gate: cancelled, skipped or failed needs fail it

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Plan item | KD-8 |
| Mode | offline harness |
| Tag | ckp |
| Preconditions | Temp copy of ci.yml; `act` is not used |
| Steps | 1. Extract the `ci-ok` step expression from the YAML<br>2. Evaluate it for the matrix: all success; one failure; one cancelled; one skipped; two failures (script: replace `contains(needs.*.result, X)` with a Python check over a result list)<br>3. `.tools/actionlint` on the file |
| Expected result | Gate step runs and exits 1 for failure, cancelled and skipped; exits 0 only when all five are success. The `if:` on the step does not skip itself when needs failed (the job has `if: always()`). actionlint clean. (Live evidence of the gate is TC-T08-54 where `ci-ok` is red.) |
| Actual result | |
| Evidence | `evidence/TC-T08-57.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-58: Timing design: caches, no setup-action cache, job timeouts

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Plan item | KD-7 |
| Mode | static |
| Tag | ckp |
| Preconditions | none |
| Steps | 1. `grep -nE 'actions/cache\|key:\|cache:\|timeout-minutes\|restore-keys\|vendor' .github/workflows/ci.yml` |
| Expected result | Caches exist for `~/.cache/pre-commit` (key with OS, Python version, hash of `.pre-commit-config.yaml` and `scripts/tool-versions.env`), `.tools/` (hash of tool-versions.env) and the Composer cache dir (hash of `composer.lock`); `vendor/` is never cached; no setup action uses its own `cache:` input; every job has `timeout-minutes: 10`; `ci-ok` has a small timeout. A cache key not tied to its inputs, or `vendor/` cached, is a Fail. |
| Actual result | |
| Evidence | `evidence/TC-T08-58.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-59: Timing: three cold runs at most 10:00 each (NFR-07)

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Plan item | KD-7, O-7 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | T08 PR green. Cold 1 is the first run of the PR. For cold 2 and 3 the owner deletes all Actions caches (Settings, Actions, Caches) and chooses 'Re-run all jobs' |
| Steps | 1. Owner sends, for each of the three cold runs: run URL, the total duration from the run summary, each job's duration<br>2. Tester checks each cold run's logs for `Cache not found` on every cache step (TC-T08-61)<br>3. Tester records the three values in the report |
| Expected result | Pass: each of the three cold runs is at most 10:00 total (all three must pass, not the mean) and no job hit its timeout. Fail: any cold run over 10:00, or any job cancelled by timeout. If a cold run was not actually cold (a cache hit appears) it does not count and must be repeated. If the cold runs fail the budget, the plan's fallbacks (gitleaks hook as a system hook, own cache key for docs, split core) are applied as recorded changes and the case is rerun; the timeout is not raised and no step is dropped. Measure from the run summary page, not from the sum of job times. |
| Actual result | |
| Evidence | `evidence/TC-T08-59.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-60: Timing: three warm runs at most 6:00 each (NFR-07)

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Plan item | KD-7, O-7 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | Cold runs done; three plain 'Re-run all jobs' with caches kept |
| Steps | 1. Owner sends run URL, total duration and per-job durations for each warm run<br>2. Tester checks `Cache hit` in the logs |
| Expected result | Pass: each warm run is at most 6:00 and shows cache hits for pre-commit and `.tools/`. Fail: a warm run over 6:00, or a run with no cache hit (not counted; repeat). Durations of the six runs are tabulated in the report with their URLs and compared with the plan's unverified estimates (the estimates are not pass criteria). |
| Actual result | |
| Evidence | `evidence/TC-T08-60.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-61: Timing: cache behaviour is real (cold has no hits, warm has hits)

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Plan item | KD-7 |
| Mode | live CI run |
| Tag | n/a |
| Preconditions | Logs of the six timing runs |
| Steps | 1. Search each log for the cache restore step results (`Cache not found for input keys` vs `Cache restored from key`) |
| Expected result | Cold runs: all three caches miss in `core`, `docs` and `drupal` where used. Warm runs: pre-commit and `.tools/` hit. A cold run that hits any cache invalidates the cold measurement (not counted). |
| Actual result | |
| Evidence | `evidence/TC-T08-61.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-62: Artifacts: one reports-<group> artifact per job with the logs and reports

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-8 |
| Mode | live CI run |
| Tag | n/a |
| Preconditions | Green run from TC-T08-49 |
| Steps | 1. Owner downloads the five artifacts (or sends the list from the run summary page and the zips)<br>2. `unzip -l` each; `ls` |
| Expected result | Artifacts `reports-core`, `reports-docs`, `reports-drupal`, `reports-engine`, `reports-web` exist; each contains `quality-<g>.txt` (the same text as the job log for that group); `reports-core` also holds `gitleaks.json` and `exceptions-report.txt`; retention 14 days shown on the run page. An absent artifact, or an empty `quality-<g>.txt`, is a Fail. JUnit and coverage files are absent at T08 for the SKIP components and the upload log shows a warning, not an error. |
| Actual result | |
| Evidence | `evidence/TC-T08-62.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-63: Artifacts are uploaded when a job fails

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Plan item | KD-8 |
| Mode | live CI run |
| Tag | n/a |
| Preconditions | Demo PR run (TC-T08-54) or any red run |
| Steps | 1. Open the artifacts of the failing demo run |
| Expected result | `reports-core` exists even though `core` failed, and its `quality-core.txt` contains the failing test name and the message. This shows `if: always()` works. No artifact on a failed job is a Fail. |
| Actual result | |
| Evidence | `evidence/TC-T08-63.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-64: Artifact content hygiene: redacted, no secrets, no decision content

| Field | Value |
|---|---|
| Linked criterion | AC4, C6 |
| Plan item | KD-4, KD-13 output rule |
| Mode | live CI run |
| Tag | n/a |
| Preconditions | Artifacts from TC-T08-62 |
| Steps | 1. `python3 -m json.tool gitleaks.json`<br>2. Run `.tools/gitleaks dir <artifact folder> --redact` and `grep -rniE '(BUY\|AVOID\|VETO)\|[A-Za-z0-9+/]{40,}\|BEGIN [A-Z ]*PRIVATE KEY' <artifact folder>`<br>3. Inspect the report for a `Secret` or `Match` field |
| Expected result | The JSON parses and has `[]` (or findings with `Secret`/`Match` fields showing REDACTED). gitleaks reports 0 findings in the artifacts; the grep finds no token-like string, no private key and no symbol-level decision text (T08 artifacts hold only tool reports). Any real-looking secret is a Critical defect, stop and report. |
| Actual result | |
| Evidence | `evidence/TC-T08-64.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-65: KD-13 item 1: full-history gitleaks scan over every published ref

| Field | Value |
|---|---|
| Linked criterion | C6, AC1 |
| Plan item | KD-13 item 1, SA-1 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | Before the flip; the checkout fetches all refs including `refs/pull/*` |
| Steps | 1. Owner (with the main session) runs the scan command from `decision-repo-visibility.md` over all refs (check the `--log-opts` spelling for 8.30.1: if the flag is rejected the case records the corrected command)<br>2. Owner sends the output file path and the exit code |
| Expected result | 0 findings. Pass needs the command text, tool version, ref list or count scanned, and rc=0 in the evidence. Any finding: stop; a real secret is rotated; a false positive is allowlisted by fingerprint only with a solution-architect decision; history is never rewritten. A scan limited to the default branch is not sufficient (Fail: insufficient scope). |
| Actual result | |
| Evidence | `evidence/TC-T08-65.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-66: KD-13 item 2: DEPLOY_SMOKE_HEADER handling and the deploy-drupal.yml change

| Field | Value |
|---|---|
| Linked criterion | AC5, C6 |
| Plan item | KD-13 item 2 |
| Mode | static |
| Tag | cka |
| Preconditions | Owner's answer about the value of `DEPLOY_SMOKE_HEADER` |
| Steps | 1. `git diff d935c2f..HEAD -- .github/workflows/deploy-drupal.yml`<br>2. `grep -n 'DEPLOY_SMOKE_HEADER' .github/workflows/deploy-drupal.yml docs/runbooks/ci-secrets.md docs/runbooks/deploy.md`<br>3. `python3 scripts/check_ci.py` |
| Expected result | Either the diff is empty (the variable holds no bypass value; ci-secrets.md lists it as a variable and says why that is safe), or the only change is `vars.DEPLOY_SMOKE_HEADER` to `secrets.DEPLOY_SMOKE_HEADER` in its own commit that cites T07, and ci-secrets.md lists it under secrets. Any other change to deploy-drupal.yml is a Fail. Check_ci passes. Owner evidence that old deploy run logs were reviewed is recorded in TC-T08-67. |
| Actual result | |
| Evidence | `evidence/TC-T08-66.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-67: KD-13 items 3, 4, 6, 7: visibility flip and post-flip settings

| Field | Value |
|---|---|
| Linked criterion | AC2, C6 |
| Plan item | KD-13, O-1 |
| Mode | owner-run |
| Tag | n/a |
| Preconditions | Items 1 and 2 done; README notice merged on the branch |
| Steps | 1. Owner sends: decision on the personal address in `TC-T07-56.20261103T062710Z.txt` (accept or redacted commit) and acceptance of the work email<br>2. Screenshot of Settings showing visibility Public and the flip date<br>3. Code security: secret scanning and push protection on<br>4. Review of old deploy-drupal run logs (deleted runs listed)<br>5. If the owner instead chose private with Pro: the NFR-09 amendment record and proof of the plan; the case then replaces step 2 to 4 with that record |
| Expected result | Visibility Public with a date no earlier than the scan in TC-T08-65 and no later than the ruleset (O-5); secret scanning and push protection enabled; fork-PR approval strictest (TC-T08-52); owner decisions on the address and email recorded in the owner's own message; no run log with a bypass value remains. For the Pro branch: the amendment is approved by the owner and recorded by the solution-architect. Missing owner evidence is Blocked. |
| Actual result | |
| Evidence | `evidence/TC-T08-67.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-68: Governance: OQ-03 closed, RK-06 output rule recorded, traceability updated

| Field | Value |
|---|---|
| Linked criterion | C5, C3 |
| Plan item | KD-13, Definition of done |
| Mode | static |
| Tag | cka |
| Preconditions | At close |
| Steps | 1. `grep -nE 'OQ-03' docs/architecture/solution-architecture.md`<br>2. `grep -nE 'RK-06' docs/architecture/solution-architecture.md`<br>3. `grep -nE 'NFR-07\|R-12' docs/TRACEABILITY.md`<br>4. `grep -n 'T08' docs/PROGRESS.md` |
| Expected result | OQ-03 shows resolved with a link to `decision-repo-visibility.md`; the cost map GitHub row says public repository, standard runners free; RK-06 carries the output rule; TRACEABILITY NFR-07 and R-12 rows cite T08 evidence; PROGRESS shows T08 status. At design time this case is Blocked until close (the main session closes). |
| Actual result | |
| Evidence | `evidence/TC-T08-68.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-69: T07 files untouched

| Field | Value |
|---|---|
| Linked criterion | C2, C5 |
| Plan item | Context |
| Mode | static |
| Tag | cka |
| Preconditions | Base d935c2f |
| Steps | 1. `git diff --stat d935c2f..HEAD -- scripts/deploy-drupal.sh scripts/pantheon_known_hosts .ddev/commands/web/deploy-drupal .ddev/providers/pantheon.yaml apps/drupal/.gitignore .ddev/web-build/Dockerfile .github/workflows/deploy-drupal.yml` |
| Expected result | Empty, except the single allowed `DEPLOY_SMOKE_HEADER` line in deploy-drupal.yml (TC-T08-66). Any other change is a Fail against T08 scope. |
| Actual result | |
| Evidence | `evidence/TC-T08-69.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-70: SA-2 conditions 3 and 5: ddev quality still the local gate, parity recorded

| Field | Value |
|---|---|
| Linked criterion | AC1, C7 |
| Plan item | SA-2 c3, c5, plan step 9 |
| Mode | local run (network) |
| Tag | n/a |
| Preconditions | DDEV started (`ddev start`); bootstrap run |
| Steps | 1. `ddev quality 2>&1 \| tee docs/tests/T08/evidence/TC-T08-70.ddev.txt; echo rc=${PIPESTATUS[0]}`<br>2. `ddev exec composer --version`; `ddev exec php -v`<br>3. Compare with the CI log's Composer and PHP versions and with the line in `.github/README.md`<br>4. Compare SKIP set with expected-skips |
| Expected result | rc=0; `FAIL 0`; SKIP set equals expected-skips; the same set of step names ran as in the native CI log (`--list`). Composer version and PHP major.minor equal the setup-php configuration and the README line. The test report records both this local `ddev quality` result and the CI run URL (condition 5). If DDEV is unavailable the case is Blocked and the owner is asked to run it; a mismatch in versions is a Fail. |
| Actual result | |
| Evidence | `evidence/TC-T08-70.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-71: C7: clean checkout works from documented commands

| Field | Value |
|---|---|
| Linked criterion | C7 |
| Plan item | DoD C7 |
| Mode | local run (network) |
| Tag | n/a |
| Preconditions | Network; a fresh `git clone` of the branch into an empty temp dir; no `.env`, no `.tools/` |
| Steps | 1. `git clone --branch task/T08-ci-baseline . $WORK/clone && cd $WORK/clone`<br>2. `scripts/bootstrap-dev.sh`<br>3. `QUALITY_RUNNER=native scripts/quality.sh 2>&1 \| tee docs/tests/T08/evidence/TC-T08-71.txt`<br>4. Read `.github/README.md` and `docs/runbooks/local-setup.md` and confirm no undocumented command was needed |
| Expected result | Bootstrap installs pre-commit, gitleaks and actionlint with checksum checks; quality.sh exits 0 with the expected SKIP set. Each CI run is itself a clean checkout (the live run logs show a fresh checkout with no pre-existing files). `ddev quality` on a fresh clone is TC-T08-70. Any command needed that is not documented is a defect. |
| Actual result | |
| Evidence | `evidence/TC-T08-71.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-72: Process criteria: plan reviewed, code reviewed, findings resolved

| Field | Value |
|---|---|
| Linked criterion | C1, C2 |
| Plan item | Process |
| Mode | static |
| Tag | cka |
| Preconditions | At execution |
| Steps | 1. `grep -n 'Status' docs/tasks/T08/plan.md \| head -3`<br>2. `ls docs/tasks/T08/review.md` and read its Approval section<br>3. `git log --format='%h %s' d935c2f..HEAD` |
| Expected result | Plan status Approved dated before the first implementation commit (git log order: plan commit precedes code commits); review.md exists with approval and every finding resolved or ticketed, including the T00 and T03 retag review; every commit subject starts with `T08:`. |
| Actual result | |
| Evidence | `evidence/TC-T08-72.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T08-73: Evidence and traceability hygiene (C3)

| Field | Value |
|---|---|
| Linked criterion | C3 |
| Plan item | Process |
| Mode | static |
| Tag | cka |
| Preconditions | At execution |
| Steps | 1. For every case in this file: `ls docs/tests/T08/evidence/TC-T08-nn.*`<br>2. Confirm owner-run cases have the owner's evidence stored (run URLs, screenshots as text or image) under `docs/tests/T08/evidence/owner/`<br>3. Confirm the report lists every Blocked case in a 'Blocked at close' table |
| Expected result | Every case that is Pass has an evidence file; no Pass without evidence; Blocked cases are accepted only per master test plan 'Blocked at close' (the tester cannot accept them). Every criterion row of the coverage table maps to at least one case with a non-Blocked result, or to an accepted Blocked entry with the owner's own message. |
| Actual result | |
| Evidence | `evidence/TC-T08-73.<run id>.txt` |
| Status | Not run |
| Date | |
| Executed by | |

## Harness design note (`docs/tests/T08/run-checks.sh`, written in the test step)

- Same shape as `docs/tests/T07/run-checks.sh`: `case_start`, `ckp`/`cka`, `pass`/`bad`/`blk`,
  `redact()`, `--regression`, `T08_EVIDENCE=1`, and a `$WORK` temp dir removed on exit.
- Negative controls build their faulty copies in `$WORK` from copies of `git ls-files` output,
  never in the tree. Fake secret values and fake `ddev`, `composer` and `gitleaks` wrappers are
  created at run time in `$WORK/bin`.
- Live and owner-run cases (49 to 51, 52 to 56, 59 to 61, 62 to 64, 65, 67) are BLOCKED in every
  script mode and list the evidence the owner must send. They are executed by reading the owner
  evidence files in `docs/tests/T08/evidence/owner/`.
- Local-network cases (7, 20, 23, 25, 26, 29, 70, 71) need `--local` or `--ddev` and are BLOCKED
  without network or DDEV.
- The temp fixtures of the tester are separate from the developer fixtures in
  `scripts/tests/fixtures/ci/`, so a developer fixture bug cannot hide a defect.

## Change log

| Date | Change |
|---|---|
| 2026-11-03 | Initial design (tester, design mode) |
