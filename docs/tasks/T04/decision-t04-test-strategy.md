# T04: Solution-architect decisions on the test strategy

| Field | Value |
|---|---|
| Task | T04 |
| Author | solution-architect |
| Date | 2026-11-01 |
| Answers | `docs/tasks/T04/plan.md`, section "Decisions needed from solution-architect" (questions 1 to 6) |
| Related | `docs/architecture/solution-architecture.md` (FR/NFR tables), `docs/architecture/technical-design.md` (D4, D5, D6, "NFR numbers owned by T03"), `docs/architecture/openapi.yaml`, `docs/TASKS.md` T04, T04a, T08, T10, T11, T26, T27, T30, T31 and section 3.3 |

Selection rule applied to every tool choice: free, maintained, self-hostable, runs offline in
CI and DDEV, no SaaS account. The plan names tools only; T04a pins versions and confirms that
each one installs in DDEV and CI. A capability marked **unverified** must be confirmed by the
named task before it is relied on.

None of these decisions changes an FR or NFR target. Where a decision fixes a measuring
method, that is how the existing target is computed, not a new target.

---

## D-1: Planned-test granularity

**Decision:** Confirmed. **FR/NFR level, 49 rows** (FR-01 to FR-30, NFR-01 to NFR-19) in a
second "Planned tests" table in `docs/TRACEABILITY.md`. Each R row's "Test cases" cell links
to its FR and NFR rows. R-level-only planning is rejected.

**Rationale:**

- The measurable targets, priorities and verifying tasks live on FR and NFR rows (T02
  acceptance). An R row cannot say what "passed" means. For example, R-10 spans FR-22 to
  FR-25 and NFR-01, -02, -06, -14 and -15.
- FR-29 ("0 requirement rows without a test case and evidence at T32") and the T32 zero-gap
  check need a row per measurable target to be checkable by script.
- The existing R table stays as the summary, so nothing that T00 to T03 wrote is lost.

**Rules for the table:**

- One row per FR or NFR, even when several tasks verify it. The "verifying task" cell lists
  every task from `solution-architecture.md` in the same order. The "planned case ID or
  pattern" cell gives one pattern per task, for example `TC-T17-*` and `TC-T30-*` for FR-07.
- Status vocabulary: `Planned`, `Partially verified` (at least one but not all verifying
  tasks have Pass evidence), `Verified`, `Blocked (accepted, re-run in Txx)` (see D-6).
- The ID set must equal the FR/NFR set in `solution-architecture.md`. If a later amendment
  adds or splits an FR or NFR, the same change adds the row.

**Consequences:**

- 49 rows to maintain. `/close-task` of each verifying task updates the status and the case
  IDs of the rows it verifies.
- The T04 `run-checks.sh` set-equality and task-equality checks stay valid after close, so
  they belong in the regression subset (D-5).

---

## D-2: Contract test tool and the read endpoints in `openapi.yaml`

**Decision:**

1. **Schemathesis** (Python, pytest integration) is the contract test tool for the Drupal
   endpoints (T10 ingest, T11 read, `/me`), run against a running DDEV site.
2. **openapi-core** validates requests and responses against `openapi.yaml` inside engine
   tests: the publisher's request bodies (T19) and the committed example responses used as
   fixtures. This is the "contract against fixtures" part of the PR set and needs no running
   Drupal.
3. **Spectral** stays the linter for the file itself (decided in T03, D5).
4. **Dredd is rejected. Prism is not adopted** as the contract tool.
5. **Yes, the read endpoints go into `openapi.yaml`.** **T11 owns the edit.** The
   technical-architect writes it during `/plan-task T11`, before T11 coding starts (design
   first, as with the ingest contract in T03). The developer may then only change it through
   a reviewed plan amendment. Spectral lint must pass on the edited file.

**Scope of the T11 addition** (a consumer subset, following the `listWatchlistItems`
precedent in D5):

- `GET /jsonapi/node/decision`, `/position`, `/daily_run` (collection and single item), with
  only the filter, sort and `page[limit]`/`page[offset]` parameters the dashboard uses
  (T11: date, symbol, mode, action, sorting, pagination). Add `price_snapshot` only if the
  dashboard reads it.
- Response schemas list the attributes the dashboard consumes. `raw_llm_output` is
  documented as present only for scope `meridian_dashboard_user` with the administrator
  permission. Whether a field is absent per role is tested in PHPUnit Functional (T11, T22),
  not inferred from the schema.
- `GET /api/meridian/v1/me` (custom `meridian_core` route): fields `uid`, `name`, `roles`.
  This closes the T03 unverified item "`/me` contract" for T11. T22 consumes it.
- Errors on JSON:API routes stay core JSON:API error documents (`application/vnd.api+json`),
  as in D5.

**Rationale:**

- Schemathesis: MIT licence; latest 4.32.7, released 2026-10-27; requires Python 3.11 or
  later, so it fits the Python 3.12 engine toolchain; supports OpenAPI 2.0, 3.0, 3.1 and 3.2;
  has a pytest integration and a CLI; produces an offline HTML report
  ([docs](https://schemathesis.readthedocs.io/en/stable/),
  [PyPI](https://pypi.org/project/schemathesis/),
  [GitHub](https://github.com/schemathesis/schemathesis), checked 2026-11-01). Our file is
  OpenAPI 3.1.0, so 3.1 support is required.
- openapi-core: BSD-3-Clause; 0.23.1, released 2026-04-02; supports OpenAPI 3.0, 3.1 and 3.2;
  validates and unmarshals requests and responses
  ([PyPI](https://pypi.org/project/openapi-core/), checked 2026-11-01). It runs in-process,
  so it fits the no-network PR set.
- Dredd: the repository was archived on 2024-11-08 and is read-only, and its OpenAPI 3
  support is marked experimental ([GitHub](https://github.com/apiaryio/dredd), checked
  2026-11-01). It fails the "maintained" rule and our file is 3.1.
- Prism: Apache-2.0, supports OpenAPI 3.1, and offers a mock server and a validation proxy
  ([GitHub](https://github.com/stoplightio/prism), checked 2026-11-01). It is a proxy, not
  a test runner, so it would still need a separate client to drive requests. That is a
  second runtime (Node) for the same job. It may still suit T21's mock API mode; T21 decides
  that separately.
- One language (Python) for engine tests and contract tests keeps one toolchain in DDEV and
  CI.

**Consequences:**

- Schemathesis tests need a running Drupal and an OAuth token. They run in the **heavy set**
  (T08), not the PR set, from the `meridian-engine` container against DDEV. They live under
  `services/engine/tests/contract/` with a marker such as `drupal_live`, so the PR set can
  exclude them.
- Generated cases write data. Run them against a disposable, freshly installed DDEV site,
  and cap the examples per operation so the 500-item batch and the ingest lock (D5) do not
  make the run slow. T10 records the cap.
- Schemathesis checks schema conformance. It does not replace the T10 PHPUnit Functional
  cases (idempotency, 401/403/422 details, rate limit, audit log, concurrent 409).
- **Unverified:** how Schemathesis handles the DDEV mkcert certificate (CA bundle or an
  internal HTTP hostname). T10 confirms the option and records it.
- If Schemathesis turns out unusable in T10, the fallback is pytest with httpx and
  openapi-core response validation over hand-written cases. That loses generated inputs but
  keeps the contract check.

---

## D-3: Performance tooling

**Decision:**

- **API and engine timings (NFR-04, NFR-05, NFR-01):** a small Python timing harness in the
  engine test tree (stdlib `time.perf_counter` plus the httpx client). It writes every raw
  sample and the computed percentile to the evidence file. NFR-01 uses the run record
  timestamps (`started_at`, `finished_at`) the engine already stores, not a separate tool.
  NFR-07 uses the GitHub Actions job timings.
- **Page load (NFR-03):** **Playwright** with the `web-vitals` library's `onLCP()` (or a
  `PerformanceObserver` for `largest-contentful-paint`) in Chromium. Playwright is already in
  the stack and already logs in for the T24 end-to-end tests.
- **Lighthouse CI** is optional, for diagnostics only, and never a gate. If used, the upload
  target must be `filesystem`, never `temporary-public-storage`.
- **k6 and Locust are not adopted.**

**Measuring method** (how the existing targets are computed):

- Percentiles use the **nearest-rank** method on the raw samples. NFR-04's "p95 over 5 runs"
  is therefore the slowest of the 5 runs. NFR-05's p95 over 50 requests is the 48th value in
  ascending order.
- NFR-03 p75: at least 10 navigations per page per environment (default 20), each in a fresh
  browser context, with Drupal warm. The Drupal-cold figures are measured separately, as the
  NFR states.
- The evidence records the environment: DDEV host CPU and RAM, or the Pantheon and Vercel
  URLs, the date, the seeded record count (5,000) and the tool versions.
- Performance checks are **not** in the PR set. Shared CI runners give noisy timings. They
  run on DDEV or deployed dev in T10, T11, T26 and T30, and optionally in a scheduled heavy
  job that only reports.

**Rationale:**

- The NFR targets are single-client latency percentiles over a fixed sample size, not
  concurrent load. A load generator adds a tool without measuring anything the NFRs ask for.
- LCP should be evaluated at the 75th percentile, and `web-vitals` `onLCP()` handles gaps in
  the raw API ([web.dev LCP](https://web.dev/articles/lcp), checked 2026-11-01).
- Lighthouse CI: Apache-2.0. `numberOfRuns` defaults to 3. Its aggregation defaults to
  `optimistic`. Authenticated pages need a `puppeteerScript`, and `puppeteer` must be
  installed separately. `temporary-public-storage` makes reports publicly reachable by link
  ([configuration](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/configuration.md),
  [GitHub](https://github.com/GoogleChrome/lighthouse-ci), checked 2026-11-01). The
  optimistic default and a second browser driver make it a poor gate, and public upload
  would expose an authenticated dashboard.
- k6 is AGPL-3.0 and scripted in JavaScript as a separate binary
  ([GitHub](https://github.com/grafana/k6), checked 2026-11-01). That is a new runtime and a
  copyleft licence for a need we do not have.
- Locust: not checked (licence and status **unverified**). It is the named fallback if T30
  decides it needs a concurrency test, because it is Python.

**Consequences:**

- **Unverified:** LCP support in Firefox and WebKit. The web.dev page describes Chromium
  behaviour only. NFR-03 is measured in Chromium, and the evidence says so.
- **Unverified:** the `web-vitals` npm licence and offline install. T04a confirms and pins
  it, or T26 uses the raw `PerformanceObserver` instead.
- The harness is test code owned by T10 and T11 (first users). T30 reuses it.

---

## D-4: Recorded market data and network blocking

**Decision:**

- **Committed fixtures, no cassettes.** Market data fixtures are committed CSV or JSON files
  under `services/engine/tests/fixtures/market/`, with a manifest per set: source, capture
  date, capture command, symbols, dates and a SHA-256 per file.
- **Mock at the provider boundary, not at HTTP, for the market data source.** Tests use a
  fixture-backed provider that implements the T15 provider interface. The yfinance adapter's
  own tests replace the yfinance call (monkeypatch or an injected session) with fixture
  DataFrames and with the rate-limit exception for the 429 case.
- **respx** is the single HTTP mock, for httpx-based clients: the Drupal publisher (T19) and
  the LLM client's timeout and API-error paths when they are tested below the T17 fake
  client. T19 should use httpx so that one mock library covers it. `responses` is added only
  if a `requests`-based client appears.
- **Network blocking, two layers:**
  1. **pytest-socket** with `--disable-socket --allow-unix-socket` for the unit and contract
     PR set. Integration tests against DDEV services use `--allow-hosts` listing only the
     local service hosts.
  2. In CI (T08), the engine PR test job runs in a container with no network
     (`docker run --network none` or equivalent).
- **vcrpy is rejected.**

**Required named fixture dates** (T15 and T20 choose the actual dates and cite the NSE
holiday source for the holiday):

| Fixture | Purpose |
|---|---|
| Normal trading day | Baseline scoring and simulation |
| NSE trading holiday (weekday) | FR-23 `skipped` with reason, 0 decisions |
| No-new-candle date (source returns the previous bar) | FR-23 |
| HTTP 429 sequence | NFR-19 bounded retries, run continues for other symbols (T15) |
| Missing fundamentals, stale data, non-positive price | T15 data quality checks |
| MVP parity set | T13 golden file |

**Rationale:**

- yfinance declares `curl_cffi>=0.17` as well as `requests` as dependencies
  ([pyproject.toml](https://raw.githubusercontent.com/ranaroussi/yfinance/main/pyproject.toml),
  checked 2026-11-01). respx mocks HTTPX
  ([GitHub](https://github.com/lundberg/respx), checked 2026-11-01), and vcrpy's supported
  libraries list does not include curl_cffi
  ([vcrpy installation](https://vcrpy.readthedocs.io/en/latest/installation.html), checked
  2026-11-01). HTTP-level mocks or cassettes may therefore not intercept yfinance traffic at
  all. Mocking at the provider interface is reliable whatever transport yfinance uses.
- Committed fixtures are deterministic, reviewable in a diff and need no live network to
  re-create. Cassettes need a live recording to refresh, and they store request and response
  headers (cookies, session tokens). That is a secret-hygiene risk under NFR-10.
- pytest-socket blocks socket access including DNS, raises `SocketBlockedError`, and offers
  `--allow-hosts` and `--allow-unix-socket`; MIT licence
  ([GitHub](https://github.com/miketheman/pytest-socket), checked 2026-11-01).

**Consequences:**

- **Unverified (inference):** pytest-socket works on Python's `socket` module. curl_cffi uses
  libcurl, a native library, which may open sockets outside that module. That is why the
  container-level block (layer 2) is required. T15 demonstrates that a unit test which
  accidentally calls the real yfinance fails in CI.
- **Unverified:** the exact rate-limit exception yfinance raises on HTTP 429. T15 confirms it
  and records it in `docs/specs/data-sources.md`.
- Capture is a manual, owner-run step with network, never in CI. A refresh is a new fixture
  set with a new manifest. Existing sets are never edited in place, so old tests stay
  reproducible.
- **Open question for the owner:** whether redistributing Yahoo-sourced price data in this
  repository is allowed is **unverified**. Until it is checked (T15, `data-sources.md`),
  prefer synthetic or hand-built fixtures for logic tests. Keep real captures to the minimum
  the adapter parsing tests need (few symbols, few dates). If the repo is or becomes
  public, replace real captures with synthetic equivalents unless the terms allow
  redistribution.
- The fake LLM responses (FR-06, FR-07) follow the same rule: committed files, one per
  failure type, plus the injection set. They are served by the T17 fake client, not by
  respx.

---

## D-5: Docs-task `run-checks.sh` scripts in the regression suite

**Decision:** **Yes, with a regression-safe subset.** The PR set (T08) runs the
docs-task checks in a regression mode that executes only checks marked as invariants.

- **Mechanism:** each docs-task script accepts `--regression`. Every check is tagged either
  `invariant` (must hold for the rest of the project) or `snapshot` (true only at the close
  of its task). In regression mode, snapshot checks are not run. The script prints how many
  checks it excluded and why, and still exits non-zero on any invariant failure. Excluded
  snapshot checks are not "SKIP" in the sense of the SKIP convention (optional tools only).
- **Which checks are snapshot (examples):**
  - git order checks (script committed before content);
  - comparisons with a named branch (for example the T02 check that `.env.example` is
    unchanged against `task/T01-agents`, which T03 legitimately changed);
  - "fails before authoring" checks;
  - exact counts that later tasks may legitimately grow, unless rewritten as a lower bound
    (for example "exactly 6 ADRs" becomes "ADR-0001 to ADR-0006 exist").
- **Which checks are invariant (examples):** required documents and headings exist;
  `scripts/check-names.sh` passes; no broker domain or SDK names; the TRACEABILITY ID set
  equals the FR/NFR set in `solution-architecture.md` (D-1); `openapi.yaml` structural
  validation; the T01 path-guard unit tests.
- **Ownership:**
  - **T04:** its new `run-checks.sh` is written with tags and `--regression` from the start.
    The master plan states the rule.
  - **T08:** the tester retrofits T00 to T03 (tagging only), with a Change log entry in each
    task's `test-cases.md`, and T08 wires the PR job. The technical-architect reviews the
    tagging.
- **Rule against loosening:** retagging a check from invariant to snapshot, or turning an
  exact check into a lower bound, needs a Change log entry naming the later task that
  legitimately changed the content. It must never hide a content regression. The T08 review
  checks every retag.
- **When a later task intentionally changes an invariant** (for example it replaces a
  document), that task updates the check in the same change, with a Change log entry. CI
  stays green only when the check and the content agree.

**Rationale:**

- Docs carry the requirements, contract and traceability that later checks depend on (the
  T32 zero-gap check). Silent drift in them is a real regression.
- Running snapshot checks after close would fail for legitimate reasons and train people to
  ignore red CI. Leaving the scripts out entirely would lose the invariant checks.
- The scripts are shell and Python standard library with no network, and they take seconds,
  so they fit the PR set and the NFR-07 CI budget.

**Consequences:**

- A one-off retrofit cost in T08 for four scripts. T01 has unit tests and evidence rather
  than a `run-checks.sh`. Its path-guard unit tests join the PR set directly.
- Tools the sandbox lacked (Spectral, gitleaks) are available in CI after T04a. Checks that
  were SKIP for a missing optional tool must run in CI, not be skipped.

---

## D-6: Closing a task with Blocked cases

> **RECOMMENDATION, PENDING OWNER CONFIRMATION.** This policy is the solution-architect's
> recommendation. It takes effect only when the project owner confirms it in their own
> message. An agent or main-session message is not owner confirmation. Until then, the
> T00 to T02 precedent (owner acceptance recorded case by case) continues.

**Recommended policy:** a task may close with Blocked cases only when **all** of these hold:

1. **Cause.** The block is environmental or an owner action: a tool, network, account,
   platform or restart that the executing context does not have. It is never a document,
   code, configuration, test-script or design defect. A defect is a **Fail** with an entry in
   `defects.md`, and the defect workflow applies.
2. **Not a safety check.** The case does not verify the simulation-only rule (FR-11, the
   static broker check) or secret hygiene (C6, NFR-10, gitleaks). These run offline and must
   Pass before close.
3. **Written owner acceptance** in the task's `test-report.md`, in a "Blocked at close"
   table: case ID, criterion, block reason, who accepted (the owner), date, and a reference
   to the owner's own message. The main session records it but cannot give it.
4. **Re-run ticket.** Each accepted Blocked case names the earliest task where the missing
   environment exists (for example T04a for pinned tools, T05 or T06 for DDEV, T08 for CI)
   and is listed in that task's plan as a carried-over case. The re-run is executed and
   recorded with evidence there.
5. **The criterion stays open.** The TRACEABILITY row shows `Blocked (accepted, re-run in
   Txx)`, not Verified. `docs/PROGRESS.md` shows the task as Done with a note that names the
   carried-over case IDs.
6. **Hard stops.** No open Critical or High defect (the plan's exit criteria already require
   this). Every accepted Blocked case must Pass before the milestone gate that depends on it,
   and all must Pass by T32 (FR-29, zero gaps).

**Rationale:**

- It matches what T00 to T02 did and why: the agent sandbox has no network and lacks some
  tools. Refusing to close would stall the plan on environment gaps, not on quality.
- Limiting it to environment causes stops "Blocked" becoming a way to defer real faults. The
  carry-over and the T32 gate make sure each case is eventually executed.
- Excluding the safety checks keeps the project's two non-negotiable rules (simulation only,
  no secrets) from ever resting on an unexecuted test.

**Alternatives considered:**

- Every case must Pass before Done. This is the strictest option, but tasks T00 to T04 would
  have stayed open until T04a and T08 exist, and the tools needed come from later tasks.
- Owner acceptance with no re-run ticket. Simpler, but the case may never be executed, and
  T32 would find the gap late.

**Consequences:**

- The tester adds the "Blocked at close" table to the test report template (T04, as part of
  the conventions section of the master plan).
- `/close-task` checks for the owner reference and the re-run task for each Blocked case.
- The re-run tasks carry a little extra scope, which their plans must list.

---

## Summary

| ID | Question | Decision |
|---|---|---|
| D-1 | Planned-test granularity | FR/NFR level, 49 rows; R rows link to them; status vocabulary fixed |
| D-2 | Contract tool; read endpoints | Schemathesis against DDEV (heavy set) plus openapi-core in engine tests (PR set); Dredd rejected, Prism not adopted. T11 adds the read endpoints and `/me` to `openapi.yaml`, written by the technical-architect in `/plan-task T11` before coding |
| D-3 | Performance tooling | Python timing harness (nearest-rank percentiles, raw samples kept) plus Playwright `web-vitals` LCP in Chromium; Lighthouse CI optional and `filesystem` upload only; no k6 or Locust; not in the PR set |
| D-4 | Market data and network | Committed fixtures with manifests; mock yfinance at the provider boundary (curl_cffi); respx for httpx clients; pytest-socket plus a no-network container in CI; vcrpy rejected |
| D-5 | Docs scripts in regression | Yes, `--regression` mode running invariant-tagged checks only; T04 adopts now, T08 retrofits T00 to T03 with Change log entries |
| D-6 | Blocked at close | Recommendation pending owner confirmation: environment or owner-action blocks only, never safety checks or defects, written owner acceptance, named re-run task, criterion stays open, all Pass by T32 |

## Open questions

| ID | Question | Owner | Resolve in |
|---|---|---|---|
| OQ-T04-1 | Confirm the D-6 Blocked-at-close policy | Project owner | Before T04 close |
| OQ-T04-2 | Is redistributing Yahoo-sourced price data in this repository allowed? Is the repo public or private? | Project owner, solution-architect | T15 |
| OQ-T04-3 | Schemathesis TLS handling against the DDEV mkcert certificate | developer | T10 |
| OQ-T04-4 | Does the container-level network block catch an accidental real yfinance call in unit tests? | developer, tester | T15 |
| OQ-T04-5 | `web-vitals` licence and offline install; LCP outside Chromium | technical-architect | T04a, T26 |
