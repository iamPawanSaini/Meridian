# T05: DDEV Drupal project, Test report

| Field | Value |
|---|---|
| Task | T05 |
| Build or commit | `bfb5f7b` on `task/T05-ddev-drupal` (clean clone tested at this commit) |
| Environment | Ubuntu 22.04 on WSL2 (kernel 6.18.54.1), Docker 28.1.1, DDEV v1.24.4 |
| Tool versions | Host Python 3.10.12, host PHP 8.1.2 (not used), DDEV web PHP 8.3.19, MariaDB 10.6.21 |
| Date | 2026-11-01 |
| Executed by | tester |

## Summary

Run order: static mode, live-only mode in the working tree, then the clean clone
(`T05_CONFIRM=1 docs/tests/T05/run-checks.sh --clean-clone`). The clean clone ran twice; see
"Clean-clone run" below.

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T05-01 | AC1 | Pass | `evidence/TC-T05-01.txt` |
| TC-T05-02 | AC1, C6 | Pass | `evidence/TC-T05-02.txt` |
| TC-T05-03 | AC3 | Pass | `evidence/TC-T05-03.txt` |
| TC-T05-04 | AC3 | Pass | `evidence/TC-T05-04.txt` |
| TC-T05-05 | AC5 (KD-1) | Pass | `evidence/TC-T05-05.txt` |
| TC-T05-06 | AC5 (KD-1) | Pass | `evidence/TC-T05-06.txt` |
| TC-T05-07 | AC4 (KD-4) | Pass | `evidence/TC-T05-07.txt` |
| TC-T05-08 | C6 (D7) | Pass | `evidence/TC-T05-08.txt` |
| TC-T05-09 | KD-7 invariant, AC1 | Pass | `evidence/TC-T05-09.txt` |
| TC-T05-10 | AC2, AC4, C6 | Pass | `evidence/TC-T05-10.txt` |
| TC-T05-11 | AC2 (KD-5) | Pass | `evidence/TC-T05-11.txt` |
| TC-T05-12 | C4 (KD-6) | Pass | `evidence/TC-T05-12.txt` |
| TC-T05-13 | AC6, C7 | Pass | `evidence/TC-T05-13.txt` |
| TC-T05-14 | C5 | Pass | `evidence/TC-T05-14.txt` |
| TC-T05-15 | C6 (KD-8) | Pass | `evidence/TC-T05-15.txt` |
| TC-T05-16 | Simulation only | Pass | `evidence/TC-T05-16.txt` |
| TC-T05-17 | Section 0 naming | Pass | `evidence/TC-T05-17.txt` |
| TC-T05-18 | C4 (shell) | Pass | `evidence/TC-T05-18.txt` |
| TC-T05-19 | C4 (KD-6), scope | Pass | `evidence/TC-T05-19.txt` |
| TC-T05-20 | C4 (KD-7) | Pass | `evidence/TC-T05-20.txt` |
| TC-T05-21 | C4 | Pass (retest 2026-11-02; was Fail) | `evidence/TC-T05-21.txt`; retest `evidence/retest-def004/static-run-4.txt` |
| TC-T05-22 | C6 (KD-5) | Pass | `evidence/TC-T05-22.txt` |
| TC-T05-23 | Plan non-goals | Pass | `evidence/TC-T05-23.txt` |
| TC-T05-24 | C4, C6 | Pass (retest 2026-11-02; was Fail) | `evidence/TC-T05-24.txt`, `evidence/TC-T05-24-full.txt`; retest `evidence/retest-def004/TC-T05-24.txt` |
| TC-T05-25 | AC3 | Pass | `evidence/TC-T05-25.txt` |
| TC-T05-26 | AC1 | Pass | `evidence/TC-T05-26.txt` |
| TC-T05-27 | AC5 | Pass | `evidence/TC-T05-27.txt` |
| TC-T05-28 | AC5 | Pass | `evidence/TC-T05-28.txt` |
| TC-T05-29 | AC2 | Pass | `evidence/TC-T05-29.txt` |
| TC-T05-30 | AC2, negative | Pass | `evidence/TC-T05-30.txt` |
| TC-T05-31 | AC2 | Pass | `evidence/TC-T05-31.txt` |
| TC-T05-32 | AC4 | Pass | `evidence/TC-T05-32.txt` |
| TC-T05-33 | KD-7 invariant, C7 | Pass (clean clone) | `evidence/clone-live/TC-T05-33.txt` |
| TC-T05-34 | C4 | Pass (retest 2026-11-02; was Fail) | `evidence/TC-T05-34.txt`, `evidence/TC-T05-34-full.txt`; retest `evidence/retest-def004/TC-T05-34.txt` |
| TC-T05-35 | C4, negative | Pass (clean clone) | `evidence/clone-live/TC-T05-35.txt` |
| TC-T05-36 | Plan DoD (security) | Pass | `evidence/TC-T05-36.txt` |
| TC-T05-37 | AC1, C7 | Pass | `evidence/TC-T05-37.txt` |
| TC-T05-38 | AC2, AC4, KD-7 | Pass | `evidence/TC-T05-38.txt` |
| TC-T05-39 | AC6, C7 | Blocked (owner-run) | `evidence/TC-T05-39.txt` |
| TC-T05-40 | AC6 (HTTPS on WSL2) | Blocked (owner-run) | `evidence/TC-T05-40.txt` |

Totals at first run (2026-11-01): 35 pass, 3 fail, 2 blocked, 0 not run (40 cases).
Totals after the DEF-004 and DEF-005 retests (2026-11-02, see "DEF-004 retest"): 38 pass, 0 fail,
2 blocked (TC-T05-39, 40), 0 not run.

Evidence for TC-T05-25 to 36 comes from the working-tree live run (`evidence/worktree-live/`,
copied to `evidence/TC-T05-nn.txt`). The same set ran again inside the clean clone
(`evidence/clone-live/`, whole run in `clone-live/clean-clone-run.txt`).

## Failed cases (all cite DEF-004)

| Case | Reason |
|---|---|
| TC-T05-21 | The nested T03 and T04 regression runs fail only on their pre-commit steps. |
| TC-T05-24 | `pre-commit run --all-files` fails in ruff, mypy, shellcheck, yamllint, markdownlint. |
| TC-T05-34 | `ddev quality` exits 1 because the pre-commit step fails (same hooks). |

For TC-T05-34 the step lines are, as review condition 2 requires
(`evidence/TC-T05-34-full.txt`):

```text
FAIL  pre-commit
PASS  branch-name
PASS  commit-range
PASS  exceptions
PASS  assets
SKIP  component-engine (no services/engine/pyproject.toml)
PASS  component-drupal
SKIP  component-drupal-tests (no apps/drupal/phpunit.xml.dist)
SKIP  component-web (no apps/web/package.json)
```

`component-drupal` passes and `component-drupal-tests` skips, as required. In the failing hook
output no T05 product file appears. The failures are in `.claude/hooks`, `docs/tests/T03` to
`T04a`, `docs/architecture/openapi.yaml`, `.spectral.yaml`, `scripts/README.md` and similar
T00 to T04a files. One T05 file did fail: my own `docs/tests/T05/run-checks.sh` failed
shellcheck. I fixed it in this run (file-level directive with ticket T05, Change log row) and it
now passes all hooks. No new defect (DEF-005) was needed.

## Blocked cases

| Case | Reason |
|---|---|
| TC-T05-39 | Owner-run. AC6 verbatim runbook rehearsal on a separate machine or container. |
| TC-T05-40 | Owner-run. Windows browser login over HTTPS with mkcert on WSL2. |

The clean-clone run is strong evidence for AC1, AC2 and AC4 but is not TC-T05-39. It cloned
from a local `file://` path, it did not run `scripts/bootstrap-dev.sh` or `mkcert -install`, and
it ran on a machine that already has Docker and DDEV set up.

## Clean-clone run (AC6 rehearsal, TC-T05-37 and 38)

- Attempt 1 (`evidence/clone-attempt1/`): TC-T05-38 failed. `ddev stop --unlist meridian` keeps
  the Docker database volume, so the clone started with an installed Drupal database and
  `ddev drupal-install` correctly refused (exit 1). That is a harness flaw, not a product
  defect; the runbook issue behind it is listed below. The harness now runs
  `ddev delete -Oy meridian` after the unlist (Change log row).
- Attempt 2 (`evidence/TC-T05-37.txt`, `TC-T05-38.txt`, `clone-live/`): all pass.
  `ddev start` took 21 s (images cached, so not a first-pull figure), `ddev drupal-install`
  5 s, `git status --porcelain` was empty after start, install and `drush cex -y`, and the
  login link is the `meridian.ddev.site` reset URL. The whole run took 1 min 43 s.
- In the clean clone TC-T05-33 and 35 pass and TC-T05-34 fails (pre-commit is not installed
  there, and DEF-004). The working-tree run of TC-T05-33 and 35 failed only on a dirty tree,
  see below.

## Environment note: the fixers rewrote the working tree

`pre-commit run --all-files` (TC-T05-21, 24 and `ddev quality`) runs fixers (ruff, trailing
whitespace, end-of-file) and rewrote 25 tracked T00 to T04a files, including evidence files
under `docs/tests/*/evidence/`, `.claude/hooks/*` and `scripts/*`. I cannot revert them, as the
guard blocks git checkout for this agent. The main session must restore them (list them with
`git status --short`, minus the T05 files and `docs/tests/defects.md`). Because of this, the
working-tree runs of TC-T05-33 ("git status is empty") and TC-T05-35 ("tree clean again")
failed on those unrelated files. The same cases pass in the clean clone, where the tree starts
clean. I classify both as Pass on the clean-clone evidence and flag this for the reviewer. The
scoped check `git status --porcelain -- apps/drupal .ddev docs/runbooks` was empty
(`evidence/TC-T05-33-scoped.txt`).

## Runbook findings (`docs/runbooks/local-setup.md`)

1. Step 2 says unlisting is enough ("Expected: nothing to do on a first setup"). It is not.
   The database volume of the earlier checkout survives, and `ddev drupal-install` then
   refuses with "already installed". Add `ddev delete -Oy meridian` (or `--force`) to step 2
   for a re-clone.
2. Step 1 clones the default branch. Until T05 is merged, `main` has no `.ddev/config.yaml`.
   The runbook should say to check out the task branch, or hold until the merge.
3. The Verification list ends with `ddev quality`, which needs `scripts/bootstrap-dev.sh`
   first and exits 0 only after DEF-004 is fixed. The numbered steps have no bootstrap step.
   In the clean clone `ddev quality` printed `pre-commit: command not found`. Add the
   bootstrap step before Verification.
4. `scripts/bootstrap-dev.sh` warns that `PRE_COMMIT_SHA256` is not pinned (not a T05 item).
5. `ddev quality` modifies tracked files through the fixers (see above). The runbook should
   say to run it on a committed tree and to review `git status` afterwards.

## Retests

- DEF-003: Pass. `scripts/bootstrap-dev.sh` passes its Python check, exits 0 and installs the
  hooks. The hook environments build and all hooks run (`evidence/DEF-003-retest.txt`). The
  defect row is updated to Closed.
- DEF-004: first retest (2026-11-01) still reproduced. Second retest (2026-11-02): see below.
- Review findings 8 and 9 (check defects): TC-T05-07 and TC-T05-10 are fixed and now Pass.

## DEF-004 retest (2026-11-02)

Commit `c614327` on `task/T04a-def004-baseline`, same environment. Original Fail evidence is
unchanged; retest evidence is in `evidence/DEF-004-retest-*.txt` and `evidence/retest-def004/`.

| Check | Result | Evidence |
|---|---|---|
| `.tools/pre-commit run --all-files` | exit 0, all hooks Passed (Hadolint skipped: no files); no tracked file changed (only the new evidence files are untracked) | `DEF-004-retest-precommit.txt`, `DEF-004-retest-status.txt` |
| `ddev quality` | exit 0; PASS pre-commit, branch-name, commit-range, exceptions, assets, component-drupal; SKIP component-engine, component-drupal-tests, component-web; PASS 6 FAIL 0 SKIP 3 | `DEF-004-retest-quality.txt` |
| TC-T05-24 | Pass (was Fail) | `retest-def004/TC-T05-24.txt`, `static-run.txt` |
| TC-T05-34 | Pass (was Fail) | `retest-def004/TC-T05-34.txt`, `live-run.txt`, `live-run2.txt` |
| TC-T05-21 | Fail | `retest-def004/TC-T05-21.txt`, `T04a-regression.txt` |

TC-T05-21 failure at the first retest: the T04a regression check
"markdownlint 'ignores': only TASKS.md and evidence,
each with a ticket" (TC-T04a-28) fails on `docs/tests/T03/fixtures/partial-data-model.md`, added
to `.markdownlint-cli2.yaml` by `c614327` with a T04a/DEF-004 ticket. The same run shows TC-T04a-30
counting PASS 119 (T04) and 355 (T03) against 118 and 354 at close; per the DEF-004 review these are
content added since close, so I do not count them as a failure, but the check still compares against
fixed numbers and prints FAIL. Whether the exclusion is accepted is a decision for the owner and
architect; I did not change any expected result.

Notes on the live reruns. TC-T05-28 failed once in `live-run.txt` (drush status output not parsed,
"None None") and passed in `live-run2.txt` and by hand (`ddev drush status`: bootstrap Successful,
database Connected); recorded as a transient. TC-T05-33 and 35 fail in the working tree only because
the rerun itself runs on a tree with modified and untracked files (evidence files and other edits);
their Pass status rests on the clean-clone evidence in `evidence/clone-live/` and I did not rerun the
clean clone. The rerun overwrote the original `evidence/TC-T05-nn.txt` files; I restored them byte
for byte from a copy, and the new copies are in `evidence/retest-def004/`.

Regression after the fix (`evidence/retest-def004/regression/`): guard tests 30 OK; `scripts/tests`
65 OK; T00, T03 and T04 pass; T02 exits 1 on the existing `.env.example` base-branch check (the same
as before the fix); T04a --regression and T05 --regression fail only on the TC-T04a-28 check above;
the eight Python checks are unchanged.

Second retest (2026-11-02, after the main session removed the fixture exclude from
`.markdownlint-cli2.yaml` and I reformatted `docs/tests/T03/fixtures/partial-data-model.md`, formatting
only, T03 Change log row added; nothing committed): `.tools/pre-commit run --all-files` exit 0 and
the tree unchanged afterwards (`retest-def004/precommit-after-fixture.txt`); T04a `--regression`
now passes TC-T04a-28 (`retest-def004/T04a-regression-2.txt`; final T05 static run
`retest-def004/static-run-3.txt`). Only the two TC-T04a-30 count checks
still print FAIL (T04 119 vs 118, T03 355 vs 354, both exit 0, no FAIL line inside). The extra PASS
is the "pre-commit run on T0x files passes" check, SKIP at close and now running. This is not the
DEF-004 baseline problem, so DEF-004 is Retest passed and the count rule is logged as DEF-005.
TC-T05-21 stays Fail as written.

Third retest (2026-11-02): the main session ruled that TC-T04a-30 rule 1 is a no-regression
check. I changed it in `docs/tests/T04a/run-checks.sh` (FAIL on any FAIL line, non-zero exit or a
PASS count below the count at close; both numbers printed; four negative controls) and added a
T04a Change log row citing DEF-005. T04a `--regression` exits 0 (`retest-def004/T04a-regression-4.txt`)
and TC-T05-21 passes (`retest-def004/static-run-4.txt`, 24 cases PASS, 2 BLOCKED).

Final counts: 38 pass, 0 fail, 2 blocked (TC-T05-39, 40; owner-run), 0 not run.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| DEF-003 | High | Closed after retest |
| DEF-004 | Medium | Retest passed (2026-11-02); not cited by any failing case |
| DEF-005 | Low | Retest passed (2026-11-02); TC-T04a-30 now fails only on a real regression |

## Coverage notes

- Not tested: AC6 verbatim on a separate machine and the Windows browser mkcert login
  (TC-T05-39 and 40, owner-run). shellcheck and gitleaks are not on the host PATH; the
  pre-commit hooks ran them (TC-T05-24).
- Review finding 19 (broad exception in `scripts/bootstrap-dev.sh`) is not a test item.
- Review conditions: 1 done; 2 evidenced here (AC1 to AC5, clean clone, step lines); 3 and 4
  belong to `/close-task` and the developer.

## Sign-off

Not signed off. No case is Fail and DEF-004 and DEF-005 are Retest passed, but TC-T05-39 and 40 are
Blocked (owner-run) and the sign-off rule does not allow a sign-off while any case is Blocked; the
earlier task reports (T03) stayed "Not signed off" in the same situation. AC1 to AC5 are verified;
AC6 awaits the owner run, after which the report can be signed off. tester, 2026-11-02 (first run
2026-11-01).
