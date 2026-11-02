# T04a: Coding standards and quality gates, Review (tooling and baseline cleanup)

| Field | Value |
|---|---|
| Task | T04a |
| Reviewer | technical-architect |
| Date | 2026-11-01 |
| Commit range | First review `80d681a..ddad7b7`; re-review `80d681a..32316fb` (`d76614a` is the reworded `ddad7b7`; fixes in `ef6d4be`, `5567fbf`, `32316fb`) |
| Plan | `docs/tasks/T04a/plan.md` |
| Scope of this review | Developer tooling, configs, pre-commit, `quality.sh`, wrapper, bootstrap, baseline cleanup. The standards documents are reviewed for content by the solution-architect (`review-standards.md`); here they are checked only for consistency with the tooling. |

## What was run (read-only), first review

| Command | Result |
|---|---|
| `python3 -m unittest discover -s scripts/tests` | 50 tests, OK |
| `python3 -m unittest discover -s .claude/hooks/tests` | 30 tests, OK |
| `docs/tests/T04a/run-checks.sh` (agent mode) | 282 executed, 3 FAIL (TC-27, TC-33, TC-34 review not yet written), 7 SKIP (linters not installed), 10 BLOCKED |
| `python3 scripts/check_commit_msg.py --range origin/main..HEAD` | exit 1: `ddad7b7` (75 chars), `1b8a031` (78), `085b3e9` (81) |
| `QUALITY_STEPS=<(printf 'one\t-\tcat\ntwo\t-\ttrue\nthree\t-\tfalse\n') scripts/quality.sh` | only `PASS one`, `summary: PASS 1 FAIL 0 SKIP 0`, exit 0 (finding 1) |
| `git diff 2d3a9e5~1 2d3a9e5 --word-diff=porcelain -- '*.md'` | 0 changed words; no table row touched |
| T03 and T04 `run-checks.sh` (inside TC-T04a-30) | Same PASS counts as at close |

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `scripts/quality.sh:94-109` | Steps inherited stdin from the loop that reads the steps file; a stdin-reading step swallowed the remaining steps, which were never counted, and the script exited 0. | Run steps with stdin closed or read steps on another fd; regression test; check PASS+FAIL+SKIP equals steps read. | Fixed (`ef6d4be`): steps read on fd 3, each step gets `</dev/null`, count check added, `scripts/tests/test_quality_sh.py`. Probe now gives `PASS 2 FAIL 1`, exit 1. |
| 2 | Major | `scripts/check_commit_msg.py`, `scripts/quality.sh` | Ruling (a): `origin/main..HEAD` includes T01 and T02 subjects over 72 characters (`085b3e9`, `1b8a031`) because `main` holds none of the task branches. Decision: rule applies from the first T04a commit via a fixed boundary `RULE_START = 7689ec5...`, not a grandfather list. Missing boundary must not silently check a different range. | `RULE_START` constant with ticket comment, `git log <range> ^RULE_START`, `--rule-start` override, error on missing boundary, tests, D-3 addendum. | Fixed (`ef6d4be`, D-3 addendum in `32316fb`). Range check on this branch exits 0. Deviation ruled on below (R-1). |
| 3 | Major | commit `ddad7b7` | The T04a commit had a 75-character subject. | Amend the tip message before push. | Fixed: reworded as `d76614a` (`T04a: standards, review checklist, agent and CLAUDE.md refs`). |
| 4 | Major | `docs/tests/T04a/run-checks.sh` (TC-T04a-27) | Ruling (b): the long-line checker read YAML front matter, which markdownlint ignores. Test-script defect; `.claude/` files do not change. | Skip leading front matter in `mdlen`, self-test, Change log row. | Fixed (`32316fb`); TC-27 passes; independent scan finds 0 long prose lines. |
| 5 | Major | `docs/tests/T02`-`T04` test docs | Ruling (c): 72 long prose lines remained; tester to reflow word-neutrally and re-run the T02 to T04 checks. | Reflow, compare PASS counts before and after. | Fixed (`32316fb`); before and after evidence in `docs/tests/T04a/evidence/reflow-*-T0{2,3,4}.txt`; 0 long lines remain. |
| 6 | Major | `docs/tests/T04a/run-checks.sh` (TC-T04a-33) | Ruling (d): `.env.example` compared with `main`, where it does not exist. Test-script base defect. | Compare with the parent of the first T04a commit. | Fixed (`32316fb`); TC-33 passes. |
| 7 | Minor | `scripts/exceptions_report.py` `SKIP_PATH` | Whole-directory skip of `scripts/tests/` hides real suppressions there. | Narrow to the script and fixtures. | Accepted deviation (R-2): `scripts/tests/` now holds 17 intentional literal directives for the slot-form tests; the skip carries a `T04a:` reason on the line. `docs/tests/T04a/` was narrowed to named files. |
| 8 | Minor | `scripts/exceptions_report.py` `CONFIG_FILE` | Missed `.pre-commit-config.yaml`, `.gitleaks.toml`, `.shellcheckrc`, `.hadolint.yaml`, `.spectral.yaml`. | Add them and their keys. | Fixed (`ef6d4be`): files added; `disable`, `ignored`, gitleaks `paths`, Spectral `rule: off` detected; tests added. |
| 9 | Minor | `scripts/check_assets.py` | Drupal `*.libraries.yml` and `*.theme` not scanned. | Add them with a test. | Fixed (`ef6d4be`): `DRUPAL_FILE` for the theme scope and a `libraries.yml` key pattern; test added. |
| 10 | Minor | `scripts/check_commit_msg.py:67` | Any `Merge` subject passed. | In `--range`, exempt `Merge` only for commits with two or more parents. | Fixed (`ef6d4be`): parents read with `%P`; tests added. |
| 11 | Minor | `scripts/quality.sh:15` | `-e` omitted without a reason. | Comment why. | Fixed (`ef6d4be`). |
| 12 | Minor | `scripts/quality.sh:2-3`, plan Goal | Said pre-commit calls `quality.sh`. | Reword. | Fixed in `quality.sh` (`ef6d4be`). Plan wording: technical-architect corrects at close. |
| 13 | Minor | `scripts/coverage_gate.py` | Unmatched component skipped silently; floor `1` read as 100%. | `not measured` line, `--require PREFIX`, percentage always. | Fixed (`ef6d4be`); `quality.sh` component steps pass `--require`; tests added. |
| 14 | Minor | Standards tool table vs `.pre-commit-config.yaml` | markdownlint-cli2 and hadolint pins disagreed. | Align. | Fixed (`32316fb`): table now `0.18.1` and `2.12.1b3 (hadolint-py rev)`, both "verify". |
| 15 | Minor | `CODING_STANDARDS.md` coverage rule | Said the gate reads `line-rate`. | Reword. | Fixed (`32316fb`): text now says the gate counts `<line hits>` per prefix and does not read `line-rate`. |
| 16 | Note | `scripts/check_branch_name.py:189` | CI `push` events have no `GITHUB_HEAD_REF`. | T08: `pull_request` only or `GITHUB_REF_NAME`. | Ticketed (T08) |
| 17 | Note | `scripts/check_assets.py:176` | Hex regex may match JS private fields (`this.#add`). | T21a refines. | Ticketed (T21a) |
| 18 | Note | `ruff.toml:4,11` | Comment lines over 100 characters. | Fix on next touch. | Fixed (`ef6d4be`) |
| 19 | Note | `2d3a9e5` | Reflow word-neutral; helper changes behaviour-neutral. | None. | n/a |
| 20 | Minor | `scripts/exceptions_report.py:114` | New in re-review: `XML_EXCLUDE =re.compile(...)` lacks a space after `=`. `ruff format --check` (pre-commit step, TC-T04a-37) will fail on it. | Developer: `XML_EXCLUDE = re.compile(...)` before the owner-run cases. Also move `@ts-ignore` into the `SUPPRESSIONS` literal instead of the following `append` (style only, optional). | Open |

## Re-review 2026-11-01 (`d76614a..32316fb`)

Run read-only:

| Command | Result |
|---|---|
| `python3 -m unittest discover -s scripts/tests` | 65 tests, OK |
| `python3 -m unittest discover -s .claude/hooks/tests` | 30 tests, OK |
| `docs/tests/T04a/run-checks.sh` | 302 executed, all PASS, 7 SKIP (linters absent), 16 BLOCKED (owner-run or deferred) |
| `python3 scripts/check_commit_msg.py --range origin/main..HEAD` | exit 0 |
| stdin probe from finding 1 | `PASS 2 FAIL 1 SKIP 0`, exit 1 |
| `python3 scripts/exceptions_report.py` | exit 0 on the tree |

Rulings on the developer's deviations:

- **R-1, missing `RULE_START` (finding 2): accepted.** The script exits 2 when the boundary is
  missing and either `--rule-start` was given or the clone is shallow. Otherwise it checks the full
  range. In this repository the boundary is always present in a full clone: once T04 is on
  `main`, every clone has it. The only full clone without it is a different repository, such as a
  TC-14 throwaway repo. That repo has no pre-rule history to exempt, so checking the full range
  there is correct. The shallow-clone case, the silent hazard, is an error. Condition for T08: the
  CI checkout uses `fetch-depth: 0`, or the commit-range step fails with exit 2.
- **R-2, `scripts/tests/` whole-directory skip (finding 7): accepted as a permanent exclusion.**
  The tests now quote 17 directive forms on purpose, including invalid ones, to test the D-4 slot
  rule. Narrowing the skip would mean moving them all into fixture files, for little gain. The
  exclusion cites `T04a:` on the line, as D-4 allows for a permanent decision. Residual risk: a
  real suppression added to a test is not ticket-checked. ruff, mypy and this review still see
  it. Reviewers check suppressions in `scripts/tests/` by hand (checklist section 4,
  "Exceptions").

## Simulation-only and secrets

No broker SDK, client or domain in the change. New outbound URLs are only the pre-commit hook
repositories on GitHub and the CDN host names that `check_assets.py` rejects. No secrets;
`.env.example` unchanged (TC-T04a-33 passes after the fix).

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | Plan Approved and committed in `80d681a` before `1ac0b9d` |
| C2 Review findings resolved | Yes | Findings 1 to 15 and 18 fixed or accepted (R-1, R-2); 16 and 17 ticketed; 20 is Minor, open |
| C3 Criteria mapped to executed tests | Partly | 302 agent checks pass; owner-run TC-36 to 47 and deferred TC-48 to 52 pending (D-6 owner acceptance) |
| C4 CI green | Pending | Agent checks and commit range pass; ruff, mypy, shellcheck, yamllint, markdownlint and hadolint only run in owner-run TC-36 to 45 (fix finding 20 first) |
| C5 Docs updated | Yes | `scripts/README.md`, `.ddev/README.md`, CLAUDE.md, TRACEABILITY R-12 and NFR-18, D-3 and D-4 addenda |
| C6 No secrets | Yes | See above |
| C7 Clean-checkout works | Pending | Owner-run TC-36 and 38 |

## Approval

Approved with conditions. No Blocker or Major finding is open. Conditions:

1. Fix finding 20 before the owner-run cases.
2. The owner-run cases TC-T04a-36 to 47 pass and are recorded in the test report (C4, C7).
3. The owner accepts each deferred case (TC-48 to 52) in writing, under D-6.
4. T08 uses `fetch-depth: 0` (R-1).

technical-architect, 2026-11-01.
