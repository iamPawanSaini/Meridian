# Runbook: CI secrets, variables and merge settings

| Field | Value |
|---|---|
| Owner | owner (Pawan Kumar) |
| Last verified | 2026-11-03 by developer (file content only; the GitHub settings are set by the owner and not yet verified) |
| Applies to | GitHub Actions (`ci.yml`, `deploy-drupal.yml`, planned `daily-run.yml`), repository settings |

Task T08. Plan: `docs/tasks/T08/plan.md`. This file lists **names only**. A value is never
written in this repository. `scripts/check_ci.py` (rule 4) fails when a workflow uses a
`secrets.NAME` or `vars.NAME` that this file does not name (`GITHUB_TOKEN` is exempt).

## When to use

- You add or change a secret or variable in a workflow, and must record its name here.
- You rotate a credential, or set up the repository (merge methods, Actions permissions).
- You review what CI can reach.

## Prerequisites

- Owner access to the repository settings on GitHub (Settings, Secrets and variables, Actions).
- For the merge-method and ruleset settings: the repository is public (decision SA-1,
  `docs/tasks/T08/decision-repo-visibility.md`), because rulesets are not enforced on a private
  repository on GitHub Free.

## Steps

### What each workflow uses

| Workflow | Secrets | Variables |
|---|---|---|
| `ci.yml` ("Meridian CI") | none. Only the read-only `GITHUB_TOKEN` | none |
| `deploy-drupal.yml` (T07) | `TERMINUS_MACHINE_TOKEN`, `PANTHEON_DEPLOY_KEY` | `PANTHEON_SITE`, `DEPLOY_SMOKE_BUDGET`, `DEPLOY_SMOKE_HEADER` |
| `daily-run.yml` (planned, T20) | see "Planned" below | see "Planned" below |

`ci.yml` has `permissions: {}` at the top and `contents: read` per job. It never reads a secret,
so a pull request from a branch or a fork cannot reach one. `.env.example` gains no new name
from T08.

### Secrets in use

| Name | Used by | Where it is set | Who rotates it, and when |
|---|---|---|---|
| `TERMINUS_MACHINE_TOKEN` | `deploy-drupal.yml` | Repository secret, named, not set yet. A Pantheon personal access token of the machine user (T07) | Owner, before it expires (90 days after creation). See `docs/runbooks/deploy.md` |
| `PANTHEON_DEPLOY_KEY` | `deploy-drupal.yml` | Repository secret, named, not set yet. The SSH private key of the machine user (T07) | Owner, on suspicion of exposure or when the key changes. See `docs/runbooks/deploy.md` |

### Variables in use

| Name | Used by | Where it is set | Purpose |
|---|---|---|---|
| `PANTHEON_SITE` | `deploy-drupal.yml` | Repository variable | The Pantheon site machine name. The deploy job runs only when it is set |
| `DEPLOY_SMOKE_BUDGET` | `deploy-drupal.yml` | Repository variable (optional) | Seconds the smoke check retries |
| `DEPLOY_SMOKE_HEADER` | `deploy-drupal.yml` | Repository variable (optional) | One extra non-secret request header for the smoke check. **KD-13 item 2 (2026-11-04): none set, not applicable.** No `Deterrence-Bypass` value is in use. The rule stays: if the header ever holds a bypass value, it must move to a repository secret of the same name in a separate commit (cites T07), and this row moves to the secrets table |

### Planned (T20, not set yet)

Names from `docs/architecture/technical-design.md`, D7. They are not used by any workflow today.
T20 adds `daily-run.yml` and keeps this table in step.

| Name | Kind | Planned use |
|---|---|---|
| `MERIDIAN_DATABASE_URL` | secret, planned, T20 | Engine database URL |
| `ANTHROPIC_API_KEY` | secret, planned, T20 | Analyst review |
| `MERIDIAN_DRUPAL_INGEST_CLIENT_SECRET` | secret, planned, T20 | Drupal ingest client |
| `MERIDIAN_REVALIDATE_SECRET` | secret, planned, T20 | Dashboard revalidation |
| `MERIDIAN_LLM_MODEL` | variable, planned, T20 | Model name |
| `MERIDIAN_DRUPAL_BASE_URL` | variable, planned, T20 | Drupal base URL |
| `MERIDIAN_DRUPAL_INGEST_CLIENT_ID` | variable, planned, T20 | Drupal ingest client ID |
| `MERIDIAN_WEB_REVALIDATE_URL` | variable, planned, T20 | Dashboard revalidation URL |

### Repository settings the owner applies

The exact steps and the demo are in `docs/tasks/T08/plan.md`, KD-10 and KD-11. In short:

1. Settings, General, Pull Requests: **Allow merge commits** on; **squash** and **rebase** off.
   Reason (decision D-3 of T04a, and the T07 rollback decision): the commit-range check
   (`check_commit_msg.py --range`) and the evidence cite commit SHAs, and squash or rebase would
   rewrite them. The `main` ruleset also allows the Merge method only.
2. Settings, Actions, General: workflow permissions "Read repository contents and packages
   permissions"; "Allow GitHub Actions to create and approve pull requests" off; allow only
   GitHub-owned actions plus `shivammathur/setup-php` at the SHA in `.github/README.md`;
   require approval for fork pull request workflows from all outside collaborators.
3. Settings, Rules, Rulesets: a ruleset `main` with an empty bypass list, a required pull
   request (0 approvals, Merge only), and the one required status check `ci-ok`.

## Verification

- `python3 scripts/check_ci.py` prints PASS for rule 4 (every name used by a workflow is on this
  page).
- `grep -rn 'secrets\.\|vars\.' .github/workflows/` shows only the names above.
- The file holds no value: a scan with `.tools/gitleaks dir docs/runbooks/ci-secrets.md` finds
  nothing.

## Rollback

- A credential that may have leaked: revoke it at its issuer first (Pantheon account, SSH keys),
  then replace it in Settings, Secrets and variables, Actions, and re-run the failed workflow.
- A wrong setting: change it back in the same settings page. A removed required check blocks
  nothing and also protects nothing, so re-add `ci-ok` before the next merge.

## Escalation

The owner is the only person who can change repository settings. If `ci-ok` cannot be selected
as a required check, run `Meridian CI` once on a pull request first: GitHub offers a check name
only after it has reported once.
