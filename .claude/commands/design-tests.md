---
description: Loop step 2. tester writes docs/tests/<task>/test-cases.md before development
argument-hint: <task-id>
---

Run step 2 (Test design) of the per-task loop for **$ARGUMENTS**. See
`docs/process/WORKFLOW.md`.

1. Confirm that `docs/tasks/$ARGUMENTS/plan.md` exists and has Status: Approved.
   Otherwise stop and suggest `/plan-task $ARGUMENTS`.
2. Delegate to the `tester` subagent with the Agent tool, in **design mode**. Give it the
   acceptance criteria for `$ARGUMENTS` from `docs/TASKS.md`, the common criteria (section
   3.3) and the plan path. Ask it to write `docs/tests/$ARGUMENTS/test-cases.md` from
   `docs/templates/test-cases.md`. Each case needs an ID `TC-$ARGUMENTS-nn`, a linked
   criterion, exact commands, and a criterion coverage table.
3. Check the result yourself: every task-specific criterion must map to at least one case.
   If a criterion is missing, send the gap back to the tester.
4. Report the case count and the coverage table to the user.
