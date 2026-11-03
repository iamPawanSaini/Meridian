# T08: Solution-architect decision on the heavier-set triggers (SA-3)

| Field | Value |
|---|---|
| Task | T08 |
| Author | solution-architect |
| Date | 2026-11-03 |
| Answers | `docs/tasks/T08/plan.md` (Draft), "Decisions needed from solution-architect", SA-3; Non-goals item 1, KD-6, KD-8 |
| Related | `docs/tests/master-test-plan.md` "Regression suite" and "Integration", "Contract", "End-to-end"; `docs/TASKS.md` T09, T10, T27; NFR-07; `decision-native-quality.md`; `decision-repo-visibility.md` |

## Question

The master test plan says "T08 implements the jobs in `ci.yml` (and the heavier-set triggers)":
nightly, manual dispatch, push to `main` and a PR label. No heavier-set suite exists yet. May T08
defer the triggers? To which task, and what must T08 still provide?

## Facts (repository documents, read 2026-11-03)

- Heavier set = Drupal Functional tests, Schemathesis (marker `drupal_live`), Playwright
  end-to-end and accessibility, and `ddev e2e` (master test plan, "Regression suite").
- **T09** acceptance criteria require **Kernel** tests only. Kernel tests are in the PR set
  ("Drupal Unit and Kernel tests").
- **T10** is the first task whose criteria need the full stack:
  - "contract tests pass against the running DDEV site" (Schemathesis);
  - "PHPUnit functional tests for every case above".
- Playwright arrives with T21 and T22 to T26, and `ddev e2e` with T27.
- `schedule` runs only on the default branch, and in a public repository it is disabled after
  60 days without activity (`decision-repo-visibility.md`, S6; RK-05).

## Decision

**Defer the heavier-set triggers and jobs to T10.** If T09 adds any PHPUnit Functional test
(against its current criteria), T09 takes the work instead. The tripwire below makes that
automatic, so neither task can skip it silently. T08 adds no placeholder job.

### What T08 must still provide

1. **A tripwire in `scripts/check_ci.py` (rule 6, with fixtures).** If any heavier-set marker
   exists in the tree and `ci.yml` has no job whose id starts with `heavier-`, fail with
   "heavier-set tests exist but ci.yml has no heavier-* job (decision-heavier-set.md)". The
   markers (constants in the script, unit-tested):
   - `apps/drupal/web/modules/custom/*/tests/src/Functional/` or `.../FunctionalJavascript/`
     containing a `*Test.php`;
   - the string `drupal_live` in any file under `services/engine/tests/`;
   - `apps/web/playwright.config.*`;
   - `.ddev/commands/*/e2e`.

   This is the KD-3 principle ("a SKIP is never silent") applied to the heavier set.
2. **A documented hook point in `.github/README.md`** ("Adding the heavier set"). The contract
   it states for T10:
   - the heavier set lives **in `ci.yml`**, as one or more jobs with ids `heavier-<area>`;
     no new workflow file, so section 0 naming is unchanged;
   - `heavier-*` jobs are **not** in `ci-ok`'s `needs`, so they are never a required check (the
     master test plan: "A red heavier set creates a defect");
   - triggers: `schedule` (nightly, off the hour, away from the 10:30 UTC daily run, for example
     `17 21 * * *`), `workflow_dispatch`, `push` to `main`, and `pull_request` with a label
     `heavier-set`. Each job is gated with `if:` on the event or label. Adding `labeled` to the
     `pull_request` types also re-runs the PR set when a label is added; T10 accepts or filters
     that;
   - each job has its own `timeout-minutes` (proposed 30) and uploads JUnit XML and reports as
     `reports-heavier-<area>`, like KD-8;
   - whether the job runs DDEV on the runner or a native stack (setup-php plus a database
     service plus `php -S`) is decided by T10 for Drupal Functional and Schemathesis, and by
     T27 for `ddev e2e`. `decision-native-quality.md` leaves DDEV in CI to that point.
3. **A master test plan note** (tester, with a Change log row). In "Regression suite", change
   "T08 implements the jobs in `ci.yml` (and the heavier-set triggers)" to:

   ```text
   T08 implements the PR-set jobs in `ci.yml`. The heavier-set jobs and triggers are added to `ci.yml` by the first task with a heavier-set suite (T10; docs/tasks/T08/decision-heavier-set.md); `scripts/check_ci.py` fails if such a suite exists without them.
   ```

   Also add one sentence under the close rule: "Until the first heavier-set job exists (T10), the
   rule has nothing to run and does not block a close."
4. **TASKS note for T10** (owner's document: propose only). Add to T10's acceptance criteria:

   ```text
   - [ ] Heavier-set jobs added to `ci.yml` (nightly, dispatch, push to main, PR label) per docs/tasks/T08/decision-heavier-set.md; the PHPUnit Functional and Schemathesis suites run there and upload reports
   ```

## Reasons

1. **A trigger with nothing to run proves nothing.** A placeholder job would be green by
   construction. It would also put a nightly `schedule` in place that only creates noise and
   repository events. T08's ACs do not name the heavier set.
2. **The tripwire keeps the deferral honest.** Without it, T10 could add Functional tests that
   run nowhere, or that break the PR set. The check costs a few lines and fixtures.
3. **Inside `ci.yml` is the simplest home.** It needs no naming change. A non-required job does
   not block merges. The pins, permissions and secrets rules of `check_ci.py` apply to it
   automatically.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| Empty placeholder `heavier` job with all triggers now | Green by construction; nightly noise; the trigger shape may change once T10 knows its runner |
| A separate workflow file for the heavier set | Needs a section 0 change and a `check-names.sh` update, for no gain over `if:`-gated jobs |
| Make the heavier set a required check | Contradicts the master test plan failure rule; the cost on every PR would break NFR-07 |
| Defer with no tripwire | The deferral could be forgotten at T10 |

## Consequences

- **NFR-07 scope (proposed; the solution-architect applies it with owner approval when T10 adds
  the first `heavier-*` job).** Once heavier jobs live in `ci.yml`, a `push` run on `main` lasts
  longer than the PR set. Change the NFR-07 target to:

  ```text
  At most 10 min wall clock on a clean cache, and at most 6 min with warm caches, for the PR set (the `ci.yml` jobs that `ci-ok` needs). Heavier-set jobs (`heavier-*`) are excluded and have their own job timeout
  ```

  Until T10, the current wording and the proposed one mean the same thing.
- With a public repository (`decision-repo-visibility.md`), heavier-set minutes are free. On a
  private repository, a 15 to 20 min nightly run would use a large share of the included
  minutes. That cost was not counted in OQ-03's estimate.
- Plan changes (technical-architect):
  - Non-goals item 1: link this file;
  - KD-6: add rule 6 and its fixtures (one with a Functional test dir and no `heavier-` job, one
    with both);
  - KD-8: no `schedule` stays correct for T08;
  - Scope: `.github/README.md` "Adding the heavier set".

## Sources

- `docs/tests/master-test-plan.md` ("Regression suite", "Integration", "Contract",
  "End-to-end"), `docs/TASKS.md` T09, T10, T27, read 2026-11-03
- [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows),
  checked 2026-11-03: "Scheduled workflows will only run on the default branch", and the 60-day
  rule for public repositories

## Open questions

- Owner: approve the T10 AC addition (item 4) and, at T10, the NFR-07 scope wording.
