# T03: Solution-architect decisions on the technical design plan

| Field | Value |
|---|---|
| Task | T03 |
| Author | solution-architect |
| Date | 2026-11-01 |
| Answers | `docs/tasks/T03/plan.md`, section "Decisions needed from solution-architect" |
| Related | `docs/architecture/solution-architecture.md` (approved T02), ADR-0003, ADR-0005 |

## D-1: Hosted Postgres vendor (OQ-01)

**Decision:** Confirmed: **Neon Free** is the dev Postgres. T28 provisions it. T03 records
the choice and resolves OQ-01. Supabase Free is the fallback.

**Rationale:**

- Supabase Free pauses projects after 1 week of low activity
  ([Supabase pricing](https://supabase.com/pricing), checked 2026-11-01). A holiday week can
  cause that.
- Neon Free keeps data when a limit is hit
  ([Neon FAQ](https://neon.com/faqs/free-plan-limits-and-quotas), checked 2026-11-01). Over
  quota, compute is suspended and writes over the storage cap fail.
- Neon Free limits ([Neon pricing](https://neon.com/pricing), checked 2026-11-01):
  - 1 GB storage per project, far above the A-09 estimate of under 100 MB a year.
  - 100 CU-hours per month. About 22 runs of up to 15 min each, plus migrations, is under
    10 CU-hours.
  - Scale to zero after 5 min, which only adds a cold start the engine absorbs with
    connection retry.

**Consequences:**

- The schema stays vendor-neutral: plain Postgres 16, no extensions beyond core, no
  vendor-specific APIs. `DATABASE_URL` uses TLS (`sslmode=require`).
- The engine retries the connection on start (cold compute).
- Neon Free has 1 manual snapshot and no scheduled snapshots
  ([Neon pricing](https://neon.com/pricing), checked 2026-11-01). NFR-16 backups are
  therefore a daily `pg_dump` uploaded as a workflow artifact (T29). The design must not rely
  on Neon snapshots.
- T28 re-checks the limits above before provisioning and records the date. Whether Alembic
  should use a pooled or a direct connection is **unverified**; T28 confirms it.

## D-2: NFR-04 and NFR-05 final values (OQ-07)

**Decision:** Accepted with one addition.

- The T02 values stay **provisional**: NFR-04 at most 30 s for 500 records on DDEV, and
  NFR-05 p95 at most 500 ms on DDEV and at most 1,500 ms on Pantheon dev.
- A **measurement gate** at the end of T09, before T10 coding starts, records the final DDEV
  values in `technical-design.md`. They can move in either direction, with the raw
  measurement attached. This decision authorises that change, so no ADR is needed.

**Pantheon dev (addition):**

- Pantheon times out web requests at **59 s** at the edge. PHP `max_execution_time` is 120 s,
  and PHP may keep running after the edge cutoff while the client never gets the result
  ([Pantheon timeouts](https://docs.pantheon.io/timeouts), checked 2026-11-01).
- The ingest call is a web request, so set a design budget of **at most 30 s per ingest
  request on Pantheon dev**. That is about half the edge limit, leaving room for cold starts.
- The provisional Pantheon publisher batch is **100 records**. T07 measures it (warm), and
  T28 confirms it on the deployed stack.
- On a 504, a timeout or a 413, the publisher halves the batch and retries. Upserts are
  idempotent, so a timed-out batch that still committed on the server is harmless.
- The API maximum of 500 items per request stays as the contract limit (T10).

**Consequences:**

- T10 starts with real numbers.
- NFR-04 gains a Pantheon dev row: at most 30 s per request at the measured batch size.
- The publisher's adaptive batch size becomes a T19 requirement, and T03 D4 states it.
- If the T09 gate cannot run because T09 slips, T10 proceeds with the provisional values and
  T30 is the backstop.

## D-3: User login flow

**Decision:** Confirmed: **a third, confidential OAuth client `meridian-web-login`**, using
the authorisation code grant with PKCE (S256) and refresh tokens. It is separate from the
read client `meridian-web` (client credentials). One client with two grants is rejected.

**Rationale:**

- **Blast radius.** With a combined client, one secret could mint both machine read tokens
  and user tokens. Separate clients mean separate secrets, separate rotation and separate
  revocation.
- **Scopes in Simple OAuth 6.x.** The Consumer form lets you set default scopes only when the
  client credentials grant is enabled
  ([drupal.org issue 3398468](https://www.drupal.org/i/3398468), checked 2026-11-01). A
  client credentials client also acts as a fixed "client credentials user"
  ([simple_oauth commit](https://git.drupalcode.org/project/simple_oauth/commit/c234a23),
  checked 2026-11-01). Mixing a fixed machine identity with per-user tokens on one consumer
  blurs who a token represents. Separate consumers keep the authorisation matrix (T30)
  clean.
- **Module version.** The current stable Simple OAuth is 6.1.3 (released 2026-10-21) and
  works with `^10.3 || ^11`. The 5.2 branch reaches end of life on 2026-12-09
  ([Simple OAuth project](https://www.drupal.org/project/simple_oauth), checked 2026-11-01).
  T03 targets 6.x.
- **PKCE.** It is good practice even for confidential clients, and it costs nothing.

**Unverified**, for T10 and T22 to confirm on 6.1.x:

- That core Simple OAuth 6.x supports and enforces PKCE on the authorisation code grant.
  The only explicit PKCE-mandatory source found covers the separate `simple_oauth_21` module.
- That one consumer can or cannot hold several grant types.

If PKCE is not enforceable in core 6.x, the flow still uses a confidential client, `state`
and an exact redirect URI. Adding `simple_oauth_21` then needs a dated note in T22 (dependency
policy).

**Consequences:**

- Three OAuth consumers: `meridian-engine` (client credentials; `meridian_ingest` and
  `meridian_watchlist_read`), `meridian-web` (client credentials; `meridian_dashboard_read`)
  and `meridian-web-login` (authorisation code with PKCE; user roles). Exact consumer names
  are T03's to fix within section 0 naming.
- One more secret goes in the D7 matrix (Vercel and DDEV only).
- The redirect URIs are registered exactly per environment: DDEV HTTPS host and the Vercel dev
  URL. Preview URLs are not registered until T22 decides.
- The session cookie is httpOnly, Secure and SameSite=Lax, and tokens stay server-side
  (FR-21).

## D-4: Amendments to the approved T02 document

**Decision:** Allowed as **dated "T03 amendment" entries**, without an ADR, under three
conditions:

1. The edit only adds pointers, clarifications or resolutions. That covers RK-07 naming the
   revalidation secret, the NFR-04 and NFR-05 rows pointing to T03 values, and OQ-01 and
   OQ-07 resolutions.
2. It does not change the decision of any Accepted ADR.
3. It does not loosen any FR or NFR, except the NFR-04 and NFR-05 change authorised in D-2.

Each amendment is listed in an "Amendments" table in `solution-architecture.md` (date, task,
section, change, reviewer). The Sign-off table gets one line: "T03 amendment, 2026-11-01,
reviewed by solution-architect". Requirement IDs are never renumbered.

**Rationale:** ADRs record decisions. These edits record the follow-through of decisions
already made (T02 notes 17 and 18, OQ-01 and OQ-07). An ADR per pointer would bury the real
decisions.

**Consequences:** Anything that changes an Accepted ADR or loosens a target outside D-2
needs a new superseding ADR. The T03 review checks this rule against the amendment list.

## D-5: `web-next` wording in `docs/TASKS.md` section 1

**Decision:** **Fix in T03** as a minimal, dated correction. In the section 1 table, change
the "Local (DDEV/Docker)" column so it matches section 0:

- `engine` container becomes `meridian-engine`.
- `postgres` container becomes `meridian-postgres`.
- `web-next` container (node) becomes `meridian-web` container (node).

No other text in `TASKS.md` changes.

**Rationale:**

- Section 0 is the owner's decided naming, and section 1 contradicts it. T02 note 12 named
  only `web-next`, but the `engine` and `postgres` entries have the same mismatch.
- T05 and T06 build the containers "per T03" and read section 1. Leaving the contradiction
  until T32 risks a wrongly named service.
- A three-token edit is the smallest change that removes the conflict.

**Consequences:**

- The T03 commit message and review mention the edit, so the owner sees it in the PR.
- `scripts/check-names.sh` is unaffected: these are not the banned placeholder names.
- If the owner objects, revert and ticket the change to T32.

## Summary

| # | Question | Answer |
|---|---|---|
| D-1 | OQ-01 Postgres vendor | Neon Free confirmed. Vendor-neutral schema. Backups by `pg_dump` artifact. T28 provisions and re-checks |
| D-2 | OQ-07 NFR-04 and NFR-05 | Accepted: provisional values plus a measurement gate at the end of T09. Pantheon budget at most 30 s per request (edge limit 59 s), provisional batch of 100, halved on timeout |
| D-3 | User login | Separate confidential `meridian-web-login` client, authorisation code with PKCE. PKCE enforcement in Simple OAuth 6.x is unverified, for T10 and T22 |
| D-4 | T02 doc edits | Dated "T03 amendment" entries, with no ADR unless an ADR decision changes or a target loosens outside D-2 |
| D-5 | Section 1 naming | Fix in T03: `meridian-engine`, `meridian-postgres`, `meridian-web` |
