# Meridian: Trading Research Agent, Project Task Plan

Simulation-only NSE (India) research agent. Python engine produces decisions daily, Drupal (Pantheon dev) stores and manages them, Next.js (Vercel dev) is the dashboard. Built with Claude Code subagents, DDEV and Docker.

> Scope guard: this project **never places real orders**. No broker SDK is allowed in the codebase until a separately approved phase (see T33).

---

## 0. Naming conventions

Project name: **Meridian** (decided). Use these names everywhere so tooling stays consistent.

| Item | Name |
|---|---|
| Repository and root folder | `meridian` |
| DDEV project | `meridian` (local URL `https://meridian.ddev.site`) |
| Python package / engine service | `meridian_engine` (`services/engine`) |
| Drupal site name / custom modules | "Meridian" / `meridian_ingest`, `meridian_core` |
| Next.js app | `meridian-web` (`apps/web`) |
| Docker services | `meridian-postgres`, `meridian-engine`, `meridian-web` |
| GitHub Actions workflows | `daily-run.yml`, `ci.yml`, `deploy-drupal.yml` (display names prefixed "Meridian") |

Name risk: "Meridian" is a common word. A single search found no clear conflicting product in the Indian AI stock-research niche, but that does not clear domain, trademark or app-store availability. Branding checks are tracked in T02. Until cleared, treat "Meridian" as the internal project name only.

## 0b. Theme and design tokens

Palette supplied by the project owner (hex values read from the supplied image; confirm them in T21a, especially Storm cloud, whose last digits were hard to read).

| Name | Hex | Role |
|---|---|---|
| Cloud white | `#FEFCF6` | Page background (light) |
| Fresh cream | `#F4EFE6` | Cards, surfaces, table stripes (light); text on dark and on Forest green |
| Sky blue | `#D6E0E2` | Info panels, selected rows, subtle highlights; accent text on Midnight |
| Forest green | `#5E6C58` | Primary actions, links (light), brand accent |
| Storm cloud | `#686867` | Secondary text, borders, disabled states |
| Midnight | `#162A2C` | Primary text (light); page background (dark) |

Measured WCAG contrast ratios (AA needs 4.5:1 for normal text, 3:1 for large text and UI components):

| Pairing | Ratio | Verdict |
|---|---|---|
| Midnight on Cloud white / Cream / Sky blue | 14.6 / 13.1 / 11.1 | Pass, use for body text |
| Forest green on Cloud white / Cream | 5.4 / 4.9 | Pass |
| Forest green on Sky blue | 4.2 | Fails for normal text; large text and icons only |
| Storm cloud on Cloud white / Cream | 5.4 / 4.9 | Pass for secondary text |
| Storm cloud on Sky blue | 4.2 | Fails for normal text |
| Cream or Cloud white on Forest green | 4.9 / 5.4 | Pass, use for button labels |
| Cream / Cloud white / Sky blue on Midnight | 13.1 / 14.6 / 11.1 | Pass, dark-mode text |
| Forest green or Storm cloud on Midnight | 2.7 | Fail: never use as text or icons on Midnight; fills only |

Gaps the palette does not cover (defined in T21a, derived to harmonise with the palette and contrast-tested): gain, loss, warning and error colors for a trading dashboard (palette has no red or amber; never rely on color alone, always add sign, icon or label), a slightly lighter Midnight tint for dark-mode surfaces, border and focus-ring colors, and a chart series palette that stays distinguishable for color-blind users (use line styles and direct labels in addition to color).

Typography and icons (decided):
- **Font:** Fira Sans, self-hosted from files in the repo. No Google Fonts link, no CDN. Use tabular figures for numeric columns and confirm the rupee sign `₹` renders.
- **Icons:** SVG only, using `currentColor` so they follow the theme. No icon fonts or hosted icon kits.
- **Raster images:** WebP only. Favicon is SVG. Any unavoidable exception (for example an Apple touch icon needs PNG) is recorded in an ADR.
- **Rule:** nothing in the app loads fonts, styles, scripts or icons from a third-party host.

## 1. Architecture summary

| Component | Tech | Dev hosting | Local (DDEV/Docker) |
|---|---|---|---|
| Engine (fetch, score, LLM review, simulate, publish) | Python 3.12 | GitHub Actions (cron) | `meridian-engine` container |
| Records DB (engine state) | Postgres 16 | Free hosted Postgres (verify limits) | `meridian-postgres` container |
| Content backend and admin | Drupal 11 (headless) | Pantheon sandbox | DDEV `web` + `db` |
| Dashboard | Next.js (App Router, TypeScript) + `next-drupal` | Vercel Hobby (non-commercial) | `meridian-web` container (node) |
| LLM | Claude API | n/a | n/a |

Data flow: GitHub Actions cron → engine → Postgres (system of record) → publisher → Drupal ingest API → Next.js reads Drupal JSON:API → user.

## 2. Seed requirements (refine in T02)

| ID | Requirement |
|---|---|
| R-01 | Analyse a configurable NSE watchlist once per trading day |
| R-02 | Long-term (fundamental) and short-term (technical) scoring modes |
| R-03 | LLM analyst review that can veto a buy; failure counts as veto |
| R-04 | Risk-based position sizing, stop, target, time-stop, transaction costs |
| R-05 | Simulation only: no live order capability |
| R-06 | Every input, output and decision is stored and reproducible |
| R-07 | Drupal admin can browse, filter and export records, with roles |
| R-08 | Next.js dashboard: overview, decisions, positions, reports |
| R-09 | All dashboard and API access is authenticated and least-privilege |
| R-10 | Scheduled daily run, NSE holiday safe, idempotent, alerts on failure |
| R-11 | Whole stack reproducible locally with DDEV and Docker from a clean clone |
| R-12 | Every task tested and documented inside the project folder |

## 3. Working method (applies to every task)

### 3.1 Agents (details in Appendix A)

| Agent | Role |
|---|---|
| `solution-architect` | Owns requirements, architecture, ADRs, domain and technical knowledge. Answers "should we and why". |
| `technical-architect` | Breaks tasks into a plan, defines interfaces, reviews all developer code. Answers "how and is it right". |
| `developer` | Implements code and unit tests for one task at a time. |
| `tester` | Writes test cases from acceptance criteria, executes them, records evidence, files defects. Does not edit production code. |

Claude Code subagents generally cannot delegate to each other, so the **main Claude session orchestrates** the loop below via slash commands.

### 3.2 Per-task loop

1. **Plan:** `technical-architect` writes `docs/tasks/Txx/plan.md` (steps, interfaces, risks), consulting `solution-architect` when a decision is needed.
2. **Test design:** `tester` writes `docs/tests/Txx/test-cases.md` (IDs `TC-Txx-nn`), each mapped to an acceptance criterion, before development starts.
3. **Build:** `developer` implements on branch `task/Txx-slug`.
4. **Review:** `technical-architect` reviews the diff, writes `docs/tasks/Txx/review.md`; all findings resolved or ticketed.
5. **Test:** `tester` executes all cases, writes `docs/tests/Txx/test-report.md` with evidence (command output, logs, screenshots). Defects go in `docs/tests/defects.md`.
6. **Close:** docs and traceability matrix updated, task marked done in `docs/PROGRESS.md`.

### 3.3 Common acceptance criteria (every task must also meet these)

- [ ] C1: Plan exists and was reviewed before coding started
- [ ] C2: Code reviewed by `technical-architect`; review findings resolved
- [ ] C3: Every task-specific criterion maps to at least one executed test case; test report has evidence
- [ ] C4: CI green with no new lint, type or security warnings
- [ ] C5: Docs updated (README, runbook, ADR as relevant); traceability matrix row updated
- [ ] C6: No secrets in the repo; `.env.example` updated
- [ ] C7: Works from a clean checkout using only documented commands

### 3.4 Task sizes
S = under 0.5 day, M = 0.5 to 2 days, L = 2 to 4 days (indicative, for ordering only).

### 3.5 Milestones

| Milestone | Tasks | Outcome |
|---|---|---|
| M1 Foundations | T00 to T04a | Repo, agents, architecture, design, test plan and coding standards signed off |
| M2 Platform | T05 to T08 | DDEV stack, Pantheon dev, CI running |
| M3 Backend | T09 to T20 | Drupal and engine complete and tested independently |
| M4 Frontend | T21 to T26 (including T21a) | Next.js dashboard and theme complete and tested |
| M5 Integrated dev | T27 to T29 | End-to-end on DDEV and deployed dev environments |
| M6 Verified | T30 to T31 | Security and NFR checks done, 10 to 15 day live simulation |
| M7 Release | T32 to T33 | Docs final, go/no-go decision |

### 3.6 Suggested parallel tracks after T08
Drupal track (T09 to T12), Engine track (T13 to T20), Frontend track (T21 to T26, mock the API until T11 is done).

---

## 4. Project folder structure

```
meridian/
├─ CLAUDE.md                      # project memory for Claude Code
├─ .claude/
│  ├─ agents/                     # solution-architect, technical-architect, developer, tester
│  └─ commands/                   # plan-task, design-tests, implement-task, review-task, test-task, close-task
├─ .ddev/
│  ├─ config.yaml
│  ├─ docker-compose.postgres.yaml
│  ├─ docker-compose.engine.yaml
│  ├─ docker-compose.next.yaml
│  ├─ commands/                   # custom ddev commands (engine, e2e, pg ...)
│  └─ providers/pantheon.yaml
├─ apps/
│  ├─ drupal/                     # Composer root (docroot: web/, config/sync, custom modules)
│  └─ web/                        # Next.js app
├─ services/engine/               # Python package, tests, Dockerfile, Alembic
├─ docs/
│  ├─ PROGRESS.md                 # task status board
│  ├─ TRACEABILITY.md             # requirement -> task -> test case -> evidence
│  ├─ architecture/               # solution + technical design, diagrams, OpenAPI
│  ├─ adr/                        # ADR-000x-*.md
│  ├─ specs/                      # rules.md (scoring rules with IDs), data model
│  ├─ tasks/Txx/                  # plan.md, review.md
│  ├─ tests/                      # master-test-plan.md, Txx/test-cases.md + test-report.md, defects.md
│  ├─ runbooks/                   # local-setup, deploy, restore, incident
│  └─ process/WORKFLOW.md
├─ .github/workflows/             # ci.yml, daily-run.yml, deploy-drupal.yml
├─ .env.example
└─ README.md
```

---

# PHASE 0: Foundation

## T00: Repository scaffold and documentation skeleton (S)
**Owner chain:** developer (scaffold), technical-architect (review). **Depends on:** none. **Covers:** R-12

Create the monorepo, folder structure above, documentation templates and quality gates.

**Acceptance criteria**
- [ ] Folder structure from section 4 exists, with a README in each top-level folder explaining its purpose
- [ ] Templates exist for plan, review, test cases, test report, defect, ADR and runbook
- [ ] `docs/PROGRESS.md` lists all tasks T00 to T33 with status; `docs/TRACEABILITY.md` lists R-01 to R-12
- [ ] Pre-commit runs secret scanning (gitleaks) and formatting; a commit containing a fake key is rejected (demonstrated)
- [ ] `.gitignore` excludes `.env`, DB dumps, `*.db`, `node_modules`, `vendor`, `records/`
- [ ] All names follow section 0 (repo, DDEV project, packages, services); a grep for old placeholder names (`trading-agent`, `trading_engine`, `trading_ingest`) returns nothing
- [ ] `CLAUDE.md` states: project goal, simulation-only rule, repo layout, commands, per-task loop, doc locations

**Evidence:** `docs/tests/T00/test-report.md` with the rejected-commit demonstration.

## T01: Claude Code agents and workflow commands (M)
**Owner chain:** solution-architect (review of role definitions), developer, tester. **Depends on:** T00. **Covers:** R-12

**Acceptance criteria**
- [ ] Four agent files exist in `.claude/agents/` with name, description, tool restrictions and model, matching Appendix A
- [ ] Tester agent is configured without write access to application source folders (tests and `docs/tests` only); verified by attempting a source edit
- [ ] Solution and technical architects are read-only on source code, write access limited to `docs/`
- [ ] Slash commands exist for each loop step (3.2) and are documented in `docs/process/WORKFLOW.md`
- [ ] A dry-run task ("T01-demo": add a hello endpoint stub) runs through plan, test design, build, review, test and close, producing every artifact
- [ ] `docs/process/WORKFLOW.md` explains that the main session orchestrates and subagents do not call each other

**Evidence:** artifacts of the dry-run kept under `docs/tasks/T01-demo/` and `docs/tests/T01-demo/`.

---

# PHASE 1: Architecture and planning

## T02: Solution architecture (M)
**Owner chain:** solution-architect (author), technical-architect (review). **Depends on:** T00, T01. **Covers:** R-01 to R-12

**Acceptance criteria**
- [ ] `docs/architecture/solution-architecture.md` contains: context diagram, container diagram, data flow, scope and non-goals, assumptions, glossary (NSE terms, scoring terms)
- [ ] Functional and non-functional requirements refined from section 2, each with ID, priority and measurable target (for example run duration, data freshness, page load)
- [ ] Risk register with owner and mitigation for at least: free data source blocking, LLM wrong or injected output, free-tier limits changing, Pantheon sandbox sleep, GitHub cron delay, SEBI and regulatory exposure, secrets leakage
- [ ] Cost map listing each component as free, free-with-limits or paid, with the limit that matters
- [ ] ADRs written for: headless Drupal plus Next.js, engine on GitHub Actions, Postgres as system of record, monorepo with subtree deploy to Pantheon, authentication approach, no live trading in this project
- [ ] Branding check for "Meridian" recorded in `docs/architecture/naming.md`: .com/.in domain, GitHub and Vercel handles, Indian trademark registry search, app-store search; outcome is keep, keep as internal codename only, or rename (if renamed, section 0 is updated and a grep confirms no stale names remain)
- [ ] Open questions list; each resolved or ticketed
- [ ] Technical-architect sign-off recorded in the document

## T03: Technical design (M)
**Owner chain:** technical-architect (author), solution-architect (review). **Depends on:** T02. **Covers:** R-04, R-06, R-09

**Acceptance criteria**
- [ ] Drupal content model spec: content types (Decision, Position, Daily Run, Price Snapshot summary, Watchlist Item), every field with type, validation, indexing
- [ ] Postgres schema spec and migration plan (tables, keys, unique constraints, indexes)
- [ ] Engine to Drupal ingest contract as `docs/architecture/openapi.yaml`; passes OpenAPI linting
- [ ] Idempotency rule documented (external ID per record, upsert semantics) and outbox/retry design for Drupal outages
- [ ] Authentication design: engine to Drupal (OAuth client credentials, scope), Next.js to Drupal (read scope), user login flow
- [ ] Environment and secrets matrix (local DDEV, Pantheon dev, Vercel, GitHub Actions) listing every variable
- [ ] Repo and deploy strategy decided, including Drupal composer root and how `apps/drupal` reaches Pantheon
- [ ] Every requirement ID traces to at least one design element in `docs/TRACEABILITY.md`
- [ ] Solution-architect sign-off recorded

## T04: Master test plan and test infrastructure design (M)
**Owner chain:** tester (author), technical-architect (review). **Depends on:** T03. **Covers:** R-12

**Acceptance criteria**
- [ ] `docs/tests/master-test-plan.md` defines: test levels (unit, integration, contract, end-to-end, security, performance, data reconciliation, manual simulation), tools per component, environments, entry and exit criteria, defect severity scale
- [ ] Tool choices documented: pytest (engine), PHPUnit (Drupal), Vitest and Playwright (Next.js), OpenAPI contract tests, axe for accessibility
- [ ] Regression suite definition and how it runs in CI
- [ ] Test data strategy: fixtures, recorded market data, fake LLM responses, seeded Drupal content
- [ ] Traceability matrix has a planned test-case column for every requirement (100% requirement coverage planned)
- [ ] Defect workflow documented in `docs/tests/defects.md` template

## T04a: Coding standards and quality gates (M)
**Owner chain:** technical-architect (author), developer (tooling), tester (verification). **Depends on:** T04. **Covers:** R-12

Define the standards once, then enforce them automatically so reviews focus on design instead of style.

**Acceptance criteria**
- [ ] `docs/standards/CODING_STANDARDS.md` exists with sections for PHP and Drupal, Python, TypeScript and Next.js, SQL and migrations, Docker and YAML, shell scripts, Markdown docs, OpenAPI, and LLM prompt files
- [ ] Cross-cutting rules documented: naming (per section 0), error handling, structured logging, no secrets in code, dependency policy (lockfiles, pinned versions, audit before adding), comment and docstring expectations, maximum function and file size guidance
- [ ] Tool per language chosen and configured in the repo (proposed, verify current versions): PHP_CodeSniffer with Drupal and DrupalPractice standards plus PHPStan with Drupal rules; ruff (lint and format) plus mypy; ESLint, Prettier and `tsc --noEmit`; hadolint, yamllint, shellcheck, markdownlint, Spectral for OpenAPI
- [ ] Commit message convention (task ID prefix, for example `T10: add ingest upsert endpoint`) enforced by a commit hook; branch naming `task/Txx-slug` enforced in CI
- [ ] One local command, `ddev quality`, runs every check and exits non-zero on any violation; the same checks run in CI (T08) and as pre-commit hooks
- [ ] Baseline is clean: zero violations on the existing code; exceptions allowed only with an inline comment citing a ticket, and counted in a report
- [ ] Coverage thresholds defined per component and enforced in CI (for example 90% on engine `scoring` and `risk`, targets for Drupal custom modules and Next.js recorded in the doc)
- [ ] Technical-architect review checklist (`docs/standards/REVIEW_CHECKLIST.md`) derived from the standards and referenced by the `technical-architect` agent
- [ ] Verification by the tester: a deliberately non-compliant change per language (bad PHP style, untyped Python, ESLint error, long Markdown line, bad commit message, a coverage drop) is rejected by hooks or CI; evidence stored in `docs/tests/T04a/test-report.md`

**Evidence:** `docs/standards/` folder, `ddev quality` output on a clean tree, and the rejected-change demonstrations.

---

# PHASE 2: Local platform (DDEV and Docker)

## T05: DDEV Drupal project (M)
**Owner chain:** developer. **Depends on:** T03. **Covers:** R-11

Create Drupal 11 using the Pantheon-compatible Composer-managed layout in `apps/drupal`, with DDEV configured for it (for example `composer_root: apps/drupal`, `docroot: web`).

**Acceptance criteria**
- [ ] `ddev start` on a clean clone starts the project without manual steps
- [ ] Drupal installs through one documented command (`ddev drush site:install` plus config import); admin login works via `ddev drush uli`
- [ ] DDEV PHP and database versions match the values in `pantheon.yml`
- [ ] Configuration sync directory set; `ddev drush cex` after a fresh install produces no diff
- [ ] `ddev composer validate` and `ddev drush status` pass
- [ ] `docs/runbooks/local-setup.md` followed verbatim by the tester on a clean machine or container works end to end

## T06: Extra Docker services in DDEV (M)
**Owner chain:** developer. **Depends on:** T05. **Covers:** R-11

Add Postgres, Python engine and Next.js containers through `.ddev/docker-compose.*.yaml`.

**Acceptance criteria**
- [ ] `ddev start` brings up Drupal, Postgres, engine and Next.js containers
- [ ] Engine container reaches Postgres and Drupal over the internal network; Next.js container reaches Drupal
- [ ] Custom commands exist and are documented: `ddev engine ...`, `ddev pg ...`, `ddev next ...`
- [ ] Data survives `ddev restart`; a documented Postgres dump and restore script works (tested)
- [ ] Container health checks defined; a deliberately stopped service is reported by a status command
- [ ] Next.js dev server reachable through a DDEV hostname over HTTPS

## T07: Pantheon dev environment and deployment path (M)
**Owner chain:** developer, solution-architect (consult). **Depends on:** T05. **Covers:** R-11

**Acceptance criteria**
- [ ] Pantheon sandbox site created from the Composer-managed Drupal upstream; `pantheon.yml` committed
- [ ] Terminus machine token setup documented; token never committed (secret scan passes)
- [ ] `ddev auth pantheon` and `ddev pull pantheon` pull database and files into local DDEV (tested)
- [ ] Code in `apps/drupal` deploys to Pantheon dev by the decided mechanism (for example subtree push from CI); site loads on its dev URL
- [ ] Config imported on Pantheon dev matches local (`drush config:status` clean)
- [ ] Rollback procedure and sandbox sleep and limits behaviour documented in `docs/runbooks/deploy.md`

## T08: Continuous integration baseline (M)
**Owner chain:** developer, technical-architect (review). **Depends on:** T05, T06. **Covers:** R-12

**Acceptance criteria**
- [ ] `ci.yml` runs the full `ddev quality` suite defined in T04a (lint, format check, static analysis, type checks, commit and branch naming), plus unit tests per component with coverage thresholds, build, secret scan, dependency audit
- [ ] A deliberately failing test blocks merge on a demo pull request (branch protection configured)
- [ ] Pipeline total time under 10 minutes on a clean cache
- [ ] Test reports uploaded as workflow artifacts
- [ ] Required secrets listed in `docs/runbooks/ci-secrets.md` (names only)

---

# PHASE 3: Drupal backend

## T09: Content model as configuration (M)
**Owner chain:** developer. **Depends on:** T03, T05. **Covers:** R-06, R-07

**Acceptance criteria**
- [ ] Content types and fields exactly as in the T03 spec, exported as config in `config/sync`
- [ ] Validation enforced: mode in {long, short}, action in {BUY, AVOID}, score 0 to 100, required fields, numeric ranges
- [ ] Unique `external_id` enforced per type at entity level (not only in the API)
- [ ] `ddev drush cex` after install shows no diff; `cim` on a clean site recreates everything
- [ ] PHPUnit kernel tests cover every validation rule, including each rejection case
- [ ] Permissions matrix documented (admin, analyst-read, engine-ingest)

## T10: Ingest API and authentication (L)
**Owner chain:** developer, solution-architect (security consult). **Depends on:** T09. **Covers:** R-06, R-09, R-10

Custom module (`meridian_ingest`) providing idempotent upsert endpoints with OAuth client-credentials auth.

**Acceptance criteria**
- [ ] Endpoints implement the OpenAPI contract; contract tests pass against the running DDEV site
- [ ] Posting the same record twice creates one entity (idempotent), second call updates it
- [ ] Batch ingest accepts at least 500 records per request and completes within an agreed time on DDEV (target recorded in T03)
- [ ] Invalid payload returns 422 with field-level errors; missing token 401; token with wrong scope 403
- [ ] Engine client has least privilege: cannot read users, cannot delete content, cannot access admin
- [ ] Payload size limit and rate limit enforced and tested
- [ ] Each ingest writes an audit log entry (who, what, count, result)
- [ ] PHPUnit functional tests for every case above

## T11: Read API for the frontend (M)
**Owner chain:** developer. **Depends on:** T09. **Covers:** R-08, R-09

**Acceptance criteria**
- [ ] JSON:API read access for Decision, Position, Daily Run with filtering (date, symbol, mode, action), sorting and pagination
- [ ] Separate read-only OAuth client for Next.js; cannot write
- [ ] Sensitive or bulky fields (for example raw LLM response) exposed only to roles that need them; tested per role
- [ ] Cache tags configured so new ingests appear without manual cache clears (tested)
- [ ] Response time for a 50-row page with 5,000 records seeded is within target recorded in T03
- [ ] Contract tests for read endpoints pass

## T12: Admin UI and roles (M)
**Owner chain:** developer. **Depends on:** T09. **Covers:** R-07

**Acceptance criteria**
- [ ] Views for Decisions, Positions and Daily Runs with exposed filters and CSV export
- [ ] Roles: `administrator`, `analyst` (read and export only); role access verified by tests
- [ ] Watchlist Item management UI (add, disable, reorder) that the engine can read through the API
- [ ] Views exported as config; no manual setup required after `cim`
- [ ] Screenshots of each view with seeded data stored in test evidence

---

# PHASE 4: Python engine

## T13: Engine scaffold and port of MVP logic (M)
**Owner chain:** developer. **Depends on:** T03, T06. **Covers:** R-01, R-02

Package `meridian_engine` with modules: `config`, `data`, `scoring`, `llm`, `risk`, `simulation`, `store`, `publish`, `cli`. Port logic from `mvp_agent.py`.

**Acceptance criteria**
- [ ] Package layout and Dockerfile in place; `ddev engine --help` works
- [ ] Config is YAML validated against a schema (watchlist, thresholds, costs, model name); invalid config fails fast with a clear message
- [ ] Structured JSON logging with run ID on every line
- [ ] Parity test: new scoring on fixed fixtures reproduces the MVP script's scores exactly (golden file committed)
- [ ] Secrets only from environment variables

## T14: Storage layer on Postgres (M)
**Owner chain:** developer. **Depends on:** T13. **Covers:** R-06, R-10

**Acceptance criteria**
- [ ] Alembic migrations create decisions, positions, prices, runs, outbox tables per T03
- [ ] Migrations tested up and down on an empty and a populated database
- [ ] Unique constraints make a repeated daily run idempotent (tested by running twice)
- [ ] Every decision row stores inputs snapshot, LLM raw output, prompt version, model and rule version
- [ ] Backup and restore scripts tested; row counts match after restore

## T15: Market data providers (M)
**Owner chain:** developer. **Depends on:** T13. **Covers:** R-01, R-10

**Acceptance criteria**
- [ ] Provider interface with `yfinance` implementation and a stub second provider proving swappability
- [ ] Retry with exponential backoff; simulated HTTP 429 results in bounded retries, a logged failure for that symbol, and the run continuing for others
- [ ] Data quality checks: positive prices, monotonic dates, stale-data flag, missing fundamentals handled without crashing
- [ ] Tests use recorded responses (no live network in CI)
- [ ] Known limits of the free source documented in `docs/specs/data-sources.md`

## T16: Scoring and decision rules (M)
**Owner chain:** developer, solution-architect (rule review). **Depends on:** T13. **Covers:** R-02, R-04

**Acceptance criteria**
- [ ] `docs/specs/rules.md` lists every rule with an ID, threshold and rationale; each rule ID maps to tests
- [ ] Table-driven unit tests hit each boundary (just below, at and above every threshold)
- [ ] Mode-specific stop and target logic tested (ATR-based short mode, percentage long mode)
- [ ] Position sizing tests: risk cap, position cap, zero or negative risk per share, insufficient cash
- [ ] Coverage at least 90% on `scoring` and `risk`
- [ ] Changing a rule requires bumping a rule version recorded in each decision (tested)

## T17: LLM analyst review (M)
**Owner chain:** developer, solution-architect (prompt review). **Depends on:** T13. **Covers:** R-03

**Acceptance criteria**
- [ ] Prompt stored in a versioned file; version recorded with each decision
- [ ] Response validated against a JSON schema; malformed, empty, timeout or API error all result in veto with the reason stored (one test per failure type)
- [ ] Prompt-injection test: a headline containing instructions to ignore rules cannot change the output schema or produce an unvalidated buy
- [ ] Token usage and estimated cost logged per call and aggregated per run
- [ ] Model name configurable; unit tests use a fake client; one clearly marked manual smoke test against the real API with evidence recorded
- [ ] LLM is only called for candidates above the score threshold (tested by counting calls)

## T18: Simulation engine (L)
**Owner chain:** developer, technical-architect (careful review). **Depends on:** T14, T16. **Covers:** R-04, R-05

**Acceptance criteria**
- [ ] Virtual positions open on BUY, with stop, target and short-mode time-stop; costs applied on both sides
- [ ] Rules verified: gap through stop exits at open; stop and target in the same bar resolves to stop; no exits evaluated on or before entry date
- [ ] At least 12 hand-calculated scenarios (computed independently in the test docs) pass
- [ ] Accounting invariant tested: equity equals start capital plus realised plus unrealised P&L minus costs, at every step of every scenario
- [ ] Static check (test) fails if any broker SDK is imported or any broker domain is referenced
- [ ] Duplicate-position and insufficient-cash cases recorded with a note, not silently dropped

## T19: Drupal publisher with outbox (L)
**Owner chain:** developer. **Depends on:** T10, T14. **Covers:** R-06, R-07, R-10

**Acceptance criteria**
- [ ] Publishes decisions, positions and run summaries to the T10 API in batches
- [ ] Re-running publishes no duplicates (counts compared before and after)
- [ ] Outage test: stop Drupal, run the engine, outbox grows, records are not lost; restart Drupal, outbox drains to zero
- [ ] Failed publish does not fail the whole run but marks the run as `published: partial` and alerts
- [ ] Integration test against DDEV Drupal verifies field-by-field equality for a sample of records
- [ ] Credentials read from environment only; token refresh handled and tested

## T20: CLI and scheduled execution (M)
**Owner chain:** developer. **Depends on:** T18, T19. **Covers:** R-10

**Acceptance criteria**
- [ ] CLI commands: `daily`, `run`, `update`, `report`, `publish`, `replay --date` with `--no-llm` option; all documented
- [ ] `daily-run.yml` scheduled for 16:00 IST (10:30 UTC, weekdays), with manual trigger, timeout and concurrency lock so two runs cannot overlap
- [ ] NSE holiday or no-new-candle detected: run exits cleanly with status `skipped` and reason (tested)
- [ ] Failure sends a notification (issue or email) with run ID and log link (tested by forced failure)
- [ ] Run summary uploaded as workflow artifact
- [ ] Manual-dispatch run on a test branch completes successfully against local or dev targets, with evidence

---

# PHASE 5: Next.js dashboard

## T21: Next.js scaffold and Drupal client (M)
**Owner chain:** developer. **Depends on:** T06, T08. **Covers:** R-08

**Acceptance criteria**
- [ ] App Router, TypeScript strict, ESLint, Vitest and Playwright configured; runs in the DDEV Next.js container
- [ ] `next-drupal` (or equivalent typed client) configured; environment variables validated at startup with a schema
- [ ] `/api/health` reports app status and Drupal reachability
- [ ] Vercel project linked; preview deployment created for pull requests
- [ ] Mock API mode lets frontend work proceed without Drupal (documented)

## T21a: Design tokens and theme (M)
**Owner chain:** solution-architect (visual decisions), developer, tester. **Depends on:** T21. **Covers:** R-08

Implement the palette in section 0b as a single source of truth for the dashboard (and the Drupal admin and login screens where practical).

**Acceptance criteria**
- [ ] Palette hex values confirmed by the project owner and recorded in `docs/design/tokens.md`
- [ ] Tokens defined once (CSS variables or a tokens file consumed by Tailwind or CSS) with semantic names (background, surface, text, text-muted, primary, accent, border, focus) rather than color names in components
- [ ] Light theme (Cloud white, Cream, Midnight text) and dark theme (Midnight background, Cream text) both implemented; theme follows system preference with a manual toggle that persists
- [ ] Derived tokens defined and documented with rationale: gain, loss, warning, error, dark-mode surface tint, border, focus ring, chart series palette
- [ ] Automated contrast test computes the ratio for every foreground and background token pair used in components and fails the build below AA (4.5:1 text, 3:1 large text and UI); forbidden pairings from section 0b are listed and covered by the test
- [ ] Gain and loss are never conveyed by color alone (sign, arrow or label present); charts remain readable in a color-blind simulation (evidence stored)
- [ ] `/styleguide` page (admin-only) renders all tokens, buttons, tables, cards, charts and form states in both themes
- [ ] Axe accessibility check passes on `/styleguide` in both themes with no critical or serious issues
- [ ] Font is **Fira Sans**, self-hosted: WOFF2 files committed in the repo (for example `apps/web/fonts/`) and loaded with the framework's local font loader; no Google Fonts stylesheet, no CDN, no runtime request to any third-party host (build and run work offline in DDEV)
- [ ] Only the needed weights and styles are shipped (start with 400, 500, 600, 700; add italics only if used) and only the needed character subsets (Latin); `font-display: swap`, key weight preloaded, and a metric-matched fallback stack defined so layout does not jump
- [ ] Font licence (SIL Open Font License) file stored next to the font files and noted in `docs/design/tokens.md`
- [ ] Numbers render correctly: tabular figures enabled for tables and KPIs (verified the feature exists in the shipped files), and the rupee sign `₹` renders from Fira Sans in the shipped subset, or a documented fallback is chosen if the glyph is missing
- [ ] Icons are **SVG only** (no icon fonts, no CDN-hosted icon kits): sourced from an open-licensed set (for example Lucide or Tabler, licence recorded) or custom-drawn, optimised with SVGO, imported as components or a local sprite, drawn with `currentColor` so they follow the theme tokens
- [ ] Icon accessibility: decorative icons hidden from screen readers, meaningful icons have an accessible name; icon-only buttons have a label; minimum 3:1 contrast for icon against background (covered by the contrast test)
- [ ] Raster images, if any (logo art, social preview, illustrations), are **WebP** with explicit width and height; the favicon is SVG. Where a platform requires another format (for example an Apple touch icon needs PNG), the exception is recorded in an ADR rather than ignored
- [ ] Asset policy enforced: a `ddev quality` check fails on references to external font, style, script or icon hosts, and a Playwright test asserts every page load makes only same-origin requests (plus the Drupal API through the server); the Content-Security-Policy sets `font-src 'self'` and `img-src 'self' data:`
- [ ] Drupal admin and login pages show the brand colors through a documented approach (admin theme settings or a small sub-theme), or a recorded decision that admin stays default
- [ ] No hard-coded hex values in component code (lint rule or grep check in `ddev quality`)

## T22: Authentication and route protection (M)
**Owner chain:** developer, solution-architect (security consult). **Depends on:** T11, T21. **Covers:** R-09

**Acceptance criteria**
- [ ] Login through the decided flow (Drupal accounts with OAuth); logout and session expiry work
- [ ] Middleware protects every page and data route; unauthenticated requests redirect or return 401 (tested for each route)
- [ ] Access tokens and Drupal credentials never reach the browser (test inspects client bundles and network calls)
- [ ] Role-based visibility (for example raw LLM output only for administrators) tested
- [ ] Security headers set and verified

## T23: Overview page (M)
**Owner chain:** developer. **Depends on:** T22. **Covers:** R-08

**Acceptance criteria**
- [ ] KPIs: virtual equity, return vs Nifty 50, win rate, open positions, last run status
- [ ] Equity versus Nifty line chart over the simulation period
- [ ] Numbers match the engine report for a fixed fixture dataset (reconciliation test)
- [ ] Empty, loading and error states implemented and tested
- [ ] Accessibility check passes with no critical axe violations

## T24: Decisions explorer (M)
**Owner chain:** developer. **Depends on:** T22. **Covers:** R-06, R-08

**Acceptance criteria**
- [ ] Table with filters (date range, symbol, mode, action, vetoed) and pagination, state kept in the URL
- [ ] Detail view shows score, rule hits, thesis, risks, metrics snapshot, headlines, prompt and rule versions
- [ ] CSV export of the filtered set matches the table (tested)
- [ ] Playwright end-to-end tests for each filter and the detail view with seeded data
- [ ] Keyboard navigation works for the table and filters

## T25: Positions and reports pages (M)
**Owner chain:** developer. **Depends on:** T22. **Covers:** R-04, R-08

**Acceptance criteria**
- [ ] Open and closed positions with entry, stop, target, exit reason and P&L
- [ ] Report page shows forward returns (1, 3, 5 days) and alpha vs Nifty for BUY, AVOID and VETOED groups
- [ ] Report values equal the engine `report` command output within rounding (automated comparison)
- [ ] Clear indication when sample size is too small to be meaningful
- [ ] Empty and partial-data states tested

## T26: Frontend hardening (M)
**Owner chain:** developer, tester. **Depends on:** T23, T24, T25. **Covers:** R-08, R-09

**Acceptance criteria**
- [ ] Responsive layouts verified on desktop and mobile viewports (screenshots in evidence)
- [ ] Accessibility: axe has zero critical or serious issues on every page; keyboard-only walkthrough documented
- [ ] Performance budget met with 5,000 decisions seeded (target recorded in T02, for example LCP under 2.5 s on dev)
- [ ] Error boundary and Drupal-down behaviour tested (friendly error, no stack traces)
- [ ] Dependency audit has no high severity findings

---

# PHASE 6: Integration and deployment

## T27: Local end-to-end integration (L)
**Owner chain:** developer, tester. **Depends on:** T12, T20, T26. **Covers:** R-06, R-08, R-11

**Acceptance criteria**
- [ ] One command (`ddev e2e`) seeds fixtures, runs the engine with a fake LLM, publishes to Drupal and runs Playwright against Next.js; passes from a clean state
- [ ] Reconciliation script compares counts and key values at each hop (Postgres, Drupal, UI) and reports zero differences
- [ ] Failure-injection runs documented and passing: Drupal down, LLM error, data provider 429, duplicate run
- [ ] Results recorded in `docs/tests/T27/test-report.md`

## T28: Dev environment deployment (L)
**Owner chain:** developer, solution-architect (consult). **Depends on:** T07, T27. **Covers:** R-10, R-11

**Acceptance criteria**
- [ ] Drupal on Pantheon dev, Next.js on Vercel, engine scheduled on GitHub Actions, Postgres on the chosen free host
- [ ] Environment variable matrix from T03 fully implemented; secrets stored only in platform secret stores
- [ ] Smoke test suite runs against deployed URLs and passes
- [ ] One scheduled run executes unattended and its data is visible in the deployed dashboard
- [ ] Rollback of each component demonstrated once and documented

## T29: Observability and operations (M)
**Owner chain:** developer, tester. **Depends on:** T28. **Covers:** R-10

**Acceptance criteria**
- [ ] Dashboard run-health panel: last run time, status, decisions count, errors, outbox size, LLM cost
- [ ] Missed-run alert fires when no successful run is recorded by a defined time (tested by disabling a run)
- [ ] Backup and restore drill performed for Pantheon database and Postgres; timings and steps recorded
- [ ] Runbooks written: failed run, Drupal outage, data source blocked, rotating credentials, restoring from backup
- [ ] Log retention and where to find logs documented

---

# PHASE 7: Verification

## T30: Security and non-functional verification (L)
**Owner chain:** tester, solution-architect (review). **Depends on:** T28. **Covers:** R-05, R-09

**Acceptance criteria**
- [ ] Secret scan across full git history is clean
- [ ] Authorisation matrix test: every role against every endpoint and page, results tabulated
- [ ] Injection, XSS and CSRF checks on all inputs (including LLM text rendered in the UI) with evidence
- [ ] Dependency and container image vulnerability scans: no unresolved high severity items
- [ ] Performance tests: ingest batch, 5,000-record read pages, engine run duration versus targets
- [ ] Confirmation that no order-placement capability exists (static check plus manual review)
- [ ] Findings logged with severity; all critical and high fixed and retested

## T31: Live simulation validation, 10 to 15 trading days (L)
**Owner chain:** tester (lead), solution-architect (analysis). **Depends on:** T28, T29. **Covers:** R-01 to R-06, R-10

**Acceptance criteria**
- [ ] Engine runs on schedule for at least 10 trading days; every day has a run record (success, partial or skipped with reason)
- [ ] Daily checklist completed and stored (run completed, counts reconciled engine vs Drupal vs UI, no unexplained errors)
- [ ] All bugs found are logged, fixed or consciously accepted with reasoning
- [ ] Final analysis report: decisions made, BUY vs AVOID vs VETOED forward returns, equity vs Nifty, LLM cost, data issues, with the explicit caveat that the sample is small
- [ ] Recommendations list for rules, data sources and prompt changes, each tied to evidence

---

# PHASE 8: Release and handover

## T32: Documentation finalisation (M)
**Owner chain:** solution-architect, technical-architect, tester. **Depends on:** T31. **Covers:** R-11, R-12

**Acceptance criteria**
- [ ] README lets a new developer reach a running local stack using only the README (validated by someone following it cold)
- [ ] Architecture docs updated to match what was actually built (diff from T02 and T03 explained in an ADR)
- [ ] User guide for the dashboard and Drupal admin
- [ ] Traceability matrix complete: every requirement maps to tasks, test cases and evidence links; zero gaps
- [ ] Link checker and markdown lint pass on `docs/`

## T33: Go/no-go review and next-phase backlog (S)
**Owner chain:** solution-architect, technical-architect. **Depends on:** T32. **Covers:** R-05, R-12

**Acceptance criteria**
- [ ] Release checklist completed: all tasks done, open defects reviewed, known limitations listed
- [ ] Decision recorded (go, go with conditions, or no-go) with reasons
- [ ] Retrospective: what worked in the agent workflow, what to change
- [ ] Backlog for the next phase created (examples: historical backtester, better Indian data sources, sector and market-regime filters)
- [ ] Any future broker integration is recorded as a separate project requiring its own regulatory review and approval; not started here

---

# Appendix A: Agent charters (for `.claude/agents/*.md`)

Each file uses YAML frontmatter (`name`, `description`, `tools`, optionally `model`) followed by the instructions below.

### solution-architect
- **Purpose:** domain and technical knowledge holder (Indian equities basics, data sources, regulation awareness, Drupal, Pantheon, Next.js, Docker). Produces requirements, architecture, ADRs; answers design questions from other agents.
- **Inputs:** requirements, task descriptions, review requests.
- **Outputs:** `docs/architecture/*`, `docs/adr/*`, written answers saved to `docs/tasks/Txx/` when they affect a decision.
- **Tools:** read, search, web research, write only under `docs/`.
- **Must not:** edit source code or tests; make claims about regulations or free-tier limits without citing a source and date.

### technical-architect
- **Purpose:** plans each task, defines interfaces, reviews every developer change against the plan, criteria and standards.
- **Inputs:** task spec, architecture docs, pull request diff.
- **Outputs:** `docs/tasks/Txx/plan.md`, `docs/tasks/Txx/review.md` (findings with severity and resolution).
- **Tools:** read, search, run read-only commands (git diff, linters), write only under `docs/`.
- **Must not:** write production code; approve a task whose common criteria (3.3) are unmet.

### developer
- **Purpose:** implements exactly one task at a time on its branch, with unit tests, following the plan.
- **Inputs:** approved plan, test cases from the tester.
- **Outputs:** code, unit tests, updated docs for what changed, commit messages referencing the task ID.
- **Tools:** read, edit, bash (DDEV and project commands), git.
- **Must not:** change scope without a plan update; weaken or delete tests to make them pass; commit secrets; mark a task done (only the close step does).

### tester
- **Purpose:** independent verification. Designs test cases from the acceptance criteria before development, executes them after, records evidence and defects.
- **Inputs:** task acceptance criteria, design docs, the built system.
- **Outputs:** `docs/tests/Txx/test-cases.md`, `docs/tests/Txx/test-report.md`, test code under test folders, entries in `docs/tests/defects.md`.
- **Tools:** read, bash, write only to test folders and `docs/tests/`.
- **Must not:** modify production code; pass a case without stored evidence; skip a failing case.

---

# Appendix B: Document templates (minimum fields)

**Test case:** ID (`TC-Txx-nn`), linked criterion, preconditions, steps (exact commands), expected result, actual result, evidence link, status, date, executed by.

**Test report:** task ID, build or commit, environment, summary table (case, status), defects raised, coverage notes, tester sign-off.

**Defect:** ID, title, severity, found in task/case, steps to reproduce, expected vs actual, status, fix commit, retest result.

**ADR:** title, status, context, decision, alternatives considered, consequences, date.

**Plan:** goal, scope and non-goals, steps, interfaces touched, risks, test hooks needed, definition of done checklist.

**Review:** commit range, findings (severity, file, issue, resolution), approval statement.
