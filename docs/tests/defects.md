# Defect log

Use `docs/templates/defect.md` for each entry. Severity scale (refined in T04):

| Severity | Meaning |
|---|---|
| Critical | Data loss, security breach, wrong financial result, or any live-order capability |
| High | Core function broken with no workaround |
| Medium | Function impaired, workaround exists |
| Low | Cosmetic or documentation issue |

## Open

(none)

## Closed

### DEF-001: Path guard misparses quoted shell operators

| Field | Value |
|---|---|
| ID | DEF-001 |
| Severity | Medium |
| Found in | T01 (found in use during T02 planning by technical-architect) |
| Status | Retest passed |
| Fix commit | see `git log --grep DEF-001` |
| Retest result | 30/30 guard unit tests pass, incl. new `QuotedShellParsing` class |

**Steps to reproduce**

1. As `technical-architect`, run `grep -rnE "a|b" docs`

**Expected:** allowed (read-only command with a quoted pattern).

**Actual:** blocked with "could not parse shell command safely (No closing quotation)"; the
guard split on `|` before honouring quotes. Quoted `>` (for example `awk '$1 > 5'`) was also
treated as a redirect (T01 review finding 2).

**Fix:** `guard_paths.py` now tokenises with `shlex` (`punctuation_chars`) so quoted text stays
inside one word; operators and redirect targets come from the token stream.

### DEF-002: `uq_runs_date_attempt` collides for a second `publish` or `replay` row on the same date

| Field | Value |
|---|---|
| ID | DEF-002 |
| Severity | Medium |
| Found in | T03, TC-T03-24 (manual Postgres schema review) |
| Status | Retest passed |
| Fix commit | T03 commit (pending, main session) |
| Retest result | 2026-11-01: TC-T03-24 re-run Pass. `evidence/DEF-002-retest.txt` (12/12): repeated publish and replay rows with attempt 0 on one date now insert; duplicate attempt greater than 0 for a date and a second running row are still rejected; `ck_runs_attempt` still enforced. `run-checks.sh` and `check_data_model.py` all PASS. |

**Steps to reproduce**

1. Read `docs/specs/data-model.md`, table `runs`: `attempt` is "always 0" for `publish` and `replay` (`ck_runs_attempt`), and `uq_runs_date_attempt` is a plain unique constraint on (`trade_date`, `attempt`). Design D2 repeats this ("`publish` and `replay` rows use `attempt = 0`").
2. Model the constraint: `python3 -I` sqlite demo in `docs/tests/T03/evidence/DEF-002-demo.txt` (insert two rows with the same `trade_date`, `attempt = 0`).

**Expected:** any number of `publish` and `replay` runs can be recorded for one trade date (NFR-15 expects a manual `publish` dispatch after an outage, and a delayed cron or repeated dispatch can repeat it), and none of them can fail on a unique violation.

**Actual:** the second `publish` or `replay` row for the same `trade_date` violates `uq_runs_date_attempt`, so the run cannot even record itself (T14 Alembic baseline and T19/T20 would hit it).

**Suggested fix (for the author, not applied by the tester):** make the unique rule partial, `UNIQUE (trade_date, attempt) WHERE attempt > 0` (or give `publish`/`replay` a distinct key), and update `data-model.md` runs and design D2 accordingly.
