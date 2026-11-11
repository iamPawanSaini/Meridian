# T03: Technical design, Test report

| Field | Value |
|---|---|
| Task | T03 |
| Build or commit | `task/T03-retest` at HEAD `c442012` (T00 close on top of main; review Approved, re-review for DEF-002). Cases 01 to 31 were executed 2026-11-01 and re-checked on the T03 commits; TC-T03-10 and TC-T03-32 executed 2026-11-06 |
| Environment | Linux 6.18 (WSL2), bash, Python 3 with PyYAML, git 2.34.1, network available, node 22.14 via nvm, Spectral CLI 6.17.0 via npx, mermaid 12.3.0 (npx cache of mermaid-cli); pre-commit and markdownlint not run for T03 (SKIP in TC-22); Chromium unavailable (see TC-T03-32) |
| Date | 2026-11-06 (TC-T03-10 and TC-T03-32); 2026-11-01 (others) |
| Executed by | tester |

## Summary

| Case | Criterion | Status | Evidence |
|---|---|---|---|
| TC-T03-01 | AC1, AC2, AC4, AC5, AC6, AC7 | Pass | `evidence/TC-T03-01.txt` |
| TC-T03-02 | AC1 | Pass | `evidence/TC-T03-02.txt` |
| TC-T03-03 | AC2 | Pass | `evidence/TC-T03-03.txt` |
| TC-T03-04 | AC2 | Pass | `evidence/TC-T03-04.txt` |
| TC-T03-05 | AC4 | Pass | `evidence/TC-T03-05.txt` |
| TC-T03-06 | AC4 | Pass | `evidence/TC-T03-06.txt` |
| TC-T03-07 | AC3, C4 | Pass | `evidence/TC-T03-07.txt` |
| TC-T03-08 | AC3 | Pass | `evidence/TC-T03-08.txt` |
| TC-T03-09 | AC3 | Pass | `evidence/TC-T03-09.txt` |
| TC-T03-10 | AC3, C4 | Pass (2026-11-06) | `evidence/TC-T03-10.txt` |
| TC-T03-11 | AC5 | Pass | `evidence/TC-T03-11.txt` |
| TC-T03-12 | AC5 | Pass | `evidence/TC-T03-12.txt` |
| TC-T03-13 | AC5, PX, C5 | Pass | `evidence/TC-T03-13.txt` |
| TC-T03-14 | AC6, C6 | Pass | `evidence/TC-T03-14.txt` |
| TC-T03-15 | AC6, C6 | Pass | `evidence/TC-T03-15.txt` |
| TC-T03-16 | AC7 | Pass | `evidence/TC-T03-16.txt` |
| TC-T03-17 | PX, C5 | Pass | `evidence/TC-T03-17.txt` |
| TC-T03-18 | AC8, C5 | Pass | `evidence/TC-T03-18.txt` |
| TC-T03-19 | AC9, C2 | Pass | `evidence/TC-T03-19.txt` |
| TC-T03-20 | C4 | Pass | `evidence/TC-T03-20.txt` |
| TC-T03-21 | SIM | Pass | `evidence/TC-T03-21.txt` |
| TC-T03-22 | C4, C6, C7 | Pass | `evidence/TC-T03-22.txt` |
| TC-T03-23 | AC1 | Pass | `evidence/manual-review.md` |
| TC-T03-24 | AC2 | Pass (retest) | `evidence/manual-review.md`, `evidence/DEF-002-demo.txt`, `evidence/DEF-002-retest.txt` |
| TC-T03-25 | AC4 | Pass | `evidence/manual-review.md` |
| TC-T03-26 | AC5 | Pass | `evidence/manual-review.md` |
| TC-T03-27 | AC7 | Pass | `evidence/TC-T03-27.txt`, `evidence/manual-review.md` |
| TC-T03-28 | AC6, PX | Pass | `evidence/manual-review.md` |
| TC-T03-29 | AC1, AC2, AC3 | Pass | `evidence/cross-doc-fields.txt`, `evidence/manual-review.md` |
| TC-T03-30 | C3, C7 | Pass | `evidence/TC-T03-30.txt` |
| TC-T03-31 | C1, C2, C5, AC9 | Pass (re-check, commit 96b4c17) | `evidence/manual-review.md` |
| TC-T03-32 | C7 | Pass (parse-level only, 2026-11-06) | `evidence/TC-T03-32.txt`, `evidence/mermaid-parse.mjs` |

Totals: 32 pass, 0 fail, 0 blocked, 0 not run (32 cases). TC-T03-24 failed on the first run
(DEF-002) and passed on retest after Revision 3. TC-T03-10 and TC-T03-32 were Blocked on
2026-11-01 and were executed on 2026-11-06.

TC-T03-10 (Spectral): `npx @stoplight/spectral-cli lint docs/architecture/openapi.yaml --ruleset
.spectral.yaml --fail-severity=warn`, version 6.17.0, no results at warn or higher, exit 0. Note the
pre-commit hook pins 6.15.0 (`# verify`); the run used 6.17.0 because the case uses unpinned `npx`.

TC-T03-32 (Mermaid), method stated plainly:

- Rendering was attempted with `mmdc` (4 blocks: 1 in `technical-design.md`, 3 in
  `solution-architecture.md`). All 4 exited 1: chrome-headless-shell is not installed, and
  `puppeteer browsers install` failed ("no zip archiver is available", needs `unzip`, i.e. sudo). A
  manual download of the browser zip and launching it was denied by the permission classifier, so I
  stopped there. No SVG exists. **Rendering is not proven.**
- Fallback used: mermaid 12.3.0 `parse()` under node (`evidence/mermaid-parse.mjs`; DOMPurify hooks
  stubbed because jsdom is not available and package installs are blocked for the tester). 4 of 4
  blocks parse (2 flowchart-v2, 2 sequence). A negative control (unclosed `alt`) is rejected. This
  **proves syntax validity only**, not layout or visual rendering. The sequence diagram contains the
  publisher, outbox, Drupal ingest, `/oauth/token` and the failure branches.
- The case's expected result ("renders without a syntax error") is met at parse level. Status is
  recorded as "Pass (parse-level only)" so the limit stays visible; the owner may still want one
  GitHub preview of the two files.

## Defects raised

| Defect | Severity | Status |
|---|---|---|
| DEF-002 `uq_runs_date_attempt` collides for a second `publish` or `replay` row on the same date (`docs/tests/defects.md`) | Medium | Retest passed, closed |

Script defects fixed during design (not product defects): TC-T03-09 and TC-T03-17 quoting errors,
recorded in the Change log of `test-cases.md`.

## Coverage notes

- All nine acceptance criteria and C1 to C7 have at least one executed case; see the coverage table
  in `test-cases.md`.
- Automated evidence: 355 PASS lines in `evidence/run-checks.txt`, split per case. Helper outputs:
  `validate_openapi.txt`, `selftest_validator.txt`, `check_data_model.txt`, `check_env_parity.txt`.
- Not covered: visual rendering of the Mermaid diagrams (parse only), commit-history checks beyond
  TC-T03-31, and all runtime behaviour (Drupal, Alembic and Pantheon facts marked unverified are
  confirmed by T07, T09, T10, T14 and T22, not by this task).
- Observation, not a defect: Postgres `prices.source` has no named CHECK although Drupal restricts
  it to `yfinance` or `stub` (suggest `ck_prices_source` in T14).

## Sign-off

**Signed off, with one recorded limitation.** 32 of 32 cases pass; none is Fail or Blocked; DEF-002 is
retested and closed; no new defect (next free ID stays DEF-016). Limitation: TC-T03-32 passed at
parse level only because Chromium could not be installed without sudo (mmdc exit 1 for all 4 blocks);
the diagrams are syntactically valid but were not visually rendered. tester, 2026-11-06.
