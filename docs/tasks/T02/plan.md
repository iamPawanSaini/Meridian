# T02: Solution architecture, Plan

| Field | Value |
|---|---|
| Task | T02 |
| Author | technical-architect |
| Date | 2026-11-01 |
| Branch | `task/T02-solution-architecture` |
| Status | Approved |

Approved by main session on owner's instruction, 2026-11-01.

## Goal

Produce the signed-off solution architecture that every later task builds on: diagrams, scope,
refined requirements with measurable targets, risks, costs, the six founding ADRs and the
"Meridian" branding check. This is a documentation task. The **solution-architect is the author**
("build" means writing the docs). The technical-architect reviews afterwards and records sign-off.

## Scope

- `docs/architecture/solution-architecture.md` with these sections: context diagram, container
  diagram, data flow (sequence diagram for one daily run), scope and non-goals, assumptions,
  glossary (NSE terms such as trading day, holiday calendar, EOD candle, Nifty 50, circuit limit,
  STT; scoring terms such as long and short mode, score, rule hit, veto, ATR, stop, target,
  time-stop, R-multiple, forward return, alpha), refined FR and NFR, risk register, cost map,
  open questions, sign-off.
- Diagrams in Mermaid inside Markdown (`flowchart`, `sequenceDiagram`). No images, no external hosts.
- Refined requirements: R-01 to R-12 stay as parents. Children are `FR-nn` and `NFR-nn`, each with
  parent R-ID, MoSCoW priority, a measurable target and a verifying task. Set these targets
  here, and let T03 confirm or tighten them:
  engine run duration, data freshness (published by a stated IST time on trading days),
  dashboard LCP (T26), batch ingest time for 500 records on DDEV (T10), p95 response for a 50-row
  page with 5,000 records (T11, T30), run availability over the T31 window, CI duration (T08).
  If a target cannot be set yet, mark it "deferred to T03" with the reason. Do not leave it blank.
- Risk register (ID, description, likelihood, impact, owner role, mitigation, linked task),
  covering at least the seven risks in the T02 criteria. Also cover: LLM cost overrun and the
  Vercel Hobby non-commercial clause.
- Cost map: every component (GitHub Actions, hosted Postgres, Pantheon sandbox, Vercel Hobby,
  Claude API, data source, domain) marked free, free-with-limits or paid. Name the one limit
  that matters for each.
- ADRs in `docs/adr/` from `docs/templates/adr.md`. ADR-0001 headless Drupal plus Next.js;
  ADR-0002 engine on GitHub Actions; ADR-0003 Postgres as system of record (Drupal is a
  published copy); ADR-0004 monorepo with subtree deploy of `apps/drupal` to Pantheon;
  ADR-0005 authentication approach (OAuth client credentials for engine and Next.js, Drupal
  accounts for users, least-privilege scopes; T03 holds the detail); ADR-0006 no live trading.
  Update the index in `docs/adr/README.md`.
- `docs/architecture/naming.md` covers: .com and .in domains, GitHub and Vercel handles, the
  Indian trademark registry (IP India, classes 9, 36 and 42), Play Store and App Store search,
  and the repo `Meridian` vs `meridian` mismatch (T00 review finding 2). It ends with one outcome:
  keep, internal codename only, or rename.
- `docs/TRACEABILITY.md`: add the refined FR and NFR IDs to each R row. Add a column, or a list
  under the table, without breaking the existing columns.

## Non-goals

- Technical design details: content model, Postgres schema, OpenAPI contract, env matrix. These belong to T03.
- Choosing the hosted Postgres vendor. The cost map lists candidates. Record the choice in T03 or T28.
- Scoring thresholds or rule values. These belong to T16 (`docs/specs/rules.md`).
- Any code, config or workflow change. Changes to `docs/TASKS.md` section 0 apply only if the outcome is "rename".

## Steps

1. Draft context and container diagrams and the daily-run sequence from TASKS.md section 1.
   Include Postgres, the outbox and the Drupal ingest and read paths.
2. Write scope, non-goals, assumptions and the glossary.
3. Refine R-01 to R-12 into FR and NFR rows with priority, target and verifying task. Cross-check
   that every target referenced by T08, T10, T11, T26, T30 and T31 exists.
4. Write the risk register and the cost map. Every claim about free-tier limits or regulation
   (SEBI, Vercel Hobby terms, Pantheon sandbox sleep, GitHub cron delay, Claude pricing) gets
   a source URL and a "checked 2026-11-01" date. Otherwise mark it **unverified**.
5. Write ADR-0001 to ADR-0006 and update the ADR index.
6. Write `naming.md`. For each check, record the method, the source URL, the date and the result.
   Some checks cannot be done reliably by an agent: the IP India trademark search (form
   based), WHOIS and registrar availability, and app-store search. Record these as
   "not verifiable by agent, owner action" with exact instructions. The outcome must still be
   set. Default to "keep as internal codename only" until the owner actions close.
7. Collect the open questions (ID, question, owner, resolution or ticket task ID). Every item must be resolved or ticketed.
8. Update TRACEABILITY.md. Run `scripts/check-names.sh` and markdownlint, if available, on new docs.
9. Hand over for review. The technical-architect writes `docs/tasks/T02/review.md` and records
   sign-off in the solution-architecture document.

## Interfaces touched

| Interface | Change | Consumers |
|---|---|---|
| Requirement IDs (FR-nn, NFR-nn) | New, stable IDs; never renumber after sign-off | T03, T04, all test cases, TRACEABILITY |
| NFR targets | New measurable numbers | T08, T10, T11, T26, T30, T31 |
| ADR-0001 to ADR-0006 | New | T03, T05, T07, T10, T22, T28, T32 (diff ADR) |
| `docs/TRACEABILITY.md` | Refined-ID column or list | T03, T04, every close step |
| Naming outcome | Possibly section 0 of TASKS.md | `scripts/check-names.sh`, all tasks |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Targets are unrealistic for free tiers (cold starts, sandbox sleep) | Medium | Medium | State the environment for each target (DDEV vs dev) and measure warm vs cold separately |
| Uncited claims about free-tier limits or regulation | Medium | High | Review rejects any claim without a URL and date, or the "unverified" label |
| Docs mention a broker trading domain or SDK, even as an example | Low | High | ADR-0006 and the glossary describe the rule generically; review searches for broker names |
| Docs use stale placeholder names | Low | Low | `scripts/check-names.sh` must pass |
| Branding checks cannot be completed by an agent | High | Low | Record them as owner actions and use the conservative interim outcome |
| Mermaid syntax does not render on GitHub | Low | Low | Keep to basic `flowchart` and `sequenceDiagram`; check in GitHub preview |

## Test hooks needed

- No code seams. The tester verifies the document structure against each criterion with grep
  or a checklist. Checks: sections present, every FR and NFR has a priority and target, the
  seven named risks are present, six ADRs exist with all template fields, and naming.md has the
  five checks plus an outcome.
- Command evidence: `scripts/check-names.sh` output, and a grep for broker names or domains with no hits.

## Decisions needed from solution-architect

- None blocking. The solution-architect is the author and makes these calls in the documents:
  the NFR numbers, the naming outcome, and the authentication approach in ADR-0005.
- Owner actions to record, not to block on: the trademark, WHOIS and app-store checks, renaming
  the GitHub repo to lowercase, and the SHA-256 pin from T00 finding 1 (outside T02, listed for visibility).

## Definition of done

- [ ] All T02 acceptance criteria in `docs/TASKS.md` met
- [ ] C1: Plan exists and was reviewed before writing started
- [ ] C2: Docs reviewed by the technical-architect; findings resolved; sign-off recorded
- [ ] C3: Every criterion maps to an executed test case with evidence
- [ ] C4: CI is n/a (before T08). `check-names.sh` and markdown checks pass
- [ ] C5: TRACEABILITY.md, ADR index and architecture README updated
- [ ] C6: No secrets; `.env.example` unchanged (no new variables)
- [ ] C7: Docs render on GitHub; no external assets
