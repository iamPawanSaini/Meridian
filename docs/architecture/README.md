# docs/architecture

Solution architecture (T02), technical design (T03), diagrams, the ingest contract
`openapi.yaml` (T03) and the branding check `naming.md` (T02).

| Document | Task | Contents |
|---|---|---|
| [solution-architecture.md](solution-architecture.md) | T02 | Context, container and data-flow diagrams (Mermaid); scope and non-goals; assumptions; refined FR and NFR with targets; risk register; cost map; glossary; open questions; sign-off |
| [technical-design.md](technical-design.md) | T03 | D1 content model, D2 Postgres schema and migration plan, D3 idempotency, D4 outbox and retry, D5 ingest contract, D6 authentication, D7 environment and secrets matrix, D8 repo and deploy; NFR numbers; sign-off |
| [openapi.yaml](openapi.yaml) | T03 | OpenAPI 3.1 engine-to-Drupal ingest contract and watchlist read |
| [naming.md](naming.md) | T02 | Branding check for "Meridian" (domains, GitHub and Vercel handles, IP India classes 9, 36, 42, app stores, repo name) and its outcome |

Decisions are recorded separately in [`docs/adr/`](../adr/README.md) (ADR-0001 to ADR-0006
from T02).
