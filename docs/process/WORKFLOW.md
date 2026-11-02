# Workflow: how Meridian is built with Claude Code agents

## Who does what

| Actor | Role | Writes to |
|---|---|---|
| **Main session** (you and Claude) | Orchestrator. Runs the slash commands, delegates to agents, relays messages between them, enforces gates, closes tasks, and commits the close. | Everything, with your approval |
| `solution-architect` | Requirements, architecture, ADRs, domain answers ("should we, and why") | `docs/**` only. No shell. |
| `technical-architect` | Plans, interfaces, code review ("how, and is it right") | `docs/**` only. Read-only shell. |
| `developer` | Implements one task on its branch, with unit tests | Whole repo except the tester's test-case and report files |
| `tester` | Designs test cases first, executes them later, records evidence and defects | `docs/tests/**`, `tests/**`, `*/tests/**`, `*/e2e/**` |

Agent definitions are in `.claude/agents/`. Their charters are in Appendix A of
`docs/TASKS.md`.

## The main session orchestrates. Subagents do not call each other

Claude Code subagents cannot start other subagents. All coordination goes through the
main session:

- **Agent to agent questions.** The technical-architect lists open questions under
  "Decisions needed" in its plan. The main session asks the solution-architect and saves
  the answer in `docs/tasks/Txx/decision-<topic>.md`. Then it continues the
  technical-architect with the answer.
- **Review feedback.** The main session passes the review findings to the developer, then
  asks the technical-architect to review again.
- **Defects.** The main session passes the tester's defects to the developer, then runs
  review and test again.
- **Files are the shared memory.** Each agent starts cold and reads the plan, test cases
  and review from `docs/`. Anything another agent needs must be written down.

## Per-task loop

```text
/plan-task Txx  ->  /design-tests Txx  ->  /implement-task Txx  ->  /review-task Txx  ->  /test-task Txx  ->  /close-task Txx
 tech-architect      tester (design)        developer               tech-architect        tester (execute)     main session
 plan.md             test-cases.md          code on task/Txx-slug   review.md             test-report.md       PROGRESS, TRACEABILITY
```

| Step | Command | Agent | Gate before the step | Output |
|---|---|---|---|---|
| 1 Plan | `/plan-task Txx` | technical-architect (+ solution-architect) | Dependencies Done, or the user accepts the risk | `docs/tasks/Txx/plan.md`, approved by the user |
| 2 Test design | `/design-tests Txx` | tester | Plan Approved | `docs/tests/Txx/test-cases.md` |
| 3 Build | `/implement-task Txx` | developer | Plan Approved, test cases exist | Commits `Txx: ...` on `task/Txx-slug` |
| 4 Review | `/review-task Txx` | technical-architect | Commits exist | `docs/tasks/Txx/review.md`, Approved |
| 5 Test | `/test-task Txx` | tester | Review Approved | `docs/tests/Txx/test-report.md`, `evidence/`, defects |
| 6 Close | `/close-task Txx` | main session | C1 to C7 all met | PROGRESS Done, TRACEABILITY updated |

Statuses in `docs/PROGRESS.md`: Not started, Planned, In progress, In review, In test,
Blocked, Done.

## How write limits are enforced

Each agent file has a `hooks.PreToolUse` block that runs `.claude/hooks/guard_paths.py`.
The hook runs only while that agent is active. It works as follows:

- **Write, Edit and NotebookEdit** are allowed only on paths that match the agent's
  `--allow` globs. Paths are resolved first, so `..` tricks do not work.
- **Always protected, for every agent:** `.env*` (except `.env.example`),
  `.claude/agents/`, `.claude/hooks/`, `.claude/settings*.json` and `.git/`.
  Agents cannot loosen their own limits.
- **Bash modes:**
  - `none` (solution-architect): no shell.
  - `readonly` (technical-architect): denies redirects, file-changing commands, in-place
    edits, git history changes and package installs.
  - `tester`: redirects, `tee`, `cp` and similar commands may only target allowed paths or
    `/tmp`. Git history changes are denied.
  - `developer`: redirects are checked against its write area, and `--no-verify` is denied.

**Residual risk:** the shell analysis is heuristic. An interpreter one-liner (for example
`python -c "open(...,'w')"`) can still write. Code review (C2) and `git diff` in the close
step are the backstop. Tests: `python3 -m unittest discover -s .claude/hooks/tests -v`.

## First-time setup notes

- After you create or change files in `.claude/agents/`, **restart Claude Code** if that
  directory did not exist when the session started. Otherwise changes are picked up
  within seconds.
- Accept the **workspace trust** dialog for this folder. Frontmatter hooks in project
  agents do not run until the workspace is trusted. Without them, the write limits are not
  enforced.
- Run `scripts/bootstrap-dev.sh` once so the pre-commit hooks (including gitleaks) run on
  every commit.

## Conventions

- Branch: `task/Txx-slug`. Commit message: `Txx: imperative summary`. T04a enforces both.
- Templates: `docs/templates/`. Evidence: `docs/tests/Txx/evidence/`.
- Only the close step marks a task Done. Nothing is pushed or merged without the user's
  approval.
