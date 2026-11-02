# .claude

Claude Code configuration for Meridian. The project is built through the per-task loop
in `docs/process/WORKFLOW.md`.

| Path | Purpose |
|---|---|
| `agents/` | Subagent definitions: `solution-architect`, `technical-architect`, `developer`, `tester` (T01) |
| `commands/` | Slash commands, one per loop step: `/plan-task`, `/design-tests`, `/implement-task`, `/review-task`, `/test-task`, `/close-task` (T01) |
| `hooks/` | Hook scripts, for example the path guard that limits where each agent may write (T01) |
| `settings.json` | Shared project settings, committed. `settings.local.json` is per-user and git-ignored. |
