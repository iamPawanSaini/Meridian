# T04a: Coding standards and quality gates, Standards review

| Field | Value |
|---|---|
| Task | T04a |
| Reviewer | solution-architect |
| Date | 2026-11-01 |
| Commit range | `main..ddad7b7` (branch `task/T04a-coding-standards`) |
| Plan | `docs/tasks/T04a/plan.md` |
| Scope | `docs/standards/CODING_STANDARDS.md`, `docs/standards/REVIEW_CHECKLIST.md` (content and decision fidelity). Tooling is reviewed separately by the technical-architect in `review.md` |

Inputs read: `docs/TASKS.md` (sections 0, 0b, T04a, T16, T17, T18, T21a), the plan,
`decision-t04a-standards.md` (D-1 to D-4), `docs/tasks/T04/decision-t04-test-strategy.md`,
`technical-design.md`, `solution-architecture.md` (FR and NFR rows), `docs/specs/data-model.md`
and the root configs the standards cite. Every external claim below gives its source and the date
checked.

## Summary

The standards are substantive, well organised and correct for Drupal 11, Python 3.12, Next.js App
Router and Postgres 16 in nearly every rule. All four of my decisions (D-1 to D-4) are carried
over faithfully. The simulation-only rule is present and comes first. The asset rules match
section 0b.

There is one **Major** finding. The exception-comment format puts the ticket directly after the
suppression with no separator. That format makes the suppression **invalid** in mypy and ruff,
and it is undocumented in shellcheck. The cause is my own D-4 example, which the standards copied.
It must be fixed before T04a closes, because every later task copies this format.

## Decision fidelity (checked, no finding)

| Decision | Standards text | Result |
|---|---|---|
| D-1 coverage | Line-rate gate; engine 85%, `scoring` and `risk` 90% (NFR-18), Drupal 70% provisional (Unit and Kernel only), web `lib/` and `components/` 80%, `app/` via Playwright; branch reported, not gated; floors only go up; SKIP without a manifest | Matches D-1 and `quality/coverage-thresholds.json` |
| D-2 mypy and ruff | Strict per invocation for `scripts/`, `.claude/hooks/`, `meridian_engine`; engine tests use `check_untyped_defs`; `docs/tests` ruff only; py310 per-file target | Matches D-2, `ruff.toml`, `mypy.ini` and the pre-commit `files:` regex |
| D-3 commits | `^T\d{2}a?: \S`, ID must be in `TASKS.md`, 72 characters, `Merge ` and `Revert "` allowed, `fixup!` and `squash!` fail in `--range`, PR range only, merge commits only, no linear history, `--first-parent` view, re-point evidence after a force-push | Matches D-3 |
| D-4 PHPStan and exceptions | Level 6, no baseline, inline identifier ignores, `reportIgnoresWithoutComments`, unmatched ignores reported; regex `\b(T\d{2}a?\|DEF-\d{3}): \S`; ID must exist; cite the remover; closing-task rule; T32 and T33 review | Matches D-4 and `phpstan.neon.dist`, except the separator problem in finding 1 |
| Branch regex | `^task/T\d{2}a?-[a-z0-9]+(-[a-z0-9]+)*$`, `main` allowed, `GITHUB_HEAD_REF` | Matches the plan |
| Size | Function 50 lines, file 400 lines, review-checked guidance | Matches the plan |

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `CODING_STANDARDS.md` lines 406 to 407 and 425 to 432 ("Exception policy" and its examples); origin `decision-t04a-standards.md` D-4 example | The ticket is placed straight after the suppression with no comment separator. Three of the examples are invalid in the real tools. **mypy:** `# type: ignore[import-untyped]  T13: ...` fails `parse_type_ignore_tag`. Only `\s*\[codes\]\s*(#.*)?$` is accepted, so any other trailing text is an "invalid type: ignore comment" syntax error ([mypy fastparse.py](https://github.com/python/mypy/blob/master/mypy/fastparse.py), checked 2026-11-01). **ruff:** in `# noqa: S603  T20: ...` the `Txx` ID is lexed as a rule code (uppercase letters plus digits). The `:` that follows gives `InvalidCodeSuffix`, so ruff warns and **drops the whole directive** ([ruff noqa.rs](https://github.com/astral-sh/ruff/blob/main/crates/ruff_linter/src/noqa.rs), read 2026-11-01; inference from the source, no upstream test covers this exact input). Every `Txx` ticket breaks a ruff `noqa`, while the `exceptions_report.py` regex still counts it as a valid exception. **shellcheck:** only the form `# shellcheck disable=SC1234 # comment` is documented ([ShellCheck wiki, Directive](https://github.com/koalaman/shellcheck/wiki/Directive), checked 2026-11-01). The ESLint (`-- T29: ...`) and PHPStan (parenthesised) examples are correct. | Amend the rule to "ticket on the same line, **after the tool's own comment separator**", and give one verified example per tool. Python, shell, YAML and Dockerfile use a second `#`: `# noqa: S603  # T20: reason`, `# type: ignore[import-untyped]  # T13: reason`, `# shellcheck disable=SC2034 # T05: reason`. ESLint uses `-- Txx: reason`. PHPStan uses `(Txx: reason)`. phpcs uses `// phpcs:ignore Sniff.Code -- Txx: reason`. markdownlint, yamllint and hadolint forms are **unverified**: each needs a fixture run against the real tool in the owner-run cases (TC-T04a-36 onward). The `exceptions_report.py` regex needs no change. Update the fixtures that use the broken form (`scripts/tests/test_exceptions_report.py` lines 42 to 43, `docs/tests/T04a/run-checks.sh` line 433) so that the tests do not encode invalid syntax. I add a D-4 addendum with the corrected examples when the main session asks for it. | Open |
| 2 | Minor | `CODING_STANDARDS.md` tool table (hadolint and markdownlint-cli2 rows) | The table does not match the authoritative config. hadolint is listed as `2.14.0`, but `.pre-commit-config.yaml` pins `hadolint-py` `v2.12.1b3`. markdownlint-cli2 is listed as `0.19.x`, but the config pins `v0.18.1`. The document says the table is corrected in the same task when the two differ. | Correct the two rows now, or change the pins; keep "verify" until the owner-run install. | Open |
| 3 | Minor | `CODING_STANDARDS.md` tool table, `web-vitals` row; OQ-T04-5 | The proposed pin `5.1.0` looks stale. The `package.json` on the repository's `main` branch shows version `6.2.3`, licence `Apache-2.0` ([web-vitals package.json](https://github.com/GoogleChrome/web-vitals/blob/main/package.json), checked 2026-11-01; `main` may run ahead of the npm release, so the npm version is unverified). The licence is now verified. | Record the licence as verified (source and date). Change the pin to the current npm release, marked verify. T26 confirms that `onLCP()` usage matches that major version. | Open |
| 4 | Minor | `CODING_STANDARDS.md` "OpenAPI" (line 307) and `.pre-commit-config.yaml` line 103 | The standard says Spectral runs with `--fail-severity=warn`. The pre-commit hook entry does not pass that flag, and Spectral's default is `error` ([Spectral CLI guide](https://github.com/stoplightio/spectral/blob/develop/docs/guides/2-cli.md), checked 2026-11-01). Warnings therefore pass the gate today. | Add `--fail-severity=warn` to the hook entry (developer; cross-reference the technical-architect's `review.md`). The standard is right. | Open |
| 5 | Minor | `CODING_STANDARDS.md` line 31 | "The static broker check (FR-11, built in T08 and T30)" is wrong. FR-11 and the master test plan say T18 builds it, T08 runs it in the PR set, and T30 and T33 repeat it. | Reword to: "built in T18, run in CI from T08, repeated in T30 and T33". | Open |
| 6 | Minor | `CODING_STANDARDS.md` naming table (PHP row) and "PHP and Drupal" (DI rule) | The standards steer hooks into `meridian_core.module` and allow `\Drupal::` calls there. From Drupal 11.1, hooks can be methods with `#[Hook]` on autowired classes in `src/Hook/`. Install and update hooks stay procedural ([change record 3442349](https://www.drupal.org/node/3442349), [core conversion 3486534](https://www.drupal.org/node/3486534), checked 2026-11-01). For new Drupal 11 code that is the more testable, DI-friendly form. | Prefer `#[Hook]` classes in `src/Hook/` with constructor injection. Keep procedural code for `.install` hooks, update hooks and any hook not yet supported as OOP. Allow `\Drupal::` only in those procedural files. | Open |
| 7 | Minor | `CODING_STANDARDS.md` "LLM prompt files" and "Error handling" line 76 | The section is consistent with T17 and RK-02 (versioned file, `prompt_version` per decision, schema-validated reply, veto on failure, untrusted text fenced, veto-only). Four gaps remain. (a) FR-12: the raw LLM output is stored with each decision; this is not stated. (b) The JSON schema is not required to be a versioned file next to the prompt, with a schema change bumping `prompt_version`. (c) Parsing is not required to be strict: the code must not repair or extract JSON from prose, so a non-conforming reply is a veto. (d) The error-handling list names 4 failure types, but FR-06 has 5 (it also has schema violation). | Add (a) to (c) to the LLM section, and add "schema violation" to the error-handling list. | Open |
| 8 | Minor | `REVIEW_CHECKLIST.md` | The standards say "every rule here maps to a checklist item or to a tool". These rules have neither. **LLM:** the reply can only veto and never creates a BUY (FR-05); the model comes from config; the solution-architect reviews prompt changes. **Drupal:** `declare(strict_types=1)` and typed signatures; routes declare a permission or OAuth scope; the ingest `Error` schema. **Docker:** no secret in `ARG`, `ENV` or layers; a `.dockerignore` exists. **TS:** Drupal data validated at the `lib/` boundary. **SQL:** a read-path query has an index in the technical design. **Python:** no `print()` in engine code; I/O behind interfaces. **CLI:** non-zero exit with one stderr line. **Shell:** paths from the repo root. | Add these as yes/no items in the matching sections. The LLM veto-only item matters most. | Open |
| 9 | Minor | `CODING_STANDARDS.md` "Markdown docs" line 292 | The `TASKS.md` MD013 exclusion is stated as settled. It is a main-session interim choice pending owner confirmation (OQ-T04a-1). | Add "(interim, pending owner confirmation, OQ-T04a-1)". | Open |
| 10 | Minor | `CODING_STANDARDS.md` "Python" | There are two domain rules for the engine. (a) Dates: `trade_date` is an IST calendar date and timestamps are UTC (`data-model.md` line 32). GitHub runners and containers run in UTC, so "timezone-aware" alone does not stop a wrong trade date between 00:00 and 05:30 IST. (b) Money: prices and cash are `numeric(14,4)` and are hashed as decimal strings (`technical-design.md` line 160), and T18 tests an exact accounting invariant. Float arithmetic on cash and P&L risks drift. | Add: derive `trade_date` with `zoneinfo.ZoneInfo("Asia/Kolkata")`; store timestamps in UTC; never use host local time. Use `decimal.Decimal` for prices, cash, costs and P&L on the simulation, persistence and publish paths; floats are allowed only inside indicator maths and are quantised at the boundary. | Open |
| 11 | Minor | `CODING_STANDARDS.md` "TypeScript and Next.js" line 242; checklist section 6 | "Every page and data route requires authentication (FR-19)" contradicts design D6. D6 lists an exact set of exempt routes (`/login`, `/api/auth/*`, static assets and others). | Reword to "every route except the exempt list in `technical-design.md` D6", and make the checklist item check that no route was added to that list without a design change. | Open |
| 12 | Note | `CODING_STANDARDS.md` line 50 | The `MERIDIAN_` prefix rule conflicts with existing D7 names such as `DRUPAL_BASE_URL` and `DRUPAL_READ_CLIENT_ID` in `.env.example`. | Clarify: names already in the D7 matrix keep their names. | n/a |
| 13 | Note | `CODING_STANDARDS.md` runtimes line 358 | Python 3.10 reached end-of-life on 2026-10-01 ([PEP 619](https://peps.python.org/pep-0619/), checked 2026-11-01). Keeping a py310 syntax floor for stdlib tooling is fine. | Say that 3.10 is the minimum supported version, and that CI (T08) runs the tooling on 3.12. Revisit the floor in T32. Node 22 versus Node 24 LTS for T21 is **unverified**; T21 decides it and cites the Node release schedule. | n/a |
| 14 | Note | `CODING_STANDARDS.md` runtimes | "PHP as set by `pantheon.yml`" is correct, but give the floor. Drupal 11 supports PHP 8.3 and 8.4, not 8.1 or 8.2 ([Drupal PHP requirements](https://www.drupal.org/docs/getting-started/system-requirements/php-requirements), checked 2026-11-01). | Add "PHP 8.3 or later". | n/a |
| 15 | Note | `CODING_STANDARDS.md` "Asset rules" | The rules match section 0b: self-hosted Fira Sans, SVG with `currentColor`, WebP, SVG favicon, ADR for exceptions, no third-party hosts, no hard-coded hex. T21a details are left out by design (tabular figures, the `₹` glyph, Latin subset, CSP `font-src 'self'`). Separately, `technical-design.md` D6 lists `/favicon.ico` as an exempt route while section 0b requires an SVG favicon. | A one-line pointer to T21a is enough. T21a or T22 reconciles the favicon path; this is not a standards defect. | n/a |
| 16 | Note | `REVIEW_CHECKLIST.md` section 4, "Secrets" | A reviewer cannot observe "no `--no-verify` anywhere in the history of the branch". | Rephrase as "Did gitleaks and the commit-range check pass on the PR range (`quality.sh`, CI from T08)?". | n/a |

## Requested checks, result

| Check | Result |
|---|---|
| All 9 language sections present and substantive | Yes. Correct for the stack, apart from findings 6, 10 and 11 |
| Cross-cutting rules: naming, errors, logging with run ID, secrets, dependencies, comments, size | Yes. Logging requires JSON lines with `run_id`, `trade_date` and `symbol`, and redaction. Finding 12 is a clarification |
| D-1 to D-4 applied faithfully | Yes, except the exception-format separator (finding 1) |
| LLM prompt rules consistent with T17 | Mostly; gaps in finding 7 |
| Asset rules match section 0b | Yes |
| Simulation-only rule present | Yes, first section; attribution fix in finding 5 |
| Tool versions marked verify or cited | Yes; mismatches and a stale pin in findings 2 and 3 |
| Checklist derivable from the standards | Partly (finding 8) |

## Common criteria check

This review covers the standards documents only. The technical-architect's `review.md` and the
tester's report assess C1 to C7 for the whole task.

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | Plan approved 2026-11-01; commit `80d681a` comes before the build commits |
| C2 Review findings resolved | No | Findings 1 to 11 are open |
| C3 Criteria mapped to executed tests | n/a here | Tester |
| C4 CI green | n/a here | Technical-architect's tooling review |
| C5 Docs updated | Partly | Standards and checklist exist; findings 2, 3, 5 and 9 correct their content |
| C6 No secrets | Yes | No secret-like values in either document |
| C7 Clean-checkout works | n/a here | Owner-run cases |

## Approval

**Changes requested.** One Major (finding 1) is open. Re-review needs only the changed sections:
the exception policy and its examples, with the per-tool forms verified against the real tools,
or marked unverified with a named owner-run case. Findings 2 to 11 should be fixed in this task,
because each one is a small text edit. Any that are deferred need a ticket ID.

solution-architect, 2026-11-01
