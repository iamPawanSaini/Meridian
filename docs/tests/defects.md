# Defect log

Use `docs/templates/defect.md` for each entry. The test levels, the exit criteria and the
severity scale are defined in [`master-test-plan.md`](master-test-plan.md), which is the single
source of the severity meanings. The table in "Triage SLA" repeats those meanings unchanged next
to the triage times. If the two ever differ, the master plan wins.

## Workflow

A failed test case (Fail) creates a defect. A Blocked case does not: Blocked means a tool or an
environment is missing, not that the product is wrong.

States, in order: Open, Triaged, In progress, Fixed, Retest passed, Closed, Reopened, Won't fix.

| State | Moved by | Meaning and next step |
|---|---|---|
| Open | tester | Raised with steps to reproduce, severity and the failing case ID. Goes to Triaged. |
| Triaged | technical-architect | Severity confirmed and an owner chosen. Goes to In progress, or to Won't fix. |
| In progress | developer | Fix being written on the task branch. Goes to Fixed. |
| Fixed | developer | Fix committed; the fix commit is recorded. Goes to Retest passed or Reopened. |
| Retest passed | tester | The tester re-ran the failing case and its neighbours, and stored evidence. Goes to Closed. |
| Closed | main session | Retest evidence is on file and the report is updated. Terminal. |
| Reopened | tester | The retest failed or the defect returned. Goes back to In progress. |
| Won't fix | technical-architect | Accepted without a fix, with a written reason. Critical or High needs a solution-architect decision. Terminal. |

## Rules

- Retest is done by the tester, with evidence stored (output, log or screenshot) and referenced
  in the defect. A developer's own check is not a retest.
- A defect is set to the Closed state only after Retest passed. The main session sets Status to
  Closed at `/close-task` of the task that found the defect. The "Closed" section of this file
  holds entries in Retest passed, Closed or Won't fix; DEF-001 and DEF-002 stay at Retest passed
  until their tasks close.
- Won't fix for a Critical or High defect needs a solution-architect decision, recorded in the
  defect. The technical-architect may decide Medium and Low.
- A Critical or High defect that is open blocks task close and the milestone gate (see "Exit
  criteria" in the master plan).
- A fix is verified against the original steps to reproduce. A regression case is added to the
  task cases when the defect was not already covered.
- Do not edit a script or a check to make a defect disappear. Script defects are logged in the
  Change log of the task's `test-cases.md` (see "Conventions" in the master plan).

## Triage SLA

Time counts working days from the day the defect is Open until it is Triaged. The fix target
counts from Triaged until Fixed. The meanings are those of the master plan.

| Severity | Meaning | Triage within | Fix target |
|---|---|---|---|
| Critical | Data loss, security breach, wrong financial result, or any live-order capability | 4 working hours | 1 working day |
| High | Core function broken with no workaround | 1 working day | 3 working days |
| Medium | Function impaired, workaround exists | 2 working days | before task close, or ticketed in a named later task with technical-architect agreement |
| Low | Cosmetic or documentation issue | 5 working days | before task close or ticketed |

## Defects and review findings

A defect comes from a test: a Fail in a test report. A review finding comes from the
technical-architect's review of a diff in `docs/tasks/Txx/review.md`, with the scale Blocker,
Major, Minor and Note. Review findings are resolved in the same task and are not logged here.
If a review finding is later shown to fail a test case, or is found after review, it becomes a
defect. Blocker and Major findings must be resolved before the test report is signed off; Minor
and Note findings may be ticketed.

## Open

(none)

## Closed

### DEF-001: Path guard misparses quoted shell operators

| Field | Value |
|---|---|
| ID | DEF-001 |
| Severity | Medium |
| Found in | T01 (found in use during T02 planning by technical-architect) |
| Status | Retest passed |
| Fix commit | see `git log --grep DEF-001` |
| Retest result | 30/30 guard unit tests pass, incl. new `QuotedShellParsing` class |

**Steps to reproduce**

1. As `technical-architect`, run `grep -rnE "a|b" docs`

**Expected:** allowed (read-only command with a quoted pattern).

**Actual:** blocked with "could not parse shell command safely (No closing quotation)"; the
guard split on `|` before honouring quotes. Quoted `>` (for example `awk '$1 > 5'`) was also
treated as a redirect (T01 review finding 2).

**Fix:** `guard_paths.py` now tokenises with `shlex` (`punctuation_chars`) so quoted text stays
inside one word; operators and redirect targets come from the token stream.

### DEF-002: `uq_runs_date_attempt` collides for a second `publish` or `replay` row on the same date

| Field | Value |
|---|---|
| ID | DEF-002 |
| Severity | Medium |
| Found in | T03, TC-T03-24 (manual Postgres schema review) |
| Status | Retest passed |
| Fix commit | T03 commit (pending, main session) |
| Retest result | 2026-11-01: TC-T03-24 re-run Pass. `evidence/DEF-002-retest.txt` (12/12): repeated publish and replay rows with attempt 0 on one date now insert; duplicate attempt greater than 0 for a date and a second running row are still rejected; `ck_runs_attempt` still enforced. `run-checks.sh` and `check_data_model.py` all PASS. |

**Steps to reproduce**

1. Read `docs/specs/data-model.md`, table `runs`: `attempt` is "always 0" for `publish` and `replay`
   (`ck_runs_attempt`), and `uq_runs_date_attempt` is a plain unique constraint on (`trade_date`,
   `attempt`). Design D2 repeats this ("`publish` and `replay` rows use `attempt = 0`").
2. Model the constraint: `python3 -I` sqlite demo in `docs/tests/T03/evidence/DEF-002-demo.txt`
   (insert two rows with the same `trade_date`, `attempt = 0`).

**Expected:** any number of `publish` and `replay` runs can be recorded for one trade date (NFR-15
expects a manual `publish` dispatch after an outage, and a delayed cron or repeated dispatch can
repeat it), and none of them can fail on a unique violation.

**Actual:** the second `publish` or `replay` row for the same `trade_date` violates
`uq_runs_date_attempt`, so the run cannot even record itself (T14 Alembic baseline and T19/T20 would
hit it).

**Suggested fix (for the author, not applied by the tester):** make the unique rule partial,
`UNIQUE (trade_date, attempt) WHERE attempt > 0` (or give `publish`/`replay` a distinct key), and
update `data-model.md` runs and design D2 accordingly.
