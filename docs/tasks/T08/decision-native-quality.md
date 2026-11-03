# T08: Solution-architect decision on running the quality suite natively in CI (SA-2)

| Field | Value |
|---|---|
| Task | T08 |
| Author | solution-architect |
| Date | 2026-11-03 |
| Answers | `docs/tasks/T08/plan.md` (Draft), "Decisions needed from solution-architect", SA-2; KD-1, KD-6, KD-7 |
| Related | `docs/TASKS.md` T08 AC1 and T04a AC (line 259); NFR-07; `scripts/README.md` (`QUALITY_RUNNER`); `decision-heavier-set.md` |

## Question

May T08 AC1 ("`ci.yml` runs the full `ddev quality` suite defined in T04a ...") be met by
running every step of `scripts/quality.sh` on the GitHub runner with `QUALITY_RUNNER=native`,
instead of starting DDEV on the runner?

## Decision

**Yes.** Running `scripts/quality.sh` natively meets AC1, if the five conditions below hold.
DDEV is not installed in `ci.yml`. No DDEV parity job is added now, not even a
dispatch-only one.

### Conditions (each is a T08 test case)

1. **One implementation.** Every CI job calls `scripts/quality.sh --group <g>`, and the YAML
   holds no check logic. `check_ci.py` rule 1 (group coverage) enforces that the union of the
   groups equals `quality.sh --list`.
2. **The runner does not change the step set.** `quality.sh --list` output and every SKIP
   decision depend only on manifests, never on `QUALITY_RUNNER`. Add a unit test: `--list`
   under `QUALITY_RUNNER=native` and `QUALITY_RUNNER=ddev` (with a fake runner) gives the same
   output. With the expected-skips rule (KD-3), CI and `ddev quality` then run the same steps and
   SKIP the same ones.
3. **Toolchain parity is checked, not assumed** (`check_ci.py` rule 2):
   - PHP major.minor equals `.ddev/config.yaml` and `apps/drupal/pantheon.yml`;
   - the Composer version given to setup-php equals the DDEV Composer version recorded in
     `.github/README.md`;
   - later, Python and Node versions equal the `meridian-engine` and `meridian-web` image tags
     (T13, T21).

   Lint tool versions are already identical by construction: pre-commit hook `rev`s, and
   component tools from `composer.lock` (and the T13 and T21 lock files).
4. **Accepted residual differences are written down** in `scripts/README.md`, so nobody
   assumes byte-identical environments:
   - the OS image: Ubuntu runner, against DDEV's Debian-based containers;
   - the PHP extension set: setup-php's set against `ddev-webserver`'s.
     `composer check-platform-reqs --lock` (`build-drupal`) covers what the code requires;
   - the PHP patch level, which floats in both places.

   A check that passes in one place and fails in the other is a defect against T08 (or the
   owning task), not a reason to skip it.
5. **The local gate stays DDEV.** Task test reports that change `quality.sh` keep recording both
   `ddev quality` locally and the CI run (plan step 9). That is the standing parity evidence.

### Note for T09 (not T08 scope)

PHPUnit Kernel tests need a database. In native CI, T09 adds a database service container to
the `drupal` job. Its engine and version must match DDEV's `ddev-dbserver` (MariaDB or MySQL as
configured), and `check_ci.py` gains that parity check. SQLite is not acceptable as a stand-in,
because it hides SQL dialect differences that Pantheon (MariaDB) would expose.

## Reasons

1. **The suite is the list of checks, not the container.** T04a's own criterion says
   "`ddev quality` runs every check ...; the same checks run in CI (T08)" (`docs/TASKS.md` line
   259). It asks for the same checks, not the same host. `ddev quality` is a wrapper that sets
   `QUALITY_RUNNER=ddev` and calls `scripts/quality.sh`. CI runs that same script.
2. **NFR-07 is a Must** (10 min cold, 6 min warm). Installing DDEV, pulling images, building
   the custom web image and running the `composer install` hook would add several minutes before
   the first check. That cost is **unverified** and not measured; the plan's "3 to 5 min"
   figure is an estimate. Even half of it would put the cold budget at risk once the pre-commit
   cold install is added. Native setup uses cached setup actions and adds seconds.
3. **Simplest option that meets the requirement.** A dispatch-only DDEV job proves nothing that
   conditions 3 and 5 do not already prove, and it would decay unrun. DDEV in CI earns its place
   when a suite needs the full stack. That is the heavier set (`decision-heavier-set.md`): T10
   for Schemathesis, T27 for `ddev e2e`. That task decides it.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| Start DDEV on the runner for every PR | Likely breaks NFR-07 (reason 2); adds Docker-in-runner fragility to the required check |
| Native PR set plus a `workflow_dispatch`-only DDEV parity job now | No requirement needs it yet. Conditions 3 and 5 cover parity. Defer to the heavier-set task |
| Native, with no parity check | Silent drift (PHP minor, Composer) would make CI and local disagree. Rejected |
| Run `quality.sh` inside the project's own containers (`docker run` of DDEV-like images) | Rebuilds DDEV by hand; more YAML logic; still needs image pulls |

## Consequences

- KD-1 stands as written. Remove the sentence "SA-2 confirms this reading" and link this file
  instead.
- New test case (tester): condition 2 (`--list` and SKIP decisions do not depend on the runner).
- `scripts/README.md` gains the "Accepted differences" paragraph (condition 4).
- `check_ci.py` rule 2 includes Composer (condition 3), and T09 extends it to the database
  service (note above).

## Wording change proposed for `docs/TASKS.md` (owner's document: propose only)

**Not required.** The native reading is supported by T04a's own criterion (reason 1), and T08
can proceed on it now. I still recommend this clarification, so that a later reviewer does not
read "`ddev quality`" as "DDEV must run in CI". The owner decides. If approved, replace the first
T08 criterion with:

```text
- [ ] `ci.yml` runs every check of the `ddev quality` suite defined in T04a (lint, format check, static analysis, type checks, commit and branch naming) by calling `scripts/quality.sh`, the same implementation that `ddev quality` uses, natively on the GitHub runner with toolchain versions checked against DDEV and Pantheon; plus unit tests per component with coverage thresholds, build, secret scan, dependency audit
```

## Sources

- `docs/TASKS.md` T04a AC (line 259) and T08 AC1, read 2026-11-03
- `docs/architecture/solution-architecture.md` NFR-07, read 2026-11-03
- No external facts are relied on. The DDEV cold-start cost is **unverified**, and nothing in
  this decision depends on its exact value.

## Open questions

- Owner: approve or decline the optional AC1 clarification above.
