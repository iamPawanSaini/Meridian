# T02: Solution architecture, Test report

| Field | Value |
|---|---|
| Task | T02 |
| Build or commit | `085b3e9` + uncommitted T02 docs (branch `task/T02-solution-architecture`) |
| Environment | Linux 6.18 (WSL2), bash, Python 3 (`python3 -I`), no network or web tool, markdownlint not installed, `.tools/pre-commit` not installed, no Mermaid renderer |
| Date | 2026-11-01 |
| Executed by | tester |

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T02-01 | AC1 | Pass | `evidence/TC-T02-01.txt` |
| TC-T02-02 | AC1, C7 | Pass | `evidence/TC-T02-02.txt` |
| TC-T02-03 | AC1 | Pass | `evidence/TC-T02-03.txt` |
| TC-T02-04 | AC2 | Pass | `evidence/TC-T02-04.txt` |
| TC-T02-05 | AC2 | Pass | `evidence/TC-T02-05.txt` |
| TC-T02-06 | AC2 | Pass | `evidence/TC-T02-06.txt` |
| TC-T02-07 | AC2 | Pass (manual) | `evidence/manual-review.md` |
| TC-T02-08 | AC3 | Pass | `evidence/TC-T02-08.txt` |
| TC-T02-09 | AC3 | Pass | `evidence/TC-T02-09.txt` |
| TC-T02-10 | AC3 | Pass (manual) | `evidence/manual-review.md` |
| TC-T02-11 | AC4 | Pass | `evidence/TC-T02-11.txt` |
| TC-T02-12 | AC4 | Pass (manual) | `evidence/manual-review.md` |
| TC-T02-13 | AC5 | Pass | `evidence/TC-T02-13.txt` |
| TC-T02-14 | AC5 | Pass | `evidence/TC-T02-14.txt` |
| TC-T02-15 | AC5, C5 | Pass | `evidence/TC-T02-15.txt` |
| TC-T02-16 | AC5 | Pass | `evidence/TC-T02-16.txt` |
| TC-T02-17 | AC6 | Pass | `evidence/TC-T02-17.txt` |
| TC-T02-18 | AC6 | Pass | `evidence/TC-T02-18.txt` |
| TC-T02-19 | AC6, C4 | Pass (rename sub-check vacuous) | `evidence/TC-T02-19.txt`, `evidence/extra-steps.txt` |
| TC-T02-20 | AC6 | Pass (manual) | `evidence/manual-review.md` |
| TC-T02-21 | PX | Pass | `evidence/TC-T02-21.txt` |
| TC-T02-22 | C7 | Pass | `evidence/TC-T02-22.txt` |
| TC-T02-23 | SIM | Pass | `evidence/TC-T02-23.txt`, `evidence/extra-steps.txt` |
| TC-T02-24 | AC7 | Pass | `evidence/TC-T02-24.txt` |
| TC-T02-25 | AC8, C2 | Pass | `evidence/TC-T02-25.txt` |
| TC-T02-26 | AC2, C5 | Pass | `evidence/TC-T02-26.txt` |
| TC-T02-27 | C1, C2 | Pass | `evidence/TC-T02-27.txt`, `evidence/extra-steps.txt` |
| TC-T02-28 | C5 | Pass | `evidence/TC-T02-28.txt` |
| TC-T02-29 | C6 | **Blocked** | `evidence/TC-T02-29.txt`, `evidence/extra-steps.txt` |
| TC-T02-30 | C4, C7 | Pass (markdownlint SKIP, not available) | `evidence/TC-T02-30.txt` |
| TC-T02-31 | C3 | Pass (manual) | `evidence/manual-review.md` |
| TC-T02-32 | C7 | **Blocked** | `evidence/TC-T02-32-static.txt`, `evidence/manual-review.md` |
| TC-T02-33 | AC1, AC2 | Pass (manual) | `evidence/manual-review.md` |
| TC-T02-34 | PX | Pass (main session) | `evidence/TC-T02-34-main-session-spotcheck.md`: 4 of 4 sampled claims supported |
| TC-T02-35 | AC5 | Pass (manual) | `evidence/manual-review.md` |

Totals: 33 pass, 0 fail, 2 blocked, 0 not run.

Full script output: `evidence/run-checks.txt`. The only `FAIL` line in it is `BLOCKED .tools/pre-commit not installed` (TC-T02-29), an environment condition, not a document defect. The script exits non-zero because of that line.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| (none) | | |

No document defects were found. The three blocked cases are environment or owner-action blocks, so nothing was logged in `docs/tests/defects.md`.

## Coverage notes

- **Blocked, owner action (TC-T02-29):** the secret scan needs `.tools/pre-commit`, installed by `scripts/bootstrap-dev.sh` (owner action from T00). The other C6 sub-checks passed: `.env.example` is unchanged against `task/T01-agents`, and no key-like strings were found in the T02 docs.
- **Blocked, environment (TC-T02-32):** no GitHub preview (branch not pushed, no network) and no local Mermaid renderer. Static syntax validation passed (3 blocks, balanced fences, subgraph/alt/loop vs `end`, brackets, quotes, defined nodes) but a static check is not a render.
- **TC-T02-34:** the tester had no web tool; the main session ran the live comparison afterwards (see evidence file). 4 of 4 sampled claims supported.
- markdownlint is not available: SKIP recorded, per the plan ("if available").
- TC-T02-19 rename sub-check is vacuous because the outcome is "keep as internal codename only".
- Naming owner actions OA-1 to OA-5 remain open (ticketed to T33 as OQ-10). They are not test blockers.
- Not tested: Mermaid rendering on GitHub. External claims were sampled (4 claims), not exhaustively re-verified.

## Sign-off

**Not signed off.** Cases TC-T02-29 (owner: run `scripts/bootstrap-dev.sh`, then the secret scan) and TC-T02-32 (GitHub Mermaid render, after push) are Blocked. TC-T02-34 was executed by the main session on 2026-11-01 with a web-fetch agent (4 of 4 claims supported).

To unblock:

1. TC-T02-29: owner runs `scripts/bootstrap-dev.sh` so `.tools/pre-commit` exists, then the secret scan is re-run (owner action).
2. TC-T02-32: push the branch and view `docs/architecture/solution-architecture.md` on GitHub, or install a Mermaid renderer, then re-run (environment).

No case failed and no document defect is open. Tester, 2026-11-01.
