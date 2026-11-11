# T02: Solution architecture, Test report

| Field | Value |
|---|---|
| Task | T02 |
| Build or commit | `task/T02-retest` at HEAD `9b846bb` (main + T00 close + T03 retest; review Approved, re-review 2026-11-01). Cases other than 29, 30, 32 were executed 2026-11-01 on `085b3e9` + T02 docs; 29, 30, 32 executed 2026-11-06 |
| Environment | Linux 6.18 (WSL2), bash, Python 3 (`python3 -I`), node 22.14 (nvm), mermaid 12.3.0 (npx cache of mermaid-cli), `.tools/pre-commit` 4.7.0 with gitleaks 8.30.1 (markdownlint-cli2 via pre-commit), Chromium unavailable |
| Date | 2026-11-06 (TC-T02-29, 30, 32); 2026-11-01 (others) |
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
| TC-T02-29 | C6 | Pass (2026-11-06; step 2 judged on T02 history, see notes) | `evidence/run-checks-2026-11-06.txt`, `evidence/run-checks-2026-11-06-regression.txt`, `evidence/TC-T02-29-env-diff.txt`, `evidence/TC-T02-29-env-log.txt` |
| TC-T02-30 | C4, C7 | Pass (markdownlint-cli2 clean via pre-commit, 2026-11-06) | `evidence/TC-T02-30.txt`, `evidence/TC-T02-30-markdownlint.txt` |
| TC-T02-31 | C3 | Pass (manual) | `evidence/manual-review.md` |
| TC-T02-32 | C7 | Pass (parse-level only, 2026-11-06) | `evidence/TC-T02-32.txt`, `evidence/mermaid-blocks/` |
| TC-T02-33 | AC1, AC2 | Pass (manual) | `evidence/manual-review.md` |
| TC-T02-34 | PX | Pass (main session) | `evidence/TC-T02-34-main-session-spotcheck.md`: 4 of 4 sampled claims supported |
| TC-T02-35 | AC5 | Pass (manual) | `evidence/manual-review.md` |

Totals: 35 pass, 0 fail, 0 blocked, 0 not run (35 cases). TC-T02-29 and TC-T02-32 were Blocked on
2026-11-01 and were executed on 2026-11-06; TC-T02-30 was rerun for markdownlint.

Full script output: `evidence/run-checks.txt` (2026-11-01) and `evidence/run-checks-2026-11-06.txt`
(2026-11-06). The 2026-11-06 full run has one FAIL line, the at-close `.env.example` diff (see
TC-T02-29 below); the `--regression` run (`evidence/run-checks-2026-11-06-regression.txt`) passes all
checks with that one snapshot check excluded.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| (none) | | |

No defects were found; nothing was logged in `docs/tests/defects.md` (next free ID stays DEF-016).

## Coverage notes

- **TC-T02-29 (C6):** `.tools/pre-commit run --all-files` passes (gitleaks included) and no key-like
  strings were found in the T02 docs. Step 2 (`git diff task/T01-agents -- .env.example` prints
  nothing) is NOT literally met: the diff is non-empty because T03, T06 and T07 extended
  `.env.example` after the T02 base (`git log task/T01-agents..HEAD -- .env.example` shows only
  d965f95, ad11e74 and 96b4c17; neither T02 commit touches it). I passed the case on the intent of
  C6 for T02, using the existing at-close/`--regression` convention (D-5). The owner or reviewer may
  disagree; the evidence is in `evidence/TC-T02-29-env-diff.txt`.
- **TC-T02-30:** markdownlint-cli2 now runs through `.tools/pre-commit` and is clean on the T02 docs.
  The script's standalone `markdownlint` check still prints SKIP, because that binary is absent.
- **TC-T02-32 (Mermaid), method stated plainly:** no browser could be used (Chromium needs sudo;
  running a downloaded browser and public renderers were refused), so **rendering is not proven**.
  The fallback is mermaid 12.3.0 `parse()` with `docs/tests/T03/evidence/mermaid-parse.mjs`: 3 of 3
  blocks in `solution-architecture.md` parse (2 flowchart-v2, 1 sequence) and the negative control
  (unclosed `alt`) is rejected. This proves syntax validity only, not layout or visual rendering.
- **TC-T02-34:** the tester had no web tool; the main session ran the live comparison afterwards
  (see evidence file). 4 of 4 sampled claims supported.
- TC-T02-19 rename sub-check is vacuous because the outcome is "keep as internal codename only".
- Naming owner actions OA-1 to OA-5 remain open (ticketed to T33 as OQ-10). They are not test blockers.
- Not tested: GitHub rendering of the Mermaid blocks. External claims were sampled (4 claims), not
  exhaustively re-verified.

## Sign-off

**Signed off, with limitations.** 35 of 35 cases Pass, 0 Fail, 0 Blocked, no open defect.
Limitations: (1) TC-T02-32 passed at parse level only; the owner should still open
`docs/architecture/solution-architecture.md` on GitHub once and confirm the 3 diagrams render.
(2) TC-T02-29 step 2 passed on T02 history, not on a literal empty diff (see notes).
Tester, 2026-11-06.
