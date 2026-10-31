---
description: Loop step 5. tester executes all cases and writes docs/tests/<task>/test-report.md with evidence
argument-hint: <task-id>
---

Run step 5 (Test) of the per-task loop for **$ARGUMENTS**. See `docs/process/WORKFLOW.md`.

1. Gate: `docs/tasks/$ARGUMENTS/review.md` has an Approved verdict (with or without
   conditions). Check out the task branch.
2. Delegate to the `tester` subagent with the Agent tool, in **execute mode**. Ask it to
   run every case in `docs/tests/$ARGUMENTS/test-cases.md` and to store raw output under
   `docs/tests/$ARGUMENTS/evidence/`. It writes `docs/tests/$ARGUMENTS/test-report.md`
   and logs failures in `docs/tests/defects.md`.
3. If defects are raised, send them to the `developer` subagent, then `/review-task` the
   fix and run this step again for the affected cases.
4. Report the summary table to the user. Do not mark the task done here.
