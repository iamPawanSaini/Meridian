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
| 1 | Major | `scripts/tool-versions.env` | The SHA-256 of the pre-commit zipapp is not pinned, so the first download is trust-on-first-use. | After the first bootstrap, compare the printed hash with the GitHub release and record it. | Open (owner action) |
| 2 | Minor | repo root | The GitHub repo and local folder are named `Meridian`. Section 0 says `meridian`. | The README clones into `meridian`. Renaming the GitHub repo is left to the owner and recorded for the T02 naming check. | Ticketed (T02) |
| 3 | Minor | `.pre-commit-config.yaml` | The gitleaks hook builds with Go. pre-commit downloads Go on first install, which is slow and needs network. | Accepted for now. T08 CI caches `~/.cache/pre-commit`. | Ticketed (T08) |
| 4 | Note | `scripts/check-names.sh` | Excludes `docs/TASKS.md`, whose T00 criterion quotes the old names. | Documented in the script header. | Closed |
| 5 | Note | `docs/TASKS.md` | Moved from the repo root into `docs/` by the owner. Section 4 has no `TASKS.md` entry. | Listed in `docs/README.md`. | Closed |

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | `plan.md` |
| C2 Review findings resolved | Partly | Finding 1 needs the owner |
| C3 Criteria mapped to executed tests | Partly | TC-T00-04 and TC-T00-05 blocked |
| C4 CI green | n/a | CI arrives in T08 |
| C5 Docs updated | Yes | README, CLAUDE.md, PROGRESS, TRACEABILITY |
| C6 No secrets; `.env.example` | Yes | `.env.example` has names and placeholders only |
| C7 Clean-checkout works | Pending | Verified by the owner's bootstrap run |

## Approval

**Approved with conditions:** close finding 1, and run TC-T00-04 and TC-T00-05 with stored evidence. Then T00 can be closed.
