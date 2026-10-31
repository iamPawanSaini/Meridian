---
description: Loop step 3. developer implements the approved plan on task/<task>-slug
argument-hint: <task-id>
---

Run step 3 (Build) of the per-task loop for **$ARGUMENTS**. See `docs/process/WORKFLOW.md`.

1. Gate: `docs/tasks/$ARGUMENTS/plan.md` has Status: Approved, and
   `docs/tests/$ARGUMENTS/test-cases.md` exists. If not, stop and name the missing step.
2. Choose the branch name `task/$ARGUMENTS-<slug>`, with the slug from the task title in
   kebab-case. Choose the base branch: the user's choice, or the branch of the task it
   depends on.
3. Delegate to the `developer` subagent with the Agent tool. Give it the task ID, the
   branch and base, the plan path and the test-cases path. Remind it of the commit prefix
   `$ARGUMENTS:`.
4. When it returns, show the user the commits (`git log --oneline <base>..HEAD`) and any
   deviations it reported. Set $ARGUMENTS to "In review" in `docs/PROGRESS.md`.
