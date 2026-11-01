# T04a: Coding standards and quality gates, Plan

| Field | Value |
|---|---|
| Task | T04a |
| Author | technical-architect |
| Date | 2026-11-01 |
| Branch | `task/T04a-coding-standards` |
| Status | Approved |

Approved by main session on owner's instruction, 2026-11-01.

## Goal

Write the coding standards once and enforce them by machine. One script, `scripts/quality.sh`,
is the only implementation. `ddev quality`, pre-commit and CI (T08) all call it. Only Phase 1 is
in scope. `.ddev/config.yaml` arrives in T05, so the `ddev quality` wrapper is added now but is
shown working in T05 (see "Verification split").

## Scope

- **Standards (technical-architect).** `docs/standards/CODING_STANDARDS.md` has these sections:
  PHP and Drupal, Python, TypeScript and Next.js, SQL and migrations, Docker and YAML, shell,
  Markdown, OpenAPI and LLM prompt files. It also covers the cross-cutting rules: naming
  (section 0), error handling, structured logging, no secrets, dependency policy (lockfiles,
  pins, audit before adding), comments and docstrings, and size guidance (function 50 lines,
  file 400 lines). Further parts: a tool table with version, source and date checked; the
  coverage thresholds; the exception rule; the section 0b asset rules. `REVIEW_CHECKLIST.md`
  turns each standard, C1 to C7 and the simulation-only rule into yes/no checks.
- **Configs (developer).** Root, applying to the current tree: `ruff.toml` (line length 100,
  py312, all Python), `mypy.ini` (strict for `scripts/`, `.claude/hooks/`; `meridian_engine`
  in T13), `.yamllint.yaml`, `.markdownlint-cli2.yaml` (MD013 at 100; tables, code, headings
  exempt), `.shellcheckrc`, `tsconfig.base.json` (strict) and `.prettierrc.json` (T21 extends
  them). Component config files only, no scaffolds: `apps/drupal/phpcs.xml.dist` (Drupal and
  DrupalPractice on `web/modules/custom`), `apps/drupal/phpstan.neon.dist` (phpstan-drupal),
  `apps/web/eslint.config.mjs` (next, typescript-eslint). Packages come from the T05 and T21
  manifests; no `composer.json`, `package.json` or `pyproject.toml` is created here.
- **Pre-commit (developer).** Add these hooks, pinned by rev: ruff (lint and format), mypy,
  shellcheck-py, yamllint, hadolint, markdownlint-cli2, and Spectral as a local `node` hook with
  `@stoplight/spectral-cli@<pin>`. Set `default_install_hook_types: [pre-commit, commit-msg]`.
  Every version is marked "verify" until an owner-run install confirms it. Also record the
  `web-vitals` licence and pin (closes OQ-T04-5).
- **Stdlib scripts (developer)** in `scripts/`, Python 3.10, `unittest` tests in `scripts/tests/`:
  - `check_commit_msg.py` (commit-msg hook; `--range A..B` for CI): `^T\d{2}a?: \S`, ID is a
    heading in `docs/TASKS.md`, subject at most 72 chars; `Merge `/`Revert "` allowed;
    `fixup!` fails in `--range`.
  - `check_branch_name.py`: `^task/T\d{2}a?-[a-z0-9]+(-[a-z0-9]+)*$`, ID in `TASKS.md`,
    `main` allowed, `GITHUB_HEAD_REF` in CI.
  - `exceptions_report.py`: every suppression (`noqa`, `type: ignore`, `pragma: no cover`,
    `eslint-disable`, `@ts-expect-error`, `phpcs:ignore`, `@phpstan-ignore`, shellcheck,
    yamllint, markdownlint, hadolint) and config path exclude must cite `Txx` or `DEF-nnn`
    on the same line; counts per tool (`--out FILE`).
  - `coverage_gate.py`: Cobertura XML (coverage.py, PHPUnit, Vitest) against
    `quality/coverage-thresholds.json` per component and path prefix; exit 1 names the file.
  - `check_assets.py`: `apps/web/**` and the Drupal custom theme; fails on third-party
    font, style, script or icon hosts and on hex outside the tokens file (T21a owns allowlist).
- **`scripts/quality.sh` (developer).** Runs every step, prints PASS, FAIL or SKIP per step
  and a summary, and exits non-zero on any FAIL. Steps: (1) `pre-commit run --all-files`;
  (2) branch and commit range against `origin/main`; (3) exceptions report and asset check;
  (4) component suites (lint, types, unit tests, coverage gate) keyed on a manifest:
  `services/engine/pyproject.toml`, `apps/drupal/composer.json`, `apps/web/package.json`.
  SKIP only when the manifest is absent; a missing tool with the manifest present is a FAIL.
  Runner seam `QUALITY_RUNNER=native|ddev` (T05/T06 map it to `ddev exec`, `ddev engine`,
  `ddev next`).
- `.ddev/commands/host/quality`: a thin wrapper, `exec "$DDEV_APPROOT/scripts/quality.sh" "$@"`.
  It works once T05 adds `config.yaml`. Update `.ddev/README.md` and `scripts/README.md`.
- **Baseline cleanup (developer), in its own commit.** Reflow the long Markdown lines: 308
  outside tables, about 166 of them in `TASKS.md` (decision 1). Run ruff on `.claude/hooks/` and
  `docs/tests/*.py` (for example `import re, subprocess, sys, os`). Fix shellcheck and yamllint
  findings, and add types to Python in `scripts/`. Exclude `docs/tests/*/evidence/**`
  (captured output) with a comment that cites a ticket. Then re-run the T01 guard tests and
  the T03/T04 `run-checks.sh` to show the helpers behave the same.

## Non-goals

- `.ddev/config.yaml`, Drupal, engine or Next.js scaffolds (T05, T13, T21). `ci.yml` and branch
  protection (T08). The `--regression` retrofit (T08, D-5). T21a token values and the
  Playwright same-origin test.

## Steps

1. Technical-architect: both standards docs, after the decisions below. 2. Developer:
   configs. 3. Scripts and tests. 4. `quality.sh`, wrapper, pre-commit, READMEs. 5. Cleanup.
6. Main session (agents cannot write `.claude/`): reference `REVIEW_CHECKLIST.md` in
   `.claude/agents/technical-architect.md`, reflow the long lines in `.claude/agents/*.md`, and
   add `scripts/quality.sh` to the CLAUDE.md commands table.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| `scripts/quality.sh` (exit code, PASS/FAIL/SKIP lines, `QUALITY_RUNNER`) | New | `ddev quality` (T05), CI (T08) |
| `.pre-commit-config.yaml` | Hooks and the commit-msg stage | Every commit; bootstrap |
| `quality/coverage-thresholds.json` plus Cobertura input | New | T08, T09, T13, T21 |
| Exception comment format (cites `Txx` or `DEF-nnn`) | New rule | All code |
| Root configs (ruff, mypy, tsconfig base, prettier, lint) | New | T05, T13 and T21 extend them |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Pinned versions are wrong or stale (no network here) | High | Medium | Marked "verify"; the owner-run install records the real versions and dates |
| The Markdown reflow changes the meaning of a spec | Medium | High | Separate commit; `git diff --word-diff` must show whitespace changes only |
| A silent SKIP after a component is scaffolded | Medium | High | SKIP only when the manifest is absent; T08 asserts the expected components |
| Reformatting the T03/T04 helpers changes their results | Low | Medium | Compare the PASS counts before and after |

## Verification split (for `/design-tests`)

- **Verified now (agent, stdlib and node 22):** unit tests for the five scripts; the
  commit-msg hook in a throwaway repo (`demo-secret-scan.sh` pattern) rejects `bad message`
  and accepts `T04a: x`; branch-name cases; a coverage drop on fixture XML is rejected; an
  untagged `# noqa` fixture fails and the report runs on the tree; asset and hex fixtures;
  `quality.sh` aggregation with fake steps and the SKIP versus FAIL rule; standards sections
  exist; helper regression re-runs pass; wrapper content is correct.
- **Owner-run (pre-commit downloads):** `bootstrap-dev.sh` then `quality.sh` on a clean tree
  shows zero violations, with versions captured (C7). Rejected: untyped Python in `scripts/`,
  a long Markdown line, a shellcheck error, bad YAML, a hadolint error in a throwaway
  Dockerfile, a bad commit through the installed hook.
- **Deferred (carried-over cases; under D-6 they need written owner acceptance):**
  `ddev quality` runs (T05); bad PHP style via phpcs and PHPStan (T05, then T09); ESLint,
  `tsc` and Prettier errors (T21); CI coverage drop and CI branch check (T08).

## Test hooks needed

- `--msg-file`, `--range`, `--branch`, `--tasks-file` arguments; `QUALITY_STEPS` and
  `QUALITY_RUNNER` overrides; fixtures in `scripts/tests/fixtures/` (Cobertura XML,
  suppressions, asset references).

## Decisions needed from solution-architect

1. **Markdown line length:** MD013 at 100 with a word-neutral reflow of about 308 lines (166
   in the owner's `TASKS.md`, owner OK needed), or a ticketed `TASKS.md` exclude? Recommend
   the reflow.
2. **Coverage (lines):** engine overall 85% with branch coverage on; `scoring` and `risk` 90%
   (NFR-18, fixed); Drupal custom modules 70%; web `lib/` and components 80%. Confirm.
3. **mypy scope:** strict on `scripts/`, `.claude/hooks/`, `meridian_engine`; ruff only on
   `docs/tests/` helpers. Confirm, or require types there too.
4. **Commits:** 72-char subject; allow `Merge`/`Revert`; check only the PR range (so
   `Initial commit` and `Add files via upload` stay exempt); merge or squash for `main`?
5. **PHPStan level** for custom modules (proposed 6); exception ticket format `Txx` or `DEF-nnn`.
6. **D-6 (OQ-T04-1)** is pending owner confirmation; the deferred cases depend on it, or need
   owner acceptance case by case.

## Definition of done

- [ ] All T04a acceptance criteria met, or carried over under the split above
- [ ] C1: Plan exists and was reviewed before coding started
- [ ] C2: Code reviewed; findings resolved
- [ ] C3: Every criterion maps to an executed test case with evidence
- [ ] C4: No new lint, type or security warnings (`quality.sh` until T08)
- [ ] C5: Docs and traceability (R-12, NFR-18 rows) updated
- [ ] C6: No secrets; `.env.example` unchanged (no new variables)
- [ ] C7: Clean checkout works with `scripts/bootstrap-dev.sh` and `scripts/quality.sh`
