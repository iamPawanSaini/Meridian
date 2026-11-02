# T06: Extra Docker services in DDEV, Review

| Field | Value |
|---|---|
| Task | T06 |
| Reviewer | technical-architect |
| Date | 2026-11-02 |
| Commit range | `52800ab..ad11e74` (933e3b7, d7fd1ff, d44c128, bea13fb, 086ab51, ad11e74) |
| Plan | `docs/tasks/T06/plan.md` (addendum 2026-11-02 added by this review) |
| Decision | `docs/tasks/T06/decision-nextjs-placeholder.md`, option (a) |

## What was checked

- **Diff.** Read in full: 3 compose files, 4 host commands, 3 helper files and 9 doc files.
- **Live checks (read-only, DDEV v1.24.4).**
  - `ddev meridian-status`: exit 0, five lines `running healthy`.
  - `curl` without `-k` to `https://meridian.ddev.site:3001/`: prints `200 0` with the
    placeholder sentence.
  - `ddev engine bash -c 'printf "<%s>\n" "$@"' _ 'a b' '' 'c"d'`: prints exactly three lines.
  - `echo hi | ddev engine cat`: prints `hi`.
  - Through `ddev`, exit status 7 becomes 1, and `ddev pg bogus` gives 1. Run directly,
    `pg bogus` gives 2. DDEV's `Failed to run ...` line goes to **stderr**.
  - `ddev next` fetch of `$DRUPAL_BASE_URL/user/login`: 200. Without `NODE_EXTRA_CA_CERTS`:
    `UNABLE_TO_VERIFY_LEAF_SIGNATURE`.
  - Volume `meridian-postgres-data` has both DDEV labels.
  - `meridian-web` runs as `1000:1000` with no restart policy, on `ddev-meridian_default`, and
    links `ddev-router:meridian.ddev.site`.
  - The node image's local RepoDigest matches the pinned digest.
  - `git check-ignore -v db-dumps/x.dump` names `.gitignore:22`, and `db-dumps/` is mode 700.
  - `git status --ignored .ddev` shows no new untracked path.
- **Tools.** `.tools/pre-commit run --files <19 changed files>` passes: gitleaks, shellcheck,
  yamllint, check-yaml, markdownlint, naming, suppressions, assets. `scripts/check-names.sh`
  passes.
- **`.env.example`.** No variable line was added, removed or revalued. Only comments changed.

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `.ddev/commands/host/pg:76`, `:80`, `:82`; `docs/runbooks/local-setup.md:154` | Restore validation uses `pg_restore --list`, which reads only the header and table of contents. `ddev pg dump` streams `pg_dump -Fc` through a pipe, so the archive has no data offsets. A dump truncated or corrupted in its data section therefore passes validation. Line 80 then drops `meridian`, and line 82 fails part-way. The database is left empty or partial, and the only message is DDEV's generic failure line. The runbook promise "checks the file ... before touching the database" overstates the check. This is a gap in my KD-8 design, which the developer followed. See CODING_STANDARDS "Error handling" (a boundary error needs a clear message) and plan KD-8 step 1 ("without touching the database"). | (a) Validate by reading the whole archive before the drop: `pgx pg_restore -f /dev/null <"$file"`. This decodes every data block and fails on truncation or corruption. Keep exit 1 and "database unchanged". (b) If `createdb` or the final `pg_restore` fails after the drop, print to stderr: `meridian is now empty or partial; restore again from a good dump`, then exit 1. (c) Runbook line 154: say the whole archive is read before the drop, and say what a failure after the drop leaves behind. (d) Tester: extend TC-T06-34 with a dump of a seeded table of at least 1 MB, cut at about half its size. Restore must give a non-zero exit with the checksum unchanged. Plan addendum 2026-11-02 records the KD-8 change. | Open |
| 2 | Minor | `docs/runbooks/local-setup.md:107-108`; `.ddev/README.md:68`, `:94`; `.ddev/commands/host/meridian-status:15-16` | "The last line names the bad services" holds for **stdout** only. Through `ddev`, DDEV writes `Failed to run meridian-status; error=exit status 1` to stderr, so a terminal (or a `2>&1` capture) shows that line last. `.ddev/README.md:94` also says DDEV prints `Failed to run ...` "as the last line" without naming the stream. | Say "the last line of standard output names ...". In the `:94` fact row, add "on stderr, with `error=exit status N`". No code change. | Open |
| 3 | Minor | `.ddev/commands/host/pg:43` | `trap "rm -f -- '$tmp'" EXIT` puts the path inside single quotes in a string that is evaluated later. The directory comes from the user's `FILE`, so a directory name with a `'` breaks the trap. Cleanup then fails, or the trap runs the rest of the path as a command. See CODING_STANDARDS "Shell scripts" ("Quote every expansion"). | Use `printf -v q '%q' "$tmp"; trap "rm -f -- $q" EXIT`. Or make `tmp` a global and use `trap 'rm -f -- "$tmp"' EXIT`, which also removes the SC2064 suppression on line 42. | Open |
| 4 | Minor | `.ddev/commands/host/pg:35-48` | `ddev pg dump FILE` with an existing directory as `FILE` runs `mv` into that directory. This leaves a hidden `.pgdump.XXXXXX` file there, prints a misleading size and exits 0. | Before `mktemp`, reject `-d "$file"` with a stderr message and exit 2. Tester: add one negative line to TC-T06-34. | Open |
| 5 | Minor | `docs/runbooks/local-setup.md` (T06 commands section); `.ddev/README.md:66-67` | The docs do not say how a relative `FILE` resolves for `ddev pg dump FILE` and `ddev pg restore FILE`. A host command resolves it against the working directory DDEV gives it, not the caller's subdirectory, unless `## HostWorkingDir` is set. | Pick one. (a) State the rule: relative paths resolve from the repo root. The tester confirms by running from `docs/`. (b) Add `## HostWorkingDir: true` if DDEV v1.24.4 supports it for host commands, and document that. Record the result in the verified-facts table. | Open |
| 6 | Minor | `.ddev/docker-compose.engine.yaml:29`, `.ddev/docker-compose.next.yaml:29` | The whole `ddev-global-cache` volume is mounted, so `rootCA-key.pem` is visible to two more containers. Plan Risks asked to try a compose volume `subpath` that mounts only `mkcert`. The verified-facts table has no record that this was tried. | Try the long volume syntax with `volume: {subpath: mkcert}`, mounted at `/mnt/ddev-global-cache/mkcert` (Docker 28 and compose 2.34 support it). If it works, use it in both files. If not, add a verified-facts row with the result. The runbook already states the read-only exposure. | Open |
| 7 | Minor | `docs/architecture/technical-design.md:577`; `.ddev/README.md:77` | D7 and the verified-facts intro cite "evidence in `docs/tests/T06/`". Today that folder holds only `design-time-run.txt`. The claim needs the tester's evidence. | At `/close-task`, replace the folder reference with the real evidence: TC-T06-23, TC-T06-24, TC-T06-40 and their evidence files. If a case fails, reopen D7. | Open (close step) |
| 8 | Note | Plan KD-7, KD-10; `.ddev/README.md:70-72` | DDEV v1.24.4 turns every non-zero host-command exit into 1. The original status is only in its stderr line. The plan's interface expected 2 and N through `ddev`. The implementation is correct: the scripts return 2 and N, which a direct run shows, and `.ddev/README.md` documents the flattening. No acceptance criterion depends on a specific code. AC3 needs the commands to exist and be documented. AC5 needs the stopped service to be "reported" (non-zero exit and an `exited` line), which is met. | Plan amended (addendum 2026-11-02). Tests assert 2 and N by direct invocation, or exit 1 plus `exit status N` on stderr through `ddev`. T13 and T27 must not rely on engine exit codes through `ddev engine`. | Resolved (plan addendum) |
| 9 | Note | `.ddev/commands/host/engine:33-37`, `next:33-37` | The `docker exec` fallback is applied as the plan says. Container names come from `DDEV_SITENAME` (default `meridian` when the script runs directly). `-t` is added only when both stdin and stdout are terminals. `"$@"` passes through unchanged. `-i` is always set, so a caller inside a `while read` loop must redirect stdin. `scripts/quality.sh:122` already uses `</dev/null`. | None. T13 and T21 keep `</dev/null` in any loop that calls these commands. | n/a |
| 10 | Note | `.env.example:47` | The changed comment is 109 characters. No linter covers `.env.example`, but the rest of the file stays within 100. | Optional: wrap it onto two comment lines. | n/a |
| 11 | Note | compose files, helpers | Checked and correct, no action. Health checks and start periods match KD-4 to KD-6. The Postgres check uses `-h 127.0.0.1`, so it stays unhealthy while the init server is socket-only. No check calls Drupal or Postgres across services. `user: ${DDEV_UID}:${DDEV_GID}` is set on engine and web only. Digests are pinned. There is no `restart:` and no host `ports:`, and `HTTPS_EXPOSE` binds 3001 only. `$$MERIDIAN_POSTGRES_PASSWORD` escapes compose interpolation. The CA bundle is the system CAs plus the mkcert root, with a warning when the root is absent. `start.sh` switches on `apps/web/package.json` and passes `--hostname 0.0.0.0 --port 3000`. The placeholder is 10 lines, uses `node:http` only and names T21. | None. | n/a |
| 12 | Note | all | Simulation-only rule. The images are only the official `postgres`, `python` and `node`. No broker SDK, domain or order code was added. The only denylist hits are the existing rule sentences in `CLAUDE.md`, `README.md` and the standards. | None. | n/a |

## Suspected test defects (tester-owned; not edited here)

Each one is a check problem, not an implementation problem, unless the row says otherwise. The
tester logs each one as a `DEF-nnn` in `docs/tests/defects.md` and fixes the check.

| Case | Verdict | Reason and fix |
|---|---|---|
| TC-T06-01 | Check problem | `ls .ddev/docker-compose.*.yaml \| sort` returns engine, next, postgres. The check compares that against `$CPG $CEN $CWB` (postgres, engine, next), so it can never match. Fix: sort both sides. |
| TC-T06-17 | Check problem | `deny_docs` greps whole changed files. `CLAUDE.md:19`, `README.md:6` and `CODING_STANDARDS.md:29` already contain "order-placement code" in the simulation-only **rule** text. No line T06 added matches the denylist (checked with `git diff -U0`). Fix: scan only the added lines, or allow the rule sentence. |
| TC-T06-19 and TC-T05-21 | Check problem, plus a gap in my plan | T04a `envsame` (TC-T04a-33) byte-compares `.env.example` up to HEAD. KD-9 allows comment edits, and the plan's re-tag list named only TC-T05-15. Fix: compare only the variable lines (for example, drop `#` lines and diff the rest), or re-tag the check as a snapshot (`cka`). The names and values are unchanged (verified). |
| TC-T06-24 | Check problem | Node reports `UNABLE_TO_VERIFY_LEAF_SIGNATURE` (probed). The pattern `UNABLE_TO_GET_ISSUER_CERT\|SELF_SIGNED\|CERT_\|unable to verify` is case-sensitive and does not match it. Fix: add `UNABLE_TO_VERIFY_LEAF_SIGNATURE`, or match `-i 'unable to verify'`. |
| TC-T06-25, 26, 28, 34 (exit codes) | Check problem (platform) | Through `ddev`, every failure is exit 1 (finding 8). Fix: assert the codes 2, 5 and 7 by direct invocation (`DDEV_SITENAME=meridian .ddev/commands/host/<cmd>`). Through `ddev`, assert exit 1 and `exit status N` on stderr. The rest of each case is unaffected. |
| TC-T06-36 to 39 (last line) | Check problem | These cases do not need DDEV to change. `rcof` captures `2>&1`, so `tail -1` reads DDEV's stderr line. The command's stdout still ends with `NOT OK: <services>`. Fix: capture stdout separately and run `tail -1` on it. The doc wording follows finding 2. |

## Review checklist summary

- 1 Simulation only: yes (finding 12).
- 2 C1 to C7: see below.
- 3 Plan adherence:
  - Yes. The `docker exec` fallback is the plan's documented fallback.
  - The `ddev e2e` row was moved to T27, as KD-7 asked.
  - There is no `pyproject.toml`, `package.json` or Dockerfile, and no scope creep.
  - The dependencies are three official images, audited in KD-11.
- 4 Cross-cutting:
  - Naming passes.
  - Error handling: finding 1.
  - No secrets.
  - Images pinned by tag and digest.
  - The one suppression (`pg:42`, SC2064) has a ticket in the correct slot. It is a permanent
    choice decided in T06, which the exception policy allows. Finding 3 offers a way to drop it.
- 4 Size: every file is under 400 lines and every function under 50.
- 5 Tests: the T06 design covers the boundaries. Six check defects are listed above.
- 6 Shell: `#!/usr/bin/env bash` and `set -euo pipefail` are in all six scripts. Expansions are
  quoted (except finding 3), `[[ ]]` is used, errors go to stderr with usage, and `mktemp` is
  paired with a `trap`.

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | Plan and decision committed in 6e9e69d, an ancestor of the first code commit 933e3b7 |
| C2 Review findings resolved | No | Finding 1 (Major) and findings 2 to 7 (Minor) are open |
| C3 Criteria mapped to executed tests | Not yet | Mapping exists in `docs/tests/T06/test-cases.md`; execution is `/test-task`, after the check fixes above. AC6b is `Blocked (accepted, re-run in T21)` and needs the owner's written acceptance |
| C4 CI green | Partly | pre-commit on the changed files passes and check-names passes. `ddev quality` exit 0 and the T05 and T04a `--regression` runs are owed in `/test-task`, after the TC-T05-15, TC-T05-23 and TC-T04a-33 re-tags |
| C5 Docs updated | Yes, with findings 2, 5, 7 | Runbook, `.ddev/README.md` with verified facts, `CLAUDE.md`, `README.md`, component READMEs, D7 with revision 4, open item and standards digest rule are all done. The placeholder-until-T21 wording appears in the runbook, `README.md`, `.ddev/README.md` and `apps/web/README.md`. `TRACEABILITY.md` is updated at close |
| C6 No secrets | Yes | gitleaks passes, there are no values in compose files and `.env.example` changed comments only. Dumps are git-ignored with mode 600 files in a 700 directory |
| C7 Clean-checkout works | Not yet | `env_file` `required: false` is verified with no `.env`. The full clean-clone case runs in `/test-task` |

## Approval

**Changes requested.** Finding 1 (Major) must be fixed in this task. Fix findings 2 to 6 now or
ticket them, and finding 7 is a close-step item. After that, the tester fixes the six check
defects and runs `/test-task`. A re-review covers the changed lines of `pg` and the runbook only.
technical-architect, 2026-11-02.

## Re-review 2026-11-02 (`c6d4fbb..5bf194e`)

Commits:

- 68ab8c0: `pg` validates the whole archive, uses a safe trap and refuses a directory target.
- 5bf194e: docs, stderr wording, relative-path note and the `subpath` fact.

The developer sent no report, so I checked the diff myself.

Checks run (read-only):

- `.tools/pre-commit run --files` on `.ddev/README.md`, `.ddev/commands/host/pg` and
  `docs/runbooks/local-setup.md` passes, including shellcheck, markdownlint and the
  suppressions check.
- From `docs/`, `ddev pg dump tasks/T06` refuses with `'tasks/T06' is a directory` and exits 2.
  DDEV reports this as exit 1. No file was written, and `git status --porcelain` is empty.
- The same probe shows that a relative `FILE` resolves against the caller's directory, not the
  repo root. `tasks/T06` exists only under `docs/`. The new usage text and runbook line say
  this correctly.
- I ran no service-stopping command. The tester's live suite was running.

| # | Was | Now | Evidence and notes |
|---|---|---|---|
| 1 | Major | **Fixed in 68ab8c0, closed in code.** Behavioural proof is owed by TC-T06-34 | `pg:93-99` validates with `pg_restore -f /dev/null` before any change, and on failure exits 1 with "database unchanged". `restore_into_db` (`pg:62-66`) chains drop, create and restore with `&&`. Because it is called in an `if !` context, it reports "FAILED after the old database was dropped ... may be empty or partial" and exits 1. Runbook lines 153-156 now describe both cases accurately. **Condition:** the tester's TC-T06-34 gets the extra case: a seeded dump of at least 1 MB cut at about half its size, which must give a non-zero exit with the checksum unchanged. That case must pass in `/test-task`. If it fails, finding 1 reopens as Major |
| 2 | Minor | **Partly fixed, still open (Minor)** | Fixed: the `.ddev/README.md` paragraph (lines 70-74) and the exit-code fact row now say the `Failed to run ...` line goes to stderr and stdout is unchanged. Not changed: runbook step 6 (`local-setup.md:107-108`), the `.ddev/README.md:68` table row and the `meridian-status` usage text (lines 15-16) still say "the last line" without "of standard output". At a terminal, DDEV's red stderr line shows last. Resolution: add "of standard output" in those three places, or ticket it. This does not block approval |
| 3 | Minor | **Closed** | The trap now calls `cleanup_tmp`, which reads the global `TMP_DUMP` (`pg:37-40`, `:54-58`). No path is put into an evaluated string. The SC2064 suppression is gone, so T06 now has no suppression |
| 4 | Minor | **Closed** | `pg:49-52` refuses `-d "$file"` with exit 2 before `mktemp`. Verified live (see above) |
| 5 | Minor | **Closed** | The usage text and runbook say a relative `FILE` resolves against the directory `ddev` was run from. This was verified live. The default path still uses `$root/db-dumps` |
| 6 | Minor | **Closed (residual risk accepted and recorded)** | `.ddev/README.md` adds a verified-facts row: `subpath: mkcert` works, but `rootCA-key.pem` is in the same folder, so it gives no benefit. The whole volume stays mounted read-only. This local-only exposure is already the case for DDEV's own `web` container and is documented in the runbook. The T32 known-limitations review should list it |
| 7 | Minor | **Open, close step** | Unchanged by design. At `/close-task`, cite TC-T06-23, 24 and 40 and their evidence files in D7 (`technical-design.md:577`) and `.ddev/README.md:79` |
| 8 to 12 | Note | No change | Finding 8 is resolved by the plan addendum. Findings 9 to 12 need no action |

Notes on the new code:

- `pg:86` (an error message) is 105 characters. No rule covers it, so this needs no action.
- After a successful dump, the `EXIT` trap stays set with `TMP_DUMP=""`, which is harmless.

The suspected test defects table above still stands. These are tester-owned check fixes and
are not part of this re-review.

### Common criteria after the re-review

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | Unchanged |
| C2 Review findings resolved | Yes, with conditions | No Blocker or Major is open. Finding 2 (Minor) must be fixed or ticketed. Finding 7 is done at close. Finding 1 depends on TC-T06-34 passing |
| C3 Criteria mapped to executed tests | Not yet | Owed in `/test-task`. AC6b needs the owner's written acceptance |
| C4 CI green | Partly | pre-commit passes on the changed files. `ddev quality` and the regression runs are owed in `/test-task` |
| C5 Docs updated | Yes | Except the finding 2 wording and the finding 7 close-step citation |
| C6 No secrets | Yes | Unchanged. gitleaks passes |
| C7 Clean-checkout works | Not yet | Owed in `/test-task` |

### Approval after the re-review

**Approved with conditions.**

- TC-T06-34, extended with the truncated-archive case, passes in `/test-task`. If it fails,
  finding 1 reopens as Major.
- Finding 2's remaining wording is fixed, or ticketed with an ID, before `/close-task`.
- Finding 7 is applied at `/close-task`.
- C3, C4 and C7 are met by the test report. The tester fixes the six check defects above
  first, and the T05 and T04a regression checks are re-tagged.
- The owner accepts AC6b (`Blocked (accepted, re-run in T21)`) in writing before T06 is marked
  `Done`.

technical-architect, 2026-11-02.
