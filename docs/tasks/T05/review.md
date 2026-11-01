# T05: DDEV Drupal project, Review

| Field | Value |
|---|---|
| Task | T05 |
| Reviewer | technical-architect |
| Date | 2026-11-01 |
| Commit range | `8078a3b..05272b4` (ed24b15, fb2f3c2, 21322da, 4f68c69, 05272b4) plus the staged, uncommitted work (`git diff --cached`, 13 files) |
| Plan | `docs/tasks/T05/plan.md` |

## Scope of this review

- Committed: `.ddev/config.yaml`, `.ddev/commands/web/drupal-install`, `.gitignore`,
  `apps/drupal/composer.json`, `composer.lock` (sampled), `pantheon.yml`, `settings.php`,
  `config/sync/` (69 files), `web/modules/custom/.gitkeep`.
- Staged: `.ddev/.gitignore`, `.ddev/README.md`, `.ddev/commands/host/quality`, `CLAUDE.md`,
  `README.md`, `apps/drupal/README.md`, `composer.json` (allow-plugins), `phpstan.neon.dist`,
  `settings.php` (phpcs directive removed), `docs/runbooks/README.md`,
  `docs/runbooks/local-setup.md`, `CODING_STANDARDS.md`, `scripts/quality.sh`.

### Read-only re-verification by the reviewer (2026-11-01)

| Check | Result |
|---|---|
| `ddev describe -j` | status `running`, PHP `8.3`, `mariadb` `10.6`, `https://meridian.ddev.site` |
| `ddev drush status` | Drupal 11.4.11, Drush 13.8.0.0, bootstrap Successful, database Connected, config `../config/sync` |
| `ddev drush config:status` | "No differences between DB and sync directory." |
| `composer validate --no-check-publish` (in DDEV) | valid, exit 0 |
| `vendor/bin/phpcs --standard=phpcs.xml.dist` on the empty custom tree | exit 0 |
| `vendor/bin/phpstan analyse -c phpstan.neon.dist` on the empty custom tree | prints `[ERROR] No files found to analyse.` but **exits 0** (PHPStan 2.3.4, with and without `--no-progress`). See finding 4 |
| `phpcs --standard=Drupal,DrupalPractice` on `settings.php` | 0 errors, 5 warnings (line length, unused `$databases`); file is outside the phpcs scope |
| `php -l settings.php` | no syntax errors |
| `composer.lock` | 469,953 bytes (under the 1024 KB hook limit). 88 packages, 86 dev. `platform-overrides.php` `8.3.0`. Sampled names: drupal/core 11.4.11, drush 13.8.0, drupal-integrations 11.2.0, symfony 7.4.x. No broker or trading package |
| Simulation-only denylist grep over the new config, command, settings, runbook and README | no hit |
| `git status --porcelain --ignored .ddev` | only DDEV-generated files ignored; `.ddev/README.md`, `providers/pantheon.yaml`, future `docker-compose.*.yaml` and `web-build/Dockerfile.*` are **not** ignored |
| Nested scaffold `.gitignore` files (`apps/drupal`, `web`, `web/sites`, `web/sites/default`, `web/modules`) | none hides an owned path (`settings.php`, `web/modules/custom/**`, `config/sync/**`, `pantheon.yml`, `composer.lock`) |
| Hook install time vs commit time | `.git/hooks/pre-commit` written 22:03:11; all five T05 commits are 22:01:57 to 22:02:05. See finding 2 |

Not re-run (they write state): `ddev drupal-install`, `ddev drush uli`, `ddev drush cex`,
`ddev quality`, `pre-commit run`.

## Findings

Severity: **Blocker** (must fix before merge), **Major** (must fix in this task),
**Minor** (fix or ticket), **Note** (no action needed; "Nit" in the caller's scale).

| # | Severity | File | Issue | Resolution | Status |
|---|---|---|---|---|---|
| 1 | Major | `apps/drupal/config/sync/*.yml`, `config/sync/.htaccess`; `.pre-commit-config.yaml`, `.yamllint.yaml` | The committed Drupal export fails the repo's own pre-commit hooks, so C4 (`.tools/pre-commit run --all-files`, and therefore `ddev quality`) cannot pass. (a) yamllint `braces`: Drupal writes empty maps as `{  }`; 37 files contain it (for example `block.block.stark_admin.yml`, `system.mail.yml:11`). (b) yamllint `line-length` (100): `user.mail.yml` lines 11, 31, 39, 43, 56, 60, 73, 93; `system.performance.yml:13`; `system.maintenance.yml:4`. (c) `end-of-file-fixer`: `user.mail.yml` and `.htaccess` have no final newline. The fixer would rewrite them, and the next `drush cex` that writes the directory would revert them, so the hook and AC4 ("cex gives no diff") fight each other. | Do **not** hand-edit exported files. Treat `config/sync` as generated (CODING_STANDARDS "config exports" exclusion): add `exclude: ^apps/drupal/config/sync/` to the `trailing-whitespace` and `end-of-file-fixer` hooks in `.pre-commit-config.yaml`, each with a `# T05: Drupal config export format is owned by drush cex` comment. In `.yamllint.yaml` add per-rule `ignore:` entries (not a top-level whole-file ignore) for `braces` and `line-length`, plus any other rule yamllint reports on that path, each path line carrying a `# T05: ...` comment. Verify that yamllint honours the per-rule ignore for files that pre-commit passes explicitly. Then show `pre-commit run --all-files` green, `scripts/exceptions_report.py` counting the new entries, and `ddev drush cex -y` still leaving `git status` clean. | Open |
| 2 | Major | All five T05 commits; staged work | No pre-commit or commit-msg hook ran on any T05 change. The hooks were installed at 22:03:11, one minute after the last commit, and the staged work cannot be committed because the hook environment does not build on this host (Python 3.10 with no `typing_extensions` for virtualenv; see `~/.cache/pre-commit/pre-commit.log`). gitleaks, yamllint, shellcheck and markdownlint are therefore unproven for the whole change, and the DoD item "`ddev quality` exits 0, `component-drupal` PASS, `component-drupal-tests` SKIP" has no evidence. Finding 1 shows that at least one hook would fail. | Owner action: make the hook environment build (for example install `python3-venv` and `python3-typing-extensions`, or run `scripts/bootstrap-dev.sh` with a Python that has them). Then, after finding 1 is fixed: run `.tools/pre-commit run --all-files` and `ddev quality`, save both outputs as T05 evidence, and commit the staged work **through** the hook. Never use `--no-verify`. The five existing commits do not need rewriting if the `--all-files` run covers their content. | Open (owner action) |
| 3 | Major | `docs/runbooks/local-setup.md` line 6; plan step 9 | Plan step 9 (developer clean-clone rehearsal, runbook verbatim, time recorded) has no evidence. The runbook header says "clean-clone rehearsal in the T05 evidence", but `docs/tests/T05/evidence/` holds only `design-time-run.txt`. A runbook must not claim verification that did not happen (AC6, C7). | Run the step 9 rehearsal (`ddev stop --unlist meridian`, fresh clone into the scratch directory, follow the runbook word for word, record each command, its output, the total time and `git status --porcelain` after `ddev start`, `ddev drupal-install` and `ddev drush cex -y`), save it under `docs/tests/T05/evidence/`, and make the "Last verified" field point to that file. If it cannot run, change "Last verified" to state exactly what was verified (working tree only) and leave AC6 to the tester or owner. | Open |
| 4 | Minor | `scripts/quality.sh` lines 61 to 63 (staged) | The guard comment says "PHPStan exits 1 with 'No files found to analyse'". On this stack (PHPStan 2.3.4, the committed `phpstan.neon.dist`) the reviewer measured exit **0** with that message. The exit 1 the developer saw was probably the earlier "included multiple times" error, before the `includes:` were removed. KD-6 item 2 says to run a tool unconditionally when it exits 0. | Either remove the guard and run PHPStan unconditionally (KD-6 as written), or keep it with a true reason, for example "PHPStan prints a misleading `[ERROR] No files found` and passes vacuously; the guard makes the not-run state explicit". Keep the T09 removal note. Update the matching expectation in `apps/drupal/README.md` or the evidence if either repeats the exit-1 claim. | Open |
| 5 | Minor | `apps/drupal/web/sites/default/settings.php` (mode `100755`) | `settings.php` is committed as executable. It has no shebang and is never executed directly. | Commit it as `100644` (`chmod 644`, or `git update-index --chmod=-x`). | Open |
| 6 | Minor | `scripts/quality.sh` line 53 | Stale comment: "Verify the exact tool commands when T05 (Drupal), T13 (engine) and T21 (web) add the manifests." T05 has now verified the Drupal commands. | Drop "T05 (Drupal)" from the comment. | Open |
| 7 | Minor | `apps/drupal/README.md` "Versions and sources"; plan DoD | The developer reports `ddev composer audit` as clean, but the DoD item "`ddev composer audit` output recorded" has no recorded output or date in the repo. | Add a row (command, result "No security vulnerability advisories found", date) to the versions table, or save the output as a T05 evidence file and link it. | Open |
| 8 | Minor | `docs/tests/T05/run-checks.sh` line 300 (TC-T05-07), owner: tester | Tester defect reported by the developer, and confirmed. After the two levels of shell quoting, the inner `grep -E` pattern begins with an unescaped `$settings`. In ERE, `$` is an end-of-line anchor, so the check can never match and false-FAILs a correct `settings.php` (line 45). | The tester fixes it, for example by using `[$]settings\[` in the pattern or by moving the regex into a single-quoted helper. The reviewer does not edit tester files. | Open (tester) |
| 9 | Minor | `docs/tests/T05/run-checks.sh` line 353 (TC-T05-10), owner: tester | Tester defect reported by the developer, and confirmed. `password:\s*\S` matches `system.mail.yml:9` (`password: null`) and `user.mail.yml:48,65,98` (`password: Your password`, which is email body text). Core exports false-FAIL the C6 check. | The tester narrows the check, for example by parsing YAML and requiring `system.mail.yml` `mailer_dsn.password` to be null, keeping the `hash_salt` and private key greps, and not grepping email bodies for the word "password". | Open (tester) |
| 10 | Note | `.ddev/config.yaml` line 19 | Deviation 1, `fail_on_hook_fail: true`. Accepted. It closes the plan's KD-3 verify item: the developer observed that the default does not fail `ddev start`. It is documented in `.ddev/README.md` and the runbook. | None. | Accepted |
| 11 | Note | `apps/drupal/composer.json` allow-plugins | Deviation 2. Accepted. Every plugin is decided explicitly, with no `"*"`. `symfony/runtime: true` is justified by an observed fatal (`index.php` needs `autoload_runtime.php`), and the scaffolded `web/autoload_runtime.php` is git-ignored. `php-http/discovery` and `tbachert/spi` are off. The reasons are in `apps/drupal/README.md` "Composer plugins". | None. T07 confirms that Integrated Composer runs the runtime plugin on Pantheon. | Accepted |
| 12 | Note | `apps/drupal/phpstan.neon.dist` | Deviation 3. Accepted. This matches KD-6 item 3. The comment names `extension-installer` and `phpstan-drupal`, so the T04a invariant still holds. Level 6 and the no-baseline rule are unchanged. | None. | Accepted |
| 13 | Note | `scripts/quality.sh` | Deviation 4. phpcs runs unconditionally, and the reviewer confirmed exit 0 on the empty tree. The step split (`component-drupal`, and `component-drupal-tests` with manifest `phpunit.xml.dist`) and the always-run `--version` calls match KD-6. For the PHPStan guard, see finding 4. | None. | Accepted |
| 14 | Note | `.ddev/.gitignore` (staged) | Deviation 5. Accepted. DDEV's generated file would have ignored `README.*` (which hides `.ddev/README.md`) and `providers/pantheon.yaml` (which T07 needs). The reviewer checked that the owned file ignores only generated paths. Residual risk: a newer DDEV may write new files, and `git status` is then dirty. The file header says to add them. | T06 re-checks `git status --ignored .ddev` after it adds services. | Accepted |
| 15 | Note | `apps/drupal/web/sites/default/settings.php` | Deviation 6. Accepted, and it is an improvement. `// phpcs:ignoreFile` was a whole-file suppression with no ticket, which the exception policy forbids. The file is outside the `phpcs.xml.dist` scope anyway. | None. | Accepted |
| 16 | Note | `apps/drupal/README.md` versions table | Deviation 7. Accepted under plan step 1: PHP 8.3 on Pantheon is marked owner-to-verify for T07, with its source and date. MariaDB 10.6 is sourced from the Pantheon docs and observed in DDEV. | T07 confirms it on a real site. | Accepted |
| 17 | Note | `CLAUDE.md` Commands table | Deviation 8. Accepted. The edit is in the plan's Scope and was approved with the plan. The new rows match the runbook commands. | None. | Accepted |
| 18 | Note | `.ddev/commands/web/drupal-install` | Correct against KD-5. It uses `set -euo pipefail`, rejects unknown arguments with exit 2, and refuses on a bootstrapped site without `--force` (exit 1). The `\|\| true` on the bootstrap probe is explained by the comment above it. It uses `--existing-config`, fails on any `config:status` difference, and prints the next step. | None. | Accepted |

## Checklist summary (`docs/standards/REVIEW_CHECKLIST.md`)

- Simulation-only: yes. No broker package in `composer.lock` (sampled and grepped), and no
  broker host in config, commands or docs. The new outbound hosts are packages.drupal.org,
  Packagist and docs links only.
- Secrets: yes. `settings.php` has no salt, credentials or keys. `settings.ddev.php`,
  `settings.pantheon.php`, `settings.local.php` and `private/` are ignored. `.env.example` is
  unchanged, which is correct per KD-8. gitleaks has not run on the change (finding 2).
- Naming: yes. The project is `meridian`, the URL is `https://meridian.ddev.site` and the
  modules are planned as `meridian_ingest` and `meridian_core`. `check-names.sh` has not run
  through the hook (finding 2).
- Plan adherence: yes, except plan step 9 (finding 3) and the evidence items of the DoD
  (findings 2 and 7). No scope creep: no contrib module, `phpunit.xml.dist`, provider file or
  extra service.
- Exceptions: no new suppression. One whole-file suppression was removed (finding 15). Finding
  1 adds ticketed config excludes.
- Shell: `drupal-install` and the `quality` wrapper look shellcheck-clean by reading.
  shellcheck has not run (finding 2).
- Markdown: two staged lines exceed 100 characters (`docs/runbooks/README.md:3`,
  `local-setup.md:17`). In both, the overflow is a single trailing word or link with no space
  after column 100, so MD013 in its default non-strict mode accepts them.
- Commits: the branch name is correct. Every subject starts with `T05:` plus a space and has
  at most 72 characters. The test design (8078a3b) was committed before the implementation.

## Common criteria check

| Criterion | Met? | Notes |
|---|---|---|
| C1 Plan before code | Yes | Plan approved 2026-11-01. The test design was committed at 8078a3b, before the first implementation commit ed24b15 |
| C2 Review findings resolved | No | Findings 1 to 3 (Major) and 4 to 9 (Minor) are open |
| C3 Criteria mapped to executed tests | Pending | Belongs to `/test-task`. The tester first fixes TC-T05-07 and TC-T05-10 (findings 8 and 9), which would otherwise false-FAIL |
| C4 CI green | No | Pre-commit never ran on the change, and the config export fails yamllint and end-of-file-fixer (findings 1 and 2). No `ddev quality` evidence |
| C5 Docs updated | Partly | Runbook, READMEs, `CLAUDE.md` and the standards tool table are updated. The runbook's verification claim is unbacked (finding 3). The TRACEABILITY R-11 and FR-26 rows are due at `/close-task` |
| C6 No secrets | Yes (pending gitleaks) | No secret found by reading or grepping, and `.env.example` correctly has no new variable. The gitleaks run is part of finding 2 |
| C7 Clean-checkout works | Not shown | The working tree is clean apart from staged files, and live AC1 to AC5 checks pass on the existing project. No clean-clone evidence yet (finding 3) |

## Decisions needed

None for the solution-architect. Owner actions: make the pre-commit environment build on the
host (finding 2), and confirm PHP 8.3 on a real Pantheon site in T07 (finding 16).

## Approval

Changes requested. Re-review after findings 1 to 3 are fixed and evidenced, and after
findings 4 to 7 are fixed or ticketed. Findings 8 and 9 go to the tester before `/test-task`.
technical-architect, 2026-11-01.
