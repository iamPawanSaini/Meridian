# ADR-0006: No live trading; Meridian is simulation only

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-11-01 |
| Deciders | solution-architect (author), technical-architect (reviewer, T02 sign-off), project owner |

## Context

Meridian scores NSE equities and simulates what would happen if its decisions were acted on
(R-04, R-05). Live trading would bring regulatory duties, financial risk and a far stronger
need for security and testing.

SEBI's retail algorithmic trading framework covers orders placed through broker APIs:

- The framework circular is dated 2025-02-04.
- Its implementation timeline was extended by
  [circular SEBI/HO/MIRSD/MIRSD-PoD/P/CIR/2025/132](https://www.sebi.gov.in/legal/circulars/sep-2025/extension-of-timeline-for-implementation-of-sebi-circular-dated-february-04-2025-on-safer-participation-of-retail-investors-in-algorithmic-trading-_96979.html),
  dated 2025-09-30 (title and date checked 2026-11-01).
- The new timeline and the framework's detailed obligations are **unverified**.

Publishing recommendations to others can also bring the SEBI (Research Analysts)
Regulations, 2014 into play
([SEBI](https://www.sebi.gov.in/legal/regulations/dec-2024/securities-and-exchange-board-of-india-research-analysts-regulations-2014-last-amended-on-december-16-2024-_90153.html),
checked 2026-11-01; see RK-06).

## Decision

Meridian is **simulation only** in this project:

- **No order capability.** No broker SDK, broker API client, order-placement code, order
  routing, broker account credentials or broker trading domains appear anywhere in the
  repository: code, tests, config, fixtures or docs. Docs describe this rule generically and
  name no broker.
- **Positions are virtual.** They exist only as simulation records in Postgres and Drupal.
  Costs are modelled from config.
- **Enforcement:**
  - A static check fails CI if any broker SDK import or broker domain appears (T18).
  - T30 confirms by a static check plus manual review.
  - `scripts/check-names.sh` and code review apply as usual.
- **Market data** comes only through the data-provider interface from non-broker sources
  (T15).
- **No live mode.** There is no "live" flag, no dormant code path and no secret slot for
  broker credentials.
- **Future broker integration** is a separate project with its own regulatory review and
  approval. It is recorded in T33 and not started here. Any request that implies live
  trading stops work and goes to the owner.

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
|---|---|---|---|
| Paper trading through a broker's sandbox API | Realistic fills | Brings in a broker SDK, an account and credentials. The capability is one config change away from live | Violates the no-SDK rule and widens risk |
| Live mode behind a feature flag, off by default | Ready for later | The capability exists and could be switched on by mistake or by a compromised secret | Any live capability is out of scope |
| Read-only broker market-data API | Better Indian data | Still adds a broker SDK, account and terms | Data quality is handled by the provider interface and the T33 backlog (licensed data vendors) |

## Consequences

- Positive: No order risk, a smaller regulatory surface and a simpler security model. The
  simulation can be tested deterministically.
- Negative: Simulated fills ignore slippage, liquidity and partial fills beyond the modelled
  costs. Results overstate what live trading would achieve, and reports must say so (T25,
  T31).
- Follow-ups: T18 (static check), T30 (verification), T31 (caveats in the analysis), T33
  (separate project for any broker work).
