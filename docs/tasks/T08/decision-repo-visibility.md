# T08: Solution-architect decision on repository visibility (SA-1, OQ-03)

| Field | Value |
|---|---|
| Task | T08 |
| Author | solution-architect |
| Date | 2026-11-03 |
| Answers | `docs/tasks/T08/plan.md` (Draft), "Decisions needed from solution-architect", SA-1; fact 12, KD-10, KD-11, risk row 1, O-1 |
| Related | `solution-architecture.md` OQ-03, NFR-09, NFR-10, RK-05, RK-06, RK-10, cost map; `docs/TASKS.md` T08 AC2 |
| Decision owner | project owner (OQ-03 owner). This file is the recommendation; it takes effect when the owner confirms it |

## Context

T08 AC2 needs a merge that GitHub actually blocks. The repository `iamPawanSaini/Meridian` is
owned by a personal account. Facts checked on 2026-11-03:

- **Rulesets:** available "in public repositories with GitHub Free and GitHub Free for
  organizations, and in public and private repositories with GitHub Pro, GitHub Team, and
  GitHub Enterprise Cloud" (S1). This is the docs availability note as returned by a search on the
  check date. The fetched page body did not render the note, so the exact wording is from the
  search result.
- **Protected branches:** listed under GitHub Pro as "Advanced tools and insights in private
  repositories". GitHub Free for personal accounts gives "unlimited public repositories with a
  full feature set, and ... unlimited private repositories with a limited feature set" (S2).
- **Pricing page:** "Repository rules" is marked "Public repositories" for Free. "Status checks"
  are included for Free, but a check can only block a merge through a rule or a protected
  branch (S3).
- **Conclusion (verified):** on GitHub Free, a private repository cannot enforce a required
  check. So AC2 cannot be shown on private Free.
- **Actions:** standard GitHub-hosted runners in public repositories are free and do not use
  the included allowance. For private repositories, GitHub Free includes USD 12 a month and
  GitHub Pro USD 18 a month. A Linux 2-core runner costs USD 0.006 a minute, so that is about
  2,000 and 3,000 minutes (our calculation). With no payment method, "usage is blocked once you
  consume the included compute usage" (S4). The page does not say whether minutes are rounded
  up per job. Per-job rounding, which would make five parallel jobs cost more, is
  **unverified**.
- **Pro price:** USD 4 a month, or USD 48 a year. This comes from secondary sources only (S8).
  GitHub's own pages checked do not state it, so the price is **unverified**. GitHub Team is
  "USD 4 per user / month" (S3), but it needs an organization.
- **What making the repository public does** (S5): "The code will be visible to everyone".
  "Anyone can fork your repository." "Actions history and logs will be visible to everyone."
  "All push rulesets will be disabled" (none are used). "Stars and watchers ... will be erased."
- **Scheduled workflows:** "In a public repository, scheduled workflows are automatically
  disabled when no repository activity has occurred in 60 days" (S6). This is already RK-05.
- **Fork pull requests:** "With the exception of `GITHUB_TOKEN`, secrets are not passed to the
  runner when a workflow is triggered from a forked repository" (S6). `ci.yml` uses no secrets.
  `deploy-drupal.yml` runs only on `push` to `main` and on `workflow_dispatch`, and a fork
  cannot trigger either.
- **Secret scanning:** in public repositories, "Secret scanning runs automatically for free", and
  it "scans your entire Git history on all branches" (S7). This adds a second, independent
  layer to gitleaks.
- **Commit email:** "Any commits you made prior to changing your commit email address are still
  associated with your previous email address" (S9). The work email in old commits becomes
  public with the repository. Only a history rewrite would remove it. The plan forbids rewrites,
  because evidence cites SHAs, and GitHub also keeps `refs/pull/*` for PRs #1 and #2.

## Decision

**Make the repository public**, after the pre-publication checklist below. Do this before KD-10
O-5 (ruleset). Do not use private on GitHub Free. If the owner does not accept the exposure
listed under "Consequences", the fallback is **private with GitHub Pro**. That fallback needs an
owner-approved NFR-09 amendment (see "Alternatives").

### Pre-publication checklist (owner, with the main session; in this order)

1. **Full-history secret scan over every ref GitHub will publish**, including the PR refs:

   ```bash
   git fetch origin '+refs/heads/*:refs/remotes/origin/*' '+refs/pull/*/head:refs/remotes/origin/pr/*' --tags
   .tools/gitleaks git --redact --no-banner --config .gitleaks.toml --log-opts="--all" .
   ```

   Pass: 0 findings. Use the T08 KD-4 pinned binary if it is installed. Otherwise use gitleaks
   8.30.1 from the release page with its checksum verified. Check the `--log-opts` flag against
   `gitleaks git --help` (**unverified** flag spelling for 8.30.1). If anything is found, stop:
   - a real secret is rotated first and stays rotated. The history is not rewritten;
   - a false positive is allowlisted by fingerprint only with a solution-architect decision
     (plan risk row 3).
2. **Repository variables printed in logs.** Variables are not masked. `deploy-drupal.yml` passes
   `vars.DEPLOY_SMOKE_HEADER` into `env:`, and the runner prints step environment values in the
   log. If that variable holds a `Deterrence-Bypass` value, move it to a **secret** of the same
   name before going public. Then change the `vars.` reference to `secrets.` (a T07 follow-up,
   reviewed). `PANTHEON_SITE` and `DEPLOY_SMOKE_BUDGET` are not sensitive. Also review the
   existing `deploy-drupal` run logs and delete any run that shows something you do not want
   public (Actions, the run, "Delete workflow run").
3. **Personal data in the tree.** One T07 evidence file
   (`docs/tests/T07/evidence/TC-T07-56.20261103T062710Z.txt`) contains the owner's personal
   address. The other addresses in `docs/` are `example.com` or `example.in` placeholders.
   Accept it or redact it in a new commit; the history keeps it either way.
4. **Commit email.** Accept that the existing commits show the work email. Check the employer's
   policy on personal projects that show a work address (an owner matter, not assessed here).
   From now on, use the personal account's `noreply` address and turn on "Keep my email
   addresses private" and the block on command-line pushes that expose the email (setting name
   **unverified**). If exposing the work email is not acceptable, choose the fallback
   (private with Pro). Do not rewrite history.
5. **README notice.** Add a top-level statement in a reviewed commit: "Simulation-only research
   software. It places no orders and gives no investment advice." This applies FR-30 to the
   public repository and supports the RK-06 posture.
6. **Flip:** Settings, General, Danger Zone, "Change visibility", Public.
7. **Settings straight after the flip:**
   - Code security: turn on secret scanning and push protection (free for public repositories,
     S7).
   - Actions, General, "Fork pull request workflows from outside collaborators": require approval
     for all outside collaborators (option wording **unverified**; pick the strictest).
   - Then KD-10 O-3 to O-5 as planned.

## Reasons

1. **It is the only USD 0 option that meets AC2** (S1 to S3). NFR-09 stays intact.
2. **CI minutes stop being a budget.** Public standard runners are free (S4). On private Free,
   the five-job CI, the daily run (about 22 x 15 min) and a later nightly heavier set would share
   about 2,000 minutes. Once they run out, CI is blocked and so is every merge.
3. **Nothing in the repository depends on secrecy.** Secrets live only in GitHub Secrets and env
   vars, gitleaks runs in pre-commit and (from T08) over the full history, and GitHub secret
   scanning adds a second check for free. The Pantheon dev URL is publicly reachable in any case.
4. **The regulatory posture is unchanged**, if the output rule below holds. RK-06 is about
   publishing recommendations to others. Code, specs and synthetic fixtures are not
   recommendations. The rule keeps real decisions off public surfaces.

## Alternatives considered

| Option | Cost | AC2 | Why not chosen |
|---|---|---|---|
| Public (chosen) | USD 0 | Met | n/a; exposure handled by the checklist and the output rule |
| Private with GitHub Pro | about USD 4 a month (**unverified**, S8) | Met | Breaks NFR-09 ("USD 0 per month for hosting ... Only the Claude API is paid"; GitHub Actions is named there). Needs an owner-approved NFR-09 change, for example "USD 0 per month, except GitHub Pro (USD 4 a month) for branch protection on a private repository". CI and the daily run then share about 3,000 minutes. **This is the fallback** if the owner rejects the exposure |
| Private on GitHub Free, AC2 recorded as not met | USD 0 | Not met | R-12 exists so that a red CI result blocks a merge. Without enforcement, `ci-ok` only advises, and AC2 would stay open for the life of the project. It also risks running out of minutes (reason 2) |
| Move the repository to a free organization | USD 0 | Public only | Same visibility rule as personal Free (S1). It adds an org and changes `iamPawanSaini/Meridian` in every link, and gains nothing |
| GitHub Team (organization) | USD 4 per user a month (S3) | Met | Same cost problem as Pro, plus the organization move |

## Consequences

- **Output rule (new, binding on T19, T20, T29, T31): no simulated decision content goes on a
  public GitHub surface.** Decision content means symbol-level BUY/AVOID/VETO results, scores,
  LLM text, positions and P&L by symbol. Public surfaces are workflow logs, step summaries,
  artifacts, issues, and files committed to the repository. Allowed: counts, statuses,
  durations, error classes, run IDs. Specifically:
  - T20: the "Run summary uploaded as workflow artifact" (TASKS T20 AC) holds aggregates only.
  - RK-10: the daily Postgres backup must not be a plain workflow artifact. Encrypt it
    (for example with `age`, with the public key in the repo and the private key held offline by
    the owner), or store it outside GitHub. T28 or T29 decides which; the solution-architect
    reviews.
  - T29: alert issues carry the run ID, status and error class, never decision rows.
  - T31: the committed analysis is aggregate only (group returns, counts, alpha). Any per-symbol
    table stays in the private dashboard or Postgres.
  - Artifacts in a public repository need read access to download (S10), and in a public
    repository that is every GitHub user. That this includes signed-out users is
    **unverified**. Treat artifacts as public either way.
- RK-05 (60-day schedule disable) applies in full. The weekly "workflow enabled" check stays.
- `solution-architecture.md` changes (solution-architect, after the owner confirms):
  - OQ-03 resolved with a link here;
  - the cost map GitHub row: "public repository: standard runners free";
  - RK-06 mitigation: add the output rule.
- Plan changes (technical-architect):
  - fact 12: replace "unverified" with the S1 to S3 facts;
  - risk row 1: resolved by this decision;
  - O-1: the checklist above, before O-5;
  - KD-10: for a personal-account repository, the Actions permission option reads "Allow
    `<owner>`, and select non-`<owner>`, actions" (exact label **unverified**). Bypass lists are
    organization-only for branch protection (S11). Whether a personal-account owner can bypass a
    ruleset with an empty bypass list is **unverified**; KD-11 step 4 ("no bypass option is
    offered") verifies it, and the merge-box evidence must show it;
  - KD-8: no change. `ci.yml` uses no secrets, so fork PRs are safe;
  - checklist item 2 (variable to secret) is a T07 file change; record it as a T08 commit with a
    T07 cross-reference, or as a T07 follow-up, before the flip.
- Going back to private later is possible, but on Free it ends ruleset enforcement and erases
  stars. Treat the flip as permanent for this project.

## Wording changes proposed for `docs/TASKS.md` (owner's document: propose only)

None for the chosen option. For the fallback, NFR-09 changes in `solution-architecture.md`
(solution-architect, with owner approval). `TASKS.md` itself is not affected.

## Sources (all checked 2026-11-03)

- S1: [About
  rulesets](https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).
  The plan availability sentence comes from a web search result for this page; the fetched body did
  not include the note
- S2: [GitHub's plans](https://docs.github.com/en/get-started/learning-about-github/githubs-plans):
  Free personal "full feature set" for public repositories; Pro "Protected branches" under "Advanced
  tools and insights in private repositories"; Pro USD 18 a month included Actions usage
- S3: [GitHub pricing](https://github.com/pricing): Free, "Repository rules: Public repositories";
  "Status checks: Included"; Team "USD 4 per user / month"
- S4: [GitHub Actions
  billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions): public
  standard runners free; Free USD 12 and Pro USD 18 a month; Linux 2-core USD 0.006 a minute; usage
  blocked without a payment method
- S5: [Setting repository
  visibility](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility):
  effects of making a repository public
- S6: [Events that trigger
  workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows):
  `schedule` notes; fork secrets note
- S7: [About secret
  scanning](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning):
  free and automatic for public repositories; scans the entire history on all branches
- S8: secondary sources only, for example [GitHub Pro pricing
  (creditforstartups.com)](https://creditforstartups.com/resources/github-pro-pricing): USD 4 a
  month (**unverified** against GitHub)
- S9: [Setting your commit email
  address](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address):
  past commits keep the old address
- S10: [Downloading workflow
  artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts):
  "Read access to the repository is required"
- S11: [About protected
  branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches):
  "Actors may only be added to bypass lists when the repository belongs to an organization"; "Do not
  allow bypassing" applies the rules to admins

## Open questions (owner)

- Confirm public, or choose the Pro fallback and approve the NFR-09 change.
- Accept the work email in the existing commits (checklist item 4).
- Confirm whether `DEPLOY_SMOKE_HEADER` is set, and if so allow the move to a secret
  (checklist item 2).
