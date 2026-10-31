# T02 manual case evidence (tester, 2026-11-01)

Reviewed `docs/architecture/solution-architecture.md` (435 lines), `naming.md`, ADR-0001 to 0006, `docs/tasks/T02/review.md`, against `docs/TASKS.md`.

## TC-T02-07 Targets measurable and realistic: PASS

49 FR/NFR rows (30 FR, 19 NFR). Grep for fast/responsive/quick/good/reasonable/snappy/smooth in the target cells: 0 hits.

- Performance NFRs state number, unit, percentile or condition and environment: NFR-01 (DDEV fake LLM 5 min; Dev p95 15 min; timeout 30 min), NFR-02 (IST times, percent of days, T31 window), NFR-03 (LCP p75 2.5 s Dev warm, 2.0 s DDEV, cold measured separately: shell 2.5 s, data 40 s), NFR-04 (DDEV 500 records at most 30 s, p95 over 5 runs), NFR-05 (p95 500 ms DDEV / 1,500 ms Pantheon warm, 50 requests), NFR-07 (10 min cold / 6 min warm cache).
- Deferred item: NFR-04 Pantheon dev value deferred to T03 with a stated reason (Pantheon request time limit not yet recorded); OQ-07 tickets it.
- Functional targets are counts or percentages (FR-06 5 failure types, FR-09 12 scenarios, FR-18 0.01 tolerance).
- Plausibility on free tiers: warm/cold split and the 30 s Pantheon wake are accounted for; NFR-02 slack covers GitHub cron delay. Judged plausible.
- Observation, not a failure: NFR-10/12/13 name no environment, but they are environment-independent checks.

## TC-T02-10 Mitigations actionable and match risk: PASS

- RK-01: provider interface, backoff, fixtures, licensed-source backlog (T15).
- RK-02: schema validation, veto on failure, injection tests, escaped rendering (T17, T30).
- RK-03: dated re-check at T28 and T33, portable boundaries.
- RK-04: wake GET and 120 s retry, snapshot fallback, outbox, cached last-good (T07, T19, T26).
- RK-05: off-hour cron, slack, 19:00 IST missed-run alert, runbook, weekly enabled check (T20, T29).
- RK-06: simulation only (ADR-0006), private dashboard, disclaimer FR-30, legal review in T33 (T22, T33).
- RK-07: gitleaks pre-commit plus CI history scan, scoped tokens, redaction, rotation runbook (T08, T22, T29, T30).
- RK-08: caps NFR-08, spend limit (T17, T29). RK-09: stay non-commercial, move to Pro before commercial use (T28, T33). RK-10: vendor choice against limits, backup artifact (T28, T29). RK-11 and RK-12 likewise actionable.
- No mitigation reads "monitor" with no action. All linked task headings (T07, T08, T15, T17, T19, T20, T22, T25, T26, T28, T29, T30, T31, T33) exist in docs/TASKS.md. A keyword spot-check of each task section found related content (1 to 4 lines each).

## TC-T02-12 Cost map limits: PASS

Limits are concrete and are the likeliest breakers: GitHub Actions (schedule delay, 60-day disable, USD 12 included, 6 h job); Postgres lists Neon Free (1 GB, 100 CU-hours) and Supabase Free (500 MB, pause) and defers the choice to T03/T28; Pantheon (1 h idle sleep, about 30 s wake, 0 custom domains); Vercel Hobby (non-commercial clause, quotas); Claude API (per-token price, about USD 0.20 per run); yfinance (unofficial, personal use, undocumented rate limits flagged unverified). No vendor is chosen.

## TC-T02-20 Owner actions and conservative outcome: PASS

"Not verifiable by agent" rows (checks 1, 2, 6, 8, 9) map to OA-1 to OA-4 with exact URLs, search terms (Wordmark and Phonetic, match type Contains, classes 9, 36, 42), and what to record (application number, mark, class, proprietor, status; registrant, dates). OA-5 covers the repo rename. Outcome is "keep as internal codename only" while owner actions are open: conservative. Agent-run checks (1, 3, 4, 5) cite method and URL. Note: checks 1 and 2 give the URL only, no command line; accepted as low impact.

## TC-T02-31 Criteria map to executed cases with evidence: PASS

Every AC1 to AC8 and C1 to C7 row has at least one executed case with an evidence file (see test-report.md). C6 and C7 each contain a Blocked case (29, 32) but also executed Pass sub-checks; those two Blocked cases are carried into the sign-off. The report lists the commit SHA and environment.

## TC-T02-32 Mermaid renders: BLOCKED

No GitHub preview (branch not pushed, no network) and no local renderer (`npx --no-install mmdc` fails). Static validation only (`evidence/TC-T02-32-static.txt`): 3 mermaid blocks (2 flowchart, 1 sequenceDiagram); fences balanced; subgraph/alt/loop openers equal `end` counts (3/3 and 4/4); no odd quote counts; no unbalanced brackets; all flowchart edge endpoints are defined nodes; no semicolons inside blocks. Syntax looks valid, but a static check is not a render, so the case is not Pass.

## TC-T02-33 Architecture level only: PASS

Grep for CREATE TABLE, openapi, paths:, threshold assignments over solution-architecture.md and docs/adr/*.md: one hit, solution-architecture.md line 14 ("OpenAPI contract ... belongs to T03"), which is the boundary statement. No DDL, paths, field lists, thresholds or env matrix. Scope section "Not decided in T02" lists T03, T16, T17.

## TC-T02-34 Spot-check cited facts: BLOCKED

No web tool and no network, so live re-verification was not possible. Static check only: TC-T02-21 passed (every cost row and limit/regulatory risk row has an https URL plus 2026-11-01 date or "unverified"; no http://). Claims selected (URL and date presence only, content not compared):

- Vercel Hobby non-commercial and quotas: https://vercel.com/docs/plans/hobby, 2026-11-01.
- Pantheon sandbox sleep about 1 h, wake about 30 s: https://docs.pantheon.io/application-containers, 2026-11-01.
- SEBI RA Regulations as amended 2024-12-16 and algo circular extension 2025-09-30: sebi.gov.in URLs, 2026-11-01; algo timeline marked unverified.
- Claude pricing: https://platform.claude.com/docs/en/about-claude/pricing, 2026-11-01.

Honest "unverified" markers exist for NSE terms, yfinance rate limits, registrar prices.

## TC-T02-35 ADR coherence: PASS

- ADR-0003 (Postgres system of record, outbox, Drupal copy, watchlist exception with snapshot fallback) matches the container diagram arrows (engine to Postgres, outbox drain to ingest, watchlist read) and the sequence diagram alt branch.
- ADR-0005 scopes (engine ingest write plus separate watchlist read; read-only Next.js client; user tokens for admin fields; shared secret for revalidation) match the diagram labels and ADR-0001 revalidation text.
- ADR-0002 (16:00 IST = 10:30 UTC, concurrency, 30 min timeout) matches FR-22, NFR-01 and the sequence diagram.
- ADR-0004 (monorepo, subtree split of apps/drupal, deploy-only Pantheon repo) is consistent with the container diagram and RK-04 wake-before-drush.
- ADR-0006 states the rule generically, no broker names (grep clean); consistent with FR-11 and RK-06.
- Every alternatives table gives a concrete reason per rejected option. Decisions use active voice.
- No contradictions found.
