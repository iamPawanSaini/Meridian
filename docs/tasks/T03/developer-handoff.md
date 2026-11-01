# T03: Developer handoff

| Field | Value |
|---|---|
| Task | T03 |
| Author | technical-architect |
| Date | 2026-11-01 |
| For | developer (plan step 12): files outside `docs/` that the architect cannot write |
| Revision | 2 (2026-11-01), after the solution-architect review `docs/tasks/T03/review.md` |

## Revision 2: what changed

Re-apply section 1 (`.env.example`) in full. Section 2 (`.spectral.yaml`) is unchanged.

| Change | Reason |
|---|---|
| `MERIDIAN_DATABASE_URL` password and `MERIDIAN_POSTGRES_PASSWORD` now use the same placeholder `change-me-local` (was `change-me` and blank) | Review finding 12(d): the comment says they must match |
| Comments on `MERIDIAN_REVALIDATE_SECRET` and `MERIDIAN_SESSION_SECRET` state "at least 32 random bytes" | Review finding 12(b) |
| Comment on the dashboard group: Vercel sets these for the Production environment only | Review finding 12(a) |
| Comment on `PANTHEON_DEPLOY_KEY`: RSA or ECDSA-256 key of a dedicated Pantheon machine user | Review finding 11(b) |
| Comment on OAuth client IDs and secrets: created by the T10 drush provisioning command | Review finding 12(c) |

No variable was added, removed or renamed in revision 2: the set of 22 names still equals
the D7 matrix.

Create or replace the two files below exactly as given, then commit with a `T03:` prefix.
After that, `python3 -I docs/tests/T03/check_env_parity.py` and TC-T03-09 should pass.

## 1. `.env.example` (replace the whole file)

The names equal the D7 matrix in `docs/architecture/technical-design.md`. All secret values
are blank. `NEXT_PUBLIC_DRUPAL_BASE_URL` is removed and replaced by the server-only
`DRUPAL_BASE_URL` (FR-21).

```dotenv
# Meridian environment variables (names only, placeholder values).
# Copy to .env for local use. .env is git-ignored and must never be committed.
# Every variable the project reads must be listed here (common criterion C6).
# The full matrix (consumer, secret or not, store per environment) is section D7 of
# docs/architecture/technical-design.md. Keep both in sync.

# --- Engine: database and LLM (T14, T17) ------------------------
# Postgres connection. Deployed dev uses Neon with sslmode=require (GitHub Secrets).
MERIDIAN_DATABASE_URL=postgresql://meridian:change-me-local@meridian-postgres:5432/meridian
# Claude API key. Optional locally: tests use the fake LLM client.
ANTHROPIC_API_KEY=
# Model name for the analyst review.
MERIDIAN_LLM_MODEL=

# --- Local Postgres container (T06) -----------------------------
# Password of the local meridian-postgres user; must match the password in
# MERIDIAN_DATABASE_URL. Change both together in your local .env.
MERIDIAN_POSTGRES_PASSWORD=change-me-local

# --- Engine to Drupal publisher and watchlist read (T10, T13, T19)
MERIDIAN_DRUPAL_BASE_URL=https://meridian.ddev.site
# OAuth consumer meridian-engine (scopes meridian_ingest, meridian_watchlist_read).
# IDs and secrets come from the T10 drush provisioning command (prints each secret once).
MERIDIAN_DRUPAL_INGEST_CLIENT_ID=
MERIDIAN_DRUPAL_INGEST_CLIENT_SECRET=

# --- On-demand revalidation, engine to meridian-web (T19, T21) --
# Inside DDEV the engine reaches meridian-web over the internal network.
MERIDIAN_WEB_REVALIDATE_URL=http://meridian-web:3000/api/revalidate
# Shared secret, at least 32 random bytes; same value for the engine and meridian-web.
MERIDIAN_REVALIDATE_SECRET=
# Time-based revalidate interval for meridian-web data fetches, in seconds.
MERIDIAN_REVALIDATE_SECONDS=300

# --- Next.js dashboard meridian-web, server only (T21, T22) -----
# Never prefix these with NEXT_PUBLIC_ (FR-21). On Vercel, set them for the Production
# environment only; Preview deployments run in mock API mode with no Drupal secrets.
DRUPAL_BASE_URL=https://meridian.ddev.site
# OAuth consumer meridian-web (client credentials, scope meridian_dashboard_read).
DRUPAL_READ_CLIENT_ID=
DRUPAL_READ_CLIENT_SECRET=
# OAuth consumer meridian-web-login (authorization code with PKCE).
DRUPAL_LOGIN_CLIENT_ID=
DRUPAL_LOGIN_CLIENT_SECRET=
# Public base URL of meridian-web, used for the OAuth redirect URI (host fixed in T06).
MERIDIAN_WEB_BASE_URL=https://meridian.ddev.site:3001
# Session cookie encryption key, at least 32 random bytes.
MERIDIAN_SESSION_SECRET=

# --- Drupal Simple OAuth keys (T10) -----------------------------
# Leave blank to use the defaults apps/drupal/private/oauth/private.key and public.key.
# The key files are secrets and are git-ignored; these are only paths.
MERIDIAN_OAUTH_PRIVATE_KEY_PATH=
MERIDIAN_OAUTH_PUBLIC_KEY_PATH=

# --- Pantheon deploy and DDEV pull (T07) ------------------------
# Set the Terminus token in your global DDEV config, not in this repo. Listed for parity.
TERMINUS_MACHINE_TOKEN=
PANTHEON_SITE=meridian
# SSH private key (RSA or ECDSA-256; not ed25519) of a dedicated Pantheon machine user
# with access to this site only. GitHub Secrets only; leave blank locally.
PANTHEON_DEPLOY_KEY=
```

Notes:

- The port `3001` for `meridian-web` on DDEV is a placeholder. T06 fixes the real HTTPS host
  and updates this file and the D7 matrix together.
- `TERMINUS_MACHINE_TOKEN` and `PANTHEON_DEPLOY_KEY` stay blank in every local `.env`.

## 2. `.spectral.yaml` (new file at the repo root)

```yaml
# Spectral ruleset for the OpenAPI contract (T03; version pinned in T04a).
# Run: npx @stoplight/spectral-cli lint docs/architecture/openapi.yaml --ruleset .spectral.yaml --fail-severity=warn
# Do not switch off core rules here. Fix the contract instead.
extends:
  - spectral:oas
```

## 3. Checks after the change

```bash
python3 -I docs/tests/T03/check_env_parity.py
docs/tests/T03/run-checks.sh
```
