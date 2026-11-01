# T04a: Coding standards and quality gates, Test report

| Field | Value |
|---|---|
| Task | T04a |
| Build or commit | `e56df69` on `task/T04a-coding-standards` (design 80d681a; reviews: `docs/tasks/T04a/review.md`, `review-standards.md`, both approved) |
| Environment | Linux 6.18 (WSL2), bash, Python 3.10.12, git 2.34.1, node 22.14.0, php present; agent sandbox, no network. Not installed: pre-commit, ruff, mypy, shellcheck, yamllint, markdownlint-cli2, hadolint, Spectral, composer, DDEV |
| Date | 2026-11-01 |
| Executed by | tester (execute mode). The standards, scripts and configs were written by the technical-architect and developer; the cases were designed by the tester before they existed |

## How it was run

- `docs/tests/T04a/run-checks.sh` on the working tree: 302 PASS, 0 FAIL, 7 SKIP, 16 BLOCKED, exit 0
  (`evidence/run-checks-execution.txt`; per-case blocks `evidence/TC-T04a-nn.txt`).
- `--regression` (invariants only): 293 PASS, 0 FAIL, 9 snapshot checks excluded
  (`evidence/run-checks-regression-execution.txt`).
- Clean clone of the branch into `/tmp` (no untracked files, HEAD e56df69): 302 PASS, 0 FAIL,
  exit 0 (`evidence/run-checks-clean-clone.txt`).
- TC-30 (T03 regression), settled: `docs/tests/T03/run-checks.sh` five more times on a quiet tree,
  354 PASS and exit 0 each time (`evidence/TC-T04a-30-T03-repeat-1.txt` to `-5.txt`). The single
  failure seen during design (353 PASS, exit 1) did not recur and was not reproducible; it happened
  while files in the tree were being edited. It is noted as an unexplained one-off, not logged as a
  defect.
- `evidence/design-time-run.txt` is the historical design-time run and was not changed.
- Manual TC-52: `evidence/manual-review.md`.
- Harness check: against the reference models in `reference/` the same script gave 300 PASS
  (`evidence/harness-selftest-reference-impl.txt`), so the behavioural cases are able to pass and
  reject. Against the real scripts they pass for the right reasons: every rejection case is paired
  with an accepting control.

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T04a-01 | AC1 | Pass | `evidence/TC-T04a-01.txt` |
| TC-T04a-02 | AC1, AC3 | Pass | `evidence/TC-T04a-02.txt` |
| TC-T04a-03 | AC2 | Pass | `evidence/TC-T04a-03.txt` |
| TC-T04a-04 | AC2, AC3, AC4, AC6 | Pass | `evidence/TC-T04a-04.txt` |
| TC-T04a-05 | AC7 | Pass | `evidence/TC-T04a-05.txt` |
| TC-T04a-06 | AC7 | Pass | `evidence/TC-T04a-06.txt` |
| TC-T04a-07 | AC8 | Pass | `evidence/TC-T04a-07.txt` |
| TC-T04a-08 | AC3 | Pass | `evidence/TC-T04a-08.txt` |
| TC-T04a-09 | AC3 | Pass | `evidence/TC-T04a-09.txt` |
| TC-T04a-10 | AC3, AC4 | Pass | `evidence/TC-T04a-10.txt` |
| TC-T04a-11 | AC4 | Pass | `evidence/TC-T04a-11.txt` |
| TC-T04a-12 | AC4, AC9 | Pass | `evidence/TC-T04a-12.txt` |
| TC-T04a-13 | AC4 | Pass | `evidence/TC-T04a-13.txt` |
| TC-T04a-14 | AC4 | Pass | `evidence/TC-T04a-14.txt` |
| TC-T04a-15 | AC4, AC9 | Pass | `evidence/TC-T04a-15.txt` |
| TC-T04a-16 | AC4 | Pass | `evidence/TC-T04a-16.txt` |
| TC-T04a-17 | AC6 | Pass | `evidence/TC-T04a-17.txt` |
| TC-T04a-18 | AC6 | Pass | `evidence/TC-T04a-18.txt` |
| TC-T04a-19 | AC7, AC9 | Pass | `evidence/TC-T04a-19.txt` |
| TC-T04a-20 | AC7 | Pass | `evidence/TC-T04a-20.txt` |
| TC-T04a-21 | AC9 | Pass | `evidence/TC-T04a-21.txt` |
| TC-T04a-22 | AC9 | Pass | `evidence/TC-T04a-22.txt` |
| TC-T04a-23 | AC5 | Pass | `evidence/TC-T04a-23.txt` |
| TC-T04a-24 | AC5 | Pass | `evidence/TC-T04a-24.txt` |
| TC-T04a-25 | AC5 | Pass | `evidence/TC-T04a-25.txt` |
| TC-T04a-26 | AC3, AC9 | Pass | `evidence/TC-T04a-26.txt` |
| TC-T04a-27 | AC6, AC9 | Pass | `evidence/TC-T04a-27.txt` |
| TC-T04a-28 | AC6 | Pass | `evidence/TC-T04a-28.txt` |
| TC-T04a-29 | AC6 | Pass | `evidence/TC-T04a-29.txt` |
| TC-T04a-30 | C5 | Pass | `evidence/TC-T04a-30.txt`, `TC-T04a-30-T03-repeat-*.txt` |
| TC-T04a-31 | AC3, C4 | Blocked (all 7 tools absent; 0 checks ran) | `evidence/TC-T04a-31.txt` |
| TC-T04a-32 | C5 | Pass | `evidence/TC-T04a-32.txt` |
| TC-T04a-33 | C6, SIM | Pass | `evidence/TC-T04a-33.txt` |
| TC-T04a-34 | C1, C2 | Pass (snapshot) | `evidence/TC-T04a-34.txt` |
| TC-T04a-35 | AC5 (SKIP rule) | Pass (snapshot) | `evidence/TC-T04a-35.txt` |
| TC-T04a-36 to 47 | AC3 to AC6, AC9, C4, C7 | Blocked (owner-run) | none yet |
| TC-T04a-48 | AC5 | Blocked (deferred to T05) | none |
| TC-T04a-49 | AC3, AC9 | Blocked (deferred to T05, T09) | none |
| TC-T04a-50 | AC3, AC9 | Blocked (deferred to T21) | none |
| TC-T04a-51 | AC4, AC7, AC9 | Blocked (deferred to T08, T09, T13, T21) | none |
| TC-T04a-52 | AC1, AC2, AC8 | Pass | `evidence/manual-review.md` |
| TC-T04a-53 to 56 | AC6 (D-4 addendum rows) | Blocked (owner-run) | none yet |
| TC-T04a-57 | AC6 | Blocked (deferred to T21) | none |
| TC-T04a-58 | AC6 | Blocked (deferred to T05, T09) | none |

Totals (58 cases): 35 pass, 0 fail, 23 blocked, 0 not run. The 23 blocked are TC-31, TC-36 to 47
(12), TC-48 to 51 (4), TC-53 to 56 (4), TC-57 and 58.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| (none) | | |

No case failed, so no defect is logged and `docs/tests/defects.md` is unchanged (next ID DEF-003).
Observations for the technical-architect (advisory, not defects): O-1 and O-2 in
`evidence/manual-review.md` (no checklist question for the py310 target or for merge-commit-only).

## Blocked at close

Every row needs either the evidence named or written owner acceptance before the task closes.
Decision D-6 (accept carried-over cases in writing) is still unconfirmed by the owner, so none of
the deferred rows is yet accepted. The T04a review conditions (owner-run TC-36 to 47, owner
acceptance of the deferred cases, T08 `fetch-depth: 0`) are the same list.

| Case | Why Blocked | Needed to unblock | Owner acceptance |
|---|---|---|---|
| TC-31 | None of ruff, mypy, shellcheck, yamllint, markdownlint-cli2, pre-commit is installed here; zero checks ran | Covered by owner-run TC-36, 37, 39 to 45 | Pending |
| TC-36 to 38 | Needs network for pre-commit downloads: bootstrap, `pre-commit run --all-files`, `quality.sh` on a clean tree | Owner runs `docs/tests/T04a/run-checks.sh --owner`; stores output and tool versions (C7) | Pending |
| TC-39 to 45 | Real-hook rejection demos (untyped Python, ruff, long Markdown, shellcheck, YAML, hadolint, Spectral) | Same owner run | Pending |
| TC-46, 47 | Bad commit message through the installed hook; bad branch through `quality.sh` | Same owner run | Pending |
| TC-53 to 56 | Real-tool checks of the D-4 addendum rows (coverage.py, hadolint, markdownlint, yamllint) | Same owner run (pip and hook downloads) | Pending |
| TC-48 | `ddev quality` needs `.ddev/config.yaml` | T05 | Pending (D-6) |
| TC-49, 58 | Bad PHP style, phpcs ignore form; need Composer tools and custom modules | T05, T09 | Pending (D-6) |
| TC-50, 57 | ESLint, tsc, Prettier, `@ts-expect-error` form; need the web scaffold | T21 | Pending (D-6) |
| TC-51 | CI coverage drop, CI branch check, real Cobertura attribute names | T08, T09, T13, T21 | Pending (D-6) |

## Coverage notes

- What passed is the agent-side verification: the standards and checklist content, the tool
  configs, the hook wiring, and the behaviour of all five scripts and `quality.sh` in throwaway
  repos (commit messages incl. 72-character boundary, `--range`, a real git hook, branch names,
  exceptions in the D-4 addendum forms with bare-form negatives, coverage floors and boundaries on
  Cobertura fixtures, asset rules, SKIP versus FAIL and the exit code, the wrapper).
- The "verification by the tester" criterion (one non-compliant change per language rejected) is
  therefore only partly met by agent evidence: the commit message, the coverage drop, the long
  Markdown line (checker), untyped Python (typing proxy) and asset cases are proven here; the
  rejections by the real ruff, mypy, shellcheck, yamllint, hadolint, markdownlint and Spectral
  hooks, and bad PHP and ESLint changes, are not yet.
- The interface assumptions A-1 to A-5 held against the developer's scripts; no adapter change was
  needed.
- The TASKS.md exclusion rests on the pending owner confirmation of OQ-T04a-1.

## Sign-off

Not signed off. No case failed and no defect is open, but 23 cases are Blocked and the Blocked at
close table above is not yet accepted: owner-run TC-36 to 47 and 53 to 56 have not been run, and
the deferred cases need written owner acceptance because D-6 is unconfirmed. It becomes "Signed off
with accepted Blocked cases" once the owner-run evidence is stored (or accepted) and each deferred
row is accepted in writing. Tester, 2026-11-01.
