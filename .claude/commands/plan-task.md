---
description: Loop step 1. technical-architect writes docs/tasks/<task>/plan.md
argument-hint: <task-id, e.g. T05>
---

Run step 1 (Plan) of the per-task loop for **$ARGUMENTS**. See `docs/process/WORKFLOW.md`.

1. Find $ARGUMENTS in `docs/TASKS.md` and check its "Depends on" tasks in
   `docs/PROGRESS.md`. If a dependency is not Done, tell the user and ask whether to go on.
2. Delegate to the `technical-architect` subagent with the Agent tool. In the prompt,
   include the task ID, the full task text from `docs/TASKS.md`, and the paths of related
   docs. Ask it to write `docs/tasks/$ARGUMENTS/plan.md` from `docs/templates/plan.md`.
3. If the plan lists "Decisions needed from solution-architect", delegate each question to
   the `solution-architect` subagent. Save its answer as
   `docs/tasks/$ARGUMENTS/decision-<topic>.md`. Then send the answers back to the
   `technical-architect` (continue it with SendMessage) to finish the plan.
4. Show the user a short summary of the plan and ask them to approve it. When they
   approve, set the plan's Status to Approved, and set $ARGUMENTS to "Planned" in
   `docs/PROGRESS.md`.

Do not start implementation in this command.
