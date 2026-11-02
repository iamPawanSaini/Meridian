# T07: Solution-architect decision on the Pantheon upstream (SA-3)

| Field | Value |
|---|---|
| Task | T07 |
| Author | solution-architect |
| Date | 2026-11-02 |
| Answers | `docs/tasks/T07/plan.md` (Draft), "Decisions needed from solution-architect", SA-3; KD-7 |
| Related | ADR-0004; technical-design D8; plan O-4 (first force push), R12 |

## Context

`meridian-trade` was created from "Drupal (Composer Managed)". After the one-time force push
(O-4), Pantheon `master` holds only our split history, so the dashboard will keep offering
upstream updates. The plan asks whether to keep that upstream with a "never apply updates"
policy, or switch to an empty upstream with `terminus site:upstream:set`.

## Decision

**Keep the "Drupal (Composer Managed)" upstream. Never apply upstream updates** on
`meridian-trade`, neither the dashboard "Apply Updates" button nor `terminus
upstream:updates:apply`. Drupal core, `pantheon-systems/drupal-integrations` and all other
packages are updated with Composer in `apps/drupal` and deployed like any other change. Do not
switch the upstream.

Runbook rule text: "Upstream and Composer updates offered by the Pantheon dashboard are never
applied. They would write a commit on Pantheon `master`, and the next deploy would be rejected.
If one was applied by mistake, follow 'Emergency force push' with the split of `main`."

## Reasons

1. **Switching is the riskier change.** Pantheon calls switching an existing site's upstream
   "risky", recommends creating a new site instead, says the destination must share Git history
   with the current one, and blocks framework changes (S1). An empty upstream has unrelated
   history, so the outcome of `site:upstream:set` on our site is undocumented.
2. **The empty-upstream docs point the other way.** The only Pantheon guides about the empty
   upstream are from 2022 and treat moving **from** empty **to** `drupal-composer-managed` as
   the supported direction (S2, S3). Whether Integrated Composer works on an empty upstream is
   not documented (S2, S3, S4).
3. **Our build settings do not depend on the upstream.** Settings in `pantheon.yml` override
   `pantheon.upstream.yml` (S5), and the split tree has no `pantheon.upstream.yml` at all. Our
   `apps/drupal/pantheon.yml` already sets `build_step: true`, `web_docroot: true`, PHP 8.3 and
   MariaDB 10.6 (plan KD-7). So the upstream setting only affects what the dashboard offers.
4. **AC1 stays true as written.** The site was created from the Composer-managed upstream and
   keeps it.
5. **Simplest option.** No platform call, no change of state that is hard to undo; one
   documented rule.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| Switch to the empty upstream | Undocumented outcome for our case (reason 1); possible Integrated Composer side effects (reason 2); no benefit beyond hiding a dashboard notice |
| Apply upstream updates and merge them back into `apps/drupal` | Writes on Pantheon `master` (forbidden by ADR-0004); the upstream's `upstream-configuration` path repository is not part of our tree |
| Custom upstream | Included only for Enterprise Gold and EDU accounts (S1); not free |

## Consequences

- The dashboard keeps showing "updates available". The runbook says to ignore it.
- A mistaken "Apply Updates" makes the next deploy fail loudly (non-force push). Recovery is
  the emergency force push in `decision-rollback.md`, decision 4.
- Upstream protections that lived in `pantheon.upstream.yml` (for example
  `protected_web_paths`) are gone after the force push. The platform still protects
  `composer.json`, `composer.lock`, `package.json` and `phpunit.xml.dist` (S5). The plan's
  private-files probe (KD-12) covers the path we rely on.
- Integrated Composer deploys `require-dev` to Dev and Multidev (S6), so `drupal/core-dev` is
  expected on Pantheon dev. Plan R12 should be reworded: installing `require-dev` on dev is
  documented behaviour, not a risk; the risk left is a build failure from a scaffold or plugin
  rule.
- Pantheon support for a site whose history no longer descends from its upstream is
  **unverified**. Sandbox sites have no support entitlement we rely on, so this does not
  block T07.

## Unverified items and how T07 verifies them

| Item | How T07 verifies |
|---|---|
| Integrated Composer runs on our split with only `pantheon.yml` (no `pantheon.upstream.yml`) | First build log after O-4 (plan KD-7); `settings.pantheon.php` exists on Pantheon |
| `web_docroot: true` in `pantheon.yml` is honoured without the upstream file | `/user/login` serves from `/code/web` (smoke check) |
| Dashboard upstream-updates notice is harmless if ignored | Observe once after O-4; record with date |

## Wording changes proposed for `docs/TASKS.md` (owner's document: propose only)

None. AC1 stays as written (reason 4).

## Technical-design and ADR follow-ups (technical-architect applies in plan step 11)

- **D8.** After the "First push" paragraph add: "The site keeps the Drupal (Composer Managed)
  upstream. Pantheon upstream and Composer updates are never applied on Pantheon; packages are
  updated in `apps/drupal` and deployed (`docs/tasks/T07/decision-upstream.md`)."
- **ADR-0004.** No change. It already says nobody commits to the Pantheon repository by hand;
  applying upstream updates is such a commit.

## Sources (all checked 2026-11-02)

- S1: [Switch Your Custom Upstream](https://docs.pantheon.io/guides/custom-upstream/switch-custom-upstream)
  and [terminus site:upstream:set](https://docs.pantheon.io/terminus/commands/site-upstream-set)
- S2: [Drupal sites on the empty upstream, introduction](https://docs.pantheon.io/guides/drupal-hosted-createempty-md)
  ("Last Reviewed 2022-12-13")
- S3: [Convert an Empty Upstream Drupal Site to a Composer Managed Site](https://docs.pantheon.io/composer-convert-from-empty)
  ("Last Reviewed 2022-12-13")
- S4: [Integrated Composer](https://docs.pantheon.io/guides/integrated-composer) ("Last
  Reviewed 2024-10-15")
- S5: [Pantheon YAML configuration files](https://docs.pantheon.io/pantheon-yml) ("Last
  Reviewed 2026-07-06"): `pantheon.yml` overrides `pantheon.upstream.yml`; platform-protected
  paths
- S6: [Integrated Composer dependencies](https://docs.pantheon.io/guides/integrated-composer/dependencies)
  ("Last Reviewed 2026-09-17"): `require-dev` deploys to Dev and Multidev, not Test or Live

## Open questions

- None.
