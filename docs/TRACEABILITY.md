# Traceability matrix

Requirement to task to test case to evidence. Requirements are the seeds in `docs/TASKS.md`
section 2. T02 refines them and adds priority and measurable targets. T03 adds design
elements, T04 adds the planned test cases, and every task close updates its rows.

Tasks come from each task's **Covers** line in `docs/TASKS.md`.

| Req | Requirement | Tasks | Design element (T03) | Test cases | Evidence | Status |
|---|---|---|---|---|---|---|
| R-01 | Analyse a configurable NSE watchlist once per trading day | T02, T13, T15, T31 | |  |  | Open |
| R-02 | Long-term (fundamental) and short-term (technical) scoring modes | T02, T13, T16, T31 | |  |  | Open |
| R-03 | LLM analyst review that can veto a buy; failure counts as veto | T02, T17, T31 | |  |  | Open |
| R-04 | Risk-based position sizing, stop, target, time-stop, transaction costs | T02, T03, T16, T18, T25, T31 | |  |  | Open |
| R-05 | Simulation only: no live order capability | T02, T18, T30, T31, T33 | |  |  | Open |
| R-06 | Every input, output and decision is stored and reproducible | T02, T03, T09, T10, T14, T19, T24, T27, T31 | |  |  | Open |
| R-07 | Drupal admin can browse, filter and export records, with roles | T02, T09, T12, T19 | |  |  | Open |
| R-08 | Next.js dashboard: overview, decisions, positions, reports | T02, T11, T21, T21a, T23, T24, T25, T26, T27 | |  |  | Open |
| R-09 | All dashboard and API access is authenticated and least-privilege | T02, T03, T10, T11, T22, T26, T30 | |  |  | Open |
| R-10 | Scheduled daily run, NSE holiday safe, idempotent, alerts on failure | T02, T10, T14, T15, T19, T20, T28, T29, T31 | |  |  | Open |
| R-11 | Whole stack reproducible locally with DDEV and Docker from a clean clone | T02, T05, T06, T07, T27, T28, T32 | |  |  | Open |
| R-12 | Every task tested and documented inside the project folder | T00, T01, T02, T04, T04a, T08, T32, T33 | | TC-T00-01 to TC-T00-08 | `docs/tests/T00/test-report.md` | Open |
