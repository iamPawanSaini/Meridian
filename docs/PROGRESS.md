# Progress board

Status of every task in `docs/TASKS.md`. Only the close step (`/close-task`) marks a task **Done**.

Statuses: Not started, Planned, In progress, In review, In test, Blocked, Done.

| Task | Title | Size | Phase | Depends on | Status | Branch | Notes |
|---|---|---|---|---|---|---|---|
| T00 | Repository scaffold and documentation skeleton | S | 0 Foundation | none | In test | `task/T00-scaffold` | Secret-scan demo pending (see `docs/tests/T00/test-report.md`) |
| T01 | Claude Code agents and workflow commands | M | 0 Foundation | T00 | In test | `task/T01-agents` | 6/7 pass (live guard probe passed; DEF-001 fixed); TC-T01-06 dry run `T01-demo` not yet run |
| T02 | Solution architecture | M | 1 Architecture and planning | T00, T01 | In test | `task/T02-solution-architecture` | Approved by technical-architect; 33/35 pass; blocked on owner secret scan (TC-T02-29) and GitHub render (TC-T02-32) |
| T03 | Technical design | M | 1 Architecture and planning | T02 | In test | `task/T03-technical-design` | Approved by solution-architect (Rev 3); 30/32 pass; DEF-002 fixed; blocked on owner Spectral lint (TC-T03-10), Mermaid render (TC-T03-32) |
| T04 | Master test plan and test infrastructure design | M | 1 Architecture and planning | T03 | Done (2026-11-01) | `task/T04-master-test-plan` | 32/32 pass, signed off; review approved; pre-commit/markdownlint SKIP (owner re-run for C4) |
| T04a | Coding standards and quality gates | M | 1 Architecture and planning | T04 | In test | `task/T04a-coding-standards` | Both reviews approved; DEF-004 fixed on `task/T04a-def004-baseline` (pre-commit --all-files and ddev quality exit 0); retest now passes TC-T04a-36/37/39/40/42-48/56; still blocked: TC-T04a-38, 41, 53, 54, 55 (owner env) and deferred cases; report not yet rewritten |
| T05 | DDEV Drupal project | M | 2 Local platform (DDEV and Docker) | T03 | In test | `task/T05-ddev-drupal` | Review approved; 38 pass, 0 fail, 2 blocked owner-run (TC-T05-39 runbook verbatim, TC-T05-40 Windows browser login); DEF-003, DEF-004, DEF-005 retest passed; not signed off until owner runs 39/40 |
| T06 | Extra Docker services in DDEV | M | 2 Local platform (DDEV and Docker) | T05 | Done (2026-11-02) | `task/T06-ddev-services` | AC6 partial: HTTPS route verified with placeholder; Next.js dev server re-run (TC-T06-42) owed by T21, owner-accepted. 51 pass, 0 fail; TC-T06-48, 49 owner-run, deferred (owner-accepted) |
| T07 | Pantheon dev environment and deployment path | M | 2 Local platform (DDEV and Docker) | T05 | Not started |  |  |
| T08 | Continuous integration baseline | M | 2 Local platform (DDEV and Docker) | T05, T06 | Not started |  |  |
| T09 | Content model as configuration | M | 3 Drupal backend | T03, T05 | Not started |  |  |
| T10 | Ingest API and authentication | L | 3 Drupal backend | T09 | Not started |  |  |
| T11 | Read API for the frontend | M | 3 Drupal backend | T09 | Not started |  |  |
| T12 | Admin UI and roles | M | 3 Drupal backend | T09 | Not started |  |  |
| T13 | Engine scaffold and port of MVP logic | M | 4 Python engine | T03, T06 | Not started |  |  |
| T14 | Storage layer on Postgres | M | 4 Python engine | T13 | Not started |  |  |
| T15 | Market data providers | M | 4 Python engine | T13 | Not started |  |  |
| T16 | Scoring and decision rules | M | 4 Python engine | T13 | Not started |  |  |
| T17 | LLM analyst review | M | 4 Python engine | T13 | Not started |  |  |
| T18 | Simulation engine | L | 4 Python engine | T14, T16 | Not started |  |  |
| T19 | Drupal publisher with outbox | L | 4 Python engine | T10, T14 | Not started |  |  |
| T20 | CLI and scheduled execution | M | 4 Python engine | T18, T19 | Not started |  |  |
| T21 | Next.js scaffold and Drupal client | M | 5 Next.js dashboard | T06, T08 | Not started |  | Owes T06 AC6b re-run (TC-T06-42) before close |
| T21a | Design tokens and theme | M | 5 Next.js dashboard | T21 | Not started |  |  |
| T22 | Authentication and route protection | M | 5 Next.js dashboard | T11, T21 | Not started |  |  |
| T23 | Overview page | M | 5 Next.js dashboard | T22 | Not started |  |  |
| T24 | Decisions explorer | M | 5 Next.js dashboard | T22 | Not started |  |  |
| T25 | Positions and reports pages | M | 5 Next.js dashboard | T22 | Not started |  |  |
| T26 | Frontend hardening | M | 5 Next.js dashboard | T23, T24, T25 | Not started |  |  |
| T27 | Local end-to-end integration | L | 6 Integration and deployment | T12, T20, T26 | Not started |  |  |
| T28 | Dev environment deployment | L | 6 Integration and deployment | T07, T27 | Not started |  |  |
| T29 | Observability and operations | M | 6 Integration and deployment | T28 | Not started |  |  |
| T30 | Security and non-functional verification | L | 7 Verification | T28 | Not started |  |  |
| T31 | Live simulation validation, 10 to 15 trading days | L | 7 Verification | T28, T29 | Not started |  |  |
| T32 | Documentation finalisation | M | 8 Release and handover | T31 | Not started |  |  |
| T33 | Go/no-go review and next-phase backlog | S | 8 Release and handover | T32 | Not started |  |  |
