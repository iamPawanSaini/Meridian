# T04a: Solution-architect decisions on coding standards and quality gates

| Field | Value |
|---|---|
| Task | T04a |
| Author | solution-architect |
| Date | 2026-11-01 |
| Answers | `docs/tasks/T04a/plan.md`, section "Decisions needed from solution-architect", questions 2 to 5 |
| Related | `docs/tasks/T04/decision-t04-test-strategy.md` (D-5, D-6), `docs/architecture/solution-architecture.md` (NFR-18), `docs/TASKS.md` T04a, T08 |

Capability claims cite tool documentation with the date checked. A claim marked
**unverified** must be confirmed by the named task before anyone relies on it. T04a pins all
versions.

## Interim choices recorded by the main session (questions 1 and 6)

The main session has fixed these two owner-level items, conservatively and pending the
owner. They are recorded here so this document is complete. **They are not
solution-architect decisions.**

- **Q1, Markdown line length.** `docs/TASKS.md` is the owner's document and is **not
  reflowed**. It is excluded from MD013 by a config exclude that cites a ticket (T32, the
  documentation finalisation task). Only project-authored docs are reflowed. This is
  consistent with D-5 below: an exclude is an exception and must cite a ticket.
- **Q6, D-6 (OQ-T04-1).** Still pending owner confirmation. The deferred T04a cases (T05,
  T08, T09, T21) stay **Blocked**, with written owner acceptance per case at close.

---

## D-1 (question 2): Coverage thresholds

**Decision:** I accept the proposed thresholds with the measuring rules below. All values
are **line coverage floors** (Cobertura `line-rate`), checked per component and path prefix
by `coverage_gate.py`.

| Component | Path | Line floor | Branch |
|---|---|---|---|
| Engine, `scoring` | `meridian_engine/scoring/` | **90%** (NFR-18, fixed) | Measured and reported; not a gate yet |
| Engine, `risk` | `meridian_engine/risk/` | **90%** (NFR-18, fixed) | Measured and reported; not a gate yet |
| Engine, overall | `meridian_engine/` | **85%** | Measured and reported |
| Drupal custom modules | `web/modules/custom/meridian_*` | **70%**, provisional until first measured in T09 | Not gated |
| Next.js | `apps/web/lib/`, `apps/web/components/` | **80%** | Not gated |
| Next.js routes and pages | `apps/web/app/` | No unit floor; covered by Playwright | n/a |

**Measuring rules:**

- **Gate on line rate, not on the combined figure.** With branch coverage on, coverage.py
  counts each line and each branch destination as an opportunity in its total percentage
  ([coverage.py branch coverage](https://coverage.readthedocs.io/en/latest/branch.html),
  checked 2026-11-01). That total is not the "line coverage" NFR-18 specifies. The gate reads
  the line rate. The same page says the XML report has separate statement and branch
  figures. **Unverified:** the exact Cobertura attribute names (`line-rate`,
  `branch-rate`) in coverage.py's output. The `coverage_gate.py` fixtures must use real
  coverage.py output (T13) to confirm them.
- **Branch coverage on in the engine, reported, not gated.** T16 reviews the first measured
  branch rate for `scoring` and `risk`. It may add a branch floor, recorded in
  `CODING_STANDARDS.md`. The FR-04 three-point boundary tests should drive it high anyway.
- **Floors only go up.** Lowering a floor needs a solution-architect decision record. The
  one exception is the first-measurement adjustment for Drupal (below).
- **Drupal 70% is provisional.** Count Unit and Kernel tests only. Functional tests
  (`BrowserTestBase`) drive the site over HTTP, in a different PHP process from PHPUnit, so
  the code that runs in that request probably does not appear in PHPUnit coverage. **This is
  inference and unverified.** T09 records the first measured value. If 70% cannot be reached
  without excluding classes covered only by Functional tests, T09 asks for a decision rather
  than adding untracked excludes. Any exclude follows the exception rule (D-4).
- **Next.js:** `app/` routes and async Server Components are left out of the unit floor.
  Next.js says Vitest does not support `async` Server Components and recommends end-to-end
  tests for them ([Next.js Vitest guide](https://nextjs.org/docs/app/guides/testing/vitest),
  checked 2026-11-01). Their coverage comes from Playwright (T24 to T26).
- `scripts/` and `.claude/hooks/` have no coverage floor. They are stdlib `unittest` code and
  coverage.py is not installed for them. Every script still needs tests.

**Rationale:** NFR-18 fixes only `scoring` and `risk`. The other floors are high enough to
stop untested code being merged, and low enough that glue code (CLI, adapters) does not force
tests written only for coverage. Gating on line rate keeps the number comparable with NFR-18.

**Consequences:**

- `quality/coverage-thresholds.json` stores the line floors per prefix. Branch is
  informational until T16.
- T09, T13 and T21 produce Cobertura XML on their first test run, and the gate applies from
  then on. A component without a manifest is SKIP (plan rule).

---

## D-2 (question 3): mypy and ruff scope

**Decision:**

| Path | ruff (lint and format) | mypy |
|---|---|---|
| `scripts/` (including `scripts/tests/`) | Yes | **strict** |
| `.claude/hooks/` | Yes | **strict** |
| `services/engine/meridian_engine/` (from T13) | Yes | **strict** |
| `services/engine/tests/` (from T13) | Yes | Checked, not strict: `check_untyped_defs = true`; untyped test functions allowed |
| `docs/tests/**/*.py` helpers | Yes | **No** (ruff only) |

- **Apply strict per invocation, not per module.** Use `mypy --strict` on the file sets in
  the pre-commit hook (`files:` regex) for `scripts/` and `.claude/hooks/`. Use
  `[tool.mypy] strict = true` in the engine's own `pyproject.toml` (T13). The mypy docs say
  some options are global-only, and they do not state that `strict` works in a
  `[mypy-PATTERN]` section. They do document per-module flags such as
  `disallow_untyped_defs` and `check_untyped_defs`. They also note that the set of flags
  `strict` turns on may change over time
  ([mypy config file](https://mypy.readthedocs.io/en/stable/config_file.html), checked
  2026-11-01). Per-module `strict` is therefore **unverified**, so we avoid relying on it.
- **Python target per path.** The root `ruff.toml` targets py312 (the engine). `scripts/`,
  `.claude/hooks/` and `docs/tests/` run on the stdlib Python 3.10 that the plan assumes.
  Set `per-file-target-version` to `py310` for those globs, so ruff does not suggest 3.11+
  syntax there ([ruff settings](https://docs.astral.sh/ruff/settings/#per-file-target-version),
  checked 2026-11-01). Run mypy with `--python-version 3.10` for them.

**Rationale:**

- `scripts/` and the hooks are long-lived tooling. The path guard is a security control, and
  the commit and coverage gates are quality gates. Type errors there weaken every later
  check.
- `docs/tests/` helpers belong to the task tester and are mostly snapshot checks for one
  task. Requiring strict types adds cost without much benefit. ruff still catches real
  faults such as unused names and bad imports.
- The helpers that become regression invariants (D-5 of T04) are long-lived, but they are
  small and pinned by their own self-tests (for example `selftest_validator.py`).

**Consequences:**

- If a `docs/tests` helper moves into `scripts/` to be shared, it must then pass strict mypy.
- The baseline cleanup adds types to `scripts/` and `.claude/hooks/`. Changes in
  `.claude/hooks/` are written by the main session, because agents cannot write `.claude/`.
  The T01 guard unit tests are re-run afterwards.

---

## D-3 (question 4): Commit rules and the merge method

**Decision:**

1. **Subject format:** `^T\d{2}a?: \S`. The task ID must be a heading in `docs/TASKS.md`.
   Maximum **72 characters** for the whole subject line, including the prefix.
2. **Allowed exceptions:** subjects starting with `Merge` (Git and GitHub merge commits) and
   `Revert "` (from `git revert`). `fixup!` and `squash!` fail in `--range` mode, so they
   must be squashed locally before push.
3. **Range checked:** only the commits that the PR adds (`origin/main..HEAD` in CI). The
   hook checks each new commit locally. History already on `main` is never re-checked.
   This keeps `Initial commit` and `Add files via upload` exempt without an allowlist, as
   well as the existing T01 and T02 subjects. Those are longer than 72 characters (for
   example `1b8a031`, `085b3e9`), so a full-history check would fail on them.
4. **Merge method for `main`: merge commit (no fast-forward).** Disable squash and rebase in
   the repository settings (T08). Do not turn on "require linear history" in branch
   protection.

**Rationale:**

- **72 characters:** commit-message guidance gives 50 as the target and 72 as the hard limit,
  because GitHub truncates longer subjects
  ([How to Write a Git Commit Message](https://cbea.ms/git-commit/), checked 2026-11-01). The
  `Txx:` prefix with its space uses 5 to 6 characters, so 50 is too tight for a hard gate.
- **Merge commit, not squash:** the per-task commits are part of the evidence trail.
  - Under T04's test-first process, the git-order checks require the test script to be
    committed before the content.
  - Test reports cite commit SHAs as evidence.
  - Squashing combines the commits into one and loses the original SHAs and timing.
    Rebase-and-merge rewrites every commit with new SHAs
    ([GitHub merge methods](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/about-merge-methods-on-github),
    checked 2026-11-01). Either one breaks git-order evidence and SHA links once the branch
    is deleted.
  - A merge commit keeps every branch commit and its SHA reachable from `main`. GitHub also
    lets a repository enable only one merge method (same source).
- **Range-only checking** is the simplest way to exempt history without a list of commits
  that could grow.

**Consequences:**

- `main` history is non-linear. Use `git log --first-parent main` for a per-task view.
- GitHub's default merge subject (`Merge pull request #n from ...`) passes the `Merge`
  exception. Its length is not checked.
- Developers must keep commits clean before pushing: no `fixup!` commits, and every subject
  carries a task ID. Since squashing is off, the branch history is what lands on `main`.
- T08 configures the merge method, and documents in `docs/runbooks/ci-secrets.md` or the
  CI README that squash and rebase are disabled and why.
- Evidence must cite SHAs from the task branch that is merged into `main`, not from a branch
  that was later rewritten. Rewriting a pushed task branch (force-push) after evidence was
  recorded needs the evidence to be re-pointed.

### D-3 Addendum 2026-11-01 (tooling review, `docs/tasks/T04a/review.md` finding 2)

This addendum carries out the intent of D-3, "history already on `main` is never re-checked".
**No rule changes.**

- **Fixed boundary.** The commit-message rule applies only to commits after
  `RULE_START = 7689ec5774ed54ff9e144e9a99c289b9998e6632`. That is the T04 close commit, the
  parent of the first T04a commit.
- **Range check.** `check_range` always excludes `^RULE_START`, in addition to the PR base. So
  a range that reaches back past T04 never re-checks older subjects.
- **CI (T08).** Checkout needs `fetch-depth: 0`, so that `RULE_START` and `origin/main` are
  present for the range check.
- **No history rewrite.** Commits at or before `RULE_START` are never reworded or rebased,
  because evidence cites their SHAs. The same applies to any pushed commit that evidence cites
  (D-3 consequences).
- **Recorded fix.** The main session reworded the unpushed tip commit `ddad7b7` to `d76614a`.
  Its subject was 75 characters, over the 72 limit. The tree is unchanged. The commit was not
  pushed and no evidence cited it, so this rewrite is allowed under D-3. Evidence must cite
  `d76614a`, not `ddad7b7`.

---

## D-4 (question 5): PHPStan level and the exception ticket format

> **Partly superseded.** The ticket placement and the examples in this section are superseded
> by "Addendum 2026-11-01, review-standards finding 1" below. The PHPStan level, the no-baseline
> rule, the ID formats and the matching regex still stand.

**Decision:**

- **PHPStan level 6** for `web/modules/custom`, with `phpstan-drupal` and the deprecation
  rules. Raising to level 8 is a ratchet candidate after T12: T12's review records the error
  count at level 8 and proposes the change if it is small.
- **No PHPStan baseline file.** The tree is new, so there is nothing to grandfather. Every
  ignore is inline, uses an identifier, and has a parenthesised reason that carries the
  ticket. Enable `reportIgnoresWithoutComments: true` and keep
  `reportUnmatchedIgnoredErrors` on (the default), so stale ignores fail.
- **Exception ticket format**, the same for every tool: the ticket ID, a colon, then a
  reason, on the same line as the suppression or config exclude.
  - Allowed IDs: `Txx` or `Txxa` (a task in `docs/TASKS.md`), or `DEF-nnn` (a defect in
    `docs/tests/defects.md`).
  - Matching regex: `\b(T\d{2}a?|DEF-\d{3}): \S`.
  - Examples: `# noqa: E501  T32: owner document, not reflowed`, and
    `// @phpstan-ignore method.notFound (T09: core stub missing, remove after fix)`.
  - The cited task is the one that will **remove or re-decide** the exception. For a
    permanent exclusion, cite the task that decided it, for example
    `T04a: captured evidence output` for `docs/tests/*/evidence/**`.
  - A cited `DEF-nnn` must exist in `defects.md`. `exceptions_report.py` checks that the ID
    exists in `TASKS.md` or `defects.md`.

**Rationale:**

- PHPStan levels are cumulative. Level 5 checks argument types, level 6 adds missing type
  hints, level 7 partially wrong union types, level 8 nullable access, and levels 9 and 10
  strict `mixed` handling ([PHPStan rule levels](https://phpstan.org/user-guide/rule-levels),
  checked 2026-11-01). Level 6 makes new custom code fully typed. Level 8 tends to flag
  Drupal's loosely typed entity and field API calls on nullable returns. That would push
  developers toward ignores, so it waits for evidence from T12.
- PHPStan supports identifier-based inline ignores with a parenthesised comment, an option
  to report ignores without a comment, and reporting of ignores that no longer match
  ([PHPStan ignoring errors](https://phpstan.org/user-guide/ignoring-errors), checked
  2026-11-01). That lets the ticket rule be enforced by PHPStan itself as well as by the
  report.
- phpstan-drupal is MIT and is loaded automatically with `phpstan/extension-installer`.
  It does not recommend a level
  ([GitHub](https://github.com/mglaman/phpstan-drupal), checked 2026-11-01).
- One ticket format across tools keeps `exceptions_report.py` simple. Both ID kinds already
  exist in the project.

**Consequences:**

- T09 sets up `phpstan.neon.dist` at level 6 with the two report options. It is
  demonstrated with a deliberately bad module file in T09 (deferred case, D-6).
- The exceptions report counts each exception per tool and per ticket. T32 and T33 review
  every remaining exception, as part of the release checklist's "known limitations".
- Closing a task with a `Txx` exception that names that same task as the remover is a review
  finding. The exception must be removed or re-pointed before close.

---

## D-4 Addendum 2026-11-01, review-standards finding 1: suppression and ticket forms

**Why:** the original D-4 examples put the ticket straight after the suppression, with no
separator (for example `# noqa: E501  T32: reason`). Several tools then reject or silently drop
the suppression (see `docs/tasks/T04a/review-standards.md`, finding 1):

- mypy accepts only `[codes]` and an optional `# comment` after `type: ignore`. Anything else is
  an "invalid type: ignore comment" error
  ([mypy fastparse.py](https://github.com/python/mypy/blob/master/mypy/fastparse.py), checked
  2026-11-01).
- ruff reads `T32` as a rule code. The following `:` makes the whole `noqa` directive invalid,
  and ruff drops it with a warning
  ([ruff noqa.rs](https://github.com/astral-sh/ruff/blob/main/crates/ruff_linter/src/noqa.rs),
  read 2026-11-01; inference from the source).
- yamllint matches its directives with a pattern that allows only whitespace after the rule
  list. Any trailing text, even `# T05: reason`, makes yamllint **silently ignore** the
  directive
  ([yamllint linter.py](https://github.com/adrienverge/yamllint/blob/master/yamllint/linter.py),
  checked 2026-11-01).

**Decision:** the ticket stays **on the same line**, but always in the **tool's own comment or
description slot**, after the tool's separator. Never put it as bare text after the rule list.
The ticket regex `\b(T\d{2}a?|DEF-\d{3}): \S` and the ID-existence check are unchanged.

### Forms per tool

"Verified" means confirmed in the tool's documentation or source on the date shown. "Verify in
owner-run TC" means it must be confirmed by a fixture run against the real tool (owner-run cases
TC-T04a-36 onward, or the named later task) before anyone relies on it.

| Tool | Required form (the ticket is in the comment slot) | Separator | Status and source |
|---|---|---|---|
| ruff | `x = call()  # noqa: S603  # T20: argument list is fixed` | second `#` | Verified: the [ruff docs](https://docs.astral.sh/ruff/linter/#error-suppression) say the code list "ends at the last valid code", and a trailing `#` comment is allowed; ruff `noqa.rs` test `# noqa: F401 # Some comment` (checked 2026-11-01) |
| mypy | `import yaml  # type: ignore[import-untyped]  # T13: stubs come with the engine manifest` | second `#` | Verified: `fastparse.py` pattern `\s*\[([^]#]*)\]\s*(#.*)?$` (checked 2026-11-01) |
| coverage.py | `if debug:  # pragma: no cover  # T13: reason` | second `#` | Verify in owner-run TC (T13, first coverage run). The default exclude regex is believed to match anywhere in the line; not checked in this session |
| shellcheck | `# shellcheck disable=SC2034 # T05: read by the sourcing DDEV command` | second `#` | Verified: documented trailing-comment form ([ShellCheck wiki, Directive](https://github.com/koalaman/shellcheck/wiki/Directive), checked 2026-11-01) |
| hadolint | `# hadolint ignore=DL3008 # T06: distro pins the version` | second `#` | Verified from source: the pragma parser consumes an optional `# ...` comment after the rule list ([hadolint Pragma.hs](https://github.com/hadolint/hadolint/blob/master/src/Hadolint/Pragma.hs), checked 2026-11-01; inference from the source). Verify in owner-run TC |
| ESLint | `// eslint-disable-next-line no-console -- T29: replaced by the server logger` | `--` | Verified: [ESLint rule config, comment descriptions](https://eslint.org/docs/latest/use/configure/rules) (checked 2026-11-01) |
| TypeScript | `// @ts-expect-error T21: upstream type is wrong, issue linked in the plan` | space after the directive | Verify in T21 (deferred TC). `@ts-ignore` stays forbidden |
| PHPStan | `// @phpstan-ignore method.notFound (T09: core stub missing)` | parentheses | Verified: [PHPStan ignoring errors](https://phpstan.org/user-guide/ignoring-errors) (checked 2026-11-01, original D-4) |
| phpcs | `// phpcs:ignore Drupal.Commenting.FunctionComment.Missing -- T09: reason` | `--` | Partly verified: `--` notes are documented for `phpcs:ignoreFile`, `phpcs:disable` and `phpcs:enable` from PHP_CodeSniffer 3.2.0 ([PHPCS Advanced Usage](https://github.com/PHPCSStandards/PHP_CodeSniffer/wiki/Advanced-Usage), checked 2026-11-01). `phpcs:ignore` with `--` is not shown there. Verify in T05 or T09 (deferred TC) |
| markdownlint | `<!-- markdownlint-disable-next-line MD013 --> <!-- T32: owner wording kept -->` | a separate HTML comment on the same line | Verify in owner-run TC. The README does not document text inside the directive. From the source, unknown words seem to be ignored, but a separate comment does not depend on that |
| yamllint | **No inline disables.** Use a per-rule `ignore:` path list in `.yamllint.yaml`, with the ticket as a YAML comment on the path line: `- path/file.yaml  # T08: reason` | YAML `#` on the config line | Inline directives cannot hold a ticket: trailing text silently disables the directive (`linter.py`, verified above). Per-rule `ignore:` support: verify in owner-run TC |
| Spectral | **No inline form.** Use `overrides:` in `.spectral.yaml` (`files:` may use a JSON pointer, for example `openapi.yaml#/paths`, and set the rule to `"off"`), with `# Txx: reason` on the rule line | YAML `#` on the config line | Verified: [Spectral overrides](https://github.com/stoplightio/spectral/blob/develop/docs/guides/4d-overrides.md) (checked 2026-11-01). That page does not mention an inline suppression |
| Config path excludes (ruff `extend-exclude`, mypy `exclude`, markdownlint `ignores`, coverage `omit`) | `- "docs/TASKS.md"  # T32: owner document` | the format's own comment (`#` in YAML, TOML and INI) | Already in use in `.markdownlint-cli2.yaml` and `ruff.toml`. JSON has no comments, so `quality/coverage-thresholds.json` must not hold excludes |

### Scan rule for `exceptions_report.py`

1. Find every suppression token (the existing list), plus every config exclude in the files the
   report already scans.
2. Take the text **after the tool's separator** from the table above. A ticket elsewhere on the
   line does not count. The checks per tool:
   - ruff, mypy, coverage, shellcheck and hadolint: after the directive and its code list, `#`
     then optional spaces, then the ticket. For example, ruff:
     `#\s*noqa:\s*[A-Z]+[0-9]+(?:[,\s]+[A-Z]+[0-9]+)*\s+#\s*(T\d{2}a?|DEF-\d{3}): \S`.
   - ESLint and phpcs: `--` then spaces, then the ticket.
   - PHPStan: the ticket inside the `( ... )` after the identifier.
   - TypeScript: the ticket after `@ts-expect-error` and a space.
   - markdownlint: the ticket in a separate `<!-- ... -->` on the same line.
   - Config excludes: the ticket in the format's comment on the same line.
3. **FAIL**, naming the file and line, when:
   - there is no ticket;
   - the ticket is in the bare form, for example `# noqa: E501  T32: reason`;
   - the ID does not exist in `docs/TASKS.md` or `docs/tests/defects.md`;
   - a `noqa` has no code;
   - an `eslint-disable` names no rule;
   - an inline `yamllint disable` or `yamllint disable-line` appears at all;
   - `@ts-ignore` is used.
4. Count per tool and per ticket, as before.

**Consequences:**

- `docs/standards/CODING_STANDARDS.md` ("Exception policy" and its examples) must use these
  forms. The fixtures that use the bare form must be updated: `scripts/tests/` (for example
  `test_exceptions_report.py` lines 42 to 43) and `docs/tests/T04a/run-checks.sh` (line 433).
  Add a negative fixture that proves the bare form now FAILs.
- The owner-run cases add one real-tool fixture per row that is still marked "verify". Each
  fixture shows that the suppression takes effect, not only that the report accepts it.
  Deferred rows (TypeScript, phpcs) are re-run in T21 and in T05 or T09.
- If a "verify" row fails against the real tool, the form is replaced through a new addendum,
  not by local workarounds.

---

## Summary

| ID | Question | Decision |
|---|---|---|
| Q1 | Markdown line length | Main session's interim choice, pending owner: `TASKS.md` not reflowed, MD013 exclude citing T32; project docs reflowed |
| D-1 | Coverage | Line floors: engine 85%, `scoring` and `risk` 90% (NFR-18), Drupal custom 70% provisional (Unit plus Kernel, T09 measures), web `lib/` and `components/` 80%; branch on and reported, gated later only if T16 decides; floors only go up |
| D-2 | mypy scope | Strict for `scripts/`, `.claude/hooks/`, `meridian_engine` (per invocation, not per module); engine tests non-strict checked; `docs/tests` helpers ruff only; py310 target for stdlib paths |
| D-3 | Commits | `Txx:` subject at most 72 characters; `Merge` and `Revert "` allowed; `fixup!` fails; PR range only; `main` uses merge commits only (squash and rebase disabled) to keep per-task commits and SHAs |
| D-4 | PHPStan and exceptions | Level 6, no baseline, inline identifier ignores with a reason; ticket format `Txx:` or `DEF-nnn:` plus a reason on the same line; the ID must exist. **Addendum 2026-11-01:** the ticket goes in the tool's own comment slot (`# Txx:` after `noqa` or `type: ignore`, `-- Txx:` for ESLint and phpcs); no inline yamllint disables |
| Q6 | D-6 | Main session's interim choice, pending owner: deferred cases stay Blocked with per-case owner acceptance |

## Open questions

| ID | Question | Owner | Resolve in |
|---|---|---|---|
| OQ-T04a-1 | Confirm the Q1 `TASKS.md` exclusion and the D-6 policy | Project owner | Before T04a close |
| OQ-T04a-2 | Is Functional-test code excluded from PHPUnit coverage, and is 70% reachable with Unit plus Kernel? | developer | T09 |
| OQ-T04a-3 | Cobertura attribute names in coverage.py, PHPUnit and Vitest XML | developer | T09, T13, T21 |
| OQ-T04a-4 | Branch-coverage floor for `scoring` and `risk` | solution-architect | T16 |
| OQ-T04a-5 | Raise PHPStan to level 8 | technical-architect | T12 review |
| OQ-T04a-6 | Confirm the "verify" rows of the D-4 addendum against the real tools (coverage, hadolint, markdownlint, yamllint per-rule `ignore:`; TypeScript and phpcs deferred) | tester (owner-run) | T04a owner-run TCs; T05/T09; T21 |
