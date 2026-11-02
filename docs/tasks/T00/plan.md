# T00: Repository scaffold and documentation skeleton, Plan

| Field | Value |
|---|---|
| Task | T00 |
| Author | technical-architect (role played by the main session; the agents do not exist until T01) |
| Date | 2026-11-01 |
| Branch | `task/T00-scaffold` |
| Status | Approved |

## Goal

Create the monorepo skeleton, documentation templates and the first quality gate
(secret scanning and basic formatting), so that every later task has a place for its
code, docs and evidence.

## Scope

- Folder structure from `docs/TASKS.md` section 4, with a README in each top-level folder
  and in each `docs/` subfolder.
- Templates from Appendix B: plan, review, test cases, test report, defect, ADR, runbook.
- `docs/PROGRESS.md` (T00 to T33, including T04a and T21a) and `docs/TRACEABILITY.md`
  (R-01 to R-12). Both are generated from `docs/TASKS.md` so the IDs match it exactly.
- `.pre-commit-config.yaml`: gitleaks, hygiene and formatting hooks, and a naming check.
- `scripts/bootstrap-dev.sh`: installs a pinned pre-commit zipapp into `.tools/`. This
  avoids a global pip install, which this machine does not have (no pip or ensurepip).
- `scripts/demo-secret-scan.sh`: the rejected-commit demonstration, run in a throwaway
  repo so no key ever reaches this repo's history.
- `.gitignore`, `.env.example`, `CLAUDE.md`, root `README.md`.
- `docs/TASKS.md` moved from the repo root into `docs/`.

## Non-goals

- Per-language linters and formatters, and `ddev quality` (T04a).
- DDEV config (T05), Drupal, engine or Next.js code.
- Agents and commands (T01). Only their folders are created here.

## Steps

1. Create folders and READMEs.
2. Write templates.
3. Generate PROGRESS and TRACEABILITY from `docs/TASKS.md`.
4. Add pre-commit config, gitleaks config, bootstrap, name check and demo scripts.
5. Write `.gitignore`, `.env.example`, `CLAUDE.md`, `README.md`.
6. Run the test cases in `docs/tests/T00/test-cases.md`.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| Git hooks (pre-commit) | New | Every contributor and agent |
| `scripts/check-names.sh` | New | pre-commit, later CI (T08) |
| `docs/templates/*` | New | All agents |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| gitleaks hook needs Go to build | Medium | Hook install fails | pre-commit 3+ downloads a Go toolchain automatically. Fallback: the `gitleaks-system` hook with a pinned binary. |
| Unpinned download of the pre-commit zipapp | Low | Supply chain | Version is pinned. Pin the SHA-256 in `scripts/tool-versions.env` after the first verified download. |
| Repo folder is `Meridian`, not `meridian` | Certain | Cosmetic | Clone with `git clone ... meridian` (README). Renaming the GitHub repo is the owner's choice. |

## Test hooks needed

- `scripts/demo-secret-scan.sh` with an evidence-file argument.
- `docs/tests/T00/run-checks.sh` for the structural criteria.

## Decisions needed from solution-architect

- None.

## Definition of done

- [ ] All T00 acceptance criteria met
- [x] C1: Plan exists before coding
- [ ] C2 to C7 (see `review.md`)
