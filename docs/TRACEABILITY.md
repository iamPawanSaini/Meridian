# Traceability matrix

Requirement to task to test case to evidence. Requirements are the seeds in `docs/TASKS.md`
section 2. T02 refines them and adds priority and measurable targets. T03 adds design
elements, T04 adds the planned test cases, and every task close updates its rows.

Tasks come from each task's **Covers** line in `docs/TASKS.md`. Refined IDs (`FR-nn`,
`NFR-nn`) are defined, with priority, target and verifying task, in
`docs/architecture/solution-architecture.md` (section "Requirements"). They are stable and
never renumbered.

| Req | Requirement | Refined IDs (T02) | Tasks | Design element (T03) | Test cases | Evidence | Status |
|---|---|---|---|---|---|---|---|
| R-01 | Analyse a configurable NSE watchlist once per trading day | FR-01, FR-02, NFR-19 | T02, T10, T12, T13, T15, T31 | |  |  | Open |
| R-02 | Long-term (fundamental) and short-term (technical) scoring modes | FR-03, FR-04 | T02, T13, T16, T31 | |  |  | Open |
| R-03 | LLM analyst review that can veto a buy; failure counts as veto | FR-05, FR-06, FR-07, NFR-08 | T02, T17, T29, T30, T31 | |  |  | Open |
| R-04 | Risk-based position sizing, stop, target, time-stop, transaction costs | FR-08, FR-09, FR-10 | T02, T03, T16, T18, T25, T31 | |  |  | Open |
| R-05 | Simulation only: no live order capability | FR-11 | T02, T18, T30, T31, T33 | |  |  | Open |
| R-06 | Every input, output and decision is stored and reproducible | FR-12, FR-13, FR-14, NFR-04, NFR-16 | T02, T03, T09, T10, T14, T17, T19, T20, T24, T27, T29, T30, T31 | |  |  | Open |
| R-07 | Drupal admin can browse, filter and export records, with roles | FR-15, FR-16 | T02, T09, T12, T19 | |  |  | Open |
| R-08 | Next.js dashboard: overview, decisions, positions, reports | FR-17, FR-18, FR-30, NFR-03, NFR-05, NFR-12, NFR-13 | T02, T11, T12, T21, T21a, T22, T23, T24, T25, T26, T27, T30 | |  |  | Open |
| R-09 | All dashboard and API access is authenticated and least-privilege | FR-19, FR-20, FR-21, NFR-10, NFR-11 | T02, T03, T10, T11, T22, T26, T30 | |  |  | Open |
| R-10 | Scheduled daily run, NSE holiday safe, idempotent, alerts on failure | FR-22, FR-23, FR-24, FR-25, NFR-01, NFR-02, NFR-06, NFR-14, NFR-15 | T02, T10, T14, T15, T19, T20, T27, T28, T29, T30, T31 | |  |  | Open |
| R-11 | Whole stack reproducible locally with DDEV and Docker from a clean clone | FR-26, FR-27, NFR-09, NFR-17 | T02, T05, T06, T07, T27, T28, T32 | |  |  | Open |
| R-12 | Every task tested and documented inside the project folder | FR-28, FR-29, NFR-07, NFR-18 | T00, T01, T02, T04, T04a, T08, T16, T32, T33 | | TC-T00-01 to TC-T00-08, TC-T01-01 to TC-T01-07 | `docs/tests/T00/test-report.md`, `docs/tests/T01/test-report.md` | Open |
