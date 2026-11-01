# T04a: Coding standards and quality gates, Test cases

| Field | Value |
|---|---|
| Task | T04a |
| Author | tester (design mode, before the standards, configs and scripts exist) |
| Date | 2026-11-01 |
| Criteria source | `docs/TASKS.md` T04a (AC1 to AC9) and section 3.3 (C1 to C7) |
| Plan and decisions | `docs/tasks/T04a/plan.md`, `docs/tasks/T04a/decision-t04a-standards.md` (D-1 to D-4) |

## How to run

- Agent-runnable cases (01 to 35): `docs/tests/T04a/run-checks.sh 2>&1 | tee
  docs/tests/T04a/evidence/run-checks.txt`. Each case is the block headed `== TC-T04a-nn`; copy
  it to `evidence/TC-T04a-nn.txt`. The script exits non-zero if any check fails.
- Regression mode (decision D-5): `run-checks.sh --regression` skips the snapshot checks tagged
  `cka` (TC-10 "verify" markers, TC-34 and TC-35 in full) and prints how many were excluded.
  Everything else is an invariant, including all behavioural checks.
- Owner-run cases (36 to 47 and 53 to 56): `run-checks.sh --owner`.
  It copies the tracked tree to a throwaway
  directory, runs `scripts/bootstrap-dev.sh` there (network needed once for the hook
  environments), then runs the baseline and the rejection demos. Each demo refuses a bad file
  and accepts a same-named good control, so a broken tool cannot count as a rejection. Output goes
  to `evidence/TC-T04a-nn-rejected.txt` and `-control.txt`. Until the owner runs it, these cases
  are Blocked.
- Deferred cases (48 to 51, 57, 58) are Blocked until T05, T08, T09, T13 and T21 exist. Under D-6
  (pending the owner) each needs written owner acceptance at close.
- Environment of the agent sandbox: python3.10 stdlib, node 22, php present; no network, no
  pre-commit, ruff, mypy, shellcheck, yamllint, markdownlint, hadolint, Spectral, composer. Those
  linters are reported as SKIP only inside TC-31 (optional-tool rule); the owner-run cases cover
  them.
- Executed by a session other than the one that authored the standards and scripts.

### Design-time record

- `evidence/design-time-run.txt`: today the script reports 16 PASS and 266 FAIL. The passes are
  checks of existing files (T01 guard tests, T03 and T04 re-runs, `check-names.sh`, TRACEABILITY
  R-12 and NFR-18 rows, `.ddev/README.md` wording, T32 heading, the checker self-tests, the
  absence of scaffolds). No check passes on a missing file.
- `evidence/harness-selftest-reference-impl.txt`: the harness was run with
  `T04A_SCRIPTS_DIR=docs/tests/T04a/reference` against tiny reference models of the five scripts
  and `quality.sh` (180 PASS; only checks that need the real wrapper or real documents fail). This
  proves every behavioural case in TC-12 to TC-24 can pass for a correct implementation and
  is not wired to fail. The reference models are not production code and are not tested for
  quality.

### Interface assumptions (raise a clarification or defect; never loosen an expectation)

These are named in the header of `run-checks.sh`. Only the adapter function for the item may be
changed, with a Change log row.

- A-1 `check_commit_msg.py --msg-file F` and `--range A..B`, both with `--tasks-file`; default
  `docs/TASKS.md`; reject means non-zero exit plus a message.
- A-2 `check_branch_name.py [--branch B]`, else `GITHUB_HEAD_REF`, else the current branch.
  `exceptions_report.py [--out FILE]` and `check_assets.py` scan the git working tree of the
  current directory (the checks run them inside a throwaway repo holding `docs/TASKS.md` and
  `docs/tests/defects.md`).
- A-3 `QUALITY_STEPS` names a file of `NAME<TAB>MANIFEST<TAB>COMMAND` lines replacing the built-in
  steps; `-` means always run; an absent manifest path means SKIP; a present manifest with a
  failing or missing command means FAIL.
- A-4 `coverage_gate.py --thresholds quality/coverage-thresholds.json COBERTURA.xml`.
- A-5 Cobertura fixture file names follow the path column of decision D-1.
- The tokens-file path for the asset check is read from `check_assets.py` or `scripts/README.md`
  (`apps/web/**/*tokens*`); if it is not documented, TC-22 fails.

## Acceptance criteria (labels used below)

- AC1: `docs/standards/CODING_STANDARDS.md` has sections for PHP and Drupal, Python, TypeScript
  and Next.js, SQL and migrations, Docker and YAML, shell, Markdown, OpenAPI, LLM prompt files
- AC2: cross-cutting rules: naming, error handling, structured logging, no secrets, dependency
  policy, comments and docstrings, maximum function and file size
- AC3: tool per language chosen and configured in the repo (phpcs, PHPStan, ruff, mypy, ESLint,
  Prettier, tsc, hadolint, yamllint, shellcheck, markdownlint, Spectral); hooks pinned
- AC4: commit message convention enforced by a commit hook; branch naming enforced in CI
- AC5: one local command (`ddev quality`) runs every check and exits non-zero on any violation;
  the same checks run in CI (T08) and as pre-commit hooks
- AC6: baseline clean with zero violations; exceptions only with an inline ticket comment, and
  counted in a report
- AC7: coverage thresholds defined per component and recorded in the doc; enforced in CI
- AC8: `docs/standards/REVIEW_CHECKLIST.md` derived from the standards and referenced by the
  `technical-architect` agent
- AC9: tester verification: a deliberately non-compliant change per language (bad PHP style,
  untyped Python, ESLint error, long Markdown line, bad commit message, a coverage drop) is
  rejected by hooks or CI
- C1 to C7: common criteria, `docs/TASKS.md` section 3.3 (C4 limited to `quality.sh` and
  pre-commit until T08)
- SIM: CLAUDE.md simulation-only rule

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: standards sections | TC-T04a-01, 02, 52 |
| AC2: cross-cutting rules | TC-T04a-03, 04, 52 |
| AC3: tools chosen, configured, pinned | TC-T04a-02, 04, 08, 09, 10, 26, 31, 36, 49, 50 |
| AC4: commit hook and branch naming | TC-T04a-11, 12, 13, 14, 15, 16, 46, 47, 51 |
| AC5: single command, exit code, wrapper | TC-T04a-23, 24, 25, 38, 48 |
| AC6: baseline clean, exceptions with ticket and report | TC-T04a-17, 18, 27, 28, 29, 37, 38, 53 to 58 |
| AC7: coverage thresholds recorded and enforced | TC-T04a-05, 06, 19, 20, 51 |
| AC8: REVIEW_CHECKLIST and agent reference | TC-T04a-07, 52 |
| AC9: rejection per language | TC-T04a-12, 13, 15, 19, 20, 26, 27, 39 to 47, 49, 50, 51 |
| Asset rules (section 0b, plan scope) | TC-T04a-04, 21, 22 |
| C1: plan reviewed before coding | TC-T04a-34 |
| C2: reviewed, findings resolved | TC-T04a-34 |
| C3: every criterion has an executed case | this table; the report |
| C4: no new lint, type or security warnings | TC-T04a-31, 37, 38 |
| C5: docs and traceability | TC-T04a-30, 32 |
| C6: no secrets, `.env.example` unchanged | TC-T04a-33 |
| C7: clean checkout works | TC-T04a-36, 38 |
| SIM: no broker names or trading hosts | TC-T04a-33 |

Negative coverage: unknown, malformed, over-long, `fixup!`, `squash!` and `Revert` without quote
messages (12, 13, 14); 73-character subject; bad branch names (16); untagged and mis-tagged
suppressions for 11 tools and two config excludes (17, 18); coverage 1 point under each floor, a
branch rate that cannot rescue a line floor (19, 20), malformed, empty and missing XML;
8 third-party
hosts and 4 hex forms (21); SKIP versus FAIL and non-zero exit (24); a typing proxy and long line
checker self-test that prove the checkers can reject (26, 27); six owner-run rejection demos with
controls (39 to 47).

Automated: 01 to 35 (35 cases, about 300 checks). Owner-run: 36 to 47 and 53 to 56 (16).
Deferred: 48 to 51, 57, 58 (6). Manual: 52 (1). Total 58.

## Change log

| Date | Change | Reason |
|---|---|---|
| 2026-11-01 | Initial design | n/a |
| 2026-11-01 | TC-27 line-length checker skips a leading YAML front-matter block; self-test added | Review finding 4: test-script defect, markdownlint does the same; not a loosening of the 100-character rule |
| 2026-11-01 | TC-33 `.env.example` base is the parent of the first `T04a:` commit, not local `main` | Review finding 6: local `main` can be stale |
| 2026-11-01 | TC-17, 18, 29 exception fixtures and the TC-29 scan use the per-tool forms of the D-4 addendum; bare-form negatives added; yamllint and Spectral config-ignore cases added | Decision change by the solution-architect (D-4 addendum), not a loosening: the old bare form is now an expected rejection |
| 2026-11-01 | TC-53 to 58 added for the addendum rows marked "verify" (OQ-T04a-6) | New cases; coverage.py, hadolint, markdownlint, yamllint owner-run; TypeScript and phpcs deferred |
| 2026-11-01 | TC-29 independent scan skips `docs/tasks/` | Main-session scope decision: task plans, decisions and reviews quote invalid forms on purpose. Not a loosening: `docs/standards` and all code and config stay scanned |
| 2026-11-01 | Prose lines in `docs/tests/T02`, `T03`, `T04` test-cases and test-report reflowed to 100 characters | Review finding 5: word-neutral (0 word changes in `git diff --word-diff=porcelain`; PASS counts of the three `run-checks.sh` unchanged; `evidence/reflow-*.txt`) |

## Cases: standards and review checklist

### TC-T04a-01: CODING_STANDARDS.md and one section per language

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Type | Automated |
| Preconditions | Repo root |
| Steps | 1. `docs/tests/T04a/run-checks.sh` and read block `== TC-T04a-01` |
| Expected result | The file exists and has headings for PHP and Drupal, Python, TypeScript and Next.js, SQL and migrations, Docker and YAML, Shell, Markdown, OpenAPI, LLM prompt files; no TODO/TBD marker. A missing file fails every line |
| Actual result | |
| Evidence | `evidence/TC-T04a-01.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-02: Each language section names its tool and key rules

| Field | Value |
|---|---|
| Linked criterion | AC1, AC3 |
| Type | Automated |
| Preconditions | As TC-01 |
| Steps | 1. Read block `== TC-T04a-02` |
| Expected result | Inside the right section: PHP names PHP_CodeSniffer, Drupal, DrupalPractice, PHPStan, phpstan-drupal, level 6, no baseline, reason on ignores; Python names ruff, mypy, 100, py312 and py310, strict per invocation for `scripts/`, `.claude/hooks/`, `meridian_engine`; TypeScript names ESLint, Prettier, `tsc --noEmit`, strict; SQL names Alembic, reversible migrations, parameterised queries; Docker and YAML name hadolint, yamllint, pinned images; shell names shellcheck and `set -euo pipefail`; Markdown names markdownlint, 100, tables exempt and the T32 TASKS.md exclusion; OpenAPI names Spectral and `openapi.yaml`; prompts: versioned, untrusted data, no secrets. A term only elsewhere in the file fails |
| Actual result | |
| Evidence | `evidence/TC-T04a-02.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-03: Cross-cutting rules

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Type | Automated |
| Preconditions | As TC-01 |
| Steps | 1. Read block `== TC-T04a-03` |
| Expected result | Sections for naming (section 0, `meridian_engine`, `check-names.sh`), error handling, structured logging (structured, JSON or key=value, no secrets in logs), secrets (gitleaks, `.env.example`), dependency policy (lockfile, pin, audit), comments and docstrings (why, docstring), size (50-line functions, 400-line files) |
| Actual result | |
| Evidence | `evidence/TC-T04a-03.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-04: Tool table, exception rule, commit and branch rules, asset rules, scope

| Field | Value |
|---|---|
| Linked criterion | AC2, AC3, AC4, AC6 |
| Type | Automated |
| Preconditions | As TC-01 |
| Steps | 1. Read block `== TC-T04a-04` |
| Expected result | A tools table with Version, Source and Date checked columns and a dated row (`YYYY-MM-DD`) for ruff, mypy, PHP_CodeSniffer, PHPStan, ESLint, Prettier, tsc, hadolint, yamllint, shellcheck, markdownlint, Spectral; the literal ticket regex `\b(T\d{2}a?|DEF-\d{3}): \S`; exception rule (same line, counted in a report, `DEF-` must exist); commit rules (72, Merge, Revert, `fixup!`, PR range, merge commits only with squash disabled); `task/Txx-slug`; section 0b asset rules (self-hosted, no third-party host, tokens); scope table (docs/tests helpers ruff only; py310); `web-vitals` licence (Apache or MIT) with a version, closing OQ-T04-5 |
| Actual result | |
| Evidence | `evidence/TC-T04a-04.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-05: Coverage thresholds in the standards

| Field | Value |
|---|---|
| Linked criterion | AC7 |
| Type | Automated |
| Preconditions | As TC-01 |
| Steps | 1. Read block `== TC-T04a-05` |
| Expected result | The coverage section records: engine `scoring` and `risk` 90 (NFR-18), engine overall 85, Drupal custom modules 70 (provisional, Kernel tests counted), web `lib/` and `components/` 80 with `app/` left to Playwright; line coverage is the gate, branch reported and not gated, floors only go up |
| Actual result | |
| Evidence | `evidence/TC-T04a-05.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-06: quality/coverage-thresholds.json matches the decision

| Field | Value |
|---|---|
| Linked criterion | AC7 |
| Type | Automated |
| Preconditions | As TC-01 |
| Steps | 1. Read block `== TC-T04a-06` |
| Expected result | Valid JSON containing, in context with their path prefix, the values scoring 90, risk 90, engine 85, Drupal custom 70, web `lib` 80, web `components` 80 (as 90 or 0.90); no scoring or risk line floor below 90. Values higher than the decision are allowed ("floors only go up") only if the standards say the same; a lower value fails |
| Actual result | |
| Evidence | `evidence/TC-T04a-06.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-07: REVIEW_CHECKLIST.md and the agent reference

| Field | Value |
|---|---|
| Linked criterion | AC8 |
| Type | Automated |
| Preconditions | `.claude/agents/technical-architect.md` edited by the main session (agents cannot write `.claude/`) |
| Steps | 1. Read block `== TC-T04a-07` |
| Expected result | The checklist exists with at least 30 yes/no questions, a block per standards section, each of C1 to C7, the simulation-only rule, and the cross-cutting rules including "exceptions cite a ticket"; `technical-architect.md` contains `REVIEW_CHECKLIST.md` |
| Actual result | |
| Evidence | `evidence/TC-T04a-07.txt` |
| Status | Not run |
| Date | |
| Executed by | |

## Cases: configs and hooks

### TC-T04a-08: Root tool configs

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Automated |
| Preconditions | Repo root |
| Steps | 1. Read block `== TC-T04a-08` |
| Expected result | `ruff.toml` (line-length 100, py312, `per-file-target-version` py310 for scripts, hooks, docs/tests); `mypy.ini` exists and has no `strict` inside a `[mypy-...]` section (D-2); `.yamllint.yaml` extends a base and sets line-length; `.markdownlint-cli2.yaml` has MD013 at 100 with tables, code blocks and headings false; `.shellcheckrc`; `tsconfig.base.json` valid JSON with `strict` true; `.prettierrc.json` valid JSON |
| Actual result | |
| Evidence | `evidence/TC-T04a-08.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-09: Component configs (PHP and ESLint)

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Type | Automated |
| Preconditions | Node 22 for the syntax check |
| Steps | 1. Read block `== TC-T04a-09` |
| Expected result | `apps/drupal/phpcs.xml.dist` is a valid ruleset with Drupal, DrupalPractice and `web/modules/custom`; `apps/drupal/phpstan.neon.dist` has level 6, `reportIgnoresWithoutComments: true`, phpstan-drupal, custom modules, no baseline, stale ignores still reported; `apps/web/eslint.config.mjs` parses under `node --check` and uses next and typescript-eslint |
| Actual result | |
| Evidence | `evidence/TC-T04a-09.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-10: pre-commit hooks pinned

| Field | Value |
|---|---|
| Linked criterion | AC3, AC4 |
| Type | Automated (the "verify" marker check is a snapshot) |
| Preconditions | Repo root |
| Steps | 1. Read block `== TC-T04a-10` |
| Expected result | Every non-local repo has a numeric version `rev` (no branch name); ruff lint and format, mypy, shellcheck-py, yamllint, hadolint, markdownlint-cli2, gitleaks and pre-commit-hooks are present; Spectral is a local `language: node` hook with `@stoplight/spectral-cli@<version>`; `default_install_hook_types` lists `pre-commit` and `commit-msg`; the mypy hook has `--strict`, python 3.10 and `files` for `scripts` and `.claude/hooks`; at least 3 "verify" markers until TC-36 confirms the versions |
| Actual result | |
| Evidence | `evidence/TC-T04a-10.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-11: commit-msg hook wiring (static)

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Automated |
| Preconditions | As TC-10 |
| Steps | 1. Read block `== TC-T04a-11` |
| Expected result | A hook within a few lines of `commit-msg` stage calls `check_commit_msg.py`; `bootstrap-dev.sh` installs the hooks and the commit-msg type (explicit `--hook-type commit-msg` or relying on `default_install_hook_types`, with the install command present) |
| Actual result | |
| Evidence | `evidence/TC-T04a-11.txt` |
| Status | Not run |
| Date | |
| Executed by | |

## Cases: behaviour of the scripts (throwaway dirs, no network)

### TC-T04a-12: commit-msg hook accepts and rejects (message mode)

| Field | Value |
|---|---|
| Linked criterion | AC4, AC9 (bad commit message) |
| Type | Automated |
| Preconditions | `scripts/check_commit_msg.py`; python3.10; fixture TASKS file with T04, T04a, T10, T32 |
| Steps | 1. Read block `== TC-T04a-12`: it calls `check_commit_msg.py --tasks-file F --msg-file M` for each message |
| Expected result | Accepted: `T04a: x`, `T10: add ingest upsert endpoint`, a subject with a 150-character body line. Rejected (non-zero, message, no traceback): `bad message`, empty, `T04a:x`, `T04a: ` (no text), `t04: x`, `T4: x`, `Initial commit`, `T04ab: x`, ` T04a: x`; the rejection text explains the format |
| Actual result | |
| Evidence | `evidence/TC-T04a-12.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-13: Length, Merge, Revert, fixup, unknown id

| Field | Value |
|---|---|
| Linked criterion | AC4 (decision D-3) |
| Type | Automated |
| Preconditions | As TC-12 |
| Steps | 1. Read block `== TC-T04a-13` |
| Expected result | A 72-character subject (counted with the prefix) and a 71-character one are accepted; 73 is rejected. Accepted: `Merge branch ...`, a `Merge pull request ...` subject over 72 characters, `Revert "T10: x"`. Rejected: `Revert it`, `Merged things`, `fixup! T04a: x`, `squash! T04a: x`, `T99: x` (named in the message), `T05a: x`. With the real `docs/TASKS.md` as default: `T04a: x` accepted, `T99: x` rejected |
| Actual result | |
| Evidence | `evidence/TC-T04a-13.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-14: commit-msg --range checks only the PR range

| Field | Value |
|---|---|
| Linked criterion | AC4 (decision D-3) |
| Type | Automated |
| Preconditions | Throwaway git repo built by the script: `Initial commit`, an over-long `Add files via upload ...` commit and `bad legacy message` before the base; `T04a: first`, `T10: second` after it |
| Steps | 1. Read block `== TC-T04a-14` |
| Expected result | The range `BASE..HEAD` passes although older commits are bad or over-long. Adding any of these makes it fail and names the commit: `bad message`, `fixup! T04a: first`, `squash! T10: second`, a 73-character subject, `T99: x`. A 72-character subject, `Revert "T10: second"` and a no-ff `Merge branch 'side'` (with the commit it brings) pass; the empty range `HEAD..HEAD` passes |
| Actual result | |
| Evidence | `evidence/TC-T04a-14.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-15: A real git commit-msg hook refuses the bad message

| Field | Value |
|---|---|
| Linked criterion | AC4, AC9 |
| Type | Automated |
| Preconditions | Throwaway repo with `.git/hooks/commit-msg` that runs `check_commit_msg.py --msg-file "$1"` |
| Steps | 1. Read block `== TC-T04a-15` (`git commit --allow-empty -m "bad message"`, then `-m "T04a: x"`) |
| Expected result | The first commit is refused with a message and `git rev-list --count` is unchanged; the second succeeds and the count rises by one |
| Actual result | |
| Evidence | `evidence/TC-T04a-15.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-16: Branch name check

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Automated |
| Preconditions | `scripts/check_branch_name.py`; fixture TASKS file |
| Steps | 1. Read block `== TC-T04a-16` |
| Expected result | Accepted: `task/T04a-coding-standards`, `task/T10-ingest`, `task/T04-master-test-plan`, `main`. Rejected: `feature/x`, `master`, `task/T04a`, `task/T04a-`, `task/T04a-Bad-Caps`, `task/T04a-two--dashes`, `task/T04a-trailing-`, `task/t04-x`, `task/T4-x`, `task/T99-x`, `task/T05a-x`, `task/T10-a_b`, `task/T10-a/b`. With no argument: `GITHUB_HEAD_REF` is used (`task/T10-ingest` ok, `feature/x` rejected); with neither, the current git branch is used |
| Actual result | |
| Evidence | `evidence/TC-T04a-16.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-17: An untagged suppression fails, for every tool

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Type | Automated |
| Preconditions | `scripts/exceptions_report.py`; throwaway repo with TASKS.md and defects.md (DEF-001) |
| Steps | 1. Read block `== TC-T04a-17`: one fixture file per tool with the suppression and no ticket |
| Expected result | A clean repo passes. Each untagged `noqa`, `type: ignore`, `pragma: no cover`, `eslint-disable`, `@ts-expect-error`, `phpcs:ignore`, `@phpstan-ignore`, `shellcheck disable`, `yamllint disable`, `markdownlint-disable`, `hadolint ignore` makes the report exit non-zero. The failure names file and line (`pkg/mod.py:2`) |
| Actual result | |
| Evidence | `evidence/TC-T04a-17.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-18: Tagged suppressions pass and are counted; the tag rules

| Field | Value |
|---|---|
| Linked criterion | AC6 (decision D-4) |
| Type | Automated |
| Preconditions | As TC-17 |
| Steps | 1. Read block `== TC-T04a-18` |
| Expected result | Per the D-4 addendum the ticket must sit in the tool's own comment slot: `# noqa: F401  # T32: legacy`, `type: ignore[code]  # T32: ...`, `pragma: no cover  # T32: ...`, `shellcheck disable=SC2034 # T32: ...`, `hadolint ignore=DL3008 # T32: ...`, `eslint-disable-next-line rule -- T32: ...`, `phpcs:ignore sniff -- T32: ...`, `@phpstan-ignore id (T32: ...)`, `@ts-expect-error T32: ...`, `<!-- markdownlint-disable-next-line MD013 --> <!-- T32: ... -->` all pass. The bare forms (for example `# noqa: F401  T32: legacy`) and `@ts-ignore T32: ...` are rejected, and yamllint has no accepted inline form (any trailing ticket is rejected). Also rejected: `noqa` without a code and `eslint-disable` without a rule even with a ticket; a ticket before the directive. Per-rule `ignore:` paths in `.yamllint.yaml` and Spectral `overrides` rules set to off need a YAML comment ticket on the same line. A repo with 2 `noqa`, 1 `type: ignore` and 1 `shellcheck` writes a report (`--out`) showing those counts per tool and the tickets used. Accepted: `DEF-001: ...` (exists), `T04a: ...`. Rejected: `DEF-999` (absent), `T99`, `T32` with no reason, `T32:x`, `t32: x`, a ticket on the previous or the next line. Config excludes: a `.markdownlint-cli2.yaml` `ignores` entry or a `ruff.toml` `exclude` without a ticket is rejected; with `T32:` or `T04a:` it passes |
| Actual result | |
| Evidence | `evidence/TC-T04a-18.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-19: Coverage gate floors and boundaries

| Field | Value |
|---|---|
| Linked criterion | AC7, AC9 (coverage drop) |
| Type | Automated |
| Preconditions | `scripts/coverage_gate.py`; `quality/coverage-thresholds.json`; the script writes Cobertura XML fixtures (100-line files) |
| Steps | 1. Read block `== TC-T04a-19` |
| Expected result | Scoring 95, risk 95, other 90 passes. Scoring 89 fails naming `scoring/rules.py`; exactly 90 passes; risk 89 fails naming `risk/limits.py`; exactly 90 passes. Overall engine 83.3 fails (scoring and risk fine); exactly 85 passes. A fall from 95 to 70 on scoring fails |
| Actual result | |
| Evidence | `evidence/TC-T04a-19.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-20: Line rate not branch, other components, malformed input

| Field | Value |
|---|---|
| Linked criterion | AC7 (decision D-1) |
| Type | Automated |
| Preconditions | As TC-19 |
| Steps | 1. Read block `== TC-T04a-20` |
| Expected result | Line 95 with branch rate 0.10 passes; line 85 with branch rate 1.0 fails (the gate reads the line rate). Drupal custom 69 fails, 70 passes; web `lib/` 79 fails, 80 passes; web `components/` 79 fails; web `app/` at 10 percent passes (no unit floor). Malformed XML, a report with no files and a missing file are rejected with a message and no traceback |
| Actual result | |
| Evidence | `evidence/TC-T04a-20.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-21: Asset check rejects third-party hosts and hard-coded hex

| Field | Value |
|---|---|
| Linked criterion | AC9 (plan scope, section 0b) |
| Type | Automated |
| Preconditions | `scripts/check_assets.py`; throwaway repo with files under `apps/web/app/` and the Drupal custom theme |
| Steps | 1. Read block `== TC-T04a-21` |
| Expected result | The control (same-origin stylesheet) passes. Rejected: `fonts.googleapis.com` link, `fonts.gstatic.com` in `url()`, scripts from `cdn.jsdelivr.net` and `unpkg.com`, `@import` from `cdnjs.cloudflare.com`, an icon stylesheet from `use.fontawesome.com`, a protocol-relative `//fonts.googleapis.com`, hex `#1a2b3c`, `#fff`, `#1a2b3cff` in CSS and a hex in TSX inline style; the same host and a hex in the Drupal theme. The failure names the file |
| Actual result | |
| Evidence | `evidence/TC-T04a-21.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-22: Asset check has no false positives and honours scope

| Field | Value |
|---|---|
| Linked criterion | AC9 (plan scope) |
| Type | Automated |
| Preconditions | As TC-21 |
| Steps | 1. Read block `== TC-T04a-22` |
| Expected result | Accepted: `url(/fonts/inter.woff2)`, `var(--color-fg)`, `href="#main-content"`, the entity `&#39;`, an external documentation `<a href>`, hex inside the tokens file (path read from the script), a Markdown file under `docs/` that names a font host, and a `services/engine` file with a font URL and a hex colour |
| Actual result | |
| Evidence | `evidence/TC-T04a-22.txt` |
| Status | Not run |
| Date | |
| Executed by | |

## Cases: quality.sh, wrapper, tests

### TC-T04a-23: quality.sh static contract

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated |
| Preconditions | Repo root |
| Steps | 1. Read block `== TC-T04a-23` |
| Expected result | `scripts/quality.sh` exists, is executable, passes `bash -n`, starts with a bash shebang; it names pre-commit, `check_branch_name`, `check_commit_msg`, `exceptions_report`, `check_assets`, `coverage_gate`, `origin/main`, the three manifests (`services/engine/pyproject.toml`, `apps/drupal/composer.json`, `apps/web/package.json`), `QUALITY_RUNNER`, `QUALITY_STEPS` and the words PASS, FAIL, SKIP; no `\|\| true` on a code line |
| Actual result | |
| Evidence | `evidence/TC-T04a-23.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-24: quality.sh with fake steps (PASS, FAIL, SKIP, exit code)

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated |
| Preconditions | `QUALITY_STEPS` supported (A-3); manifests are absolute paths under a temporary directory |
| Steps | 1. Read block `== TC-T04a-24` |
| Expected result | One passing step: exit 0 and a PASS line. A step whose manifest is absent and whose command would fail: SKIP, exit 0, no FAIL line. Pass, fail, pass: exit non-zero, FAIL for the middle, PASS for both others (it keeps going). A present manifest with a command that does not exist (`meridian-no-such-tool-xyz`): FAIL and not SKIP, exit non-zero. A present manifest with a failing command: FAIL, non-zero. Pass, skip, fail: non-zero, with PASS, SKIP and FAIL counts in a summary line. Only SKIP steps: exit 0. `QUALITY_RUNNER=bogus` is rejected with a message |
| Actual result | |
| Evidence | `evidence/TC-T04a-24.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-25: .ddev/commands/host/quality wrapper

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Automated (the real `ddev quality` is TC-48) |
| Preconditions | `DDEV_APPROOT` set to the repo root by the script |
| Steps | 1. Read block `== TC-T04a-25` |
| Expected result | The wrapper exists, is executable, has a bash shebang and a `## Description:` header, and contains exactly `exec "$DDEV_APPROOT/scripts/quality.sh" "$@"`. With a fake FAIL step it exits non-zero and prints FAIL; with a fake PASS step it exits 0 |
| Actual result | |
| Evidence | `evidence/TC-T04a-25.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-26: Script unit tests, typing proxy, Python 3.10

| Field | Value |
|---|---|
| Linked criterion | AC3, AC9 (untyped Python, agent-side proxy) |
| Type | Automated |
| Preconditions | python3.10 |
| Steps | 1. Read block `== TC-T04a-26` |
| Expected result | `scripts/tests/test_<name>.py` exists with at least 3 tests for each of the five scripts; `python3 -m unittest discover -s scripts/tests` passes; all scripts compile on 3.10; the typing proxy (an `ast` check for missing annotations) flags an untyped fixture and passes a typed one, and finds no unannotated function in `scripts/` and `.claude/hooks/`. This is a proxy only; the real `mypy --strict` demo is TC-39 |
| Actual result | |
| Evidence | `evidence/TC-T04a-26.txt` |
| Status | Not run |
| Date | |
| Executed by | |

## Cases: baseline

### TC-T04a-27: Project-authored Markdown within 100 characters

| Field | Value |
|---|---|
| Linked criterion | AC6, AC9 (long Markdown line) |
| Type | Automated |
| Preconditions | Repo root |
| Steps | 1. Read block `== TC-T04a-27` |
| Expected result | The checker flags a 160-character prose line and exempts a long table row, fenced code, heading, bare URL and a leading YAML front-matter block; a `---` block later in a file and prose after front matter are still flagged (self-tests, review finding 4). Over all tracked or untracked Markdown except `docs/TASKS.md` and `docs/tests/*/evidence/**` (at least 50 files) there are 0 lines over 100 characters. The T04a documents themselves also pass. The current tree has about 308 such lines, so this fails until the cleanup commit |
| Actual result | |
| Evidence | `evidence/TC-T04a-27.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-28: Exclusions carry a ticket; TASKS.md cites T32

| Field | Value |
|---|---|
| Linked criterion | AC6 (interim decision Q1) |
| Type | Automated |
| Preconditions | `docs/TASKS.md` has a `## T32:` heading |
| Steps | 1. Read block `== TC-T04a-28` |
| Expected result | `.markdownlint-cli2.yaml` excludes `docs/TASKS.md` on a line with `T32: <reason>` and `docs/tests/*/evidence` on a line with a ticket; `ruff.toml` excludes evidence with a ticket; the `ignores` list has exactly these two kinds of entries, each ticketed |
| Actual result | |
| Evidence | `evidence/TC-T04a-28.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-29: Exceptions report on the real tree

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Type | Automated |
| Preconditions | `scripts/exceptions_report.py` |
| Steps | 1. Read block `== TC-T04a-29` |
| Expected result | The report runs on the real tree, exits 0 and writes a non-empty file. An independent scan (comment forms over code files, excluding the tool, its fixtures, T04a tests and evidence) finds every suppression with the ticket in the tool's comment slot (the per-tool forms of the D-4 addendum; yamllint inline and `@ts-ignore` never allowed), and each non-zero per-tool count equals a count in the report. The report lists the `TASKS.md` exclusion with `T32` |
| Actual result | |
| Evidence | `evidence/TC-T04a-29.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-30: Helper regression after the cleanup

| Field | Value |
|---|---|
| Linked criterion | C5 (plan: helpers behave the same) |
| Type | Automated |
| Preconditions | The cleanup commit is in |
| Steps | 1. Read block `== TC-T04a-30` |
| Expected result | The T01 guard unit tests pass; `docs/tests/T04/run-checks.sh --regression` exits 0 with 118 PASS (as at close); `docs/tests/T03/run-checks.sh` exits 0 with the same PASS count as its stored evidence |
| Actual result | |
| Evidence | `evidence/TC-T04a-30.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-31: Optional linters on the tree

| Field | Value |
|---|---|
| Linked criterion | AC3, C4 |
| Type | Automated; SKIP only for an absent tool |
| Preconditions | Tools are absent in the agent sandbox |
| Steps | 1. Read block `== TC-T04a-31` |
| Expected result | If installed: `ruff check`, `ruff format --check`, `mypy --strict --python-version 3.10 scripts .claude/hooks`, `shellcheck`, `yamllint .`, `markdownlint-cli2`, `.tools/pre-commit run --all-files` all exit 0. Absent tools print SKIP and the report lists each; the owner-run cases cover them |
| Actual result | |
| Evidence | `evidence/TC-T04a-31.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-32: Documentation and traceability

| Field | Value |
|---|---|
| Linked criterion | C5 |
| Type | Automated |
| Preconditions | Main session has edited `CLAUDE.md` |
| Steps | 1. Read block `== TC-T04a-32` |
| Expected result | `scripts/README.md` lists `quality.sh` and the five scripts; `.ddev/README.md` describes the quality command and T05; `CLAUDE.md` lists `scripts/quality.sh`; the TRACEABILITY R-12 and NFR-18 rows name T04a |
| Actual result | |
| Evidence | `evidence/TC-T04a-32.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-33: Simulation only, no secrets, `.env.example`

| Field | Value |
|---|---|
| Linked criterion | C6, SIM |
| Type | Automated |
| Preconditions | Repo root |
| Steps | 1. Read block `== TC-T04a-33` |
| Expected result | No broker vendor name or trading hostname, and no secret pattern, in the standards, scripts, configs, `.ddev` and this file (at least 10 files scanned); `.env.example` is identical to its content at the parent of the first `T04a:` commit (review finding 6); `check-names.sh` passes |
| Actual result | |
| Evidence | `evidence/TC-T04a-33.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-34: Process (snapshot)

| Field | Value |
|---|---|
| Linked criterion | C1, C2 |
| Type | Automated, at-close |
| Preconditions | Branch history available |
| Steps | 1. Read block `== TC-T04a-34` |
| Expected result | The plan status is Approved; `run-checks.sh` and `test-cases.md` were first committed strictly before the standards, the checklist, `quality.sh` and `check_commit_msg.py` (ancestor check); `docs/tasks/T04a/review.md` exists and is Approved; the first commit of `run-checks.sh` starts with `T04a:` |
| Actual result | |
| Evidence | `evidence/TC-T04a-34.txt` |
| Status | Not run |
| Date | |
| Executed by | |

### TC-T04a-35: No component scaffolds yet (snapshot)

| Field | Value |
|---|---|
| Linked criterion | AC5 (SKIP rule is real), plan non-goal |
| Type | Automated, at-close |
| Preconditions | Before T05, T13, T21 |
| Steps | 1. Read block `== TC-T04a-35` |
| Expected result | `services/engine/pyproject.toml`, `apps/drupal/composer.json`, `apps/web/package.json` and `.ddev/config.yaml` are all absent. After T05 or T13 this check is retired with a Change log row naming that task |
| Actual result | |
| Evidence | `evidence/TC-T04a-35.txt` |
| Status | Not run |
| Date | |
| Executed by | |

## Cases: owner-run (`run-checks.sh --owner`)

Each demo case: the bad file is refused (non-zero) and the same-named good control is accepted
(zero), both with the real hooks. A refusal without an accepted control is Fail.

### TC-T04a-36: Bootstrap in a clean copy installs both hook types (C7)

| Field | Value |
|---|---|
| Linked criterion | C7, AC3, AC4 |
| Type | Owner-run (network) |
| Preconditions | Network; git; Python 3; clean copy made by the script |
| Steps | 1. `docs/tests/T04a/run-checks.sh --owner 2>&1 \| tee docs/tests/T04a/evidence/owner-run.txt` and read block `== TC-T04a-36` |
| Expected result | `scripts/bootstrap-dev.sh` succeeds; `.tools/pre-commit --version` prints; `.git/hooks/pre-commit` and `.git/hooks/commit-msg` exist; the pinned `rev:` list and Spectral version are printed. Record the real versions and dates; replace the "verify" markers in the same commit |
| Actual result | |
| Evidence | `evidence/owner-run.txt` |
| Status | Not run (Blocked until the owner runs it) |
| Date | |
| Executed by | |

### TC-T04a-37: Baseline clean: pre-commit run --all-files

| Field | Value |
|---|---|
| Linked criterion | AC6, C4 |
| Type | Owner-run (network) |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-37` (`.tools/pre-commit run --all-files` in the copy) |
| Expected result | Exit 0, every hook Passed or Skipped, zero violations |
| Actual result | |
| Evidence | `evidence/owner-run.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-38: quality.sh on the clean tree

| Field | Value |
|---|---|
| Linked criterion | AC5, AC6, C7 |
| Type | Owner-run (network) |
| Preconditions | TC-36 passed; branch `task/T04a-owner-demo` |
| Steps | 1. Read block `== TC-T04a-38` (`scripts/quality.sh` in the copy) |
| Expected result | Exit 0; PASS for the pre-commit, branch, commit range and exceptions steps; SKIP for the engine, Drupal and web component steps because their manifests are absent; a summary line |
| Actual result | |
| Evidence | `evidence/owner-run.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-39: Untyped Python is refused by mypy --strict

| Field | Value |
|---|---|
| Linked criterion | AC9 (untyped Python) |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-39`: `scripts/zz_demo.py` with `def add(a, b)` is refused, then the typed twin is accepted |
| Expected result | Refused file: non-zero exit and a mypy error line in `evidence/TC-T04a-39-rejected.txt`; typed twin: exit 0 in `-control.txt` |
| Actual result | |
| Evidence | `evidence/TC-T04a-39-rejected.txt`, `evidence/TC-T04a-39-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-40: ruff lint rejection

| Field | Value |
|---|---|
| Linked criterion | AC3, AC9 |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-40`: an unused import is refused, a docstring-only twin is accepted |
| Expected result | Refused with F401; control accepted |
| Actual result | |
| Evidence | `evidence/TC-T04a-40-rejected.txt`, `-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-41: Long Markdown line is refused by markdownlint

| Field | Value |
|---|---|
| Linked criterion | AC9 (long Markdown line) |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-41`: `docs/zz_demo.md` with a 200-character prose line, then the wrapped twin |
| Expected result | Refused with MD013; wrapped control accepted |
| Actual result | |
| Evidence | `evidence/TC-T04a-41-rejected.txt`, `-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-42: shellcheck error is refused

| Field | Value |
|---|---|
| Linked criterion | AC3, AC9 |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-42`: an unterminated string in an executable script, then a clean twin |
| Expected result | Refused with a shellcheck parse error; control accepted |
| Actual result | |
| Evidence | `evidence/TC-T04a-42-rejected.txt`, `-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-43: Bad YAML is refused by yamllint

| Field | Value |
|---|---|
| Linked criterion | AC3, AC9 |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-43`: a duplicate key, then a clean twin |
| Expected result | Refused with `key-duplicates`; control accepted |
| Actual result | |
| Evidence | `evidence/TC-T04a-43-rejected.txt`, `-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-44: Dockerfile error is refused by hadolint

| Field | Value |
|---|---|
| Linked criterion | AC3, AC9 |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-44`: `zz/Dockerfile` with an untagged base and `RUN cd`, then a tagged twin |
| Expected result | Refused with a DL rule; control accepted |
| Actual result | |
| Evidence | `evidence/TC-T04a-44-rejected.txt`, `-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-45: Invalid OpenAPI is refused by Spectral

| Field | Value |
|---|---|
| Linked criterion | AC3, AC9 |
| Type | Owner-run (network for the node package) |
| Preconditions | TC-36 passed; the Spectral hook covers `docs/architecture/openapi.yaml` |
| Steps | 1. Read block `== TC-T04a-45`: the `info:` key renamed, then the original restored |
| Expected result | Refused with an oas schema error; the original is accepted |
| Actual result | |
| Evidence | `evidence/TC-T04a-45-rejected.txt`, `-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-46: Bad commit message through the installed hook

| Field | Value |
|---|---|
| Linked criterion | AC4, AC9 (bad commit message) |
| Type | Owner-run |
| Preconditions | TC-36 passed (commit-msg hook installed in the copy) |
| Steps | 1. Read block `== TC-T04a-46`: `git commit --allow-empty -m "bad message"`, then `-m "T04a: owner demo"` |
| Expected result | The first is refused and creates no commit; the second succeeds |
| Actual result | |
| Evidence | `evidence/TC-T04a-46-rejected.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-47: Bad branch name fails quality.sh

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-47`: on branch `feature/bad` run `scripts/quality.sh` |
| Expected result | Non-zero exit and a FAIL line on the branch step |
| Actual result | |
| Evidence | `evidence/TC-T04a-47-rejected.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

## Cases: deferred and manual

### TC-T04a-48: ddev quality (deferred to T05)

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Type | Deferred (needs `.ddev/config.yaml` and DDEV) |
| Preconditions | T05 done |
| Steps | 1. `ddev quality` on a clean tree, then with one fake violation |
| Expected result | Exit 0 on the clean tree with the PASS/SKIP lines of TC-38 plus the Drupal steps; non-zero with a FAIL line when a violation is added; same output as `scripts/quality.sh` |
| Actual result | |
| Evidence | `evidence/TC-T04a-48.txt` |
| Status | Blocked (deferred to T05; owner acceptance required at close under D-6) |
| Date | |
| Executed by | |

### TC-T04a-49: Bad PHP style is rejected by phpcs and PHPStan (deferred to T05 and T09)

| Field | Value |
|---|---|
| Linked criterion | AC3, AC9 (bad PHP style) |
| Type | Deferred (Composer tools from T05, custom modules from T09) |
| Preconditions | `apps/drupal/composer.json` with phpcs, Drupal coder, phpstan-drupal |
| Steps | 1. A custom-module file with `class bad_class{function X(){ return 1;}}` and a PHPStan type error; run `ddev quality`; then the corrected twin |
| Expected result | phpcs reports Drupal standard errors and PHPStan reports a level 6 error; non-zero exit; the twin passes; an ignore without a ticket reason is reported |
| Actual result | |
| Evidence | `evidence/TC-T04a-49.txt` |
| Status | Blocked (deferred; owner acceptance under D-6) |
| Date | |
| Executed by | |

### TC-T04a-50: ESLint, tsc and Prettier errors (deferred to T21)

| Field | Value |
|---|---|
| Linked criterion | AC3, AC9 (ESLint error) |
| Type | Deferred (needs `apps/web/package.json`) |
| Preconditions | T21 done |
| Steps | 1. A file with an ESLint error, one with a type error, one badly formatted; run `ddev quality`; then the twins |
| Expected result | Three separate failures with tool-named lines; non-zero exit; twins pass |
| Actual result | |
| Evidence | `evidence/TC-T04a-50.txt` |
| Status | Blocked (deferred; owner acceptance under D-6) |
| Date | |
| Executed by | |

### TC-T04a-51: CI coverage drop and CI branch check, real Cobertura files (deferred to T08)

| Field | Value |
|---|---|
| Linked criterion | AC4, AC7, AC9 (coverage drop in CI) |
| Type | Deferred (T08 `ci.yml`; real XML from T09, T13, T21) |
| Preconditions | CI exists; engine, Drupal and web tests produce Cobertura XML |
| Steps | 1. A pull request with a coverage drop below a floor; a pull request from `feature/x`; compare the XML attribute names with the gate's fixtures |
| Expected result | CI fails on the drop with the file named; fails on the branch name; the gate reads real coverage.py, PHPUnit and Vitest XML (closes OQ-T04a-3) |
| Actual result | |
| Evidence | `evidence/TC-T04a-51.txt` |
| Status | Blocked (deferred; owner acceptance under D-6) |
| Date | |
| Executed by | |

### TC-T04a-52: Standards are actionable (manual)

| Field | Value |
|---|---|
| Linked criterion | AC1, AC2, AC8 |
| Type | Manual |
| Preconditions | Standards and checklist written |
| Steps | 1. Pick ten rules: PHPStan level 6, Python strict scope, ruff py310 scope, 72-character subject, merge commits only, ticket format, coverage floors, function 50 lines, LLM prompt untrusted data, dependency audit. 2. For each, record where it is enforced (tool, script or checklist item) |
| Expected result | Each rule has an enforcer, and its checklist question can be answered yes or no from a diff. Any rule with neither is a finding; two or more is Fail |
| Actual result | |
| Evidence | `evidence/manual-review.md` |
| Status | Not run |
| Date | |
| Executed by | |

## Cases: D-4 addendum real-tool checks (OQ-T04a-6)

Each shows that the suppression takes effect with the ticket in the comment slot, not only that
`exceptions_report.py` accepts it. A "verify" row that fails against the real tool needs a new
addendum from the solution-architect, not a local workaround.

### TC-T04a-53: coverage.py honours the ticketed pragma

| Field | Value |
|---|---|
| Linked criterion | AC6 (D-4 addendum row: coverage.py) |
| Type | Owner-run (network for `pip install coverage`) |
| Preconditions | `run-checks.sh --owner`; python3 venv |
| Steps | 1. Read block `== TC-T04a-53`: `x.py` has `if a < 0:  # pragma: no cover  # T13: reason`, `y.py` is identical without the pragma; run both under `coverage run` and `coverage report --fail-under=100` |
| Expected result | `x.py` reports 100 percent (the line and its block are excluded); `y.py` is below 100 |
| Actual result | |
| Evidence | `evidence/TC-T04a-53-pragma.txt`, `-control.txt` |
| Status | Not run (Blocked until the owner runs it) |
| Date | |
| Executed by | |

### TC-T04a-54: hadolint honours the ticketed ignore

| Field | Value |
|---|---|
| Linked criterion | AC6 (addendum row: hadolint) |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-54`: a Dockerfile with `RUN apk add curl` with and without `# hadolint ignore=DL3018 # T06: reason` on the line before |
| Expected result | DL3018 is reported without the pragma and absent with it |
| Actual result | |
| Evidence | `evidence/TC-T04a-54-ignored.txt`, `-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-55: markdownlint honours the separate-comment ticket form

| Field | Value |
|---|---|
| Linked criterion | AC6 (addendum row: markdownlint) |
| Type | Owner-run |
| Preconditions | TC-36 passed |
| Steps | 1. Read block `== TC-T04a-55`: a 200-character line preceded by `<!-- markdownlint-disable-next-line MD013 --> <!-- T32: reason -->`, and the same line without it |
| Expected result | The first passes all hooks; the second fails MD013 |
| Actual result | |
| Evidence | `evidence/TC-T04a-55-ignored.txt`, `-control.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-56: yamllint per-rule ignore path works; inline ticket form is ignored

| Field | Value |
|---|---|
| Linked criterion | AC6 (addendum row: yamllint) |
| Type | Owner-run |
| Preconditions | TC-36 passed; the script temporarily replaces `.yamllint.yaml` in the copy |
| Steps | 1. Read block `== TC-T04a-56`: `line-length` max 40 with `ignore:` listing one path with a `# T32:` comment; three long-line files: the ignored path, another path, and a file with `# yamllint disable-line rule:line-length # T32: x` |
| Expected result | The ignored path passes; the other path fails; the inline directive with trailing text still fails (silently ignored, which is why no inline form is allowed) |
| Actual result | |
| Evidence | `evidence/TC-T04a-56-ignored.txt`, `-control.txt`, `-inline.txt` |
| Status | Not run (Blocked) |
| Date | |
| Executed by | |

### TC-T04a-57: TypeScript `@ts-expect-error T21: reason` (deferred to T21)

| Field | Value |
|---|---|
| Linked criterion | AC6 (addendum row: TypeScript) |
| Type | Deferred (needs `apps/web` and `tsc`) |
| Preconditions | T21 done |
| Steps | 1. A type error with and without `// @ts-expect-error T21: reason`; `tsc --noEmit`; then `// @ts-ignore` through ESLint |
| Expected result | The directive suppresses the error; the ticket text does not break it; `@ts-ignore` is reported |
| Actual result | |
| Evidence | `evidence/TC-T04a-57.txt` |
| Status | Blocked (deferred; owner acceptance under D-6) |
| Date | |
| Executed by | |

### TC-T04a-58: phpcs `phpcs:ignore <sniff> -- T09: reason` (deferred to T05 or T09)

| Field | Value |
|---|---|
| Linked criterion | AC6 (addendum row: phpcs) |
| Type | Deferred (needs Composer tools) |
| Preconditions | T05 tools or T09 module |
| Steps | 1. A violating line with and without `// phpcs:ignore Drupal.Commenting.FunctionComment.Missing -- T09: reason`; run phpcs |
| Expected result | The sniff is suppressed with the `--` note, so the form is usable |
| Actual result | |
| Evidence | `evidence/TC-T04a-58.txt` |
| Status | Blocked (deferred; owner acceptance under D-6) |
| Date | |
| Executed by | |
