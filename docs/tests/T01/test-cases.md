# T01: Claude Code agents and workflow commands, Test cases

| Field | Value |
|---|---|
| Task | T01 |
| Author | tester (role played by the main session; the agents load only after a restart) |
| Date | 2026-11-01 |
| Criteria source | `docs/TASKS.md` T01 |

## Criterion coverage

| Criterion | Test cases |
|---|---|
| AC1: Four agent files with name, description, tools, model, matching Appendix A | TC-T01-01 |
| AC2: Tester cannot write application source; verified by attempting a source edit | TC-T01-02 (hook level), TC-T01-03 (live agent) |
| AC3: Architects read-only on source; writes limited to `docs/` | TC-T01-04 |
| AC4: A slash command per loop step, documented in WORKFLOW.md | TC-T01-05 |
| AC5: Dry run "T01-demo" produces every artifact | TC-T01-06 |
| AC6: WORKFLOW.md explains main-session orchestration | TC-T01-07 |

### TC-T01-01: Agent files

| Field | Value |
|---|---|
| Linked criterion | AC1 |
| Steps | `python3 -m unittest discover -s .claude/hooks/tests -v` (class `AgentFrontmatter`) |
| Expected result | Each of the 4 files has `name`, `description`, `tools`, `model` and `hooks`, and its guard arguments equal the tested profile. Manual check against Appendix A: purpose, inputs, outputs, tools and must-nots are present in the body. |

### TC-T01-02: Tester guard blocks a source edit (hook level)

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Steps | 1. Unit tests, class `TesterGuard`. 2. Run the hook command from `tester.md` exactly as configured, with an Edit of `apps/web/app/page.tsx`. |
| Expected result | Source writes are blocked (exit 2), including through Bash redirect, `sed -i`, `cp` and `..` traversal. Writes to `docs/tests/` and test folders are allowed. |

### TC-T01-03: Tester agent cannot edit source (live)

| Field | Value |
|---|---|
| Linked criterion | AC2 |
| Preconditions | Claude Code restarted in the repo, workspace trusted |
| Steps | In the main session: "Use the tester agent to add a comment line to README.md, and also to docs/tests/T01/evidence/live-probe.txt. Report the exact tool results." |
| Expected result | The README.md edit is blocked with `[tester guard] Blocked: ...`. The probe file under `docs/tests/` is written. `git diff README.md` is empty. |

### TC-T01-04: Architects are read-only on source

| Field | Value |
|---|---|
| Linked criterion | AC3 |
| Steps | Unit tests, class `ArchitectGuards` |
| Expected result | solution-architect: writes under `docs/` allowed, source writes blocked, no Bash. technical-architect: writes under `docs/` allowed, read-only commands allowed, mutating commands blocked. |

### TC-T01-05: Commands exist and are documented

| Field | Value |
|---|---|
| Linked criterion | AC4 |
| Steps | For each of plan-task, design-tests, implement-task, review-task, test-task and close-task: check that `.claude/commands/<c>.md` exists and that `docs/process/WORKFLOW.md` mentions `/<c>` |
| Expected result | All 6 pass. |

### TC-T01-06: Dry run T01-demo

| Field | Value |
|---|---|
| Linked criterion | AC5 |
| Preconditions | Restarted session (as in TC-T01-03) |
| Steps | Run `/plan-task T01-demo`, `/design-tests T01-demo`, `/implement-task T01-demo`, `/review-task T01-demo`, `/test-task T01-demo` and `/close-task T01-demo`. The task is "add a hello endpoint stub": `scripts/demo/hello_endpoint.py`, a stdlib HTTP handler that returns `{"status":"ok","service":"meridian"}`, with tests in `scripts/demo/tests/`. |
| Expected result | These files exist: `docs/tasks/T01-demo/plan.md`, `docs/tasks/T01-demo/review.md`, `docs/tests/T01-demo/test-cases.md`, `docs/tests/T01-demo/test-report.md`, `docs/tests/T01-demo/evidence/*`. There are commits prefixed `T01-demo:` on `task/T01-demo-hello-endpoint`. |

### TC-T01-07: Orchestration documented

| Field | Value |
|---|---|
| Linked criterion | AC6 |
| Steps | `grep -i "main session orchestrates" docs/process/WORKFLOW.md` and `grep -i "subagents cannot start other subagents" docs/process/WORKFLOW.md` |
| Expected result | Both match. |
