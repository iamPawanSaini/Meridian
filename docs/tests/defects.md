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
