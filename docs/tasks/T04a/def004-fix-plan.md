# DEF-004 fix plan: make the T04a baseline clean under the real hooks

| Field | Value |
|---|---|
| Defect | DEF-004 (`docs/tests/defects.md`) |
| Task | T04a (owns the baseline), fixed after T05 on the owner's instruction |
| Branch | `task/T04a-def004-baseline` (cut from `task/T05-ddev-drupal` at 990e95c) |
| Author | main session |
| Date | 2026-11-01 |

## Goal

`.tools/pre-commit run --all-files` exits 0 on a committed tree, so `ddev quality` can exit 0, and
TC-T05-21, TC-T05-24 and TC-T05-34 pass on retest.

## Rules for the fix

1. **Behaviour stays the same.** Every change is formatting, lint hygiene or typing. No change in
   what a script checks or prints, except where a lint finding is a real bug (record it).
2. **Fix, do not relax.** No new blanket rule disables in `ruff.toml`, `.shellcheckrc`,
   `.yamllint.yaml` or `.markdownlint-cli2.yaml`. Where a fix would risk behaviour, use one inline
   suppression with a `T04a:` reason (DEF-004), which `scripts/exceptions_report.py` counts.
3. **Path-scoped excludes are allowed only for content that must not be changed**, each with a
   `T04a:` or `T05:` reason comment on the same line:
   - test evidence (`docs/tests/*/evidence/`), already excluded from the fixer hooks in T05;
   - deliberately non-compliant test fixtures (for example `docs/tests/T03/fixtures/`).
4. **Ownership** (the path guard enforces it):
   - main session: `.claude/hooks/*`;
   - developer: `scripts/`, `.spectral.yaml`, `docs/architecture/`, `docs/process/`,
     `docs/standards/`, `docs/tasks/`, `.claude/commands/`, and the other non-test docs;
   - tester: everything under `docs/tests/` (scripts, test-case docs, master test plan,
     fixtures), with a Change log row in each affected task's `test-cases.md`.
5. **Historical records.** Reviews, plans and decisions under `docs/tasks/` get formatting-only
   fixes (tables, code spans, blank lines). The wording does not change.
6. **Commits.** Agents do not commit. The main session commits through the real hook in logical
   groups, prefix `T04a:`.

## Verification (tester)

- `.tools/pre-commit run --all-files` exits 0, and `git status` stays clean afterwards (no fixer
  rewrites).
- `python3 -m unittest discover -s .claude/hooks/tests` (30 tests) and the `scripts/tests` suite
  (65 tests) pass.
- `run-checks.sh --regression` for T00 to T05 gives the same results as before the fix.
- Spectral and the T03 OpenAPI validator still pass on `docs/architecture/openapi.yaml`.
- `ddev quality` exits 0 (retest of TC-T05-34), and TC-T05-21 and TC-T05-24 pass.
