# T07: Solution-architect decision on scope: AC3 wording, NFR-04 timing, AC4 closure (SA-5 to SA-7)

| Field | Value |
|---|---|
| Task | T07 |
| Author | solution-architect |
| Date | 2026-11-02 |
| Answers | `docs/tasks/T07/plan.md` (Draft), "Decisions needed from solution-architect", SA-5, SA-6, SA-7; KD-11, KD-12, "Verification phases for AC4" |
| Related | `docs/TASKS.md` T07, T10, T28, T31; technical-design "NFR numbers owned by T03"; `docs/tasks/T06/decision-nextjs-placeholder.md` (deferred-case practice); `decision-ci-credentials.md` |

## SA-5: AC3 wording

### Decision

**Accept the KD-11 reading and propose a wording change in `docs/TASKS.md`.** Until the owner
changes the text, the test report records the reading in a note on the AC3 case. `ddev auth
pantheon` does not exist in DDEV v1.24.4 (plan, "Facts established", probed 2026-11-02);
authentication is the provider's `auth_command` (`terminus auth:login` with
`TERMINUS_MACHINE_TOKEN` from the global DDEV config) plus `ddev auth ssh` for the key.

### Reasons

1. The intent of AC3 is "a developer can pull the Pantheon database and files into DDEV". The
   command name was an example of the old DDEV interface.
2. Testing a command that does not exist would be a false Fail; claiming it would be a false
   Pass.

### Proposed `docs/TASKS.md` text (owner's document: propose only)

Current:

```text
- [ ] `ddev auth pantheon` and `ddev pull pantheon` pull database and files into local DDEV (tested)
```

Proposed:

```text
- [ ] Terminus authentication for DDEV is set up (PAT in the global DDEV config; `ddev auth ssh` loads the SSH key) and `ddev pull pantheon` pulls database and files into local DDEV (tested)
```

The AC3 test passes only if `ddev pull pantheon` runs from a fresh shell with no manual
`terminus auth:login` before it (so the provider's `auth_command` is what authenticates).

## SA-6: NFR-04 on Pantheon

### Decision

**Accept.** T07 records the wake time, warm GET latency (p50, p95 over 20 requests), and the
edge body size result. The 100-item warm ingest measurement moves to **T10** (on Pantheon dev,
warm, 5 runs, p95, same method as MG-1), and **T28** confirms it on the deployed stack.

### Reasons

1. The ingest endpoint exists only from T10. A T07 measurement with a stand-in script would
   measure something else (no OAuth, no lock, no outbox path).
2. T10 can deploy to Pantheon dev with `ddev deploy-drupal` even if CI deploys are not set up
   (`decision-ci-credentials.md`, decision 2).

### Additional T07 measurement: the Sandbox interstitial page

Pantheon shows an **interstitial warning page on all Sandbox sites, in all environments**,
since 2025-05-06. A browser cookie suppresses it for 24 hours. Automated tools can add the HTTP
header `Deterrence-Bypass` to skip it (S1, S2). The docs do not say whether non-browser
requests (curl, JSON:API reads, OAuth token requests, ingest POSTs) are intercepted, and the
header **value** is not shown in the text retrieved (**unverified**).

This affects the T07 smoke check and KD-12 measurements, and later T10 (engine publisher),
T11 and T21 (Next.js server reads), T22 (OAuth), T28. T07 owns finding out:

1. `curl -sS -o body -w '%{http_code}'` of `/user/login` without the header: record the status,
   and whether the body is Drupal's login form or the interstitial.
2. The same with `-H 'Deterrence-Bypass: 1'` (and, if needed, other values the Pantheon page
   shows when read in a browser): record which value works.
3. The same for a POST (the KD-12 body-size request) and for `/jsonapi` (expect 401 or 200
   from Drupal, not the interstitial).
4. The smoke check (KD-1 stage 8) asserts a Drupal marker in the body (for example the form id
   `user-login-form`), not only HTTP 200, and sends the bypass header if step 2 shows it is
   needed.
5. Record the result in D8 and the NFR numbers section, and raise an item for T10 and T21 if
   API requests are intercepted. That item asks: does the engine and the Next.js server send
   the header (a non-secret constant), and does the bypass header need to be in D7?

### Proposed `docs/TASKS.md` text

None. NFR-04 is not a T07 criterion in `docs/TASKS.md`; the move is a technical-design change.

## SA-7: When AC4 counts as met

### Decision

**AC4 is met by the local real deploy (phase 2)**, because it runs the same
`scripts/deploy-drupal.sh` that the workflow calls, and the criterion asks for "the decided
mechanism", with CI given only as an example. T07 may close as **Done** without a CI run, on
these conditions:

1. Phase 1 (offline harness) and phase 2 (real deploy, `config:status` clean, smoke check with
   the Drupal marker) pass with evidence.
2. The workflow's own logic is checked statically in T07: actionlint at a pinned version passes,
   and a test asserts the guard (`vars.PANTHEON_SITE` empty gives the "not configured, skipped"
   step) and that the run step calls `scripts/deploy-drupal.sh` with secrets through `env:`.
3. The CI run is a separate test case with the status
   `Blocked (accepted, owner-run after O-6)`. The owner accepts this in writing at T07 close
   (D-6 practice from
   `docs/tasks/T04a/decision-t04a-standards.md`). An agent message is not owner acceptance.
4. The first push-triggered run on `main` after the merge (expected: skipped, because
   `PANTHEON_SITE` is unset) is recorded as an addendum with its run URL; it is not a close
   condition.

### Who owes the CI run

- If the machine user exists (`decision-ci-credentials.md`, decision 1): the run is due after
  O-6 and O-7. The owner sends the run URL; the tester adds a dated addendum to
  `docs/tests/T07/test-report.md`. **T28 cannot close** until this case is Pass.
- If deploys are local-only (decision 2 there): the case is recorded as `Not run: deploys are
  local-only by decision` and T28 checks the local path instead. If a machine user becomes
  possible later, the task that sets O-6 runs the case.

### Reasons

1. Waiting for a workflow run would block T07 on a credential decision that may legitimately
   end in "local-only", which would leave T07 open with no path to close.
2. The risk left untested is small and specific: runner setup (Terminus phar checksum,
   `ssh-agent` from a secret). The deploy logic is the same script.
3. This follows the T06 practice for a criterion that depends on a later step (AC6b).

### Proposed `docs/TASKS.md` text (owner's document: propose only)

Current:

```text
- [ ] Code in `apps/drupal` deploys to Pantheon dev by the decided mechanism (for example subtree push from CI); site loads on its dev URL
```

Proposed:

```text
- [ ] Code in `apps/drupal` deploys to Pantheon dev by the decided mechanism (subtree split pushed by `scripts/deploy-drupal.sh`, run with `ddev deploy-drupal` or from `deploy-drupal.yml`); site loads on its dev URL
```

### Wording at T07 close

**`docs/TRACEABILITY.md`, R-11 and FR-27 rows.** The evidence cell adds this text (use the real
case IDs). The R-11 status stays `Open`, because T08, T21 and T28 still owe items.

```text
T07: AC4 Pass by local deploy (TC-T07-nn); CI run TC-T07-nn Blocked (accepted, owner-run after O-6)
```

**`docs/PROGRESS.md`, T07 notes.** Drop the last clause if O-5 succeeded.

```text
AC4 by local deploy; CI deploy run owed after O-6 (owner-accepted); deploys local-only until a machine user exists
```

## Further Pantheon facts for the runbook (AC6)

| Fact | Value | Source |
|---|---|---|
| Idle sleep | Dev and Sandbox containers sleep after about 1 hour idle; a web request wakes them, "usually within 30 seconds" | S3 ("Last Reviewed 2020-04-24", old: T07 records the observed wake time) |
| Freeze | Sandbox sites over 4 months old with no code commits or other Git activity for 3 months are frozen; requests return `530 Site Frozen`; unfreeze from the workspace Sites tab | S4 ("Last Reviewed 2025-02-14") |
| Timeouts | Edge 59 s; PHP `max_execution_time` 120 s; Pantheon cron 180 s | S5 ("Last Reviewed 2025-02-14") |
| Body size limit | Not stated in S5 | **Unverified**; KD-12 measures it |
| Sandbox limits | Two Sandbox sites per user account; no custom domains; no automatic backups | S2 |

Consequence for T31 (plan R9): ingest requests are not Git activity, so a freeze can hit a
live-simulation window if no deploy happened in the 3 months before it. The runbook adds a
pre-T31 check: confirm the last Git activity on Pantheon is less than 60 days old, or run a
deploy (any reviewed change) before the window. A freeze inside a 10 to 15 day window is then
not possible.

## Technical-design follow-ups (technical-architect applies in plan step 11)

- **NFR numbers, NFR-04 Pantheon dev row.** Replace "T07 measures warm, T28 confirms" with
  "T07 records wake time, warm GET latency and the edge body limit; T10 measures the 100-item
  warm ingest on Pantheon dev (p95 over 5 runs); T28 confirms".
- **Ingest body size row.** Add the T07 result with date, or keep **unverified** with the
  reason.
- **D8.** Add the interstitial result and, if needed, the bypass header rule.
- **Unverified register.** Add "Sandbox interstitial and API requests" (D8; T07) and close it
  with the result.

## Sources (all checked 2026-11-02)

- S1: [Release note: interstitial warning pages on sandbox sites](https://docs.pantheon.io/release-notes/2025/05/interstitial-pages)
  (effective 2025-05-06; updated 2025-05-08 to cover all sandbox sites)
- S2: [Site Hosting Plans](https://docs.pantheon.io/guides/account-mgmt/plans/site-plans)
  ("Last Reviewed 2026-07-27"): interstitial in all environments, `Deterrence-Bypass` header,
  two Sandbox sites per account, no custom domains, no automatic backups on Sandbox
- S3: [Application containers](https://docs.pantheon.io/application-containers), idle
  containers
- S4: [Platform and site information](https://docs.pantheon.io/guides/platform-considerations/platform-site-info),
  inactive site freezing
- S5: [Timeouts on Pantheon](https://docs.pantheon.io/timeouts)

## Open questions

- Owner: accept in writing at T07 close that the CI run is a deferred case (SA-7, condition 3).
- Owner: decide whether to apply the proposed AC2, AC3 and AC4 wording in `docs/TASKS.md`.
