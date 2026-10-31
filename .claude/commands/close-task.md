---
description: Loop step 6. verify the gates and close the task (PROGRESS, TRACEABILITY, docs)
argument-hint: <task-id>
---

Run step 6 (Close) of the per-task loop for **$ARGUMENTS**. The main session does this
step itself. See `docs/process/WORKFLOW.md`.

1. Check every gate and list any that fail:
   - The plan is Approved (C1).
   - The review verdict is Approved, with every finding Fixed or Ticketed (C2).
   - The test report is signed off, every criterion has an executed case with evidence,
     and no case is Fail or Blocked (C3).
   - CI is green (C4). Mark this n/a before T08.
   - The docs, README and runbooks are updated (C5).
   - No secrets, and `.env.example` is current (C6).
   - The task works from a clean checkout (C7).
2. If any gate fails, stop. Tell the user what is missing and which command fixes it.
3. If all gates pass:
   - Update `docs/TRACEABILITY.md`: add test case IDs and evidence links to each
     requirement in the task's "Covers" line.
   - Set $ARGUMENTS to **Done** in `docs/PROGRESS.md`, with the date.
   - Commit on the task branch with the message `$ARGUMENTS: close task`.
4. Ask the user before you merge or push. Never push without explicit approval.
