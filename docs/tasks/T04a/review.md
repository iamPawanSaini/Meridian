# T04a: Coding standards and quality gates, Review (tooling and baseline cleanup)

| Field | Value |
|---|---|
| Task | T04a |
| Reviewer | technical-architect |
| Date | 2026-11-01 |
| Commit range | `80d681a..ddad7b7` (`1ac0b9d` tooling, `2d3a9e5` baseline cleanup, `ddad7b7` standards docs and main-session edits) |
| Plan | `docs/tasks/T04a/plan.md` |
| Scope of this review | Developer tooling, configs, pre-commit, `quality.sh`, wrapper, bootstrap, baseline cleanup. The standards documents are reviewed for content by the solution-architect (`review-standards.md`); here they are checked only for consistency with the tooling. |

## What was run (read-only)

| Command | Result |
|---|---|
| `python3 -m unittest discover -s scripts/tests` | 50 tests, OK |
| `python3 -m unittest discover -s .claude/hooks/tests` | 30 tests, OK |
| `docs/tests/T04a/run-checks.sh` (agent mode) | 282 executed, 3 FAIL (TC-27, TC-33, TC-34 review not yet written), 7 SKIP (ruff, mypy, shellcheck, yamllint, markdownlint, pre-commit not installed), 10 BLOCKED (owner-run or deferred) |
| `python3 scripts/check_commit_msg.py --range origin/main..HEAD` | exit 1: `ddad7b7` (75 chars), `1b8a031` (78), `085b3e9` (81) |
| `QUALITY_STEPS=<(printf 'one\t-\tcat\ntwo\t-\ttrue\nthree\t-\tfalse\n') scripts/quality.sh` | prints only `PASS one`, `summary: PASS 1 FAIL 0 SKIP 0`, exit 0 (see finding 1) |
| `git diff 2d3a9e5~1 2d3a9e5 --word-diff=porcelain -- '*.md'` | 0 changed words; no table row touched. Reflow is word-neutral. |
| T03 and T04 `run-checks.sh` (inside TC-T04a-30) | Same PASS counts as at close; helper cleanup is behaviour-neutral |

ruff, mypy, shellcheck, yamllint, markdownlint and hadolint are not installed here, so C4 rests on
the owner-run cases TC-T04a-36 to 45.

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `scripts/quality.sh:94-109` | Each step runs as `bash -c "$cmd"` with stdin inherited from the `while read ... done <"$steps_file"` loop. A step that reads stdin (for example `ddev exec`, `docker exec -i`, any tool that reads a pipe) consumes the remaining step lines. Those steps never run, are counted as neither PASS, FAIL nor SKIP, and the script exits 0. Reproduced: steps `cat`, `true`, `false` give `PASS 1 FAIL 0 SKIP 0`, exit 0. This is a silent pass of the quality gate. | Developer: run each step with stdin closed, `output="$(bash -c "$cmd" </dev/null 2>&1)"`, or read the steps on a separate descriptor (`while IFS=$'\t' read -r -u 3 name manifest cmd; do ... done 3<"$steps_file"`). Add a `TC-T04a-24`-style unit case (tester) and a fake-step regression: a stdin-reading step followed by a failing step must give FAIL and a non-zero exit. Also print the number of steps read and assert in the summary that PASS+FAIL+SKIP equals it. | Open |
| 2 | Major | `scripts/check_commit_msg.py:89-105`, `scripts/quality.sh:48-50` | Ruling on issue (a). `main` (`3eb3351`) holds none of the task branches, so `origin/main..HEAD` contains T00 to T04a, and `085b3e9` (T01, 81 chars) and `1b8a031` (T02, 78 chars) fail. D-3 meant pre-rule history to be exempt; it assumed those commits were on `main`. History rewrite is not allowed (evidence cites these SHAs). **Decision: the rule applies from the first T04a commit onward**, through a fixed rule-start boundary, not a grandfather list (a list can grow; a boundary cannot). | Developer: in `check_commit_msg.py` add `RULE_START = "7689ec5774ed54ff9e144e9a99c289b9998e6632"  # T04a: commit rules apply from T04a on (D-3); earlier commits exempt` (the T04 close commit, parent of `80d681a`). In `check_range`, run `git log --format=%H%x1f%s <range> ^RULE_START`. Add `--rule-start REV` (default `RULE_START`) so tests can pass their own boundary. If `git cat-file -e RULE_START^{commit}` fails (shallow clone), exit 2 with "fetch full history (fetch-depth: 0)"; do not silently check the full range. Tests: in a throwaway repo, a bad subject that is an ancestor of the boundary but not of the base passes; a bad subject after the boundary fails; a missing boundary exits 2. Update the `quality.sh` comment and `scripts/README.md`. Solution-architect: record this as a D-3 addendum (implementation of the existing intent, no change of rule). T08: CI checkout must use `fetch-depth: 0`. | Open |
| 3 | Major | commit `ddad7b7` | The T04a commit itself breaks the rule T04a introduces: subject is 75 characters (`T04a: coding standards and review checklist; agent and CLAUDE.md references`). The boundary in finding 2 does not exempt it, and should not. The SHA is not cited in any file and the branch is not pushed. | Main session: amend the message of the tip commit only (tree unchanged) before push and before the test report records SHAs, for example `T04a: standards, review checklist, agent and CLAUDE.md refs` (59 chars). If the owner refuses any amend, the fallback is to set `RULE_START` to `ddad7b7` instead and record that in the D-3 addendum. Run `bootstrap-dev.sh` (commit-msg hook) before the next T04a commit so this cannot recur. | Open |
| 4 | Major | `docs/tests/T04a/run-checks.sh:621-637` (TC-T04a-27) | Ruling on issue (b). The long-line checker reads YAML front matter in `.claude/agents/*.md` (lines 3 and 12) and `.claude/commands/review-task.md`, `test-task.md` (10 lines in all: `description:` and hook `command:` values). markdownlint-cli2 strips front matter before MD013 (`frontMatter` default), so the real gate accepts these files. The front matter is YAML whose values Claude Code parses; folding them adds risk for no benefit. **This is a test-script defect; the files do not change.** | Tester: in `mdlen`, skip a leading front-matter block (line 1 is `---`, up to the next `---`), add a self-test line for it in `mdself`, and add a Change log row in `test-cases.md`. Main session: no change needed in `.claude/`; the plan's step 6 "reflow `.claude/agents/*.md`" is satisfied for the body text. | Open |
| 5 | Major | `docs/tests/T02/`, `T03/`, `T04/` `test-cases.md` and `test-report.md` | Ruling on issue (c). 72 prose lines over 100 characters remain (T02: 14 + 9, T03: 15 + 10, T04: 15 + 9). markdownlint would fail them in `pre-commit run --all-files`, so TC-T04a-37 (zero violations) and C4 cannot pass. The developer is blocked from `docs/tests/` by the path guard. | Tester: reflow these six files in a separate commit (`T04a: reflow T02-T04 test docs to 100 columns`), word-neutral (`git diff --word-diff=porcelain` shows no changed words, no table rows touched). Then re-run T02, T03 and T04 `run-checks.sh`: some checks grep these files, so confirm the PASS counts are unchanged and record them in the T04a report. | Open |
| 6 | Major | `docs/tests/T04a/run-checks.sh:739` (TC-T04a-33) | Ruling on issue (d). `envsame` compares `.env.example` with local `main` and `origin/main` (`3eb3351`), where the file does not exist (it was added in `950b9b6`, T00). `git diff --quiet main -- .env.example` therefore reports a difference, a false FAIL. **Test-script base defect.** | Tester: compare with the commit before T04a, for example `base=$(git log --reverse --format=%H --grep='^T04a:' | head -1)^` and `git diff --quiet "$base" HEAD -- .env.example`, and add a Change log row. Keep the check an invariant only if it is re-based per task; otherwise tag it `cka`. | Open |
| 7 | Minor | `scripts/exceptions_report.py:49-52` | `SKIP_PATH` skips all of `scripts/tests/` and `docs/tests/T04a/`. The test files already split directive strings (`"# " + "noqa"`), so the blanket skip is not needed for them, and it hides any real suppression in those directories. The skip is itself an untracked exclusion. | Narrow the skip to `scripts/exceptions_report.py`, `scripts/tests/fixtures/` and `docs/tests/T04a/reference/` (if it holds quoted directives), each with a `T04a:` comment. Confirm the tree still reports clean. | Open |
| 8 | Minor | `scripts/exceptions_report.py:53-57` | `CONFIG_FILE` does not cover `.pre-commit-config.yaml` (`exclude:` keys), `.gitleaks.toml` (allowlist paths), `.shellcheckrc` (`disable=`), `.hadolint.yaml` (`ignored:`) or `.spectral.yaml` (rules set to `off`). An exclude added there later escapes the ticket rule. | Add these files to `CONFIG_FILE`, and add `disable`, `ignored`, `paths` (gitleaks allowlist) to `EXCLUDE_KEY` for those files. Add one test per file type. | Open |
| 9 | Minor | `scripts/check_assets.py:153` | `ASSET_FILE` omits `*.libraries.yml`, `*.info.yml`, `*.theme` and `*.json`. Drupal themes load external CSS, JS and fonts through `libraries.yml` (`type: external`), so a Google Fonts URL there passes. | Add `yml`, `yaml`, `theme` and `json` for the Drupal theme scope (at least `libraries.yml`), and a test with a `fonts.googleapis.com` library entry. T21a may refine. | Open |
| 10 | Minor | `scripts/check_commit_msg.py:67` | Any subject starting with `Merge ` passes, so `Merge my local fixes` lands without a task ID. | In `--range` mode, exempt `Merge ` only when the commit has more than one parent (`%P` in the log format). In `--msg-file` mode keep the prefix rule (git writes `Merge ` for real merges). Add tests. | Open |
| 11 | Minor | `scripts/quality.sh:15` | `set -uo pipefail` omits `-e`, contrary to the shell rule (`set -euo pipefail`) in `CODING_STANDARDS.md`. The omission is deliberate (the loop aggregates failures) but not explained. | Add a comment on the line: why `-e` is off (each step's status is captured). Same for any other deliberate departure. | Open |
| 12 | Minor | `scripts/quality.sh:2-3`, `docs/tasks/T04a/plan.md` (Goal) | The header says the pre-commit hooks call `quality.sh`. They do not: `quality.sh` runs pre-commit as step 1 (calling it from a hook would recurse). | Reword: "`ddev quality` and CI (T08) call it; it runs the pre-commit hooks as its first step." I will correct the same wording in the plan at close. | Open |
| 13 | Minor | `scripts/coverage_gate.py:78-81` | A component whose prefix matches no file is skipped silently; only "no component matched at all" fails. If T09, T13 or T21 produce Cobertura paths relative to the source root (`scoring/x.py`, `meridian_core/src/X.php`, `lib/x.ts`), a component floor could be skipped while another matches. Also, a floor of `1` is read as a fraction (100%). | Print a `not measured: <prefix>` line per unmatched component, and add `--require PREFIX` (repeatable) so each component step names the prefixes it must match; fail when a required prefix is unmatched. Treat `line` always as a percentage. Ticketed to T13 if not done now (OQ-T04a-3). | Open |
| 14 | Minor | `docs/standards/CODING_STANDARDS.md` tool table vs `.pre-commit-config.yaml:62,67` | Pins disagree: markdownlint-cli2 is `0.19.x` in the table and `v0.18.1` in the config; hadolint is `2.14.0` in the table and `hadolint-py v2.12.1b3` in the config. The doc says the config wins, but the table should match. Other pins agree (ruff 0.14.4, mypy 1.18.2, shellcheck 0.11.0.1, yamllint 1.37.1, Spectral 6.15.0, gitleaks 8.30.1, pre-commit 4.7.0). | Align the table with the config (or the config with the table), and let the owner-run install (TC-T04a-36) record the confirmed versions. Solution-architect to note in `review-standards.md`. | Open |
| 15 | Minor | `docs/standards/CODING_STANDARDS.md:381` vs `scripts/coverage_gate.py:32-46` | The standard says the gate reads Cobertura `line-rate`. The gate recomputes the rate from `<line hits>` and never reads `line-rate`. The script's behaviour is the better one (it pools files per prefix), but the text is wrong, and OQ-T04a-3 (attribute names) partly lapses. | Reword the standard: "the gate counts covered lines from the `<line>` elements per prefix; branch data is ignored". Regex, thresholds (90/90/85/70/80/80) and the 72-char and ticket regexes otherwise match the scripts. | Open |
| 16 | Note | `scripts/check_branch_name.py:189` | On a CI `push` event `GITHUB_HEAD_REF` is empty and the checkout is detached, so the check sees `HEAD` and fails. | T08: run the branch check on `pull_request` only, or fall back to `GITHUB_REF_NAME`. | Ticketed (T08) |
| 17 | Note | `scripts/check_assets.py:176` | The hex regex can match JS private fields made of hex letters (`this.#add`, `#cafe`). | T21a: exclude `.#` and `this.#` contexts when the web app lands. | Ticketed (T21a) |
| 18 | Note | `ruff.toml:4,11`, `scripts/tests/test_exceptions_report.py:109` | Some lines are just over 100 characters (TOML comments; one test line). ruff format may rewrap the test line; TOML is not linted. | Fix on the next touch, or when the owner-run ruff pass reports it. | Open |
| 19 | Note | `2d3a9e5` | Reflow is word-neutral and no table or code block changed. Helper changes (split imports, `lambda` to `def`) are behaviour-neutral; T03 and T04 regression PASS counts are unchanged. | None. | n/a |

## Simulation-only and secrets

No broker SDK, client or domain in the change. New outbound URLs are only the pre-commit hook
repositories on GitHub and the CDN host names that `check_assets.py` rejects. No secrets;
`.env.example` unchanged (the TC-T04a-33 FAIL is a test defect, finding 6).

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | Plan Approved and committed in `80d681a` before `1ac0b9d` |
| C2 Review findings resolved | No | Findings 1 to 6 open |
| C3 Criteria mapped to executed tests | Partly | Agent cases run; owner-run 36 to 47 and deferred 48 to 52 pending (D-6 acceptance) |
| C4 CI green | No | `quality.sh` commit-range step fails (findings 2, 3); markdownlint would fail (finding 5); linters not run here |
| C5 Docs updated | Yes | `scripts/README.md`, `.ddev/README.md`, CLAUDE.md, TRACEABILITY R-12 and NFR-18 rows |
| C6 No secrets | Yes | See above |
| C7 Clean-checkout works | Not yet shown | Owner-run TC-T04a-36 and 38 |

## Approval

Changes requested. Findings 1 to 6 (Major) must be fixed: 1 and 2 by the developer, 3 by the main
session, 4 to 6 by the tester. Minor findings 7 to 15 are fixed in this task or ticketed with an
ID before close. technical-architect, 2026-11-01.
