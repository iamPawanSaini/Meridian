# T04a: DEF-004 baseline fix, Review

| Field | Value |
|---|---|
| Task | T04a (DEF-004 fix, branch `task/T04a-def004-baseline`) |
| Reviewer | technical-architect |
| Date | 2026-11-02 |
| Commit range | `990e95c..c614327` (5 commits, e6b3158 to c614327) |
| Plan | `docs/tasks/T04a/def004-fix-plan.md` (rules 1 to 6) |

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

Details for each row are in "Finding details" below, so that every line stays short.

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Minor | `docs/tests/T04a/run-checks.sh` | 5 suppressions not counted | F1 | Open |
| 2 | Minor | four `run-checks.sh` files | File-scope SC2329 vs policy | F2 | Open |
| 3 | Minor | `docs/tests/defects.md` | DEF-004 state lags the fix | F3 | Open |
| 4 | Minor | `scripts/README.md:43` | `Merge` lost its space | F4 | Open |
| 5 | Minor | `docs/PROGRESS.md:15` | Says DEF-003 closed | F5 | Open |
| 6 | Note | `docs/tasks/` records | Rule 5 edits checked | F6 | n/a |
| 7 | Note | `.markdownlint-cli2.yaml:18` | Fixture exclude reason | F7 | n/a |
| 8 | Note | `docs/TRACEABILITY.md` FR-26 | Status detail dropped | F8 | n/a |
| 9 | Note | shell and Python helpers | Behaviour verified | F9 | n/a |
| 10 | Note | `.claude/hooks/` | Guard and test changes | F10 | n/a |
| 11 | Note | TC-T04a-30 | Close-time PASS counts moved | F11 | n/a |
| 12 | Note | all shell suppressions | Count is 10, not 9 | F12 | n/a |

## Finding details

### F1 (Minor): five T04a suppressions are invisible to the exceptions report

- Where: `docs/tests/T04a/run-checks.sh` lines 34 (SC2329), 68, 359, 602 and 655 (SC2016).
- Issue: fix-plan rule 2 says each inline suppression is one that
  `scripts/exceptions_report.py` counts. `SKIP_PATH` in that script skips the whole of
  `docs/tests/T04a/run-checks.sh`, because the file quotes invalid directive forms as test
  data (lines 415 and 446). The report on c614327 counts 7 shellcheck directives: the T00, T02, T03,
  T04 (2) and T05 directives, but none of these five. CODING_STANDARDS "Exception policy"
  says the report lists every exception.
- Resolution: record the five lines by file and line in the DEF-004 Fix commit or Retest
  result cell (or in the T04a test report), marked "not counted: file is in `SKIP_PATH`".
  Narrowing `SKIP_PATH` to line level is not required in this fix. If the owner wants the
  count to be complete, ticket it for T32 (known limitations).

### F2 (Minor): file-scope SC2329 directives against the "never a whole file" rule

- Where: `docs/tests/T02/run-checks.sh:8`, `T03/run-checks.sh:8`, `T04/run-checks.sh:25`,
  `T04a/run-checks.sh:34`. Each directive sits before the first command, so shellcheck applies
  it to the whole file.
- Issue: CODING_STANDARDS "Exception policy" says "Suppress one rule by its code, never a
  whole file or every rule". Each directive names one code and cites T04a in the slot after
  the second `#`, so the ticket form is correct. The scope is the whole file.
- Assessment: the suppression is justified. SC2329 reports functions that are only called
  by name through `ck`, `ckp`, `cka` or `py` (`"$@"`), which is the design of every harness.
  A per-function directive would add dozens of comments. T05 already uses the same form
  (`docs/tests/T05/run-checks.sh:27`, 4 codes), and its review accepted it.
- Resolution: the technical-architect (or the developer) adds one sentence to
  CODING_STANDARDS "Shell scripts". It says that a test harness whose helpers are called by
  name may carry one file-scope directive per rule code, placed before the first command,
  with a ticket. Until that sentence is in, record these four directives as an accepted
  deviation in the DEF-004 entry.

### F3 (Minor): DEF-004 state does not match the fix

- Where: `docs/tests/defects.md`, DEF-004 entry.
- Issue: the status is "In progress" and the Fix commit cell is empty, but the fix is
  committed (623ffdd, 35517dc, a89e6e2, c614327). Under the workflow in `defects.md`,
  committing the fix and recording the commit moves the defect to Fixed. The Triaged step was
  skipped. The owner's decision to fix it under T04a, recorded in `PROGRESS.md`, is the
  triage, but the entry does not say so.
- Resolution: before the tester's retest, set Status to Fixed and fill Fix commit with the
  range `623ffdd..c614327` or a pointer to the `DEF-004` commit grep. Add a short triage
  line (owner, 2026-11-01, fix under T04a). Leave the older Retest result text as it is,
  because it is history.

### F4 (Minor): live doc lost the trailing space of the `Merge` exemption

- Where: `scripts/README.md:43`.
- Issue: the text now says "`Merge` subjects". The code exempts only subjects that begin
  with "Merge" plus a space (`scripts/check_commit_msg.py:40`), and CODING_STANDARDS line
  507 says "`Merge` plus a space". This file is a live document, not a historical record, so
  the precision should stay.
- Resolution: write "`Merge` plus a space" in `scripts/README.md`, the same as the standards.

### F5 (Minor): PROGRESS contradicts the defect log for DEF-003

- Where: `docs/PROGRESS.md:15` (T05 row, "DEF-003 closed").
- Issue: `defects.md` now says DEF-003 is at "Retest passed". That is correct under its Rules,
  because Closed is set at the `/close-task` of the task that found the defect, and T05 is
  still In test. The two documents now disagree (C5).
- Resolution: change the PROGRESS wording to "DEF-003 retest passed" now, or set both to
  Closed at T05 `/close-task`. Do not set Closed in `defects.md` before T05 closes.

### F6 (Note): historical records follow rule 5

Checked with a word-level `git` diff (porcelain mode) on each file:

- `docs/tasks/T02/review.md`: one blank line removed between rows 16 and 17. Rows 17 to 19
  were rendered outside the findings table before. Formatting only, no word changes.
- `docs/tasks/T03/review.md`: rows 13 and 14 get an empty sixth cell to match the header.
  Formatting only.
- `docs/tasks/T04a/plan.md`: the run-on "Steps" list is split into items 1 to 5 with the
  same words, and a code span edge space is dropped.
- `decision-t04a-standards.md`, `review.md`, `review-standards.md`: code spans with an edge
  space (MD038) are rewritten. One wording change goes beyond formatting: the decision now
  reads "`Txx:` prefix with its space" (line 156). It keeps the meaning that the removed
  space carried, so I accept it as the minimum deviation from rule 5. In these records,
  `Merge` without the space is accepted, because D-3 and the standards hold the exact rule.

### F7 (Note): the fixture exclude is narrow and allowed, but its reason overstates

`.markdownlint-cli2.yaml:18` ignores one file, `docs/tests/T03/fixtures/partial-data-model.md`,
with a `T04a:` reason on the same line. Fix-plan rule 3 names this folder as an example, and no
global rule was relaxed. The fixture is deliberately incomplete in content, because the checker
must FAIL it. Its MD022 and MD058 findings (missing blank lines) are incidental, and no
committed script references the file. No action now. A later task may add the blank lines and
drop the exclude.

### F8 (Note): FR-26 status

"Partially verified" is in the vocabulary (`check_trace.py` `STATUS_RE`, TRACEABILITY header).
The old free text "(T05 ...; T06, T27 pending)" was dropped, but the Test cases cell still
links the T05 report. Accepted.

### F9 (Note): behaviour is unchanged (rule 1), checked read-only on c614327

- Old and new `run-checks.sh` were run on the same tree (old script from
  `git show 990e95c:...` through process substitution), and the PASS, FAIL and SKIP lines
  were compared with `diff`. All four were identical line for line. T00: 121 PASS, 0 FAIL.
  T02: 168 PASS, 1 FAIL. The FAIL is TC-T02-29 (`.env.example` versus `task/T01-agents`),
  the same as in `evidence/run-checks.txt`. T03: 355 PASS, 0 FAIL. T04 `--regression`:
  119 PASS, 0 FAIL.
- Old and new Python helpers produced byte-identical output and exit codes:
  `check_data_model.py`, `check_env_parity.py`, `validate_openapi.py`, every `check_trace.py`
  check and every `check_defects.py` check.
- The module literals in `selftest_trace.py` (`GOOD`, `LAST`, `SA`), `check_trace.py`
  (`LEVELS`, `RHDR`, `PHDR_WORDS`) and `reference/exceptions_report.py` (`tok`, `form`, `TK`)
  are equal under `ast.literal_eval` before and after.
- `docs/architecture/openapi.yaml` gives an identical object under `yaml.safe_load` at both
  commits, so the folded scalars change no values.
- `bash -n` passes on every `run-checks.sh`. 30 guard tests and 65 `scripts/tests` pass.
- Specific rewrites:
  - `cd ... || exit 2`: changes behaviour only when `cd` fails, where the script used to run
    in the wrong directory.
  - The glob in `adrf` and `six_adrs`: same sort order as `ls`, and dotfiles are excluded in
    both.
  - `while read` in `links_ok`: differs only for link targets that contain spaces or glob
    characters, where the old loop split them.
  - `mapfile` in `sc_run`: the array is never empty, because the repo has `*.sh` files.
  - `A && B || C` to `if`: equivalent, because the C branch returns.
  - `${mode:+"$mode"}`: equivalent to unquoted `$mode` for an empty value or one word.
  - `zip(...,strict=True)` in `ck_header`: guarded by the 7-column test, and `PHDR_WORDS`
    has 7 items, so it cannot raise.
  - `Path.read_text`: the same default encoding and newline handling as `open().read()`. The
    reflow tool keeps `encoding="utf-8"`.
- Simulation only: no broker reference was added. The two broker patterns in the guard tests
  are existing detection strings, only reformatted.

### F10 (Note): guard and its test

`guard_paths.py` changes `dict` to `dict[str, Any]` (annotation only) and reformats the code.
The sets of mutating commands are unchanged. In the test, `assertIsNotNone` plus `assert`
narrowing turns a possible `AttributeError` into a clear test failure, and passing runs are
unaffected. The unquoted `subprocess.CompletedProcess[str]` return type is valid on Python 3.9
and later. These files belong to the main session (rule 4), and commit 623ffdd is the main
session's.

### F11 (Note): TC-T04a-30 compares with close-time counts

TC-T04a-30 `same_count` compares the current PASS counts with the evidence at close: T04 118
and T03 354. The tree now gives 119 and 355. The pre-fix scripts give the same counts on this
tree, so the drift comes from content added after close, not from this fix. Tester: expect
that case to report the drift. Judge rule 1 against 990e95c, as the fix plan says, not
against the close evidence.

### F12 (Note): suppression inventory

The fix adds 10 shellcheck directives, all with a `T04a:` reason in the slot after the second
`#`: T00 1 (SC2034, on the line before `actual=`, which an eval'd string reads), T02 1, T03 1,
T04 2 and T04a 5 (one SC2329 and four SC2016). Each SC2016 covers one command whose
single-quoted `$` or backticks are literal on purpose (awk program, generated hook text, a
fixed-string grep pattern, Markdown fence text). All are justified. Use 10 in the DEF-004
record. No blanket disable was added: `ruff.toml`, `.shellcheckrc`, `.yamllint.yaml`,
`mypy.ini` and `.pre-commit-config.yaml` are unchanged in the range. The only config change is
the single-file markdownlint ignore (F7). The fixer-hook evidence excludes are from T05
(`.pre-commit-config.yaml:29-34`, `T05:` reasons).

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | `def004-fix-plan.md` committed first (e6b3158) |
| C2 Review findings resolved | Pending | F1 to F5 open (Minor); no Blocker or Major |
| C3 Criteria mapped to executed tests | Pending | Tester retest of TC-T05-21, 24, 34 |
| C4 CI green | Yes | Pre-commit and `ddev quality` exit 0 (main session); F9 re-runs pass |
| C5 Docs updated | Partly | Change logs added in T00 to T04a; F3 and F5 open |
| C6 No secrets | Yes | No new variables; gitleaks hook passes |
| C7 Clean-checkout works | Pending | Tester, in the DEF-004 retest |

## Approval

Approved with conditions. F1 to F5 must be fixed, or recorded as stated, before DEF-004 moves
past Fixed. C3 and C7 are closed by the tester's DEF-004 retest (TC-T05-21, 24 and 34, and
the regression runs compared with 990e95c). No Blocker or Major finding is open.
technical-architect, 2026-11-02.
