# T02: Solution architecture, Review

| Field | Value |
|---|---|
| Task | T02 |
| Reviewer | technical-architect |
| Date | 2026-11-01 |
| Commit range | `task/T01-agents..working tree` (base `085b3e9`; T02 files are uncommitted) |
| Plan | `docs/tasks/T02/plan.md` |

Files reviewed:

- `docs/architecture/solution-architecture.md`
- `docs/architecture/naming.md`
- `docs/architecture/README.md`
- `docs/adr/ADR-0001-headless-drupal-nextjs.md` to `docs/adr/ADR-0006-no-live-trading.md`
- `docs/adr/README.md`
- `docs/TRACEABILITY.md`

The tester's `docs/tests/T02/test-cases.md` and `run-checks.sh` were used as cross-checks.

Overall the document set is strong:

- All AC sections are present.
- The FR and NFR tables are complete: 29 FR and 19 NFR rows, each with a parent, MoSCoW
  priority, numeric target and verifying task.
- Every target referenced by T08, T10, T11, T26, T30 and T31 exists (NFR-01 to NFR-08).
- The risk register covers the seven named risks, plus LLM cost (RK-08) and Vercel Hobby
  (RK-09). Every row has likelihood, impact, owner, mitigation and task.
- The cost map is complete, with sources and dates.
- Every external claim has a URL and date or is marked **unverified**.
- `naming.md` has the five checks and exactly one Outcome line ("keep as internal codename
  only").
- Every open question is resolved or ticketed to a task that exists.
- No broker names or domains appear, `check-names.sh` passes, and nothing contradicts the
  simulation-only rule.

In the first review, one Major gap (Finding 1) blocked acceptance. It and all the Minor
findings are now resolved (see "Re-review 2026-11-01").

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `docs/adr/ADR-0003-postgres-system-of-record.md:31-33, 51`; `docs/adr/ADR-0005-authentication.md:32-34`; `docs/architecture/solution-architecture.md:108-138, 152-186, 206-208, 225` | **The watchlist flow is undefined and contradicts itself.** FR-01, ADR-0003 and the admin path say the engine reads Watchlist Items from Drupal at run start. But: (a) neither the container diagram nor the daily-run sequence shows an engine-to-Drupal read; (b) ADR-0005 gives the engine client only an ingest write scope, so it cannot read Watchlist Items; (c) ADR-0003's Consequences say "Engine runs never depend on Drupal being up", yet a Drupal-sourced watchlist at run start makes every run depend on a sleeping or down Drupal (RK-04); (d) FR-01 names two sources ("engine YAML config plus Watchlist Items managed in Drupal") with no precedence or fallback | Decide one consistent watchlist flow and apply it everywhere before the ADRs are accepted. The solution-architect chooses. One acceptable option: (1) FR-01 states the precedence (for example, Drupal Watchlist Items are authoritative and YAML only seeds or overrides locally). (2) ADR-0005's engine bullet adds a read-only watchlist scope (or names how the engine reads it) while still barring user reads, deletes and admin. (3) ADR-0003 says that if Drupal is unreachable after the wake and retry, the run uses the last watchlist snapshot in Postgres and logs it, and rewords the "never depend" consequence to match. (4) The container diagram gets an `engine -> jsonapi` (or ingest) arrow labelled "watchlist read". (5) The sequence diagram gets a step after the holiday check with an `alt` for Drupal unavailable, using the snapshot fallback. If instead the watchlist becomes YAML-only, say so in FR-01, ADR-0003 and the admin path, and ticket the removal of the Watchlist Item content type from T03 | Fixed (re-review 2026-11-01) |
| 2 | Minor | `docs/architecture/solution-architecture.md:200-202`; `docs/adr/ADR-0001-headless-drupal-nextjs.md:40` | "Responses are cached with Drupal cache tags. A new ingest invalidates them". Drupal cache tags invalidate Drupal's own caches. They do not invalidate the Next.js data cache on Vercel unless Drupal calls a revalidation endpoint on `meridian-web` (on-demand revalidation) or a time-based revalidate is used. Neither is stated, and the container diagram has no Drupal-to-web arrow | Name the mechanism, or the two candidates with "T03 decides" (on-demand revalidation webhook from Drupal, or time-based revalidation). If it is a webhook, add the arrow and note its shared secret. Fix the ADR-0001 wording **in this pass**, because the ADR is immutable once accepted | Fixed (re-review 2026-11-01) |
| 3 | Minor | `docs/architecture/solution-architecture.md:240` | FR-16 targets "3 roles" (`administrator`, `analyst`, engine-ingest client). ADR-0005 and FR-20 also require a separate read-only Next.js client, which needs its own role or scope set. So the hard count of 3 is wrong | List four roles (administrator, analyst, engine-ingest, dashboard-read), or word it as "at least these roles, final list in T03". Keep the target measurable (100% of permission-matrix cells pass) | Fixed (re-review 2026-11-01) |
| 4 | Minor | `docs/architecture/solution-architecture.md:260, 264` | NFR-02 requires results visible "by 20:00 IST on 100%" of trading days. NFR-06 allows up to 10% of trading days to end in neither success nor partial (failed runs). The two targets cannot both hold as written | Scope NFR-02 to trading days whose run ends in success or partial. Alternatively, state that a failed run recovered by manual dispatch before 20:00 counts | Fixed (re-review 2026-11-01) |
| 5 | Minor | `docs/architecture/solution-architecture.md:273` | NFR-15 says "the outbox drains to 0 within 30 min or by the next run". The architecture has no trigger for a drain between daily runs: the engine only runs from `daily-run.yml` or manual dispatch. So "30 min" is not measurable as an automatic behaviour, and T19's outage test needs to know what drains it | State the drain trigger: the next scheduled run, or a manual `publish` command or workflow dispatch, or a scheduled drain workflow. Restate the target, for example "0 records lost; outbox at 0 after the next run or within 30 min of a manual `publish`" | Fixed (re-review 2026-11-01) |
| 6 | Minor | `docs/architecture/solution-architecture.md:218-219, 263, 381` | NFR-04 (500 records in one request in at most 10 s on DDEV) is tight for 500 Drupal entity upserts with revisions, cache-tag invalidation and an audit-log write each, especially on DDEV under WSL2. It has no Pantheon dev value, although T30 runs its performance tests on the deployed environment, and Pantheon request time limits are not recorded. Line 219 says loosening needs an ADR, which would force an ADR if the T03 measurement misses | Do one of these: (a) let T03 set the final NFR-04 value in either direction from a recorded DDEV measurement taken before T10 starts (amend line 219 and OQ-07 for NFR-04 and NFR-05 only); or (b) raise the DDEV target to a safer value, for example 30 s. In both cases, state whether NFR-04 applies to Pantheon dev and, if it does, add the value or "deferred to T03" with a reason | Fixed (re-review 2026-11-01); final value ticketed T03 (OQ-07) |
| 7 | Minor | `docs/architecture/solution-architecture.md:385, 301` | OQ-11 is "Resolved: disclaimer on every dashboard page and as a header line in exports. Implemented in T23 and T24." The positions and reports pages are T25, and the shared layout is T21/T22. CSV exports are Drupal Views (FR-15, T12), not T23/T24. The new requirement also has no FR row, so it cannot be traced or tested, although RK-06 relies on it | Add `FR-30` (parent R-08, or R-05 with R-07). Target: the disclaimer text is present on 100% of dashboard pages and as a header line in 100% of CSV exports. Verifying tasks: T12 and T23 to T25 (or the T21/T22 layout). Update OQ-11 and the TRACEABILITY row | Fixed (re-review 2026-11-01) |
| 8 | Minor | `docs/TRACEABILITY.md:14-25` | Some verifying tasks named in the FR and NFR tables are missing from the Tasks column of their parent row: FR-01 T12; FR-07 T30; FR-12 T17; FR-13 T20; NFR-01, NFR-03, NFR-04 and NFR-05 T30; NFR-08 T29; NFR-15 T27; NFR-16 T29; NFR-18 T16. T04 and the close steps use this column to plan coverage | Add those tasks to each row's Tasks column, or state under the table that verifying tasks are listed only in `solution-architecture.md` and that T04 reconciles them. Fix now (a trivial edit) or ticket to T04 | Fixed (re-review 2026-11-01) |
| 9 | Note | `docs/adr/ADR-0005-authentication.md:23-25`; `docs/architecture/solution-architecture.md:320` | The reviewer could not independently re-verify the Vercel password-protection price or the Claude model prices and tokenizer note. Both are cited with a URL and date, which meets the rule | Re-check at T22 (OQ-08) and T17 (OQ-02). No action in T02 | n/a |
| 10 | Note | `docs/architecture/solution-architecture.md:85-186` | No Mermaid CLI is available, so the three diagrams were not rendered. A manual syntax read found only basic `flowchart` and `sequenceDiagram` constructs and quoted labels | The tester confirms GitHub rendering under C7 (TC-T02-32) | n/a |
| 11 | Note | `docs/architecture/solution-architecture.md:246, 300` | 10:30 UTC is a half-hour boundary. GitHub schedule load concentrates at the top of the hour, but an odd minute (for example 10:37 UTC) is safer still | T20 decides together with OQ-06 | n/a |
| 12 | Note | `docs/TASKS.md` section 1 | Section 1 names the local Next.js container `web-next`. Section 0 and the T02 docs use `meridian-web`, so the T02 docs are correct | Ticket a wording fix of TASKS.md section 1 to T03 or T32. Not a T02 defect | n/a |
| 13 | Note | `docs/tests/T02/run-checks.sh:117` | **Test-script defect** (reported, not fixed). In TC-T02-09, `t($o) !~ /.../i` is not valid case-insensitive awk. gawk parses it as concatenating the match result with variable `i`, which gives the non-empty string "0" or "1". That string is always true, so every risk row is flagged "owner" and the check FAILs falsely. The real owners (solution-architect, technical-architect, developer, project owner) are valid roles | Tester: use `tolower(t($o)) !~ /architect\|developer\|.../` | Fixed by tester (verified on re-run) |
| 14 | Note | `docs/tests/T02/run-checks.sh:175-187` | **Test-script defect.** In TC-T02-17, `nrow 'app store'` also matches the `naming.md` metadata row at line 8 ("Scope \| ... app stores ..."), which has no URL or date, so the check FAILs falsely. The real Apple App Store row (line 29) has a URL and the date | Tester: restrict `nrow` to rows of the Checks table, for example `^\| *[0-9]+ \|` | Fixed by tester (verified on re-run) |
| 15 | Note | `docs/tests/T02/run-checks.sh:206, 279` | **Test-script defect.** TC-T02-29 (and the rename branch of TC-T02-19) compare against `main`, which has no `.env.example` (`fatal: path '.env.example' exists on disk, but not in 'main'`), so the check FAILs falsely. The correct base is `task/T01-agents` or the merge-base. Manual check: `git diff --quiet task/T01-agents -- .env.example` returns 0 (unchanged) | Tester: use `task/T01-agents` or `$(git merge-base main HEAD)` with a fallback | Fixed by tester (verified on re-run) |
| 16 | Note | `docs/tests/T02/run-checks.sh:280-301` | `.tools/pre-commit` is not installed in this environment, so the gitleaks evidence is BLOCKED. `markdownlint` is not installed, so its check is SKIPPED | Tester: run `scripts/bootstrap-dev.sh` and record pre-commit and gitleaks output. Record the markdownlint skip in the test report | n/a |
| 17 | Note | `docs/architecture/solution-architecture.md:136, 191, 221-225`; `docs/adr/ADR-0005-authentication.md` (engine-to-Next.js bullet) | New in the revision: the revalidation route on `meridian-web` is authenticated by a shared secret, not by a user session. It is a deliberate exception to "every route requires login" (FR-19). ADR-0005 limits it to clearing cache and returning no data, and keeps the secret in platform stores only | T03: add the secret to the env matrix and `.env.example` (placeholder). T21/T22: the route returns 401 without a valid secret and is listed in the route-protection tests. T30: include it in the authorisation matrix | n/a |
| 18 | Note | `docs/architecture/solution-architecture.md:333` | RK-07 lists example secrets (API key, OAuth client secret, Terminus token, database URL) but not the new revalidation secret. The mitigation still covers it generally | Add it to the list when RK-07 is next edited (T03 or T29 rotation runbook). No action in T02 | n/a |
| 19 | Note | `docs/architecture/solution-architecture.md:170-176`; ADR-0003 | When the watchlist falls back to the snapshot or seed, the source is recorded but no alert is raised. A long Drupal outage could go unnoticed while edits are ignored | T20/T29: consider a warning in the run summary or alert when the source is not `drupal`. No action in T02 | n/a |

## Re-review 2026-11-01

The solution-architect revised `solution-architecture.md`, ADR-0001, ADR-0003, ADR-0005 and
`TRACEABILITY.md`. The tester fixed script defects 13 to 15. Each resolution was checked in
the files, not taken from the summary:

| # | Verified resolution |
|---|---|
| 1 | FR-01 (line 255) makes Drupal authoritative, with a fallback order of Drupal, then last Postgres snapshot, then YAML seed, and records the source on 100% of runs. The container diagram has the arrow `engine -> jsonapi` "watchlist read scope" (line 135). The sequence diagram reads the watchlist after the holiday check, with an `alt` for Drupal unreachable, and snapshots it with its source (lines 170-176). Data-flow note 4 and the admin path match. ADR-0003 sets out the same order, and its consequence is reworded to "never fail because Drupal is down", with stale-edit behaviour stated. ADR-0005 gives the engine client a separate read-only watchlist scope and still bars users, other content, deletes and admin. FR-20 says "ingest write plus watchlist read only". All five sources are consistent |
| 2 | ADR-0001 and read path step 3 name time-based revalidation (about 300 s, T03 fixes the value) plus an on-demand revalidation call from the engine after a successful publish, using a shared secret. They state that Drupal cache tags do not invalidate the Next.js cache. The container diagram (line 136) and the sequence diagram (line 191) show the call. ADR-0005 covers the secret and the route's limits. Follow-ups name T03, T19 and T21. See Notes 17 and 18 |
| 3 | FR-16 lists at least 4 roles, including `dashboard-read`, with T03 finalising the list |
| 4 | NFR-02's 100% target is scoped to success or partial runs, including recovery by manual dispatch, so it no longer conflicts with NFR-06 |
| 5 | NFR-15 names the drain triggers (next scheduled run, or a manual `publish` dispatch) and gives a measurable target. Data-flow note 5 matches |
| 6 | NFR-04 is set to a provisional 30 s on DDEV. T03 finalises it in either direction from a measurement taken before T10. The Pantheon value is deferred to T03 with a reason. The requirements intro (lines 247-249) and OQ-07 allow the two-way change for NFR-04 and NFR-05 only |
| 7 | FR-30 (R-08) is added, with targets for pages and exports and verifying tasks T12 and T22 to T25. OQ-11 and RK-06 point to it. TRACEABILITY R-08 lists FR-30 |
| 8 | A re-run of the verifying-task versus Tasks-column comparison reports no missing tasks |
| 13-15 | Script re-run: TC-T02-09, TC-T02-17 and TC-T02-29 (`.env.example`) now pass |

No new Blocker or Major was introduced. Notes 17 to 19 are follow-ups for later tasks.

Automated run after re-review and sign-off (`docs/tests/T02/run-checks.sh`, 2026-11-01): see
the closing summary in the hand-off. Before sign-off, the only failures were the two sign-off
checks (now addressed), "BLOCKED .tools/pre-commit not installed" and the markdownlint SKIP
(Finding 16, environment).

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | `plan.md` was approved on 2026-11-01 before authoring |
| C2 Review findings resolved | Yes | Findings 1 to 8 are fixed and verified. Findings 13 to 15 are fixed by the tester. The other Notes need no T02 action |
| C3 Criteria mapped to executed tests | Pending (tester step) | `test-cases.md` maps all eight ACs and C1 to C7. Execution and evidence follow in `/test-task T02` |
| C4 CI green | n/a (pre-T08) | `scripts/check-names.sh` passes, including the negative control. markdownlint is unavailable and recorded as SKIP (Finding 16) |
| C5 Docs updated | Yes | TRACEABILITY (refined IDs and verifying tasks), the ADR index (Accepted) and the architecture README are updated |
| C6 No secrets | Yes, gitleaks evidence pending (tester step) | No key-like strings. `.env.example` is unchanged against `task/T01-agents`, with no new variables in T02. The revalidation secret is added in T03 (Note 17) |
| C7 Clean-checkout works | Yes, rendering confirmation pending (tester step) | Relative links resolve. No images or external asset hosts. GitHub Mermaid rendering is confirmed in TC-T02-32 (Finding 10) |

## Approval

**Approved.** technical-architect, 2026-11-01 (re-review).

No Blocker or Major finding is open. Sign-off is recorded in
`docs/architecture/solution-architecture.md`. ADR-0001 to ADR-0006 and the
`docs/adr/README.md` index are set to **Accepted**.

The tester still needs to run the C3, C6 and C7 evidence steps. The branding owner actions
OA-1 to OA-5 remain ticketed to T33 (OQ-10). Neither is a review condition.

The first review (same date) requested changes because of Finding 1.
