# Meridian review checklist

| Field | Value |
|---|---|
| Task | T04a (covers R-12) |
| Author | technical-architect |
| Date | 2026-11-01 |
| Derived from | [CODING_STANDARDS.md](CODING_STANDARDS.md), `docs/TASKS.md` section 3.3 (C1 to C7), `CLAUDE.md` |

The technical-architect uses this list in every `/review-task`. Each item is a yes/no question.
A "no" becomes a finding in `docs/tasks/Txx/review.md` with a severity, a file and line, and the
required fix, unless the item does not apply (write "n/a" and why).

Tools already enforce many rules (`scripts/quality.sh`). For those, the question is whether the
tool ran and passed, and whether any new exception is justified. The review spends its time on
the items no tool can check: design, behaviour, tests and scope.

Severity guide: a "no" on simulation-only or secrets is a **Blocker**. A "no" on C1 to C7,
correctness, error handling or tests is at least **Major**. Style items a tool did not catch
are **Minor**. Never approve with an open Blocker or Major.

## 1. Simulation-only rule

- [ ] Is the change free of any broker SDK, broker API client or order-placement code?
- [ ] Is the change free of any reference to a broker trading domain, including tests,
  fixtures and config?
- [ ] Does every new outbound HTTP call go only to a host the architecture already lists
  (Drupal, market data provider, Claude API, Vercel, Pantheon)?
- [ ] If the request implied live trading, was the task stopped and the owner asked?

## 2. Common criteria (C1 to C7)

- [ ] C1: Does `docs/tasks/Txx/plan.md` exist, and was it approved before the first code commit?
- [ ] C2: Are all earlier review findings resolved, or ticketed with an ID?
- [ ] C3: Does every task criterion map to at least one test case that was executed, with
  evidence?
- [ ] C4: Did `scripts/quality.sh` (CI from T08) pass with no new lint, type or security
  warning?
- [ ] C5: Are README, runbook, ADR and `docs/TRACEABILITY.md` rows updated where relevant?
- [ ] C6: Is the repo free of secrets, and does `.env.example` list every new variable with a
  placeholder?
- [ ] C7: Does the change work from a clean checkout with only documented commands?

## 3. Plan adherence and scope

- [ ] Does the change implement the plan's steps and interfaces, and nothing outside its scope?
- [ ] Is every departure from the plan explained and agreed in the plan or review?
- [ ] Is every new dependency named in the plan and audited (licence, maintenance,
  vulnerabilities)?

## 4. Cross-cutting rules

Naming:

- [ ] Do all names follow section 0 naming (`meridian_engine`, `meridian_ingest`,
  `meridian_core`, `meridian-web`, service and workflow names)?
- [ ] Does `scripts/check-names.sh` pass?
- [ ] Do identifiers, files, constraints and new environment variables follow the naming
  table in the standards?

Error handling:

- [ ] Is every caught exception or error narrow, and is none swallowed silently?
- [ ] Does each boundary error keep its cause and give a clear message?
- [ ] Is fail-soft behaviour used only where a requirement allows it (FR-02, FR-05 to FR-07,
  FR-25), with the reason logged?
- [ ] Are user-facing and API errors free of stack traces, secrets and SQL?
- [ ] Are retries bounded, with backoff?

Structured logging:

- [ ] Are new log records structured (JSON or key=value), at the right level, with `run_id`,
  `trade_date` and `symbol` context in the engine?
- [ ] Is no secret, token, cookie, database URL or `Authorization` header written to a log?

Secrets:

- [ ] Do all secrets come from environment variables or a platform store, never from code,
  config exports or fixtures?
- [ ] Did gitleaks and the commit-range check pass on the PR range (`quality.sh`, CI from T08)?
- [ ] Is browser code free of secrets (no secret in a `NEXT_PUBLIC_` variable)?

Dependencies:

- [ ] Are lockfiles committed and updated with every dependency change?
- [ ] Are new tools, images and actions pinned to an exact version, tag or SHA?
- [ ] Was each new dependency audited before it was added (licence, maintenance, audit tool)?

Comments, docstrings and size:

- [ ] Do comments explain why, and do public functions have docstrings, PHPDoc or TSDoc?
- [ ] Do tests name their case ID (`TC-Txx-nn`)?
- [ ] Is each new function at most 50 lines and each file at most 400 lines, or is the size
  justified?
- [ ] Is unfinished work recorded as an open item or defect, not left as a code comment?

Exceptions:

- [ ] Does every new suppression or config exclude cite a ticket on the same line, in the
  format `Txx: reason` or `DEF-nnn: reason`?
- [ ] Is the ticket in the tool's own comment slot, in the form given in the per-tool table of
  the exception policy (second `#` for ruff, mypy, coverage, shellcheck, hadolint; `--` for
  ESLint and phpcs; parentheses for PHPStan; a separate HTML comment for markdownlint), and
  not as bare text after the rule list?
- [ ] Is the change free of inline yamllint disables, with any YAML exception made as a
  per-rule `ignore:` entry in `.yamllint.yaml` carrying a ticket comment?
- [ ] Is every Spectral exception an `overrides:` entry in `.spectral.yaml` with a ticket
  comment on the rule line?
- [ ] Is the TypeScript `ts-ignore` directive absent (only `@ts-expect-error` with a ticket)?
- [ ] If a new suppression uses a form still marked "verify (OQ-T04a-6)", is there evidence
  that the suppression takes effect in the real tool?
- [ ] Does the cited ticket exist, and is it the task that will remove or re-decide it?
- [ ] Does no exception name the task being closed as its remover?
- [ ] Does each suppression target one rule code, not a whole file or every rule?
- [ ] Does `scripts/exceptions_report.py` pass, and do its per-tool counts match the change?

## 5. Tests assert behaviour

- [ ] Do the tests assert observable behaviour (outputs, state, errors), not only that code ran
  or that a mock was called?
- [ ] Would each new test fail if the behaviour it covers were broken (checked by reasoning or
  by a deliberate break)?
- [ ] Are error paths and boundaries tested, not only the happy path?
- [ ] Do tests avoid the live network and real secrets (fakes, fixtures, pytest-socket)?
- [ ] Are coverage floors met, and is no floor lowered without a decision record?
- [ ] Are tests free of `skip` or `xfail` without a ticket?

## 6. Language areas

PHP and Drupal:

- [ ] Does phpcs pass with the Drupal and DrupalPractice standards on custom modules?
- [ ] Does PHPStan pass at level 6 with phpstan-drupal, with no baseline file and every ignore
  carrying an identifier and a ticketed reason?
- [ ] Do services use dependency injection, and do queries use the Entity or Database API with
  placeholders and an explicit `accessCheck()`?
- [ ] Is the configuration exported to `config/sync` with no secret in it?
- [ ] Does every PHP file declare `strict_types=1`, with typed parameters, returns and
  properties?
- [ ] Are hooks `#[Hook]` classes in `src/Hook/` with constructor injection, with procedural
  code and `\Drupal::` calls only in install, update or not-yet-OOP hooks?
- [ ] Does every new route declare a permission or OAuth scope?
- [ ] Does every ingest failure return the `Error` schema from `openapi.yaml`?

Python:

- [ ] Do ruff lint and ruff format pass, with line length 100 and the right target version?
- [ ] Does mypy pass in strict mode for `scripts/`, `.claude/hooks/` and `meridian_engine`?
- [ ] Is `subprocess` called with an argument list and no `shell=True`?
- [ ] Are datetimes timezone-aware, timestamps stored in UTC, and `trade_date` derived in
  `Asia/Kolkata`, never from host local time?
- [ ] Do prices, cash, costs and P&L use `Decimal` on the simulation, persistence and publish
  paths, with floats only inside indicator maths?
- [ ] Is engine code free of `print()`, with human output through the one output module?
- [ ] Is engine I/O (market data, LLM, Drupal) behind an interface that tests replace with a
  fake?
- [ ] Does each command-line tool exit non-zero on failure with one clear line on stderr?

TypeScript and Next.js:

- [ ] Do ESLint, Prettier and `tsc --noEmit` (strict) pass?
- [ ] Is the code free of `any`, and is every non-null assertion or cast explained?
- [ ] Is LLM and API text rendered escaped, with no `dangerouslySetInnerHTML`?
- [ ] Does every new page and data route require authentication, and was no route added to
  the exempt list in `technical-design.md` D6 without a design change?
- [ ] Is data from Drupal validated at the `lib/` client boundary before use?

SQL and migrations:

- [ ] Is each Alembic revision named `NNNN_slug`, one logical change, with a tested
  `downgrade()`?
- [ ] Are all queries parameterised, with no SQL built from strings?
- [ ] Does a destructive change use the two-revision pattern, and is the data-model spec
  updated?
- [ ] Does every new read-path query have a supporting index listed in the technical design?

Docker and YAML:

- [ ] Does hadolint pass, with base images pinned and the container running as non-root?
- [ ] Is no secret passed through `ARG`, `ENV` or a layer, and does the build context have a
  `.dockerignore`?
- [ ] Does yamllint pass, and do workflow actions use pinned SHAs and least-privilege
  permissions?

Shell:

- [ ] Does the shell script use `set -euo pipefail` and pass shellcheck?
- [ ] Are expansions quoted, temporary files cleaned up by a trap, and no failure hidden by
  `|| true` without a comment?
- [ ] Does the script resolve paths from the repo root, so it runs from any directory?

Markdown:

- [ ] Does markdownlint pass, with prose lines at most 100 characters?
- [ ] Are links relative inside the repo, and do external sources carry a checked date?

OpenAPI:

- [ ] Does Spectral pass on `openapi.yaml` with `spectral:oas` and `--fail-severity=warn`,
  with any rule switched off only through a ticketed `overrides:` entry?
- [ ] Do the contract and the data-model spec agree, and were contract tests updated?

LLM prompt files:

- [ ] Is the prompt in a versioned file, with the version bumped on every text change and
  stored per decision?
- [ ] Is the JSON schema a versioned file next to the prompt, and does a schema change bump
  `prompt_version`?
- [ ] Is untrusted text fenced and labelled as data, with an injection test per untrusted
  field?
- [ ] Is the reply parsed strictly (no repair, no JSON extracted from prose) and validated
  against the schema, with any failure, including a schema violation, becoming a veto?
- [ ] Can the LLM only turn a BUY into a veto, and never create a BUY (FR-05)?
- [ ] Is the raw LLM output stored with every decision (FR-12)?
- [ ] Does the model name come from configuration, not from the prompt or code?
- [ ] Did the solution-architect review the prompt change?
- [ ] Is the prompt free of secrets and personal data?

## 7. Assets and theme (section 0b)

- [ ] Are fonts self-hosted, icons SVG with `currentColor`, and raster images WebP?
- [ ] Is nothing loaded from a third-party host, and does `scripts/check_assets.py` pass?
- [ ] Do colours come only from the tokens file, with no hard-coded hex in components?

## 8. Commits and branch

- [ ] Is the branch named `task/Txx-slug` for the task under review?
- [ ] Does every commit subject start with the task ID (`Txx:` plus a space), stay within 72 characters,
  and contain no `fixup!` or `squash!` commit? (The rule applies to commits after `RULE_START`,
  `7689ec5`; older history is exempt.)
- [ ] Was the test design committed before the implementation where the task requires git
  order?
