# T06: Solution-architect decision on the Next.js placeholder (AC1, AC6)

| Field | Value |
|---|---|
| Task | T06 |
| Author | solution-architect |
| Date | 2026-11-02 |
| Answers | `docs/tasks/T06/plan.md` (Draft), "Decisions needed from solution-architect", item 1 |
| Related | `docs/TASKS.md` T06 and T21; plan KD-1 and KD-5; `scripts/quality.sh`; technical-design D7, D8; `docs/tasks/T04a/decision-t04a-standards.md` (Q6, D-6) |

This decision relies only on project documents. It makes no claim about an external tool,
regulation or price, so no external source is cited.

## Decision

**Option (a), with conditions.** T06 ships the placeholder runtime proposed in KD-1 and KD-5:
`meridian-web` runs a pinned Node 22 image, and `.ddev/meridian-web/start.sh` serves the tiny
placeholder on `https://meridian.ddev.site:3001` until `apps/web/package.json` exists, then runs
`npm run dev`. AC6 is split into two test cases. T06 verifies the route part. The dev-server part
is recorded as `Blocked (accepted, re-run in T21)` and is owed by T21.

## Reasons

1. **The quality gate stays honest.** `scripts/quality.sh` turns on `component-web` when
   `apps/web/package.json` exists. That step runs ESLint, `tsc`, Prettier, Vitest with coverage
   and `coverage_gate.py`. A minimal app without that toolchain makes `ddev quality` fail (C4).
   Making it pass would mean doing T21's toolchain work inside T06.
2. **T21 owns the design.** App Router layout, TypeScript strict, the typed Drupal client,
   schema-validated environment, mock API mode and `/api/health` are T21 criteria. A T06 scaffold
   would either be thrown away or fix those choices early without T21's plan and review.
3. **What T06 must prove is platform plumbing.** Container, DDEV labels, router route, port
   3001, mkcert trust, health check and the `ddev next` command are the risky DDEV parts. A
   placeholder on the same port, route and start script proves all of them. What it does not
   prove (Next.js binding `0.0.0.0:3000`, first-compile time against the health-check start
   period, file watching) belongs with the real app in T21.
4. **Simplest option that meets the requirement.** No npm dependency, no lockfile and no
   dependency audit in T06. The start script switches with no compose change.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| (b) Minimal real Next.js app in T06 | Turns on `component-web`, which fails without T21's tools (reason 1); pre-empts T21 (reason 2); adds npm dependencies, a lockfile and an audit to an infrastructure task |
| (c1) Throwaway Next.js app under `.ddev/` | Avoids the quality trigger, but still pulls npm dependencies, needs an audit, and is not the app T21 builds, so AC6 would still need a T21 re-run. Cost without benefit |
| (c2) Move AC6 to T21 in `docs/TASKS.md` | `docs/TASKS.md` is the owner's document. The effect equals (a), but (a) keeps the criterion where the owner put it and records the deferral in the evidence, which is more traceable |
| (c3) Treat the placeholder as full AC6 | Rejected. AC6 names the "Next.js dev server". Claiming it in full before a Next.js server exists would be a false Pass |

## Conditions on T06

1. **Split AC6 into two cases** in `docs/tests/T06/test-cases.md`:
   - **AC6a, route and TLS** (T06 Pass required): from WSL2, `curl` to
     `https://meridian.ddev.site:3001/` returns `200` with `ssl_verify_result` 0 and no `-k`,
     and the body is the fixed placeholder sentence. The owner-run Windows browser check is part
     of this case.
   - **AC6b, Next.js dev server over HTTPS** (T06 status `Blocked (accepted, re-run in T21)`):
     the same request reaches `next dev`. The case text names T21 as the task that runs it.
2. **Prove the switch, without committing a manifest.** The tester adds one case, run in the
   `--clean-clone` scratch copy only: write a temporary `apps/web/package.json` whose `dev`
   script is a dependency-free `node` one-liner that listens on the `--port` and `--hostname`
   arguments it receives. Restart `meridian-web`, and AC6a's `curl` returns that server's body.
   The file never reaches the repo (static check: no `apps/web/package.json` is tracked). This
   tests T06's own code, the `start.sh` branch and the argument passing, now rather than in T21.
3. **No overclaim in T06 docs.** `.ddev/README.md`, `apps/web/README.md` and the runbook say
   that `https://meridian.ddev.site:3001` serves a placeholder until T21. The placeholder text
   names T21 (KD-1 already requires this).
4. **Owner acceptance.** AC6b is a deferred case. It follows the D-6 practice in
   `docs/tasks/T04a/decision-t04a-standards.md`: the owner accepts it in writing at T06 close.
   An agent message is not owner acceptance.

## What T06 may claim

| Criterion | Claim at T06 close | Wording for the test report and the T06 review |
|---|---|---|
| AC1 | **Met** | "`ddev start` brings up `web`, `db`, `meridian-postgres`, `meridian-engine` and `meridian-web`. `meridian-web` is the Next.js runtime container (pinned Node 22). Until T21 it serves the T06 placeholder." |
| AC6 | **Partially met** | "AC6a Pass: a DDEV hostname over HTTPS (`https://meridian.ddev.site:3001`, trusted mkcert certificate) reaches port 3000 in `meridian-web`, verified with the placeholder server. AC6b (Next.js dev server on that route) is Blocked (accepted, re-run in T21)." |

AC1 is met because the criterion is about containers, and the Next.js container exists, runs and
is healthy. AC6 is not met in full because it names the dev server itself.

T06 may close as **Done** with AC6b open on these terms. That matches the board rule that only
`/close-task` marks Done, and the deferred-case practice above. If the close step ticks boxes in
`docs/TASKS.md`, the AC6 box stays unticked until T21 closes.

## Wording at T06 close

**`docs/TRACEABILITY.md`, FR-26 row.**

- Verifying task cell: `T05, T06, T21 (T06 AC6b re-run only), T27`.
- Case cell: replace `TC-T06-*` with the real IDs, and add the note
  `TC-T06-nn AC6b Blocked (accepted, re-run in T21)` (use the real case ID).
- Status stays `Partially verified`. FR-26 is not `Verified` until T21 passes AC6b and T27 passes.

**`docs/TRACEABILITY.md`, R-11 row.**

- Verifying task cell: add `T21`.
- Evidence cell: add this text.

  ```text
  T06: TC-T06-nn to nn Pass; AC6 route only (placeholder); Next.js dev server re-run owed by T21 (TC-T06-nn)
  ```

- Status stays `Open`.

**`docs/PROGRESS.md`.** The T06 status is `Done`. Notes text:

```text
AC6 partial: HTTPS route verified with placeholder; Next.js dev server re-run (TC-T06-nn) owed by T21, owner-accepted
```

T21 notes (its status stays as it is): `Owes T06 AC6b re-run (TC-T06-nn) before close`.

## Follow-up obligation for T21

T21 cannot close until all of these are done:

1. **Plan.** The T21 plan lists "re-run T06 AC6b (TC-T06-nn)" as a numbered item under its
   acceptance criteria. It also lists two items KD-5 leaves to T21: `python3` for
   `coverage_gate.py` in the `component-web` step, and whether the 120 s health-check start
   period covers the first compile.
2. **Test.** T21's test cases include a case that runs the AC6b procedure unchanged against
   `npm run dev`. A `curl` with no `-k` to `https://meridian.ddev.site:3001/` returns a status
   below 500 with `ssl_verify_result` 0, from a response the Next.js dev server produced (for
   example a known page body, or the redirect T21's middleware gives). `ddev meridian-status`
   shows `meridian-web` `running healthy`. Evidence is stored under `docs/tests/T21/evidence/`.
3. **Back-annotate T06.** Add a dated addendum to `docs/tests/T06/test-report.md`: AC6b Pass in
   T21, with a link to the T21 evidence. Do not rewrite the T06 results.
4. **Close wording.** In `docs/TRACEABILITY.md`, change the FR-26 note to
   `TC-T06-nn AC6b Pass (re-run in T21, TC-T21-nn)` and the R-11 evidence to match. Remove the
   T21 note from the `docs/PROGRESS.md` T06 and T21 rows. FR-26 moves to `Verified` only when
   T27 has passed too.
5. **Start script.** If T21 changes the dev branch of `.ddev/meridian-web/start.sh` (it may,
   KD-5), it re-runs the AC6a case and the T06 `ddev next` argument-fidelity case as well.

If T21 is replanned or split, the task that brings `apps/web/package.json` inherits this
obligation.

## Open questions

- None for the solution-architect. Owner acceptance of AC6b as a deferred case is needed at
  T06 close (condition 4).
