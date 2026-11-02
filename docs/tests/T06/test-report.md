# T06: Extra Docker services in DDEV, Test report

| Field | Value |
|---|---|
| Task | T06 |
| Build or commit | `5bf194e` on `task/T06-ddev-services`, plus uncommitted tester changes (check fixes, new cases, evidence; the tester does not commit) and an unrelated uncommitted `docs/tasks/T06/review.md` edit that the tester did not make |
| Environment | WSL2 (Linux 6.18.54.1-microsoft-standard-WSL2), DDEV v1.24.4, Docker 28.1.1, Python 3.10 with PyYAML, `.tools/pre-commit`; `shellcheck`, `yamllint` and `gitleaks` not on PATH (the pre-commit hooks ran them) |
| Date | 2026-11-02 |
| Executed by | tester |

## Summary

Owner approval for the intrusive live tests ("Run all, incl. poweroff") was given in the session.
The live run stopped every DDEV project through
`ddev poweroff`. Before the run `circleoftrust`, `esure` and `punrasar-baba` were already stopped
and only `meridian` was running, so no other project
was running when poweroff ran. They were not started, changed or deleted. Only `meridian` was
restarted. **The owner must run `ddev start` in the
other projects if needed.** The clean-clone run also unlisted and deleted the `meridian` project and
its Docker volumes (as designed); the original
tree was started again, and `ddev drupal-install` was re-run in it (local, throwaway data).

Execution modes and the run that counts (evidence in `evidence/`):

| Mode | Command | Result | Log |
|---|---|---|---|
| Static plus live | `T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --live` (run id 20261102T064955Z) | 46 cases PASS, 0 FAIL, 3 BLOCKED; 280 checks | `run-live-3.20261102.txt` |
| Clean clone | `T06_CONFIRM=1 T06_EVIDENCE=1 docs/tests/T06/run-checks.sh --clean-clone` (run id 20261102T070024Z) | 5 cases PASS, 0 FAIL; 49 checks | `run-clean-clone.20261102.txt` |
| Regression sets | `docs/tests/{T04a,T05,T06}/run-checks.sh --regression` | all exit 0 | `regression-T04a.20261102.txt`, `regression-T05.20261102.txt`, `regression-T06.20261102.txt` |
| `ddev quality` | `ddev quality` | exit 0; PASS 6, FAIL 0, SKIP 3 (`component-engine`, `component-drupal-tests`, `component-web`) | `ddev-quality.20261102.txt` |

Superseded runs, kept as evidence of how the checks were fixed (not counted): the first `--live` run
(`run-live-1-superseded.20261102.txt`, 2 FAIL: TC-T06-33 and
TC-T06-43 required an empty `git status` while the tester's own work was uncommitted; check defect,
fixed) and the second (`run-live-2-superseded.20261102.txt`,
failures in the pre-commit and `ddev quality` checks from one table row without a closing pipe in
`test-cases.md`, which the tester fixed). The first
static run before the check fixes had 4 FAIL (TC-T06-01, 09, 17, 19), all check defects (see the
Change log in `test-cases.md`).

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T06-01 | AC1 | Pass | `evidence/TC-T06-01.20261102T064955Z.txt` |
| TC-T06-02 | AC1, C4, dependency policy | Pass | `evidence/TC-T06-02.20261102T064955Z.txt` |
| TC-T06-03 | AC5 | Pass | `evidence/TC-T06-03.20261102T064955Z.txt` |
| TC-T06-04 | C6, KD-3 | Pass | `evidence/TC-T06-04.20261102T064955Z.txt` |
| TC-T06-05 | AC2, KD-2 | Pass | `evidence/TC-T06-05.20261102T064955Z.txt` |
| TC-T06-06 | AC2, AC6a | Pass | `evidence/TC-T06-06.20261102T064955Z.txt` |
| TC-T06-07 | AC4, KD-4 | Pass | `evidence/TC-T06-07.20261102T064955Z.txt` |
| TC-T06-08 | AC3, KD-7 | Pass | `evidence/TC-T06-08.20261102T064955Z.txt` |
| TC-T06-09 | AC4, KD-8 | Pass | `evidence/TC-T06-09.20261102T064955Z.txt` |
| TC-T06-10 | AC5, KD-10 | Pass | `evidence/TC-T06-10.20261102T064955Z.txt` |
| TC-T06-11 | AC6a, KD-1, KD-5, KD-6 | Pass | `evidence/TC-T06-11.20261102T064955Z.txt` |
| TC-T06-12 | KD-1, non-goals | Pass | `evidence/TC-T06-12.20261102T064955Z.txt` |
| TC-T06-13 | AC4, C6 | Pass | `evidence/TC-T06-13.20261102T064955Z.txt` |
| TC-T06-14 | C5, AC3, decision condition 3 | Pass | `evidence/TC-T06-14.20261102T064955Z.txt` |
| TC-T06-15 | C6, KD-9 | Pass | `evidence/TC-T06-15.20261102T064955Z.txt` |
| TC-T06-16 | C6 | Pass | `evidence/TC-T06-16.20261102T064955Z.txt` |
| TC-T06-17 | FR-11, ADR-0006, CLAUDE.md | Pass | `evidence/TC-T06-17.20261102T064955Z.txt` |
| TC-T06-18 | section 0 | Pass | `evidence/TC-T06-18.20261102T064955Z.txt` |
| TC-T06-19 | C4 | Pass | `evidence/TC-T06-19.20261102T064955Z.txt` |
| TC-T06-20 | AC1 | Pass | `evidence/TC-T06-20.20261102T064955Z.txt` |
| TC-T06-21 | AC1, KD-2 | Pass | `evidence/TC-T06-21.20261102T064955Z.txt` |
| TC-T06-22 | AC2 | Pass | `evidence/TC-T06-22.20261102T064955Z.txt` |
| TC-T06-23 | AC2 | Pass | `evidence/TC-T06-23.20261102T064955Z.txt` |
| TC-T06-24 | AC2 | Pass | `evidence/TC-T06-24.20261102T064955Z.txt` |
| TC-T06-25 | AC3 | Pass | `evidence/TC-T06-25.20261102T064955Z.txt` |
| TC-T06-26 | AC3 | Pass | `evidence/TC-T06-26.20261102T064955Z.txt` |
| TC-T06-27 | AC3 | Pass | `evidence/TC-T06-27.20261102T064955Z.txt` |
| TC-T06-28 | AC3 | Pass | `evidence/TC-T06-28.20261102T064955Z.txt` |
| TC-T06-29 | AC3, KD-7 | Pass | `evidence/TC-T06-29.20261102T064955Z.txt` |
| TC-T06-30 | C4 | Pass | `evidence/TC-T06-30.20261102T064955Z.txt` |
| TC-T06-31 | AC4 | Pass | `evidence/TC-T06-31.20261102T064955Z.txt` |
| TC-T06-32 | AC4 | Pass | `evidence/TC-T06-32.20261102T064955Z.txt` |
| TC-T06-33 | AC4 | Pass | `evidence/TC-T06-33.20261102T064955Z.txt` |
| TC-T06-34 | AC4 | Pass | `evidence/TC-T06-34.20261102T064955Z.txt` |
| TC-T06-35 | AC5 | Pass | `evidence/TC-T06-35.20261102T064955Z.txt` |
| TC-T06-36 | AC5 | Pass | `evidence/TC-T06-36.20261102T064955Z.txt` |
| TC-T06-37 | AC5 | Pass | `evidence/TC-T06-37.20261102T064955Z.txt` |
| TC-T06-38 | AC5 | Pass | `evidence/TC-T06-38.20261102T064955Z.txt` |
| TC-T06-39 | AC5 | Pass | `evidence/TC-T06-39.20261102T064955Z.txt` |
| TC-T06-40 | AC6a | Pass | `evidence/TC-T06-40.20261102T064955Z.txt` |
| TC-T06-41 | AC6a, AC2, KD-2 | Pass | `evidence/TC-T06-41.20261102T064955Z.txt` |
| TC-T06-42 | AC6b | Blocked | `evidence/TC-T06-42.20261102T064955Z.txt` |
| TC-T06-43 | KD-7, C6 | Pass | `evidence/TC-T06-43.20261102T064955Z.txt` |
| TC-T06-44 | C7, AC1 | Pass | `evidence/TC-T06-44.20261102T070024Z.txt` |
| TC-T06-45 | AC2, AC6a, C7 | Pass | `evidence/TC-T06-45.20261102T070024Z.txt` |
| TC-T06-46 | decision condition 2, KD-5 | Pass | `evidence/TC-T06-46.20261102T070024Z.txt` |
| TC-T06-47 | KD-4, AC4 | Pass | `evidence/TC-T06-47.20261102T070024Z.txt` |
| TC-T06-48 | AC6a | Blocked | `evidence/TC-T06-48.20261102T064955Z.txt` |
| TC-T06-49 | C7 | Blocked | `evidence/TC-T06-49.20261102T064955Z.txt` |
| TC-T06-50 | AC4 (review finding 1; plan addendum 2026-11-02, KD-8) | Pass | `evidence/TC-T06-50.20261102T064955Z.txt` |
| TC-T06-51 | AC4 (review finding 3) | Pass | `evidence/TC-T06-51.20261102T064955Z.txt` |
| TC-T06-52 | AC4 (review finding 4) | Pass | `evidence/TC-T06-52.20261102T064955Z.txt` |
| TC-T06-53 | AC3 (documentation claim, review finding 5) | Pass | `evidence/TC-T06-53.20261102T064955Z.txt` |
| TC-T06-54 | C7 (tester walk-through; TC-T06-49 stays the owner-run word-for-word case) | Pass | `evidence/TC-T06-54.20261102T070024Z.txt` |

Totals: 51 pass, 0 fail, 3 blocked, 0 not run (54 cases).

Blocked cases:

| Case | Reason |
|---|---|
| TC-T06-42 | AC6b: no `apps/web/package.json` until T21. Needs the owner's written acceptance at close (an agent message is not acceptance). Re-run in T21 with the procedure printed by the script. |
| TC-T06-48 | Owner-run: open `https://meridian.ddev.site:3001` in the Windows browser without a certificate warning. |
| TC-T06-49 | Owner-run: the runbook word for word on a clean machine. The tester walk-through of the same steps in a clean clone is TC-T06-54 (Pass). |

## Check defects fixed before the run

Each has a row in the Change log of `docs/tests/T06/test-cases.md` (and in
`docs/tests/T04a/test-cases.md` for the `.env.example` check). None is a product defect.

| Case | Fix |
|---|---|
| TC-T06-01 | Both sides sorted. |
| TC-T06-09 | Check updated for the whole-archive validation (`pg_restore -f /dev/null`) placed before the call to `restore_into_db` (plan addendum, review finding 1). |
| TC-T06-17 | The docs scan covers only lines T06 added. |
| TC-T06-19, TC-T05-21 | `docs/tests/T04a/run-checks.sh` TC-T04a-33 compares `.env.example` variable lines only. T04a, T05 and T06 `--regression` pass. |
| TC-T06-24 | Pattern accepts `UNABLE_TO_VERIFY_LEAF_SIGNATURE`. |
| TC-T06-25, 26, 28, 34 | Exit 2, 5, 7 asserted by direct invocation; through `ddev`, exit 1 and `exit status N` on stderr. The invalid ERE `(?i)` in TC-T06-34 removed. |
| TC-T06-36 to 39 | Last line taken from standard output only; stderr must hold `exit status 1`. |
| TC-T06-33, 43 | `git status` and `git diff` compared with a baseline taken at the start of the run, because the tester does not commit. On a committed tree the baseline is empty. |
| New | TC-T06-50 (truncated dump refused, data unchanged), 51 (path with a quote), 52 (directory target), 53 (relative FILE), 54 (runbook walk-through in the clean clone). |

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| (none) | | No product defect found. DEF-006 was not needed. |

## Coverage notes

- All six acceptance criteria are covered; AC6a passes (route and TLS on port 3001 serve the
  placeholder, trusted TLS, no HTTP route). AC6b is Blocked and
  needs the owner's written acceptance.
- Review findings 1, 3 and 4 are verified by TC-T06-50, 51 and 52; finding 5 (relative path) by
  TC-T06-53: the documented rule is true. Findings 2 and 6
  are documentation and design choices: finding 2 wording is present in the runbook and
  `.ddev/README.md`; for finding 6 the `ddev-global-cache` mount is
  read-only (TC-T06-06, 16); whether a `subpath` mount is possible is not tested.
- Clean clone: `ddev start` with no `.env` brought up all five services healthy in 43 s (images were
  already local; not a first-pull figure). `ddev delete -Oy`
  removes the `meridian-postgres-data` volume, and the runbook says so.
- NFR-17 first-pull timing was not measured.

### Runbook problems found (`docs/runbooks/local-setup.md`)

1. "Last verified" says a clean-clone run is not done. It is now done (2026-11-02, tester, TC-T06-44
   to 47 and 54).
2. Step 1 clones from GitHub and says to check out `task/T05-ddev-drupal`. The T06 branch is not on
   the remote, so the tester used `file://` of the local branch. The
   T05 sentence is out of date for this branch.
3. The Verification section still says "Until DEF-004 is fixed, `ddev quality` exits 1". DEF-004 is
   Retest passed and `ddev quality` exits 0 now.
4. Step 2 says the old checkout's local database is deleted. Since T06 it also deletes the Postgres
   volume `meridian-postgres-data`; step 2 does not say so.
5. Step 4 prints the admin password on screen. The runbook already says not to record it.
6. All other steps ran as written with the stated output.

## Sign-off

**Signed off at close, 2026-11-02, with owner-accepted deferrals.** The owner accepted in writing
in the session: "I accept AC6b deferred to T21" (TC-T06-42, re-run owed by T21) and "I accept
TC-T06-48 and TC-T06-49 as owner-run, deferred". No case is Fail. Recorded by the main session at
`/close-task`.

Tester's sign-off text at execution (kept unchanged):

Not signed off. 51 of 54 cases Pass, none Fail, and 3 are Blocked (TC-T06-42 until the owner accepts
the AC6b deferral in writing and T21 re-runs it;
TC-T06-48 and 49 are owner-run). By the rule that a report is not signed off while a case is
Blocked, the criteria AC1 to AC5 and AC6a are verified, and
AC6b and the owner-run browser and word-for-word cases remain open. Tester, 2026-11-02.
