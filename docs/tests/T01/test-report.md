# T01: Claude Code agents and workflow commands, Test report

| Field | Value |
|---|---|
| Task | T01 |
| Build or commit | `task/T01-agents` (first T01 commit) |
| Environment | WSL2 Linux, Python 3.10.12, Claude Code 2.1.316 |
| Date | 2026-11-01 |
| Executed by | tester (role played by the main session) |

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T01-01 | AC1 agent files | Pass | `evidence/TC-T01-guard-unittests.txt` (`AgentFrontmatter`) |
| TC-T01-02 | AC2 tester guard (hook level) | Pass | `evidence/TC-T01-guard-unittests.txt` (`TesterGuard`, 11 tests). A direct run of the configured hook command on `apps/web/app/page.tsx` exited 2 with `[tester guard] Blocked`. |
| TC-T01-03 | AC2 tester agent, live | **Blocked** | Needs a Claude Code restart |
| TC-T01-04 | AC3 architects read-only | Pass | `evidence/TC-T01-guard-unittests.txt` (`ArchitectGuards`) |
| TC-T01-05 | AC4 commands documented | Pass | `evidence/TC-T01-commands-workflow.txt` |
| TC-T01-06 | AC5 dry run | **Blocked** | Needs a Claude Code restart |
| TC-T01-07 | AC6 orchestration documented | Pass | `evidence/TC-T01-commands-workflow.txt` |

Totals: 5 pass, 0 fail, 2 blocked.

### Why two cases are blocked

`.claude/agents/` was created during the session that built T01. Claude Code only watches
agent directories that existed when the session started, so the four agents are not
loaded until Claude Code restarts. TC-T01-03 and TC-T01-06 must run in a new session.

## Defects raised

(none)

## Coverage notes

The guard has 26 unit tests. Known limit: the Bash analysis is heuristic. An interpreter
one-liner could still write files. This is documented in WORKFLOW.md and accepted in
review finding 1.

## Sign-off

**Not signed off.** Waiting for TC-T01-03 and TC-T01-06.
