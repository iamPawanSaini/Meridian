# .github

GitHub configuration.

| Path | Task | Purpose |
|---|---|---|
| `workflows/ci.yml` | T08 | "Meridian CI": quality suite, tests, coverage, secret scan, dependency audit |
| `workflows/daily-run.yml` | T20 | "Meridian daily run": engine on weekdays at 10:30 UTC (16:00 IST) |
| `workflows/deploy-drupal.yml` | T07 | `deploy-drupal`: runs `scripts/deploy-drupal.sh` for `apps/drupal` to Pantheon dev. Skips itself until the variable `PANTHEON_SITE` is set |

## deploy-drupal.yml (T07)

A thin wrapper. It runs only when the repository variable `PANTHEON_SITE` is set; otherwise the
`skip` job prints "deploy-drupal: not configured (PANTHEON_SITE unset), skipped". Secrets
`TERMINUS_MACHINE_TOKEN` (a Pantheon PAT) and `PANTHEON_DEPLOY_KEY` are read only through `env:`.
Actions are pinned by commit SHA; Terminus 4.3.3 is pinned by SHA-256. Lint with actionlint
1.7.12 (`.tools/actionlint .github/workflows/deploy-drupal.yml`). Setup: `docs/runbooks/deploy.md`.
