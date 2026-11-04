# T08: Continuous integration baseline, Review

| Field | Value |
|---|---|
| Task | T08 |
| Reviewer | technical-architect |
| Date | 2026-11-04 |
| Commit range | `d935c2f..24fe7fd` (13 commits on `task/T08-ci-baseline`, merged to `main` as PR #3, merge commit `d82fe2a`) |
| Plan | `docs/tasks/T08/plan.md` (Approved 2026-11-03) |
| Decisions | `decision-repo-visibility.md` (SA-1), `decision-native-quality.md` (SA-2), `decision-heavier-set.md` (SA-3) |
| Test cases | `docs/tests/T08/test-cases.md` (TC-T08-01 to 73; harness `run-checks.sh` not written yet) |
| Fix branch | `task/T08-review-fixes` (from `origin/main` at `d82fe2a`), new PR |

## Process note: merge before review and test

The owner merged PR #3 into `main` on 2026-11-04 after the PR checks were green. That was
before this review and before the test step. The plan order (step 13, O-8) is review, then
test, then merge. This is recorded as a process note, not as a code finding. It has three
consequences:

- every fix this review asks for goes on `task/T08-review-fixes` as a new PR, with `T08:`
  commits;
- TC-T08-51 (the first `push` run on `main`) can already be run by the owner, using the push
  run of `d82fe2a`;
- it is not known whether the `main` ruleset (O-5) was active at the merge. The test report
  must record when O-3 to O-5 were applied compared with the merge time.

## What was checked

- **Diff.** I read every changed file in full: `ci.yml`, `quality.sh`, `check_ci.py`,
  `bootstrap-dev.sh`, `tool-versions.env`, `requirements-docs-tests.txt`,
  `exceptions_report.py`, `.pre-commit-config.yaml`, `expected-skips.txt`, the three new or
  extended test modules and their fixtures, `ci-secrets.md`, `.github/README.md`,
  `scripts/README.md`, `local-setup.md`, the standards diff, `README.md`, the T00 and T03
  retrofit and Change logs, the master test plan diff and the `defects.md` diff.
- **Read-only tools, run on `task/T08-review-fixes` (tree equal to `24fe7fd` plus the merge).**
  - `python3 -I scripts/check_ci.py`: exit 0, rules 1 to 6 PASS.
  - `.tools/actionlint .github/workflows/*.yml`: exit 0, no output.
  - `scripts/check-names.sh`: OK.
  - `scripts/quality.sh --list`: 19 lines `GROUP<TAB>STEP`, five groups, exit 0.
  - `python3 -m unittest discover -s scripts/tests`: 141 tests, OK.
    `python3 -m unittest discover -s .claude/hooks/tests`: 30 tests, OK.
  - A probe of the docs-regression job limiter loop, copied out of `quality.sh`:
    `max=0` hangs until it is killed (timeout, rc 124). `max=abc` prints
    `[: abc: integer expression expected` and starts every suite at once (finding 2).
  - A grep of the whole diff for broker names, broker APIs and trading domains: no hit outside
    the scope-guard sentences and the TC-T03-21 evidence lines.
- I did not run `ddev quality` (about 16 min). No finding depends on it.

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Owner | Status |
|---|---|---|---|---|---|---|
| 1 | Major | `.github/workflows/ci.yml:52-57`, `:112-117`; `scripts/quality.sh:310-311` | **Stale reports in the artifacts.** The `core` and `docs` jobs both cache `path: .tools` under the same key (`tools-<os>-<hash of tool-versions.env>`). `.tools/reports/` is inside that path. The cache is saved once per key, at the end of whichever of the two jobs succeeds first, and is restored by both jobs in every later run until `tool-versions.env` changes. `quality.sh` only runs `mkdir -p` on the reports directory and never empties it. So from the second run on, `reports-docs` (or `reports-core`) also uploads `quality-<other group>.txt`, `gitleaks.json` and `exceptions-report.txt` from the run that first saved the cache. Those files come from a different job, a different run and a different commit. This makes the AC4 artifacts misleading as evidence, and the redacted `gitleaks.json` in `reports-docs` would not describe the run it is attached to. The `.tools/suite-bin/` symlink is cached as well (harmless). | Remove `.tools/reports` (and `.tools/suite-bin`) from the cached path in both jobs, for example `path: \|` with `.tools` and `!.tools/reports` (and `!.tools/suite-bin`), using the actions/cache glob exclusion. Keep `quality.sh` as it is: emptying the directory at start would break local multi-group runs. The tester checks this in TC-T08-62 on a **warm** run: each `reports-<g>` holds only that job's files. | developer | Open |
| 2 | Minor | `scripts/quality.sh:24-25`, `:171`, `:176` | **`QUALITY_DOCS_JOBS` is not validated.** With `0`, the limiter `while [ "$(jobs -rp \| wc -l)" -ge "$max" ]; do wait -n; done` never ends (probe above: hangs). In CI the 10 min job timeout would kill it; locally it hangs for ever. A non-numeric value prints test errors and runs every suite at once. No test covers values above 1: the result order, failure naming and the `.rc` file handling for parallel suites are untested. CODING_STANDARDS "Error handling", REVIEW_CHECKLIST 4 ("each command-line tool exits non-zero on failure with one clear line") and 5 ("error paths and boundaries are tested"). | Validate `QUALITY_DOCS_JOBS` as an integer of at least 1 at argument parsing. Any other value exits 2 with `error: QUALITY_DOCS_JOBS must be a positive integer`. Add unit tests: invalid values (`0`, `abc`) exit 2; `QUALITY_DOCS_JOBS=2` with three fake suites, one of them failing, reports them in glob order and names the failing one. | developer | Open |
| 3 | Minor | `scripts/quality.sh:140-254`, `:156-185`, `:165`, `:224` | **Size and lint coverage.** The docs-regression step is a 242-character line of shell built from a heredoc and stored as a string, so shellcheck never sees it as code. `builtin_steps` grew from 46 to 115 lines and the file from 137 to 395 lines (limit 400). No reason is recorded (CODING_STANDARDS "Function and file size"). The comment at line 165 is two sentences run together on one 156-character line, and line 224 is 112 characters. | Move the docs-regression body into its own script, for example `scripts/docs_regression.sh`. It is linted by shellcheck, takes `QUALITY_DOCS_JOBS`, writes the lock file, and the `step docs` line calls it. Finding 2's validation and tests can live there. Rewrap lines 165 and 224. If the developer keeps the inline form, record the size reason in the fix PR description. | developer | Open |
| 4 | Minor | `scripts/requirements-docs-tests.txt:1-3`, `scripts/tool-versions.env:25-32`, `docs/standards/CODING_STANDARDS.md:380` | **Two new dependencies are not in the plan or the standards.** PyYAML 6.0.3 (`77e4e61`) and the shellcheck 0.11.0 binary (`24fe7fd`) are not in the plan's "Interfaces touched", and no audit is recorded (CODING_STANDARDS "Dependency policy, Audit before adding"). The tool table still lists shellcheck only as shellcheck-py, and PyYAML is missing from it. On hashes: neither the plan nor the standards require `--require-hashes`. The standards require an exact version (met), and the plan's SHA-256 pins cover the downloaded binaries and the zipapp. So PyYAML pinned by version alone is **compliant**. | Record the audit in `.github/README.md` "Pinned tools" or the standards table: PyYAML licence (MIT, verify), latest release date, `pip-audit`/OSV result; shellcheck licence (GPL-3.0, verify). GPL-3.0 is allowed for a tool that is not shipped. Update the standards tool table with both, including the shellcheck binary next to shellcheck-py. Optional and recommended: hash-pin PyYAML (`--hash=sha256:` lines for the sdist and the cp312 manylinux wheel, looked up by the main session with network) and install with `--require-hashes`, for consistency with the other pins. This review accepts both dependencies as plan departures once the audit is recorded. | developer (main session for hashes) | Open |
| 5 | Minor | `docs/runbooks/local-setup.md:116-146`, `scripts/bootstrap-dev.sh:5-6`, `:110-116`, `.github/README.md:115-119`, `scripts/README.md` | **C7 and stale docs.** (a) The docs suites import PyYAML. `local-setup.md` does not list it as a prerequisite, so on a fresh WSL2 host without `python3-yaml` the docs group of `ddev quality` fails (C7: "only documented commands"). (b) Bootstrap now also installs shellcheck, but the bootstrap header, its platform error text, `local-setup.md` and TC-T08-71 name only "pre-commit, gitleaks and actionlint". (c) `local-setup.md` says "Two steps need network access: `secret-history` is local, but `audit-drupal` ...", which contradicts itself. (d) `.github/README.md` "Not verifiable until the first run" still lists the runner shellcheck as unknown, but `24fe7fd` records it as 0.9.0. (e) `scripts/README.md` "Accepted differences" does not mention that local PyYAML floats while CI uses 6.0.3. | (a) Add the prerequisite (`python3 -m pip install -r scripts/requirements-docs-tests.txt`, or the distro package) to `local-setup.md`. (b) Name shellcheck everywhere bootstrap's tools are listed. (c) Reword: only `audit-drupal` needs network; `secret-history` is local. (d) Replace the shellcheck item with the recorded fact. (e) Add the PyYAML difference as item 4. | developer | Open |
| 6 | Minor | `scripts/bootstrap-dev.sh:97-107` | **Installed binary not tied to the verified tarball.** The tarball is checked on every run, which is good, but an existing `.tools/<name>` whose version output contains the version string is kept without re-extraction. In CI, `.tools/` comes from the cache, so the binary that runs is not proven to be the one inside the verified tarball. The risk is low (only workflows in the repository can write to the cache scope), but the SHA-256 pin is meant to be the guarantee. | Always extract and `install` the member from the verified tarball (it takes milliseconds), or compare the SHA-256 of the installed binary with the member's. | developer | Open |
| 7 | Minor | `scripts/bootstrap-dev.sh` (no test) | **Bootstrap pin behaviour has no automated test.** The developer reports "no unit test (network)". A network-free test is possible: a temp git repo with a copy of the script and a fixture `tool-versions.env`, a fake `curl` first on `PATH` that copies a fixture tarball, and a fake `uname` for the platform guard. The plan scope requires "Tests in `scripts/tests/` for every changed or new script behaviour". TC-T08-23 covers the mismatch path manually but needs network. | Add `scripts/tests/test_bootstrap_dev.py` with fakes: an empty SHA exits 1; a mismatch exits 1 and removes the archive; non-Linux or non-x86_64 exits 1 with the message; the correct SHA installs. The pre-commit download can be faked the same way. Alternatively, ticket it with a reason and the tester keeps TC-T08-23 as the only evidence. | developer | Open |
| 8 | Minor | `scripts/tests/test_quality_sh.py`, `test_check_ci.py`, `test_exceptions_report.py` (new T08 classes) | **Tests do not name their case IDs.** None of the new T08 tests cites a `TC-T08-nn` ID (CODING_STANDARDS "Comments and docstrings": "Tests name their case ID"). Example mapping: runner independence is TC-T08-13, expected SKIPs TC-T08-08 to 11, summary TC-T08-12, check_ci rules TC-T08-32 to 40, Composer audit ignore TC-T08-28. | Add the IDs to the class or method docstrings. | developer | Open |
| 9 | Minor | `docs/tests/T03/run-checks.sh:171-177`, `docs/tests/T03/test-cases.md` (Change log 2026-11-03) | **T03 retag review.** Retagging the exact-count check (`-eq 2`) to `cka` is a valid D-5 snapshot case. But the Change log says the invariant part "is still checked by the unchanged sibling checks". It is not: lines 171-172 check that `technical-design.md` mentions NFR-04 and NFR-05. They do not check that the SA table rows cite technical-design. In `--regression` mode nothing now checks those SA rows. | Add a `ck` (invariant) check: each of the NFR-04 and NFR-05 rows in `solution-architecture.md` has at least one row citing technical-design (at least 1 each, not exactly 2). Keep the exact count as `cka`. Correct the Change log row. | tester | Open |
| 10 | Minor | `docs/tests/T00/run-checks.sh:6`, `:22` | **T00 retag review.** I confirm the tester's claim: T00 has no snapshot check. The set equality at line 59 (PROGRESS task IDs equal TASKS.md) is an invariant. But the retrofit adds an unused `cka` helper and a file-wide `# shellcheck disable=SC2329 # T08: ...` that cites T08, the task being closed (REVIEW_CHECKLIST 4, Exceptions: "Does no exception name the task being closed as its remover?"). | Remove `cka` and the directive from T00 until it gets a snapshot check. The `--regression` flag and the excluded-count line stay (the count is 0). Add a Change log row. | tester | Open |
| 11 | Minor | `docs/tests/T07/run-checks.sh:29`, `:836`; `scripts/quality.sh:165`, `:171` | **`T07_SKIP_NESTED` used outside its documented purpose** (deviation 1). T07 documents it as "only for negative-control runs", but docs-regression now sets it on every run. The use itself is accepted: the same step already runs T02 to T06 once, so the nested re-run would only double the time. As a result, the nested part of TC-T07-24 prints BLOCKED in every docs-regression run. | Update the T07 header comment and BLOCKED text to name docs-regression as the second permitted user, and add a T07 Change log row. | tester | Open |
| 12 | Minor | `docs/tests/defects.md:148-150` (commit `7423115`) | **Developer edited a tester-owned file** (deviation 3). The edit **stands**. It keeps every word (the note moves from Status to Retest result) and fixes a real T04 invariant (Status must be one of the eight workflow states), which is the content fix KD-12 asks for. The T04 failure also occurs at the base `d935c2f`, so it is not caused by T08. The process gap is that `docs/tests` belongs to the tester. | The tester ratifies the edit in the T08 test report and adds a History or Change log line to DEF-011 that names commit `7423115` and the reason. No revert. | tester | Open |
| 13 | Note | `scripts/quality.sh:63-79`, `:169-170` | **Recursion guard accepted** (deviation 1). `QUALITY_NESTED=1` plus the pid lock file is a sound answer to ddev dropping the environment. The nested run leaves the docs group out with a visible `note:` line, and `--group docs` is refused with exit 2. Residual: a separate `ddev quality` started by hand in another terminal while docs-regression runs also leaves docs out (with the note), and a stale lock whose pid is reused does the same. Both are acceptable locally, and CI is not affected. | None. TC-T08 coverage is listed below. | - | - |
| 14 | Note | `scripts/quality.sh:180-182` | Docs-regression discards each suite's output when the suite passes, so `reports-docs` holds only `quality-docs.txt`. AC4 is still met. | Optional: write each suite's output to `.tools/reports/docs/<Txx>.txt` so the artifact carries the per-suite logs. This fits naturally with finding 3. | developer (optional) | - |
| 15 | Note | `.github/workflows/ci.yml` | **Workflow security review passed.** `permissions: {}` at the top and `contents: read` per job. All 15 `uses:` are `owner/repo@<40 hex>` with a version comment on the line above, checked by rule 3 and by eye: checkout `3d3c42e5...`, setup-python `6d4fd22b...`, cache `55cc8345...`, upload-artifact `cf430e03...`, setup-php `eb7c497e...`. No `pull_request_target`. No `${{ }}` inside `run:` (line 176 writes to `$GITHUB_OUTPUT` only). No `secrets.` or `vars.`. `persist-credentials: false`. gitleaks runs with `--redact`. The cache key's double-quoted YAML continuation (deviation 5) joins without a space and is valid. Push runs on `main` share one concurrency group without cancel-in-progress, so GitHub may replace a queued push run with a newer one. A cancelled push run on `main` is therefore not a failure of the merged change. | None. | - | - |
| 16 | Note | `scripts/check_ci.py:40`, `:157-215` | `GROUP_CALL` takes only the first `--group` on a line (`--group a --group b` in one call counts as `a`), and a bare `quality.sh` with no `--group` is not counted. Neither form is used. `rule2` is 51 body lines, just over the guidance. | None now. If a job ever passes two groups, extend the regex. | - | - |
| 17 | Note | `.github/workflows/deploy-drupal.yml`, `docs/runbooks/ci-secrets.md:53` | **KD-13 item 2 not applied** (deviation 8). It is pending the owner's check of the `DEPLOY_SMOKE_HEADER` value. The plan makes it a precondition of the flip (O-1) and of O-5. | Owner decides. If it applies, the developer makes the `vars.` to `secrets.` change in its own `T08:` commit on the fix branch with "T07 follow-up" in the body, and moves the `ci-secrets.md` row. This review covers that commit when it lands. | owner | Open |
| 18 | Note | `docs/PROGRESS.md:18` | The T08 row still reads "Built 2026-11-03 (8 commits, not pushed)". | Update it at `/close-task`, and note the merge of PR #3. | main session | - |

## Deviation judgements

| # | Deviation | Judgement |
|---|---|---|
| 1 | Recursion guard: `QUALITY_NESTED` plus the lock file; a nested run leaves out docs and refuses `--group docs` (exit 2); `T07_SKIP_NESTED=1` | **Accepted.** The guard is needed and well tested (`test_nested_run_...`, `test_live_lock_file_...`). The T07 variable use is accepted, but T07's documentation must say so (finding 11). |
| 2 | Sequential by default, `QUALITY_DOCS_JOBS=N`, CI sets 4 in the docs job only | **Accepted.** The local clash with DDEV and pre-commit is a real reason. Input validation and parallel-path tests are missing (finding 2). The effect on the budget is confirmed only by the KD-7 timings. |
| 3 | Developer edited `docs/tests/defects.md` (DEF-011) | **Edit stands**; the tester ratifies it (finding 12). |
| 4 | Output formats: `detail:`, `--list`, unexpected SKIP, listed-but-ran, `--group` errors, bad expected-skips line | **Accepted.** They match KD-2 and KD-3 word for word where the plan gives wording. The test cases that need a Change log row are listed below. |
| 5 | `check_ci.py --ddev-dir`; README Composer record on one line; YAML double-quoted continuation | **Accepted.** `--ddev-dir` is a superset of the plan's `--ddev-config` (both exist). The one-line record is what the rule 2 regex needs. The continuation is valid YAML and passes actionlint. |
| 6 | `include-hidden-files: true` in every job | **Accepted.** It is required, because upload-artifact skips hidden paths by default and `.tools/` is hidden. It also widens what a stale cache can leak into an artifact (finding 1). |
| 7 | Bootstrap: empty SHA fails, cached tarballs are re-verified, non-Linux-x86_64 exits; no unit test | **Behaviour accepted.** It closes the open item from T00 (fact 6). The missing test is finding 7, and the installed-binary gap is finding 6. |
| 8 | KD-13 item 2 not applied | **Accepted as pending owner** (finding 17). |
| 9 | `exceptions-report.txt` written by the `exceptions` step to `.tools/reports/` | **Accepted.** It matches KD-8 and TC-T08-62. |
| 10 | `77e4e61` PyYAML via `pip install -r`, version-pinned, no hashes | **Compliant.** `--require-hashes` is not required by the plan or the standards. The missing audit record is finding 4, and hash pinning is recommended there. |
| 11 | `24fe7fd` shellcheck 0.11.0 pinned by SHA-256, first on `PATH` for docs-regression only | **Accepted.** It removes a real runner and hook version skew. The audit and docs gaps are findings 4 and 5. The `core` job's actionlint still uses the runner's shellcheck 0.9.0 on `run:` blocks; that is acceptable, and TC-T08-24 records it. |

## Plan conformance

- **KD-1 and SA-2 conditions.**
  - (1) No check logic in YAML: met. Each job runs `mkdir` and then `quality.sh --group`; the
    `ci-ok` gate is presentation.
  - (2) The runner does not change the step set: met, `RunnerIndependenceTests` with a fake
    `ddev`.
  - (3) Toolchain parity: met for PHP and Composer through rule 2. Python and Node are wired
    for T13 and T21.
  - (4) Accepted differences: met; the PyYAML item is missing (finding 5e).
  - (5) `ddev quality` stays the local gate: met in the docs; the evidence belongs to the test
    step (TC-T08-70).
- **KD-2 and KD-3.** All 19 steps and five groups match the table, and build-drupal comes first
  in its group. `--show-diff-on-failure` and the JUnit flags are present. The expected-skips
  rules (unlisted, listed-but-ran, missing ticket, unknown step, group-scoped) are implemented
  and tested.
- **KD-4 and KD-5.** Pins and bootstrap: met, with findings 6 and 7. The actionlint hook
  matches the plan exactly.
- **KD-6.** Rules 1 to 6, the overrides and the fixtures are present, including the three
  rule 6 cases and block-style `needs`.
- **KD-7 and KD-8.** Shape, triggers, concurrency, timeouts, caches (finding 1), artifacts and
  the `ci-ok` expression all match.
- **KD-9.** No floor changed.
- **KD-12.** The T00 and T03 retrofit was reviewed (findings 9 and 10).
- **KD-13 item 5 and KD-14 (SA-3).** README notice: met. The three SA-3 deliverables are
  delivered: rule 6, the `.github/README.md` section and the master test plan note with its
  Change log row.
- **T07 files untouched.** `git diff --stat d935c2f..24fe7fd` shows nothing for the T07 file
  list.
- **Scope creep.** None beyond the two late dependencies (finding 4).

## Acceptance criteria status (code versus live evidence)

| AC | In code | Left for owner and live evidence |
|---|---|---|
| AC1 every suite step in CI | Met. `--list` equals the union of the job groups (rule 1), and SKIPs are declared | TC-T08-49: the job logs of a green run; TC-T08-70: the `ddev quality` run |
| AC2 red CI blocks merge | `ci-ok` gate correct (TC-T08-57 offline) | O-3 to O-5 settings, O-6 demo PR with "no bypass offered" evidence, closed unmerged (TC-T08-52 to 56). Record whether the ruleset was active at the PR #3 merge |
| AC3 10 min cold / 6 min warm | Design met (parallel jobs, timeouts) | O-7: 3 cold and 3 warm runs with URLs (TC-T08-59 to 61). The cold re-runs must delete caches; after finding 1 the cache content changes, so measure after the fix PR |
| AC4 artifacts | Uploads configured; **stale content defect (finding 1)** | TC-T08-62 to 64 on a warm run after the fix |
| AC5 secret names documented | Met. Rule 4 passes, and `ci-secrets.md` holds names only | TC-T08-42/43; KD-13 item 2 may move one name (finding 17) |

## Suspected test-case updates (for the tester, with Change log rows)

- **TC-T08-12** step 3: "Same run with a step forced to FAIL via `QUALITY_STEPS`" cannot keep
  `--group engine`, because `--group` with `QUALITY_STEPS` exits 2. Reword step 3 as a
  no-`--group` run.
- **TC-T08-15:**
  - the PASS output is now `detail: ok docs/tests/<T>/run-checks.sh` lines plus
    `detail: <n> docs suites run`;
  - a failure prints `FAILED: <script> --regression` and the last 40 lines;
  - the suite list grows to include T08 once `docs/tests/T08/run-checks.sh` exists.
- **New case (or extend TC-T08-15) for the recursion guard:**
  - `QUALITY_NESTED=1` leaves out the docs group with the `note:` line;
  - `--group docs` under nesting exits 2;
  - a live lock file nests, and a stale lock file does not.
- **New case (or extend TC-T08-15) for `QUALITY_DOCS_JOBS`:**
  - the default is 1;
  - CI sets 4 in the `docs` job only;
  - parallel results are reported in order;
  - an invalid value exits 2 (after finding 2).
- **TC-T08-08:** optionally assert that the stderr of a bad line names `<file>:<line>`.
- **TC-T08-22, 23 and 71:** add `SHELLCHECK_VERSION` and `SHELLCHECK_SHA256` (and their
  mismatch control) and `scripts/requirements-docs-tests.txt` (PyYAML 6.0.3).
- **TC-T08-71** step 1: clone `main` (at or after `d82fe2a`) or the fix branch; the
  `task/T08-ci-baseline` branch is merged.
- **TC-T08-24:** the runner shellcheck is known (0.9.0). Record which shellcheck actionlint
  used in the `core` job.
- **TC-T08-62:** add "each `reports-<g>` holds only files produced by that job in that run"
  (finding 1). Run it on a warm run.
- **TC-T08-58:** add "`.tools/reports` is excluded from the `.tools` cache" (after finding 1).
- **TC-T08-14 and the T08 harness:** when `docs/tests/T08/run-checks.sh` is written,
  docs-regression will run it, nested, in the `docs` job with `QUALITY_NESTED=1`. Any harness
  check that calls `quality.sh --group docs` then gets exit 2. The harness must honour
  `--regression`, tag live and owner cases as BLOCKED, and stay inside the docs job budget.
- **TC-T08-69:** unchanged, but if KD-13 item 2 applies, the allowed `deploy-drupal.yml` line
  lands on the fix branch.

## Left for the test step

- Write `docs/tests/T08/run-checks.sh` (nesting-aware, see above) and run the offline cases.
- Live and owner evidence: TC-T08-49 to 56 (CI run, branch-name on PR and push, settings,
  ruleset, demo PR), TC-T08-59 to 61 (timing, after the fix PR), TC-T08-62 to 64 (artifacts,
  warm run), TC-T08-65 to 67 (KD-13 checklist), TC-T08-70 (`ddev quality`).
- Ratify the `defects.md` edit (finding 12). Apply findings 9 to 11.
- State in the report that `.env.example` is unchanged (C6), that the merge preceded review
  and test, and when the ruleset became active.

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | The plan (`705462e`) was approved on 2026-11-03 and is the first commit in the range, before any code commit |
| C2 Review findings resolved | No | Finding 1 (Major) and findings 2 to 12 are open. The fixes go on `task/T08-review-fixes` |
| C3 Criteria mapped to executed tests | No (test step) | 73 cases are designed and mapped; none executed. The harness is not written |
| C4 CI green | Partly | PR #3 checks were green (owner). The first `push` run on `main` (`d82fe2a`) and the fix PR are still to be recorded. Local unit tests, `check_ci.py`, actionlint and `check-names.sh` are clean |
| C5 Docs updated | Partly | `ci-secrets.md`, the READMEs, the standards and `local-setup.md` are updated, with gaps (findings 4 and 5). TRACEABILITY NFR-07 and R-12, OQ-03 and RK-06 in `solution-architecture.md` (solution-architect) and PROGRESS are due at close |
| C6 No secrets | Yes | No secrets in `ci.yml`; `.env.example` unchanged; the history scan runs in CI with `--redact` |
| C7 Clean-checkout works | Partly | Every CI run is a clean checkout. A local fresh clone needs PyYAML, which is undocumented (finding 5a). Evidence comes in TC-T08-71 |

## Approval (original review)

Superseded by the re-review below.

**Changes requested.** Finding 1 (Major) must be fixed on `task/T08-review-fixes`. Findings 2
to 12 must be fixed or ticketed with an ID before approval. The owner items (finding 17,
O-3 to O-7) and C3 belong to the test step. The simulation-only rule is met: no broker SDK,
broker API or trading domain anywhere in the range, and `scripts/check-names.sh` is clean.

technical-architect, 2026-11-04

## Re-review (2026-11-04)

| Field | Value |
|---|---|
| Range | `1dcf8f4..a4354ec` (`e05d714`, `a4354ec`) plus `ffaf747` (owner evidence only) on `task/T08-review-fixes` |
| Reviewer | technical-architect |

### What was checked

- I read the full diff of `e05d714` and `a4354ec`: `ci.yml`, `bootstrap-dev.sh`, `quality.sh`,
  the new `scripts/docs_regression.sh`, `requirements-docs-tests.txt`, the new
  `test_bootstrap_dev.py`, the changes to the three existing test modules, `.github/README.md`,
  `local-setup.md`, `scripts/README.md` and the standards table. I scanned `ffaf747`'s
  evidence for tokens and addresses: only the noreply address and the redacted
  negative-control finding (0 raw key occurrences).
- Read-only tools at `ffaf747`, on host Python 3.10.12:
  - `python3 -I scripts/check_ci.py`: rules 1 to 6 PASS.
  - `.tools/actionlint .github/workflows/*.yml`: exit 0.
  - `scripts/check-names.sh`: OK.
  - `.tools/shellcheck` (0.11.0) on `docs_regression.sh`, `quality.sh` and `bootstrap-dev.sh`:
    exit 0.
  - `python3 -m unittest discover -s scripts/tests`: 152 tests, OK.
  - The markdownlint hook on `local-setup.md` and `scripts/README.md`: Passed.
  - `env -u MYPYPATH .tools/pre-commit run mypy --files scripts/tests/test_check_ci.py
    scripts/tests/test_bootstrap_dev.py`: **fails** with `test_check_ci.py:14: error: Cannot
    find implementation or library stub for module named "check_ci" [import-not-found]`
    (finding R-1).

### Status of the original findings

| # | Sev | Status | Evidence and judgement |
|---|---|---|---|
| 1 | Major | Fixed (`e05d714`) | Both `.tools` caches now use `path:` `.tools`, `!.tools/reports`, `!.tools/suite-bin`. **The cache exclusion alone is enough.** Each job runs on a fresh runner with a fresh checkout. `.tools/` is git-ignored, so the only way an older report reached a job was the cache restore, and that path is now closed. Emptying `.tools/reports` in `quality.sh` is not needed, and the developer is right that it would break several `--group` runs in a row locally. Locally a stale file never reaches an artifact. The tester confirms the fix in TC-T08-62 on a warm run (each `reports-<g>` holds only that job's files) |
| 2 | Minor | Fixed (`a4354ec`) | `^[1-9][0-9]*$` is checked in `quality.sh` (also when the variable is set but empty) and again in `docs_regression.sh`; both exit 2. Tests cover `0`, `abc`, empty, `-1`, `1.5` and `2 3`, the direct script call, and a three-suite parallel run with one failing suite (order and naming) |
| 3 | Minor | Fixed (`a4354ec`), one residual (R-3) | The logic is in `scripts/docs_regression.sh` (73 lines, shellcheck clean). `quality.sh` drops back to one line for the step, and the long lines are gone |
| 4 | Minor | Fixed (`a4354ec`) | Audit table in `.github/README.md`, "Dependency audit"; two rows in the CODING_STANDARDS tool table. PyYAML hash pinning stays an open owner choice. It is optional, so it does not block |
| 5 | Minor | Fixed (`a4354ec`) | (a) PyYAML is a prerequisite in `local-setup.md`. (b) shellcheck is named in bootstrap, the READMEs and the runbook. (c) The network sentence is corrected in both places. (d) The runner shellcheck 0.9.0 is recorded. (e) Accepted difference 4 is added |
| 6 | Minor | Fixed (`e05d714`) | Each binary is always re-installed from the verified tarball. `test_untrusted_installed_binary_is_replaced_from_the_verified_tarball` proves it |
| 7 | Minor | Fixed (`a4354ec`), one residual (R-2) | `test_bootstrap_dev.py` has 8 tests with a fake `curl` and `uname`: good pins, empty SHAs, mismatches, cached-tarball re-check, platform guard, planted binary. The tests assert behaviour (exit codes, files present or absent, archive removed, no re-download) |
| 8 | Minor | Fixed (`a4354ec`) | TC-T08 IDs are in the class and method docstrings of the T08 tests |
| 9 | Minor | Open (tester) | T03 invariant check and Change log correction |
| 10 | Minor | Open (tester) | T00 unused `cka` and SC2329 directive |
| 11 | Minor | Open (tester) | T07 documentation of `T07_SKIP_NESTED` |
| 12 | Minor | Open (tester) | Ratify the DEF-011 edit |
| 13 | Note | - | Unchanged; the guard moved into `docs_regression.sh` without change |
| 14 | Note | Done (`a4354ec`) | Per-suite logs go to `.tools/reports/docs/<Txx>.txt`; the directory is emptied at the start of each docs-regression run. A test asserts the content |
| 15, 16 | Note | - | Re-checked: `ci.yml` changes only the two cache `path:` blocks. Pins, permissions and expressions are unchanged |
| 17 | Note | Resolved by the owner (no code change) | Evidence `KD13-secret-scan.20261104.txt`: no repository secrets or variables exist, `DEPLOY_SMOKE_HEADER` is not set, `deploy-drupal.yml` is unchanged. The docs follow-up is R-4 |
| 18 | Note | Open (close step) | PROGRESS row |

### New findings

| # | Severity | File | Issue | Resolution | Owner | Status |
|---|---|---|---|---|---|---|
| R-1 | Minor | `mypy.ini:5-8` (hook in `.pre-commit-config.yaml:53-55`) | **mypy fails on a partial commit unless `MYPYPATH=scripts` is set.** The test modules import `check_ci`, `exceptions_report` and `_helpers` by bare name. When pre-commit passes only a test file, mypy cannot resolve `check_ci` (reproduced above). A full `--all-files` run passes, because the module files are then on the command line. For `a4354ec` the developer set `MYPYPATH` in their own shell. No hook was skipped, so this is not a bypass, but every other contributor and agent will hit the same failure on a commit that touches only a test file. The pattern dates from T04a (`import exceptions_report`), and T08 adds more of it. Setting the path in the developer's shell is not reproducible configuration. | Put it in the config that the hook already reads: add `mypy_path = scripts` (and, if needed, `scripts/tests`) under `[mypy]` in `mypy.ini`. Do not use a hook-only `args:` entry, so that manual `mypy` runs behave the same. Verify both `env -u MYPYPATH .tools/pre-commit run mypy --files scripts/tests/test_check_ci.py` and `--all-files` (watch for "source file found twice"). | developer | Open |
| R-2 | Minor | `scripts/tests/test_bootstrap_dev.py:62-125` | **The bootstrap tests fail, instead of skipping, on a Python 3.10 host without the DEF-003 workaround.** The copied script runs the DEF-003 guard first. If `python3` on `PATH` is 3.10 without `typing_extensions` 4.16 or newer outside site-packages, every test gets exit 1 at the guard, and `tooling-tests` (and so `ddev quality`) fails for a reason that has nothing to do with the pins. This review host (3.10.12 with the workaround) and CI (3.12) pass. CODING_STANDARDS makes 3.10 the minimum for `scripts/`. | In `setUpClass`, run the same guard probe with the `python3` on `PATH`. If it fails, `skipTest("DEF-003: bootstrap needs Python 3.11+ or the typing_extensions workaround")`; the ticket makes the skip compliant with REVIEW_CHECKLIST 5. Alternatively, fail with one clear message naming DEF-003. Do not change the guard. | developer | Open |
| R-3 | Minor | `scripts/docs_regression.sh:21` | `set -uo pipefail` without `-e`, and no comment gives the reason (CODING_STANDARDS "Shell scripts": start with `set -euo pipefail`; `quality.sh:31-32` documents its own exception). Leaving out `-e` is correct here, because each suite's failure must be collected and not stop the run. | Add a one-line comment giving the reason, as in `quality.sh`. | developer | Open |
| R-4 | Minor | `docs/runbooks/ci-secrets.md:53` (and `:42-45`) | The `DEPLOY_SMOKE_HEADER` row still says "Pending the owner decision of plan KD-13 item 2". The owner has now decided: none is set. The secrets table reads as if `TERMINUS_MACHINE_TOKEN` and `PANTHEON_DEPLOY_KEY` are set, but no repository secret exists yet (the deploy job skips itself until `PANTHEON_SITE` is set). | Record the outcome: "2026-11-04: no secrets or variables set; KD-13 item 2 not applicable". Keep the rule for later: a `Deterrence-Bypass` value must be a secret, and the change cites T07. Mark the two secrets "named by the workflow, not set yet". | developer | Open |
| R-5 | Note | `scripts/tests/test_quality_sh.py` (`test_parallel_run_...`) | The parallel test asserts order and naming, which is what matters, but not that the suites ran at the same time. A sequential run would also pass it. | Optional: assert that three suites that each sleep 0.3 s finish in less than about 0.8 s. | developer (optional) | - |
| R-6 | Note | `docs/tests/T08/evidence/O6-demo-pr4.20261104.txt` | On demo PR #4 the `docs` job also failed, because T04a's suite runs `unittest discover` over `scripts/tests` and picks up the demo test. That is correct behaviour (a broken tooling test should fail there too), and the merge was blocked either way. | The tester records it in TC-T08-54 as expected. The merge-box screenshot showing that no bypass is offered is still needed for AC2. | tester, owner | - |

### Answers to the coordinator's questions

- **Cache exclusion versus emptying `.tools/reports`:** the exclusion alone closes finding 1
  (see row 1 above). No change to `quality.sh` is required.
- **`MYPYPATH=scripts`:** this is a finding (R-1, Minor), not only a note. The hook ran and
  passed, so there was no bypass. But the passing state depends on an undocumented environment
  variable, so the setting belongs in `mypy.ini`.
- **DEF-003 dependency of the bootstrap tests:** R-2, Minor. Skip with the DEF-003 ticket, or
  fail with one clear message.

### Owner-step status (updates "Left for the test step")

- Done, with evidence in `ffaf747`:
  - the repository is public (2026-11-04);
  - the KD-13 full-history scan covered all 15 refs with 0 findings, plus a negative control
    (TC-T08-65);
  - KD-13 item 2 is not applicable (no secrets or variables, TC-T08-66);
  - the owner keeps the email in the T07 evidence (item 3);
  - the `main` ruleset is active with deletion, non-fast-forward, pull request (merge only),
    required check `ci-ok` and strict mode (TC-T08-53);
  - demo PR #4 was closed unmerged with `ci-ok`, `core` and `docs` failing (TC-T08-54 and 55).
- Still needed:
  - the merge-box evidence that **no bypass option is offered** (AC2, TC-T08-54). Without it,
    AC2 is not met;
  - the O-3 and O-4 settings record (TC-T08-52), and the admin-only post-flip settings
    (secret scanning, push protection, fork approval; TC-T08-67), which the evidence notes as
    not visible through the API;
  - the timing runs (O-7, TC-T08-59 to 61). They are measured after this fix PR, because the
    cache content changed;
  - the warm-run artifact check (TC-T08-62 to 64);
  - the first `push` run on `main` (TC-T08-51), and TC-T08-70 (`ddev quality`; the developer
    reports PASS 12 FAIL 0 SKIP 7, which the tester records with evidence);
  - the T08 harness;
  - findings 9 to 12;
  - the test-case Change log rows listed above. Also add one for
    `.tools/reports/docs/<Txx>.txt` and `scripts/docs_regression.sh` (TC-T08-15, 30, 62).

### Common criteria after the re-review

| Criterion | Met? | Notes |
|---|---|---|
| C1 | Yes | Unchanged |
| C2 | Partly | The Major finding is fixed. Findings 9 to 12 (tester) and R-1 to R-4 are open Minors, to be fixed or ticketed before close |
| C3 | No (test step) | The harness and the executed cases are pending |
| C4 | Partly | The local checks are green. The CI run on the fix PR and the first `push` run on `main` are still to be recorded |
| C5 | Partly | Findings 4 and 5 are fixed; R-4 is open. TRACEABILITY, `solution-architecture.md` (solution-architect) and PROGRESS are due at close |
| C6 | Yes | No secrets; `.env.example` unchanged; the owner evidence holds only redacted output |
| C7 | Partly | The doc gap is fixed (5a). R-2 affects clean checkouts on Python 3.10. Evidence comes in TC-T08-71 |

## Approval

**Approved with conditions.** No Blocker or Major finding is open. Finding 1 is fixed, and the
cache exclusion alone is sufficient. The conditions:

1. R-1 to R-4 are fixed on `task/T08-review-fixes`, or each is ticketed with an ID, before
   `/close-task`.
2. The tester resolves findings 9 to 12 in the test step.
3. AC2 is met only when the "no bypass offered" merge-box evidence is in the test report.
4. AC3 and AC4 are measured on runs that include `e05d714`.
5. CI is green on the fix PR, and the first `push` run on `main` is recorded (C4).

The simulation-only rule is met: no broker SDK, API or trading domain in the range.

technical-architect, 2026-11-04 (re-review)
