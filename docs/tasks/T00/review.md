# T00: Repository scaffold and documentation skeleton, Review

| Field | Value |
|---|---|
| Task | T00 |
| Reviewer | technical-architect (role played by the main session) |
| Date | 2026-11-01 |
| Commit range | `3eb3351..task/T00-scaffold` |
| Plan | `docs/tasks/T00/plan.md` |

## Findings

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `scripts/tool-versions.env` | The SHA-256 of the pre-commit zipapp is not pinned, so the first download is trust-on-first-use. | After the first bootstrap, compare the printed hash with the GitHub release and record it. | Closed 2026-11-06: `PRE_COMMIT_SHA256` pinned from the v4.7.0 release digest (T08); `bootstrap-dev.sh` lines 55-62 fail on a missing pin or a mismatch; `.tools/pre-commit-4.7.0.pyz` hashes to the pin (tester, and rechecked by the reviewer) |
| 2 | Minor | repo root | The GitHub repo and local folder are named `Meridian`. Section 0 says `meridian`. | The README clones into `meridian`. Renaming the GitHub repo is left to the owner and recorded for the T02 naming check. | Ticketed (T02) |
| 3 | Minor | `.pre-commit-config.yaml` | The gitleaks hook builds with Go. pre-commit downloads Go on first install, which is slow and needs network. | Accepted for now. T08 CI caches `~/.cache/pre-commit`. | Ticketed (T08) |
| 4 | Note | `scripts/check-names.sh` | Excludes `docs/TASKS.md`, whose T00 criterion quotes the old names. | Documented in the script header. | Closed |
| 5 | Note | `docs/TASKS.md` | Moved from the repo root into `docs/` by the owner. Section 4 has no `TASKS.md` entry. | Listed in `docs/README.md`. | Closed |

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | `plan.md` |
| C2 Review findings resolved | Yes (2026-11-06) | Finding 1 closed; findings 2 and 3 ticketed; F-1 of the DEF-015 fix review closed (`d05dba2`); F-2 and F-3 closed by the tester |
| C3 Criteria mapped to executed tests | Yes (2026-11-06) | All 8 cases pass at `d05dba2`; report signed off |
| C4 CI green | n/a | CI arrives in T08 |
| C5 Docs updated | Yes | README, CLAUDE.md, PROGRESS, TRACEABILITY |
| C6 No secrets; `.env.example` | Yes | `.env.example` has names and placeholders only |
| C7 Clean-checkout works | Yes (2026-11-06) | `scripts/bootstrap-dev.sh` installed `.tools/pre-commit` and the hooks; TC-T00-05 ran all 22 hooks on the tree; TC-T00-04 ran in a throwaway repo |

## Approval

**Approved with conditions:** close finding 1, and run TC-T00-04 and TC-T00-05 with stored evidence.
Then T00 can be closed.

Update 2026-11-06: finding 1 is closed. The remaining conditions are the DEF-009 fix review
below and the TC-T00-04 and TC-T00-05 retest with stored evidence.

## DEF-009 fix review (2026-11-06)

| Field | Value |
|---|---|
| Reviewer | technical-architect |
| Branch | `task/T00-retest` |
| Commits | `0d6eefe` (the fix, 2 lines) and `d05dba2` (F-1, 3 lines); only `scripts/demo-secret-scan.sh` |
| Defect | DEF-015 (renumbered from the duplicate DEF-009; see F-2) |

### What was checked

- **Change 1, line 35:** `"$pre_commit" install -q` became `"$pre_commit" install >/dev/null`.
  `.tools/pre-commit install --help` (4.7.0) lists no `-q` or `--quiet`, so the old line
  always failed with `unrecognized arguments: -q`. That matches the stored failing run.
  Sending stdout to `/dev/null` keeps the old intent, which was a quiet install. stderr is
  still shown, and a failed install still stops the script under `set -e`. The change is
  correct and minimal.
- **Change 2, line 45:** the `tr` call is now
  `{ LC_ALL=C tr -dc ... </dev/urandom || true; } | head -c 36`. The reviewer reproduced
  it: the old form exits 141 under `set -euo pipefail`. The new form exits 0 and gives a
  40-character `ghp_` value. Only `tr`'s status is ignored. `head`'s status is still the
  pipeline status, so a `head` failure still stops the script. The reviewer checked this
  with a bad `head` option, which exited 1. This is the usual fix for an infinite producer
  under `pipefail`, and it is minimal.
- **Can `|| true` hide a real failure?** Yes, in one case. If `tr` cannot read its input
  (reproduced with `</nonexistent`), it prints an error to stderr and the pipeline exits 0.
  `$fake` is then just `ghp_`. The failure is not silent: gitleaks does not flag a bare
  `ghp_`, so the commit is accepted and the script prints `RESULT: FAIL` and returns 1. But
  it is reported as "the scan accepted a key". That is a misleading diagnosis for a
  test-harness failure. This needs `/dev/urandom` to be unreadable, which is very unlikely
  on Linux, so it is Minor (F-1).
- **Shell standards** (CODING_STANDARDS "Shell scripts"): shebang and `set -euo pipefail`
  are present. Expansions are quoted. shellcheck 0.11.0 (`.tools/shellcheck`) and 0.8.0
  report nothing. One rule is not met: "Do not hide a failure with `|| true` unless a comment
  explains why the failure is expected." The comment on line 44 explains why the token is
  generated, not why `tr`'s failure is expected (F-1).
- **Simulation-only and secrets:** no broker code or domains. No key-like string is
  committed; the token is still generated at run time.
- **Scope:** no other files or lines changed. The RETURN trap (the standard asks for
  `trap ... EXIT`) and the missing `-h` usage line are older than this fix and out of scope.

### Findings

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| F-1 | Minor | `scripts/demo-secret-scan.sh:44-45` | `\|\| true` has no comment saying why the failure is expected (CODING_STANDARDS, Shell scripts). If `tr` cannot read its input, `$fake` is `ghp_` and the run ends as `RESULT: FAIL` with the wrong diagnosis. | Add a comment above line 45: `tr` reads an endless stream and gets SIGPIPE (exit 141) when `head` closes the pipe, which is expected under `pipefail`. After line 45, add a guard: `[[ ${#fake} -eq 40 ]] \|\| { echo "ERROR: could not generate the fake token" >&2; return 2; }`. | Closed (`d05dba2`): the comment and guard match the resolution; shellcheck 0.11.0 is clean; the guard returns 2 with the error line when `tr`'s input is unreadable (reviewer reproduction) |
| F-2 | Minor | `docs/tests/defects.md:528` | The new T00 defect uses the ID DEF-009, which the T07 Pantheon User-Agent defect already has (line 66). The highest ID in use is DEF-014. | The tester renumbers the T00 entry to the next free ID (DEF-015) and updates the T00 test report and evidence references. The `0d6eefe` subject keeps "DEF-009" because history is not rewritten; the new defect entry says that this commit fixes it. The reviewer did not edit `defects.md`. | Closed 2026-11-06: tester renumbered the T00 entry to DEF-015 and updated the report |
| F-3 | Note | `docs/tests/T00/evidence/TC-T00-04-secret-scan.txt` | The working-tree evidence is the failing pre-fix run (repo commit `5b966fa`, `unrecognized arguments: -q`). | Keep it as the "found" evidence under a name that says so, or replace it with the post-fix retest run. Either way the retest must store a post-fix run with `RESULT: PASS`. | Closed 2026-11-06: post-fix run stored as `TC-T00-04-secret-scan.txt`; failing run kept as `TC-T00-04-secret-scan-prefix-run1-failed.txt` |

### SIGPIPE: fold into the defect or log separately

Fold it into the same defect entry. Do not log it as its own defect. Reasons:

- It could never be seen on its own. The `-q` failure on line 35 always stopped the script
  before it reached line 45.
- It is in the same script and has the same symptom: TC-T00-04 cannot produce
  `RESULT: PASS`. The same fix commit and the same retest close it.
- The defect entry should record it so the history is complete. Add a "Second cause found
  during the fix" paragraph naming line 45 and the 141 exit status, with the reviewer's
  reproduction. The tester or main session writes this. The reviewer did not.

### Verdict

**Approved** (updated 2026-11-06, after `d05dba2`). Both changes in `0d6eefe` are correct,
minimal and needed. F-1 is closed by `d05dba2`. No Blocker, Major or code finding is open.

F-2 and F-3 closed by the tester and do not block this approval. They must be resolved
in the retest report before TC-T00-04 and TC-T00-05 are signed off and T00 is closed.

The defect is now DEF-015: the `d05dba2` subject uses that ID. At this review the entry in
`docs/tests/defects.md` (line 528) is still headed DEF-009, so F-2 stays open until the
tester renumbers it.

Reviewer: technical-architect, 2026-11-06.
