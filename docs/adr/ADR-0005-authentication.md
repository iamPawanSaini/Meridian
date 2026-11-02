# ADR-0005: Authentication with OAuth client credentials for services and Drupal accounts for users

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-11-01 |
| Deciders | solution-architect (author), technical-architect (reviewer, T02 sign-off) |

## Context

All dashboard and API access must be authenticated and least-privilege (R-09, FR-19 to
FR-21). There are three callers:

1. The engine, which writes to Drupal through the ingest API.
2. `meridian-web` server code, which reads Drupal through JSON:API.
3. Human users (the owner plus at most 5 invited reviewers, A-03), who use the dashboard and
   the Drupal admin.

Raw LLM output must be visible to administrators only (FR-20). Tokens must never reach the
browser (FR-21). The dashboard must stay private, so that Meridian does not publish research
to the public (RK-06).

Vercel's own password protection is a paid add-on on Pro, at USD 20 per month per protected
project ([Vercel Hobby](https://vercel.com/docs/plans/hobby), checked 2026-11-01), so it is
not the primary control.

## Decision

Drupal is the single identity and authorisation authority. It uses OAuth 2 through a Drupal
OAuth server module (Simple OAuth is the expected choice; T03 confirms).

- **Engine to Drupal: OAuth client credentials.** A dedicated `engine-ingest` client and
  role with two scopes:
  - An ingest scope. It can create and update Meridian records through `meridian_ingest`
    only.
  - A separate read-only watchlist scope. It can read Watchlist Items only (ADR-0003).

  It cannot read users or other content, delete content or reach admin routes (T10).
- **Engine to Next.js: on-demand revalidation.** After a publish, the engine calls a
  `meridian-web` revalidation route authenticated by a shared secret (ADR-0001). The secret
  lives only in the platform secret stores. The route only clears cached data and returns
  no data.
- **Next.js to Drupal: OAuth client credentials, read-only.** A dedicated read client and
  scope for fields every dashboard role may see. It cannot write.
- **Users: Drupal accounts.** Users sign in to `meridian-web` through Drupal (an OAuth
  authorisation-code flow with PKCE, or an equivalent server-side flow chosen in T03 and
  T22). Users have the `administrator` or `analyst` role. Administrator-only fields, such as
  the raw LLM output, are fetched with the signed-in user's own token, so Drupal enforces
  field access.
- **Sessions and tokens** live only on the server: an httpOnly, secure, SameSite cookie for
  the session, and tokens in server memory or encrypted session storage. Nothing goes into
  client bundles or browser storage.
- **Least privilege** throughout: one client per caller, the narrowest scope, short-lived
  access tokens, and secrets only in platform secret stores.
- **No public sign-up.** The owner creates accounts.

Endpoint lists, scope names, token lifetimes and the flow details are T03 work.

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
|---|---|---|---|
| Static API keys or Basic auth for engine and Next.js | Simple | No scopes or expiry. Keys tend to leak into logs. Hard to rotate | Fails least privilege and rotation |
| Separate identity provider (hosted auth service) for users | Polished login | One more vendor, free tier and user store to sync with Drupal roles | Two sources of truth for roles. The Drupal admin still needs Drupal accounts |
| Vercel Deployment Protection or password protection only | No app code | Password protection is a paid Pro add-on. Neither gives per-role field access | Not least-privilege. Kept only as optional defense in depth (OQ-08, T22) |
| Shared JWT secret between engine, Next.js and Drupal | Stateless | A shared secret across three systems widens the blast radius. Custom crypto code | Larger leak impact than per-client OAuth |

## Consequences

- Positive: One place to manage users, roles and revocation. Each machine client is scoped
  to exactly its job. The authorisation matrix (T30) has one authority to test.
- Negative: OAuth setup and key management on Drupal (key files must stay out of git).
  Login depends on Drupal being awake, so the first login after idle can take about 30 s
  (RK-04).
- Follow-ups: T03 (auth design, scopes, env matrix including the revalidation secret), T10
  (engine client: ingest and watchlist read scopes), T11 (read client, field access), T19
  and T21 (revalidation call and route), T22 (login flow, route protection), T30 (authorisation
  matrix), OQ-08.
