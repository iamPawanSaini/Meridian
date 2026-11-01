# Meridian coding standards

| Field | Value |
|---|---|
| Task | T04a (covers R-12; coverage floors serve NFR-18) |
| Author | technical-architect |
| Date | 2026-11-01 |
| Decisions | `docs/tasks/T04a/decision-t04a-standards.md` (D-1 to D-4), `docs/tasks/T04a/plan.md` |
| Checklist | [REVIEW_CHECKLIST.md](REVIEW_CHECKLIST.md) turns these rules into yes/no checks |

These rules apply to every task from T05 on. They are written once here and enforced by machine
through `scripts/quality.sh`, so that reviews can focus on design. Where a tool enforces a rule,
the rule names the tool. Where no tool can, the rule is a review item in the checklist.

The words **must** and **must not** mark rules. **Should** marks guidance; a reviewer may accept
a departure that is explained in the change.

## How to use this document

- Read the cross-cutting rules first. They apply to every language.
- Then read the section for the language you are changing.
- Run `scripts/quality.sh` before every push (see "Running the quality checks").
- If a rule cannot be met, follow the exception policy. Never silence a tool without a ticket.

## Simulation-only rule

Meridian never places real orders (see `CLAUDE.md`). In every language:

- You must not add a broker SDK, broker API client or order-placement code.
- You must not reference a broker trading domain, not even in tests, fixtures or config.
- The static broker check (FR-11, built in T08 and T30) and the review checklist enforce this.
- A request that would add live-trading capability stops the task and goes to the owner.

## Cross-cutting rules

### Naming (section 0)

Use the names in section 0 of `docs/TASKS.md` everywhere:

| Item | Name |
|---|---|
| DDEV project | `meridian` (`https://meridian.ddev.site`) |
| Python package and engine service | `meridian_engine` (`services/engine`) |
| Drupal custom modules | `meridian_ingest`, `meridian_core` |
| Next.js app | `meridian-web` (`apps/web`) |
| Docker services | `meridian-postgres`, `meridian-engine`, `meridian-web` |
| Workflows | `ci.yml`, `daily-run.yml`, `deploy-drupal.yml` |

- `scripts/check-names.sh` runs as a pre-commit hook and fails on the old placeholder names.
- New environment variables use the `MERIDIAN_` prefix, unless a platform fixes the name
  (for example `ANTHROPIC_API_KEY`, `TERMINUS_MACHINE_TOKEN`).
- Identifiers follow the language convention:

| Language | Modules and files | Types and classes | Functions and variables | Constants |
|---|---|---|---|---|
| Python | `snake_case.py` | `PascalCase` | `snake_case` | `UPPER_SNAKE` |
| PHP (Drupal) | PSR-4, `src/Foo/BarService.php`; hooks in `meridian_core.module` | `PascalCase` | `camelCase` methods, `snake_case` hooks and machine names | `UPPER_SNAKE` |
| TypeScript | `kebab-case.ts`; React components `PascalCase.tsx` | `PascalCase` | `camelCase` | `UPPER_SNAKE` |
| SQL | `snake_case` tables and columns | n/a | n/a | n/a |
| Shell | `kebab-case.sh` | n/a | `snake_case` functions and locals | `UPPER_SNAKE` env vars |

- Database constraint and index names use the prefixes in `docs/specs/data-model.md`
  (`pk_`, `fk_`, `uq_`, `ck_`, `ix_`).
- Drupal machine names: fields start with `field_`, permissions and scopes start with
  `meridian_`.

### Error handling

- Fail loudly at the point of failure. Never swallow an exception: no bare `except:`, no
  `except Exception: pass`, no empty PHP `catch`, no empty `.catch(() => {})`.
- Catch only the exceptions you expect, as narrowly as possible. Convert them to a domain error
  at a boundary (HTTP client, database, LLM client, file system) and keep the cause
  (`raise ... from err`, `new FooException($msg, 0, $previous)`, `new Error(msg, { cause })`).
- Fail-soft only where a requirement says so, and log the reason:
  - one symbol failing does not stop the run (FR-02);
  - any LLM failure (malformed, empty, timeout, API error) is a veto with the reason stored
    (FR-05 to FR-07);
  - a failed publish marks the run `published: partial` and raises an alert (FR-25).
- Errors that reach a user or an API client never contain a stack trace, a secret, a token
  or an SQL statement. Ingest errors use the `Error` schema in `openapi.yaml`.
- Command-line tools exit non-zero on failure and print one clear line to stderr.
- Retries are bounded, use backoff, and log each attempt. No unbounded loops.

### Structured logging

- Logs are structured: one JSON object per line in the engine and the Next.js server, or
  key=value pairs where JSON is not available. Never build a log message by joining strings
  with values that a tool needs to filter on.
- Every engine log record carries `run_id` and `trade_date` once a run has started, and
  `symbol` inside per-symbol work.
- Use the standard level names: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. A recovered,
  expected failure is `WARNING`; a failure that changes the run outcome is `ERROR`.
- Python uses the stdlib `logging` module with a JSON formatter (configured once, in T13).
  Engine code does not call `print()`; CLI output for humans goes through one output module.
- Drupal uses logger channels (for example `meridian_ingest`) with placeholders and a context
  array, never string concatenation.
- Next.js logs only on the server. Client code does not log data from the API.
- **No secrets in logs.** Never log a token, password, API key, OAuth secret, session cookie,
  database URL, `Authorization` header or a full request body that may hold one. Redact
  before logging. Token counts and cost per LLM call are logged (T17); prompt text is not
  logged at `INFO`.

### No secrets in code

- Secrets come only from environment variables or a platform secret store (D7 of the
  technical design). Never commit `.env`, a key file, a dump or a token.
- Every new variable is added to `.env.example` with a placeholder value, in the same commit.
- gitleaks runs as a pre-commit hook and over the full history in CI (T08). Never bypass a
  hook with `--no-verify`. A leaked secret is rotated first, then removed.
- Browser code never receives a secret. In Next.js, a `NEXT_PUBLIC_` variable must not hold
  one.
- Tests and fixtures use obviously fake values (for example `test-not-a-secret`) that do not
  match a real key format.

### Dependency policy

- **Lockfiles are committed** for every component: `apps/drupal/composer.lock`, the lockfile of
  the Node package manager chosen in T21 (`apps/web`), and the engine lock file chosen in T13.
  CI installs from the lockfile only (`composer install`, `npm ci` or equivalent).
- **Pinned versions.** Tools are pinned by exact version or rev: pre-commit hook `rev:` in
  `.pre-commit-config.yaml`, `scripts/tool-versions.env`, Docker base images by version tag
  (plus digest where T06 confirms it works), GitHub Actions by commit SHA (T08). No `latest`.
- **Audit before adding.** A new runtime or dev dependency is named in the task plan under
  "Interfaces touched" and checked before it is added:
  - licence is permissive or compatible (MIT, BSD, Apache-2.0, ISC, MPL-2.0; GPL only for
    tools that are not shipped);
  - maintained (a release in the last 12 months, open issues answered);
  - no known vulnerability (`pip-audit`, `composer audit`, `npm audit`);
  - not a broker SDK, and not a SaaS that needs an account (master test plan selection rule);
  - the standard library or an existing dependency cannot do the job.
- Upgrades happen in a task with a plan entry, one tool family per commit, with the reason.
- `scripts/` and `.claude/hooks/` use the Python standard library only.

### Comments and docstrings

- Comments explain **why**, not what: the reason for a choice, a constraint, a requirement
  ID (`FR-07`), a link to a decision record. Delete comments that repeat the code.
- Python: every public module, class and function has a docstring (Google style: summary
  line, then `Args:`, `Returns:`, `Raises:` where useful). Private helpers need one only when
  the behaviour is not obvious.
- PHP: PHPDoc on every class and public method, as the Drupal standard requires.
- TypeScript: TSDoc (`/** ... */`) on every exported function and type in `lib/`.
- Tests name their case ID (`TC-Txx-nn`) in a docstring or comment (master test plan).
- Unfinished work is not marked with placeholder comments. Record it as an open item with an
  owner and a task ID, or as a defect.

### Function and file size

Guidance, checked in review, not by a gate:

- A function or method should be at most **50 lines** (body, excluding docstring).
- A source file should be at most **400 lines**.
- Excluded: generated code, Alembic revisions, test fixtures, data tables and config exports.
- A longer function or file needs a reason in the change description. Without one it is a
  Minor review finding (split it). Nesting deeper than three levels is a smell to refactor.

### Asset rules (section 0b)

These apply to `apps/web/**` and any Drupal custom theme. T21a owns the token values and the
allowlist.

- Fonts are self-hosted: Fira Sans WOFF2 files in the repo, loaded with the framework's local
  font loader. No Google Fonts link and no CDN.
- Icons are SVG only, drawn with `currentColor`. No icon fonts and no hosted icon kits.
- Raster images are WebP; the favicon is SVG. Any exception is recorded in an ADR.
- Nothing loads fonts, styles, scripts or icons from a third-party host. Pages make same-origin
  requests only (T21a adds a Playwright test).
- Colours come only from the tokens file (T21a). Component code has no hard-coded hex value.
- `scripts/check_assets.py` enforces the third-party host and hex rules in `scripts/quality.sh`.

## Language standards

### PHP and Drupal

Scope: `apps/drupal/web/modules/custom/meridian_*` (and a custom theme if T21a adds one).
Contributed code and core are never edited; patches go through Composer.

- **Style:** PHP_CodeSniffer (`phpcs`) with the `Drupal` and `DrupalPractice` standards from
  `drupal/coder`, configured in `apps/drupal/phpcs.xml.dist` on `web/modules/custom`.
  `phpcbf` may fix style automatically.
- **Static analysis:** PHPStan at **level 6** with `phpstan-drupal` and the deprecation rules,
  configured in `apps/drupal/phpstan.neon.dist` (D-4). Level 8 is reviewed after T12.
- **No PHPStan baseline file.** Every ignore is inline, uses an error identifier and has a
  parenthesised reason that carries the ticket. `reportIgnoresWithoutComments: true` is set
  and `reportUnmatchedIgnoredErrors` stays on, so an ignore without comment, or a stale
  ignore, fails.
- Every PHP file starts with `declare(strict_types=1);`. Parameters, returns and properties are
  typed.
- Use dependency injection in services, controllers, forms and plugins. `\Drupal::` static
  calls are allowed only in procedural hooks and `.module` or `.install` files.
- Use the Entity API and entity queries, with `accessCheck()` set explicitly. Raw database
  queries use the Database API with placeholders, never string concatenation.
- Configuration lives in `apps/drupal/config/sync` and is exported with the change. No secret
  goes into config; `settings.php` reads secrets from the environment.
- Routes declare permissions or OAuth scopes. Controllers return typed responses; the ingest
  route returns the `Error` schema for every failure.
- Tests: PHPUnit Unit and Kernel tests in `meridian_*/tests/src/{Unit,Kernel}`, Functional
  tests in `.../Functional`. Only Unit and Kernel count toward coverage (see the floors).

### Python

Scope and tools (D-2):

| Path | Target | ruff (lint and format) | mypy |
|---|---|---|---|
| `services/engine/meridian_engine/` (from T13) | py312 | Yes | strict, `[tool.mypy] strict = true` in the engine `pyproject.toml` |
| `services/engine/tests/` (from T13) | py312 | Yes | checked, not strict (`check_untyped_defs = true`) |
| `scripts/` including `scripts/tests/` | py310 (stdlib) | Yes | strict, `mypy --strict --python-version 3.10` |
| `.claude/hooks/` | py310 (stdlib) | Yes | strict, `mypy --strict --python-version 3.10` |
| `docs/tests/**/*.py` helpers | py310 (stdlib) | Yes | No (ruff only) |

- **ruff** does linting and formatting, configured in the root `ruff.toml`: line length
  **100**, `target-version = "py312"`, and `per-file-target-version` set to `py310` for
  `scripts/`, `.claude/hooks/` and `docs/tests/`, so ruff does not suggest 3.11+ syntax there.
- **mypy strict is applied per invocation, not per module.** The pre-commit hook runs
  `mypy --strict` on the file sets for `scripts/` and `.claude/hooks/`; the engine sets
  `strict = true` in its own config. Per-module `strict` is unverified, so do not rely on it.
- A `docs/tests` helper that moves into `scripts/` must then pass strict mypy.
- Every function has full type annotations in strict paths. Use `typing` precisely; avoid
  `Any` (use a `TypedDict`, a dataclass or a `Protocol`).
- Use `pathlib` for paths. Use timezone-aware datetimes; never a naive `datetime.now()`.
- `subprocess` takes an argument list, never `shell=True`, and checks the exit code.
- Engine I/O sits behind interfaces (market data provider, LLM client, Drupal publisher), so
  tests use fakes. Tests never call the live network (pytest-socket, T13).
- Tests: pytest for the engine, `unittest` for `scripts/` and `.claude/hooks/`.

### TypeScript and Next.js

Scope: `apps/web` (`meridian-web`, from T21).

- **Type check:** `tsc --noEmit` with `"strict": true`. `apps/web/tsconfig.json` extends the
  root `tsconfig.base.json`; it may add flags but not turn strict ones off.
- **Lint:** ESLint flat config `apps/web/eslint.config.mjs` with the Next.js rules and
  `typescript-eslint`.
- **Format:** Prettier, configured in the root `.prettierrc.json`. Do not hand-format.
- No `any`; use `unknown` and narrow it. A non-null assertion (`!`) or a cast needs a comment
  that says why it is safe.
- Data from Drupal is validated at the client boundary (`lib/`) before use.
- Tokens and secrets stay on the server: server-only modules for the Drupal client, no secret
  in a `NEXT_PUBLIC_` variable, no token in the browser (D6 of the technical design).
- LLM text is rendered as escaped text. `dangerouslySetInnerHTML` must not be used.
- Every page and data route requires authentication (FR-19).
- Styling uses the design tokens only (asset rules above).
- Tests: Vitest next to the source (`*.test.ts`, `*.test.tsx`), Playwright in `apps/web/e2e`.

### SQL and migrations

Scope: Postgres 16 schema of the engine (`services/engine`, Alembic, from T14).

- Migrations use Alembic. Revision names are `NNNN_slug` (for example
  `0002_add_runs_benchmark`), one logical change per revision.
- DDL is written explicitly. Autogenerate output is reviewed and edited, never committed as is.
- Every revision is reversible: it has a working `downgrade()`, and T14 tests upgrade,
  downgrade and upgrade again. Deployed dev is still forward-only (restore, not downgrade).
- Destructive changes (drop or rename) take two revisions: add and backfill, then drop later.
- Queries are parameterised: SQLAlchemy bound parameters or Core expressions. Never build SQL
  with f-strings, `%` or concatenation from values.
- Names, keys and constraints follow `docs/specs/data-model.md`; a schema change updates that
  spec in the same task.
- Every query used on a read path has a supporting index listed in the technical design.

### Docker and YAML

- **Dockerfiles** pass hadolint. Base images are pinned to an exact version tag (for example
  `python:3.12.x-slim`), with a digest where T06 confirms it. No `latest`.
- Containers run as a non-root user. No secret in `ARG`, `ENV` or any layer; pass secrets at
  run time. Each build context has a `.dockerignore`.
- Combine package install and cleanup in one layer; pin system packages where hadolint asks.
- **YAML** passes yamllint with the root `.yamllint.yaml`: two-space indent, no tabs, no
  duplicate keys, documents start without `---` unless the format needs it.
- GitHub Actions (T08): third-party actions pinned by commit SHA with the version in a comment,
  `permissions:` set to least privilege per job, secrets only through `${{ secrets.NAME }}` and
  never echoed.
- DDEV compose files use the section 0 service names.

### Shell scripts

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`. Scripts in the repo are
  executable.
- shellcheck passes with the root `.shellcheckrc`. A disable directive cites a ticket.
- Quote every expansion (`"$var"`). Use `[[ ]]` for tests and `$( )` for substitution.
- Resolve paths from the repo root (`git rev-parse --show-toplevel`), so the script runs from
  any directory.
- Temporary files use `mktemp` and are removed by a `trap ... EXIT`.
- Do not hide a failure with `|| true` unless a comment explains why the failure is expected.
- Print errors to stderr and exit non-zero. Print a short usage line for `-h` or bad input.

### Markdown docs

- markdownlint-cli2 checks every Markdown file with the root `.markdownlint-cli2.yaml`.
- Line length (MD013) is **100** characters. Tables, code blocks and headings are exempt.
- `docs/TASKS.md` is the owner's document and is not reflowed. Its exclusion is in the config
  and cites T32 (documentation finalisation) on the same line. Captured evidence
  (`docs/tests/*/evidence/**`) is excluded with a line that cites T04a.
- Plain English, short sentences, one idea per paragraph. Prefer lists and tables to long
  prose.
- Use relative links inside the repo and named links for external sources, with the date the
  source was checked.
- Fenced code blocks name their language (`bash`, `yaml`, `text`). Diagrams are Mermaid in
  fenced blocks.
- New documents start from a template in `docs/templates/` where one exists.

### OpenAPI

- The ingest and read contract is `docs/architecture/openapi.yaml` (OpenAPI 3.1.0). It is the
  single source; code follows it, not the reverse.
- Spectral lints it with the built-in `spectral:oas` ruleset through `.spectral.yaml`, with
  `--fail-severity=warn`. No rule is switched off without a ticket on the same line.
- Every operation has an `operationId` in `camelCase`, a summary, a security requirement and
  every response code it can return. Ingest errors use the `Error` schema.
- Field names, enums and patterns equal `docs/specs/data-model.md`. Each schema has an example.
- A contract change updates `openapi.yaml` in the same task, and the contract tests (T10, T11)
  are updated with it.

### LLM prompt files

Scope: the analyst-review prompt of the engine (T17) and any later prompt.

- A prompt lives in its own versioned file in the engine package, never inline in code. The
  file carries a semantic version label (`MAJOR.MINOR.PATCH`, the data-model regex).
- Any change to the prompt text bumps the version. The version is stored with every decision
  as `prompt_version` (FR-12). The model name comes from configuration, not the prompt.
- Untrusted text (headlines, LLM output, any fetched text) is data, never instructions. It is
  fenced with clear delimiters and labelled as untrusted, and the prompt tells the model to
  ignore instructions inside it (FR-07, RK-02). Prompt-injection tests cover each untrusted
  input field.
- The reply must match a JSON schema. Anything else is a veto with the reason stored. The LLM
  can only turn a BUY into a veto; it never creates a BUY.
- No secret, API key, token or personal data goes into a prompt file or a rendered prompt.
- Prompt changes are reviewed by the solution-architect (T17 owner chain).

## Tools per language

Versions below are the proposed pins. Each is marked **verify**: it has not been confirmed by
an install in this sandbox (no network). The owner-run install in T04a (TC-T04a-36 onward)
records the real version. **The config files are authoritative** (`.pre-commit-config.yaml`,
`scripts/tool-versions.env`, and later the component manifests and lockfiles). If this table and
a config differ, the config wins and this table is corrected in the same task.

| Tool | Language or area | Version | Source | Date checked | Runs in |
|---|---|---|---|---|---|
| ruff (lint and format) | Python | 0.14.x, verify | [docs.astral.sh/ruff](https://docs.astral.sh/ruff/) | 2026-11-01 (recorded; verify) | pre-commit, engine suite |
| mypy | Python | 1.18.x, verify | [mypy-lang.org](https://mypy-lang.org/) | 2026-11-01 (recorded; verify) | pre-commit, engine suite |
| PHP_CodeSniffer (phpcs) with drupal/coder | PHP | phpcs 3.13.x, coder 8.3.x, verify | [PHPCSStandards/PHP_CodeSniffer](https://github.com/PHPCSStandards/PHP_CodeSniffer), [drupal/coder](https://www.drupal.org/project/coder) | 2026-11-01 (recorded; verify) | Drupal suite (T05, T09) |
| PHPStan with phpstan-drupal | PHP | phpstan 2.1.x, phpstan-drupal 2.0.x, verify | [phpstan.org](https://phpstan.org/), [mglaman/phpstan-drupal](https://github.com/mglaman/phpstan-drupal) | 2026-11-01 (recorded; verify) | Drupal suite (T05, T09) |
| ESLint with typescript-eslint | TypeScript | ESLint 9.x, typescript-eslint 8.x, verify | [eslint.org](https://eslint.org/), [typescript-eslint.io](https://typescript-eslint.io/) | 2026-11-01 (recorded; verify) | web suite (T21) |
| Prettier | TypeScript, CSS, JSON | 3.6.x, verify | [prettier.io](https://prettier.io/) | 2026-11-01 (recorded; verify) | web suite (T21) |
| TypeScript compiler (`tsc --noEmit`) | TypeScript | 5.9.x, verify | [typescriptlang.org](https://www.typescriptlang.org/) | 2026-11-01 (recorded; verify) | web suite (T21) |
| hadolint | Dockerfile | 2.14.0, verify | [hadolint/hadolint](https://github.com/hadolint/hadolint) | 2026-11-01 (recorded; verify) | pre-commit |
| yamllint | YAML | 1.37.x, verify | [yamllint docs](https://yamllint.readthedocs.io/) | 2026-11-01 (recorded; verify) | pre-commit |
| shellcheck (shellcheck-py) | Shell | 0.11.0, verify | [koalaman/shellcheck](https://github.com/koalaman/shellcheck) | 2026-11-01 (recorded; verify) | pre-commit |
| markdownlint-cli2 | Markdown | 0.19.x, verify | [DavidAnson/markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) | 2026-11-01 (recorded; verify) | pre-commit |
| Spectral (`@stoplight/spectral-cli`) | OpenAPI | 6.15.x, verify | [stoplightio/spectral](https://github.com/stoplightio/spectral) | 2026-11-01 (recorded; verify) | pre-commit (local node hook) |
| gitleaks | Secrets | 8.30.1 (pinned since T00) | [gitleaks/gitleaks](https://github.com/gitleaks/gitleaks) | 2026-11-01 | pre-commit, CI history scan (T08) |
| pre-commit | All | 4.7.0 (pinned since T00) | [pre-commit.com](https://pre-commit.com/) | 2026-11-01 | `scripts/bootstrap-dev.sh` |
| web-vitals | Performance tests (NFR-03) | 5.1.0, Apache-2.0 licence, verify | [GoogleChrome/web-vitals](https://github.com/GoogleChrome/web-vitals) | 2026-11-01 (recorded; verify) | Playwright (T26); closes OQ-T04-5 pending install |

Runtimes: Python 3.12 for the engine, Python 3.10 (stdlib) for repo tooling, Node 22 LTS for
Spectral and the web app, PHP as set by `pantheon.yml` in T05.

The `web-vitals` licence (Apache-2.0) and pin are recorded here to close OQ-T04-5. The licence
is compatible with the dependency policy. The offline install is confirmed in T26.

## Coverage thresholds

Line coverage floors per component and path prefix (D-1). `scripts/coverage_gate.py` reads
Cobertura XML and the floors in `quality/coverage-thresholds.json`, and fails naming the file
and prefix that is below its floor.

| Component | Path | Line floor | Branch |
|---|---|---|---|
| Engine `scoring` | `meridian_engine/scoring/` | 90% (NFR-18, fixed) | Measured and reported, not gated |
| Engine `risk` | `meridian_engine/risk/` | 90% (NFR-18, fixed) | Measured and reported, not gated |
| Engine overall | `meridian_engine/` | 85% | Measured and reported, not gated |
| Drupal custom modules | `web/modules/custom/meridian_*` | 70%, provisional until first measured in T09 | Not gated |
| Next.js `lib/` and components | `apps/web/lib/`, `apps/web/components/` | 80% | Not gated |
| Next.js routes and pages | `apps/web/app/` | No unit floor; covered by Playwright (T24 to T26) | n/a |

Measuring rules:

- **The gate is the line rate** (Cobertura `line-rate`), not the combined line and branch
  figure that coverage.py prints when branch coverage is on.
- Branch coverage is on in the engine and is reported, not gated. T16 may add a branch floor
  for `scoring` and `risk`; it is then recorded here.
- Drupal counts Unit and Kernel tests only. Functional test code probably does not show in
  PHPUnit coverage (unverified, T09 measures). If 70% cannot be reached, T09 asks for a
  decision instead of adding excludes.
- `app/` routes and async Server Components have no unit floor (Vitest does not support async
  Server Components); Playwright covers them.
- `scripts/` and `.claude/hooks/` have no floor, but every script has tests.
- **Floors only go up.** Lowering a floor needs a solution-architect decision record. The only
  exception is the first-measurement adjustment for Drupal in T09.
- A component without a manifest is SKIP. Once the manifest exists the gate applies.

## Exception policy

An exception is any suppression or exclusion of a check:

- inline suppressions: `noqa`, `type: ignore`, `pragma: no cover`, `eslint-disable`,
  `@ts-expect-error`, `phpcs:ignore`, PHPStan `phpstan-ignore` tags, `shellcheck disable`,
  `yamllint disable`, `markdownlint-disable`, `hadolint ignore`;
- path excludes in any tool config (ruff, mypy, markdownlint, yamllint, coverage).

Rules (D-4):

- Every exception cites a ticket **on the same line**, as the ticket ID, a colon, a space and a
  reason. Matching regex: `\b(T\d{2}a?|DEF-\d{3}): \S`.
- Allowed IDs: `Txx` or `Txxa`, a task heading in `docs/TASKS.md`, or `DEF-nnn`, a defect in
  `docs/tests/defects.md`. The ID must exist; `scripts/exceptions_report.py` checks it.
- The cited task is the one that will **remove or re-decide** the exception. For a permanent
  exclusion, cite the task that decided it.
- Suppress one rule by its code, never a whole file or every rule. A `noqa` without a rule
  code, a bare `eslint-disable` and a PHPStan ignore without an identifier are not allowed.
- The scanner also reads Markdown. A document that quotes a suppression comment, rather than
  naming the tool, must cite a ticket on that line too.
- `@ts-expect-error` is used instead of `@ts-ignore`, so a stale suppression fails.
- `scripts/exceptions_report.py` lists every exception and counts them per tool and per
  ticket (`--out FILE` writes the report). `scripts/quality.sh` runs it and fails on an
  exception without a valid ticket.
- Closing a task while an exception names that same task as its remover is a review finding.
- T32 and T33 review every remaining exception as part of "known limitations".

Examples:

```text
import yaml  # type: ignore[import-untyped]  T13: stubs added with the engine manifest
x = call()  # noqa: S603  T20: argument list is fixed, no user input
// @phpstan-ignore method.notFound (T09: core stub missing, remove after the T09 upgrade)
// eslint-disable-next-line no-console -- T29: replaced by the server logger
# shellcheck disable=SC2034  T05: read by the sourcing DDEV command
- docs/TASKS.md  # T32: owner document, not reflowed
```

## Commits, branches and merging

**Branch names.** `task/Txx-slug`, matched by
`^task/T\d{2}a?-[a-z0-9]+(-[a-z0-9]+)*$`, for example `task/T04a-coding-standards`. The task
ID must be a heading in `docs/TASKS.md`. `main` is allowed. `scripts/check_branch_name.py`
checks it in `scripts/quality.sh` and in CI (reads `GITHUB_HEAD_REF`, T08).

**Commit messages** (D-3), checked by `scripts/check_commit_msg.py`:

- The subject matches `^T\d{2}a?: \S`, for example `T10: add ingest upsert endpoint`. The
  task ID must be a heading in `docs/TASKS.md`.
- The whole subject line is at most **72** characters, including the prefix. Aim for 50.
- Allowed exceptions: subjects starting with `Merge ` and `Revert "` (generated by Git and
  GitHub).
- `fixup!` and `squash!` commits fail in `--range` mode. Squash them locally before pushing.
- The commit-msg hook checks each new commit locally. CI checks only the PR range
  (`origin/main..HEAD`); history already on `main` is never re-checked.
- Write the subject in the imperative mood. Use the body for the why, wrapped at 72.
- Never use `--no-verify`.

**Merging into `main`:** **merge commit** only (no fast-forward). Squash and rebase merges are
disabled in the repository settings (T08), and "require linear history" stays off. This keeps
every per-task commit and its SHA reachable, so git-order checks and SHA evidence stay valid.
Use `git log --first-parent main` for a per-task view. Do not force-push a task branch after
evidence cites its SHAs; if you must, re-point the evidence.

## Running the quality checks

One script is the only implementation: `scripts/quality.sh`. Pre-commit, `ddev quality` and CI
(T08) all call it.

```bash
scripts/bootstrap-dev.sh   # once per clone: pinned pre-commit and the git hooks
scripts/quality.sh         # every check; exit code 0 only if nothing failed
```

- The script prints `PASS`, `FAIL` or `SKIP` per step and a summary, and exits non-zero on any
  `FAIL`.
- Steps: pre-commit on all files; branch name and commit range against `origin/main`;
  exceptions report and asset check; component suites (lint, types, unit tests, coverage gate).
- A component suite is `SKIP` only when its manifest is absent
  (`services/engine/pyproject.toml`, `apps/drupal/composer.json`, `apps/web/package.json`). A
  missing tool when the manifest exists is a `FAIL`.
- `QUALITY_RUNNER=native|ddev` chooses where component suites run. From T05 and T06, `ddev`
  maps them to `ddev exec`, `ddev engine` and `ddev next`.
- `QUALITY_STEPS` limits the run to named steps. It is a test hook; do not use it to skip a
  failing step before a push.
- `ddev quality` is a thin wrapper (`.ddev/commands/host/quality`) that runs
  `scripts/quality.sh` with the same arguments. It works once T05 adds `.ddev/config.yaml`.
- Fix the cause of a `FAIL`. If a rule truly cannot be met, follow the exception policy.

## Changing these standards

- Changes go through a task plan and a technical-architect review, like code.
- A change to a coverage floor, the commit rules or the exception format needs a
  solution-architect decision record.
- Keep [REVIEW_CHECKLIST.md](REVIEW_CHECKLIST.md) in step: every rule here maps to a checklist
  item or to a tool.
