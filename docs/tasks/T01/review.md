# T01: Claude Code agents and workflow commands, Review

| Field | Value |
|---|---|
| Task | T01 |
| Reviewer | technical-architect (role played by the main session) |
| Date | 2026-11-01 |
| Commit range | `task/T00-scaffold..task/T01-agents` |
| Plan | `docs/tasks/T01/plan.md` |

## Findings

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Minor | `.claude/hooks/guard_paths.py` | The Bash analysis is heuristic. `python -c` or similar can bypass it. | Accepted residual risk, documented in WORKFLOW.md. Review and `git diff` are the backstop. Revisit if an agent is seen bypassing it. | Accepted |
| 2 | Minor | `.claude/hooks/guard_paths.py` | Readonly mode can wrongly block a command with a quoted `>`, for example `awk '$1 > 5'`. | Safe direction (blocks, does not allow). The agent can use Grep or Read instead. | Accepted |
| 3 | Major | `.claude/agents/*` | The hooks need a trusted workspace and a session restart. If either is missing, the guards silently do not apply. | Documented in WORKFLOW.md "First-time setup". TC-T01-03 verifies the guards in a live session. | Open until TC-T01-03 passes |
| 4 | Note | agents | Models: architects `opus`, developer and tester `sonnet`. | The owner can change them in the frontmatter. | Closed |
| 5 | Note | `.claude/hooks/guard_paths.py` | Needs `python3` on the host that runs Claude Code. | It is present. The guard uses only the standard library. | Closed |

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | |
| C2 Findings resolved | Partly | Finding 3 is open until the live test |
| C3 Criteria mapped to executed tests | Partly | 2 of 7 cases are blocked |
| C4 CI green | n/a | Before T08 |
| C5 Docs updated | Yes | WORKFLOW.md, `.claude/README.md` |
| C6 No secrets | Yes | |
| C7 Clean-checkout works | Yes | The guard tests use only the standard library |

## Approval

**Approved with conditions:** TC-T01-03 and TC-T01-06 must pass in a restarted session.
