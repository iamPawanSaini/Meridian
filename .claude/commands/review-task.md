---
description: Loop step 4. technical-architect reviews the diff and writes docs/tasks/<task>/review.md
argument-hint: <task-id>
---

Run step 4 (Review) of the per-task loop for **$ARGUMENTS**. See `docs/process/WORKFLOW.md`.

1. Find the task branch `task/$ARGUMENTS-*` and its base. Get the commit range.
2. Delegate to the `technical-architect` subagent with the Agent tool, in **review mode**.
   Give it the commit range, the plan path and the test-cases path. Ask it to write
   `docs/tasks/$ARGUMENTS/review.md` from `docs/templates/review.md`.
3. If the verdict is "Changes requested", send the findings to the `developer` subagent to
   fix on the same branch. Then run the review again. Repeat until it is Approved, or a
   finding is ticketed with a reason the user accepts.
4. Report the verdict and the findings table to the user. Set $ARGUMENTS to "In test" in
   `docs/PROGRESS.md`.
