# T04: Master test plan and test infrastructure design, Plan

| Field | Value |
|---|---|
| Task | T04 |
| Author | technical-architect |
| Date | 2026-11-01 |
| Branch | `task/T04-master-test-plan` |
| Status | Approved |

Approved by main session on owner's instruction, 2026-11-01.

## Goal

Define how Meridian is tested, from T05 to T33, in one master test plan: levels, tools,
environments, entry and exit criteria, regression suite, test data, defect workflow and planned
coverage of every refined requirement. This is a docs task. The **tester is the author** ("build"
means writing the docs). The technical-architect reviews. It also turns the Phase 0 to 1 test habits
into written rules.

## Scope

- `docs/tests/master-test-plan.md` with these sections:
  1. Test levels. For each of unit, integration, contract, end-to-end, security, performance, data
     reconciliation and manual simulation, give the purpose, the owning tasks and the pass rule.
  2. Tools per component. Engine: pytest, pytest-cov and an HTTP mock. Drupal: PHPUnit Unit, Kernel
     and Functional. Next.js: Vitest, Playwright and axe (`@axe-core/playwright`). Contract: the
     chosen OpenAPI tool (Decision 2). Security: gitleaks, the dependency audits (pip-audit,
     `composer audit`, `npm audit`), an image scan (NFR-11) and the static broker check (FR-11).
     Performance: Decision 3. The plan names each tool and its purpose only. Versions are pinned in
     T04a.
  3. Test layout per component, as a convention for later tasks. Engine:
     `services/engine/tests/{unit,integration,contract}` and `tests/fixtures`. Drupal:
     `meridian_*/tests/src/{Unit,Kernel,Functional}`. Next.js: unit tests next to the source plus
     `apps/web/e2e`. Docs tasks: `docs/tests/Txx/run-checks.sh`.
  4. Environments: the agent sandbox (no network), DDEV, CI (GitHub Actions, no live market data or
     LLM), deployed dev (Pantheon, Vercel). Show which levels run where.
  5. Entry and exit criteria per task and per milestone. Exit needs all cases Pass, or Blocked with
     a recorded owner acceptance, and no open Critical or High defect.
  6. The defect severity scale. It is the single source; `defects.md` links to it.
  7. The regression suite and its CI jobs. Define a PR set (unit, Kernel, Vitest, contract against
     fixtures, static broker check, docs checks) and a heavier set (Functional, Playwright,
     `ddev e2e`) with its trigger. T08 implements them.
  8. Test data strategy, by kind:
     - Fixtures: owner, location and refresh rule.
     - Recorded market data: committed JSON or CSV for named dates, including an NSE holiday and a
       no-new-candle date (FR-23).
     - Fake LLM responses: one per failure type (FR-06), plus the prompt-injection set (FR-07).
     - Seeded Drupal content: the 5,000-record set for NFR-03/05 and T11, T25, T26.
     - The golden parity file (T13).
     - Rules that apply to all kinds: no real secrets, no live network in CI, data is deterministic.
  9. Reconciliation method and tolerances: FR-14 requires 0 differences, FR-18 allows ₹0.01 and 0.01
     pp. Name the hops (Postgres, Drupal, UI) for T27 and T31.
  10. Conventions (codified from T00 to T03):
      - Statuses are Pass, Fail, Blocked and Not run. Blocked means the precondition or tool is
        missing, not a product fault. A Blocked case keeps its criterion open.
      - Owner-run cases: the exact command, its expected output and the evidence path. The tool
        version is captured in the evidence.
      - Main-session-executed cases when an agent lacks a tool or a restart is needed. "Executed by"
        names who ran it.
      - Evidence naming: `evidence/TC-Txx-nn.txt`, `run-checks.txt` and `-static` or `-spotcheck` suffixes.
      - `run-checks.sh` style: no vacuous pass, a non-zero exit on failure, `SKIP` only for optional
        tools, which the report must list.
      - A script-defect "Change log" in `test-cases.md`. A check may never be loosened to hide a
        content gap.
      - Live-API cases, such as the T17 real-LLM smoke test, are manual, clearly marked and never in
        CI.
- `docs/TRACEABILITY.md`: add a second table, "Planned tests", with one row per FR and NFR (FR-01 to
  FR-30, NFR-01 to NFR-19). Its columns are ID, parent R, verifying task (from
  `solution-architecture.md`), level(s), planned test, planned case ID or pattern and status. Each R
  row's "Test cases" cell links to its FR and NFR rows. Existing columns stay unchanged.
- `docs/tests/defects.md` and `docs/templates/defect.md`:
  - Workflow states: Open, Triaged, In progress, Fixed, Retest passed, Closed, Reopened, Won't fix.
  - Who moves each state.
  - Triage SLA by severity.
  - Rules: retest by the tester with evidence, and Won't fix for Critical or High only with a
    solution-architect decision.
  - How defects differ from review findings (Blocker to Note).
- `docs/tests/README.md`: the row for the master plan points to the new file.

## Non-goals

- Tool configuration, versions, coverage thresholds and `ddev quality`, which belong to T04a (NFR-18
  is cited only).
- CI workflow files (T08), test code and fixtures themselves (each owning task).
- Hand-calculated scenarios (T18) and the rule thresholds (T16).
- Changing any FR or NFR target. Gaps go under "Decisions needed".

## Steps

1. **Test design first** (`/design-tests T04`, tester). Write `docs/tests/T04/test-cases.md` and
   `run-checks.sh` (plus a Python helper if needed) and commit them with `T04:` **before** any
   authoring. The script must fail today on every check that depends on content. It covers the test
   hooks below.
2. **Author master plan sections 1 to 6** (tester), then **sections 7 to 10**.
3. **TRACEABILITY planned-tests table**, 49 rows, built from the requirements tables in `solution-architecture.md`.
4. **Defect workflow** in `defects.md` and the template. Keep the severity table, or link it to the
   master plan, with identical levels.
5. **Self-run** `run-checks.sh` and record the output. The author may fix a script defect only
   through a Change log entry that does not loosen any check.
6. **Review** (technical-architect, `/review-task T04`). Check the content against later-task
   criteria (T08 to T31), not only the structure.
7. **Test execution** by a separate tester invocation or the main session, not in the authoring
   context. The report states who executed it.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| `docs/tests/master-test-plan.md` | New | Every `/design-tests` from T04a on; T08 CI jobs |
| `docs/TRACEABILITY.md` | New planned-tests table | `/close-task`, T32 zero-gap check |
| `docs/tests/defects.md`, `docs/templates/defect.md` | Workflow states, triage, retest | All tasks |
| Test layout conventions | New | T09 to T27 developers, T04a coverage config |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The author marks their own homework | High | Medium | The script is committed before authoring (git order checked); review by TA; execution outside the authoring context |
| Planned tests drift from the FR/NFR verifying task | Medium | Medium | The script cross-checks every row's task against `solution-architecture.md` |
| The plan overreaches into T04a or T08 | Medium | Low | Non-goals; review flags versions, thresholds or YAML |
| A tool choice turns out unusable later (no network, DDEV limits) | Medium | Medium | The choice is marked "confirm in T04a or T08" with a fallback named |
| T03 is not closed yet (no close commit) | Medium | Low | T04 reads T03 files on this branch; any T03 change after review is re-checked in the T04 review |

## Test hooks needed

The `run-checks.sh` script checks the following:

- The master plan exists and has headings for the 8 levels, tools, layout, environments, entry and
  exit criteria, severity, regression, test data and conventions.
- The named tools appear: pytest, PHPUnit, Vitest, Playwright, axe and the contract tool.
- The 4 data kinds are present, and `ci.yml` is named in the regression section.
- The severity levels are identical in `master-test-plan.md` and `defects.md`. Every workflow state
  appears in both `defects.md` and the template's Status line.
- The set of FR and NFR IDs in `solution-architecture.md` equals the set of planned-test rows. No
  cell is empty. The verifying task is the same in both. The level matches the controlled
  vocabulary.
- Existing TRACEABILITY columns are unchanged, and the T00/T01 cells are preserved.
- `scripts/check-names.sh` passes, and there are no broker domains or SDK names except in the FR-11
  check description.
- The git order check: `run-checks.sh` was committed before `master-test-plan.md`.
- A manual review case: a sample of 10 planned tests is checked against the matching later-task criteria.

## Decisions needed from solution-architect

1. **Traceability granularity.** The plan uses planned tests at FR/NFR level (49 rows) in a second
   table, with the R rows linking to them. The alternative is R-level only. Confirm FR/NFR level.
2. **Contract test tool.** The recommendation is Schemathesis (Python) against DDEV for T10 and T11,
   plus `openapi-core` response validation in engine publisher tests. The alternative is Dredd or
   Prism. Also: the read endpoints (decisions, positions, runs, `/me`) are not in `openapi.yaml`
   yet. Should T11 extend it so the T11 contract tests have a source?
3. **Performance tooling.** The recommendation is a small Python timing harness (p95 over 5 runs, as
   the NFR-04/05 targets are written) and Lighthouse CI or Playwright web-vitals for LCP (NFR-03).
   The alternative is k6 or Locust.
4. **Recorded market data and network blocking.** The recommendation is committed JSON/CSV fixtures
   with `respx` or `responses` mocks and a socket block in CI (pytest-socket). The alternative is
   VCR cassettes (vcrpy). Choose one.
5. **Docs-task scripts in regression.** Should the `docs/tests/T00..T04/run-checks.sh` scripts join
   the CI PR suite (T08)? They are snapshot checks, so some may need a "regression-safe" subset
   flag. The recommendation is yes, with the subset.
6. **Blocked at close.** Can a task close with a Blocked case if the owner accepts it in writing
   (the T00 to T02 precedent), or must every case Pass before Done?

## Definition of done

- [ ] All task acceptance criteria in `docs/TASKS.md` met
- [ ] C1: Plan exists and was reviewed before coding started
- [ ] C2: Code reviewed; findings resolved
- [ ] C3: Every criterion maps to an executed test case with evidence
- [ ] C4: CI green, no new lint, type or security warnings
- [ ] C5: Docs and traceability updated
- [ ] C6: No secrets; `.env.example` updated
- [ ] C7: Works from a clean checkout with documented commands
