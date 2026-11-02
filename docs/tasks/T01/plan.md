# T01: Claude Code agents and workflow commands, Plan

| Field | Value |
|---|---|
| Task | T01 |
| Author | technical-architect (role played by the main session; the agents do not exist yet) |
| Date | 2026-11-01 |
| Branch | `task/T01-agents` (based on `task/T00-scaffold`) |
| Status | Approved |

## Goal

Define the four subagents from Appendix A and one slash command per loop step. Enforce
each agent's write limits technically, not only by instruction. Prove the loop works with
a dry-run task.

## Scope

- `.claude/agents/{solution-architect,technical-architect,developer,tester}.md` with `name`,
  `description`, `tools`, `model`, and a subagent-scoped `hooks` block.
- `.claude/hooks/guard_paths.py`: a PreToolUse hook that runs only inside a subagent.
  - Write, Edit and NotebookEdit are allowed only under the agent's allowed path globs.
  - In `readonly` Bash mode (both architects), mutating shell commands are denied.
  - In `tester` Bash mode, redirects and in-place edits are allowed only to test paths and
    temp dirs, and git history changes are denied.
- Unit tests for the guard: `.claude/hooks/tests/test_guard_paths.py` (stdlib `unittest`,
  no install needed).
- `.claude/commands/{plan-task,design-tests,implement-task,review-task,test-task,close-task}.md`.
- `docs/process/WORKFLOW.md`.
- Dry-run task `T01-demo` (hello endpoint stub) through all six steps.

## Non-goals

- A full OS-level sandbox for Bash. A determined agent could still write files through an
  interpreter, for example `python -c`. The guard blocks the common paths, and review (C2)
  and git diff catch the rest. This residual risk is recorded in WORKFLOW.md.

## Agent write permissions

| Agent | Tools | File writes allowed | Bash |
|---|---|---|---|
| solution-architect | Read, Grep, Glob, WebSearch, WebFetch, Write, Edit | `docs/**` | none |
| technical-architect | Read, Grep, Glob, Bash, Write, Edit | `docs/**` | read-only |
| developer | Read, Grep, Glob, Bash, Write, Edit | whole repo except `docs/tests/**` test cases and reports | full; `--no-verify` denied |
| tester | Read, Grep, Glob, Bash, Write, Edit | `docs/tests/**`, `**/tests/**`, `**/e2e/**` | test mode |

## Steps

1. Write the guard and its unit tests. Run the tests.
2. Write the four agent files.
3. Write the six commands and WORKFLOW.md.
4. Restart Claude Code so the new `.claude/agents/` directory is loaded. This is required
   because the directory did not exist when the session started.
5. Run the dry-run `T01-demo` with the commands. Do a live check that the tester agent
   cannot edit a source file.
6. Review, test report, close.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| Subagent definitions | New | Main session (orchestrator) |
| PreToolUse hook (subagent-scoped) | New | All four agents |
| Slash commands | New | Project owner and main session |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Hook field names change between Claude Code versions | Low | Guard silently stops applying | The guard is scoped through agent frontmatter, not `agent_type`. Unit tests pin the input shape. The live check in step 5 verifies it. |
| Frontmatter hooks need workspace trust | Medium | Guard does not run | WORKFLOW.md says to accept the trust dialog. The live check in step 5 detects it. |
| Bash bypass | Low | Agent writes outside its area | Non-goal above. Review catches it. |

## Test hooks needed

- The guard reads hook JSON on stdin, so tests can drive it without Claude Code.

## Decisions needed from solution-architect

- Models: architects use `opus`; developer and tester use `sonnet`. The owner can change
  this in the frontmatter.

## Definition of done

See `docs/templates/plan.md`. C4 is n/a until T08.
