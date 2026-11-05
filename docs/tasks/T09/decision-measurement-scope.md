# T09: Solution-architect decision on the MG-1 measurement scope (DN-9)

| Field | Value |
|---|---|
| Task | T09 |
| Author | solution-architect |
| Date | 2026-11-04 |
| Answers | `docs/tasks/T09/plan.md` (Draft), "Decisions needed from solution-architect", DN-9; plan step 10 |
| Related | `docs/tasks/T03/decision-t03-design.md` D-2; technical-design "NFR numbers owned by T03"; NFR-04, NFR-05 (`solution-architecture.md`); `docs/TASKS.md` T10, T11, T30 |

## Question

D-2 puts measurement gate MG-1 at the end of T09, before T10 coding. MG-1 covers NFR-04
(ingest) and NFR-05 (50-row JSON:API page with 5,000 records). NFR-05 needs JSON:API and
authentication, which arrive in T11. What does T09 run?

## Decision

**T09 runs the NFR-04 part of MG-1. The 5,000-record seed and the NFR-05 measurement move to
T11.**

1. **T09 (definition of done, not an AC):** `mg1_ingest_timing.php` via `ddev drush php:script`
   on a throwaway install, as plan step 10 describes, with these fixed parameters:
   - Bundle: `decision` (the heaviest bundle), all referencing one Daily Run created first and
     not timed.
   - Payload size: each Decision carries `inputs_snapshot` and `raw_llm_output` sized so that
     500 items total about **4 MB** of JSON (the publisher batch cap in D4), so about 8 KB per
     Decision split across the two fields. This is the worst batch the publisher can send.
   - Create pass: 500 new Decisions. Update pass: the same 500 with a changed field and a new
     revision. Each pass runs in one transaction, with `validate()` on every entity and a
     violation count of 0 asserted.
   - 5 runs. Each run starts with no Decisions (the previous run's are deleted first, not
     timed). Xdebug off. Record the PHP version, the MariaDB version,
     whether pcov is loaded, and the host (WSL2, CPU, RAM).
   - Output: raw per-run timings for both passes, and the p95 (with 5 runs, p95 is the slowest
     run; state this).
2. **Record** the result with the date and raw output under "NFR numbers owned by T03" in
   `technical-design.md`, and as evidence in the T09 test report.
3. **Interpretation.** This is the entity-layer cost only. It excludes HTTP, OAuth, JSON
   decoding, hashing, reference resolution and the lock. Under D-2 it may move the provisional
   NFR-04 value either way. If create plus update p95 is above **15 s** (half the 30 s budget),
   the technical-architect raises it at T10 planning before T10 coding, because the real
   endpoint adds overhead on top. T10 confirms NFR-04 on the real endpoint (its AC3), as D-2
   already says.
4. **T11:** seeds 5,000 records and measures NFR-05 (50 requests, p95, warm) on DDEV. The D-2
   authority to set the final NFR-05 value in either direction from a recorded DDEV
   measurement moves with it. T11's AC5 already requires this measurement.

## Reasons

1. NFR-05 measures a JSON:API page. Before T11 there is no JSON:API, no read client and no cache
   tags, so a T09 number would measure a different thing (the reason used in T07 SA-6).
2. D-2's purpose is that "T10 starts with real numbers". T10 needs only NFR-04. Moving NFR-05
   does not delay T10.
3. Fixing the payload size makes the number meaningful. Empty JSON fields would understate the
   time for the largest batch the publisher actually sends.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| Full MG-1 in T09 (enable JSON:API temporarily) | Pulls T11 scope into T09; the number would not include T11's access and cache configuration |
| Skip MG-1 in T09, measure NFR-04 only in T10 | Loses the "before T10 coding" signal that D-2 asked for, which is cheap to get |
| Mixed-bundle batch | More realistic, but Decisions dominate size and cost; a Decision-only batch is the conservative bound |

## Consequences: spec changes

- **`technical-design.md`, NFR numbers, NFR-05 row** (technical-architect, plan step 11):
  replace "Measured at gate MG-1 with 5,000 seeded nodes, and confirmed in T11" with "Measured
  in T11 with 5,000 seeded nodes (D-2 authority moved to T11 by
  `docs/tasks/T09/decision-measurement-scope.md`); T30 confirms".
- **`technical-design.md`, NFR-04 DDEV row:** add "T09 runs the entity-layer part (500
  Decisions of about 8 KB, create and update, 5 runs); T10 confirms on the endpoint".
- **`solution-architecture.md`, NFR-05 row and Amendments table** (solution-architect, at T09
  close): change "provisional until the T09 measurement gate" to "provisional until the T11
  measurement (`docs/tasks/T09/decision-measurement-scope.md`)", and add one Amendments row
  (date, T09, NFR-05, pointer change, solution-architect). This is a pointer change under T03
  D-4 condition 1. No target changes, so no ADR is needed.
- `docs/TASKS.md`: no change. T11 AC5 already covers the measurement.

## Sources

- `docs/tasks/T03/decision-t03-design.md` D-2 and D-4, `docs/architecture/technical-design.md`
  ("NFR numbers owned by T03", D4 "Drain" item 5),
  `docs/architecture/solution-architecture.md` (NFR-04, NFR-05), `docs/TASKS.md` (T10, T11),
  `docs/tasks/T07/decision-scope.md` SA-6, read 2026-11-04

## Open questions

- None. The owner may want to know that NFR-05's final value is now set at T11, not T09.
