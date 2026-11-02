# TC-T04a-52: manual review, ten standards rules against enforcers

Executed 2026-11-01 by the tester (execute mode) at HEAD e56df69. Method: for each rule, find where
it is enforced (tool, script or config) in the repo, and whether `REVIEW_CHECKLIST.md` has a yes/no
question that can be answered from a diff.

| # | Rule | Enforcer found | Checklist question |
|---|---|---|---|
| 1 | PHPStan level 6, no baseline, ignores carry a reason | `apps/drupal/phpstan.neon.dist` line 10 `level: 6`, line 13 `reportIgnoresWithoutComments: true` | "Does PHPStan pass at level 6 with phpstan-drupal, with no baseline file and every ignore ..." |
| 2 | Python strict scope (`scripts/`, `.claude/hooks/`, `meridian_engine`) | `.pre-commit-config.yaml` mypy hook `--strict --python-version 3.10` | "Does mypy pass in strict mode for `scripts/`, `.claude/hooks/` and `meridian_engine`?" |
| 3 | ruff py310 target for scripts, hooks, docs/tests | `ruff.toml` lines 14 and 15 (`per-file-target-version`) | None found (observation O-1) |
| 4 | 72-character commit subject | `scripts/check_commit_msg.py` `MAX_SUBJECT = 72`; commit-msg hook | "Does every commit subject start with the task ID, stay within 72 characters ..." |
| 5 | Merge commits only for `main` | Repository setting, configured in T08 (standards line 520) | None found (observation O-2) |
| 6 | Exception ticket format | `scripts/exceptions_report.py`; TC-17, 18, 29 | "Does every new suppression or config exclude cite a ticket on the same line ..." |
| 7 | Coverage floors | `quality/coverage-thresholds.json` and `scripts/coverage_gate.py`; TC-19, 20 | "Are coverage floors met, and is no floor lowered without a decision record?" |
| 8 | Function 50 lines, file 400 lines | Review only (no tool; stated in the standards) | "Is each new function at most 50 lines and each file at most 400 lines ..." |
| 9 | LLM prompt: untrusted data delimited | Review plus the planned injection tests (T17) | "Is untrusted text fenced and labelled as data, with an injection test ..." |
| 10 | Dependency audit before adding | Review plus audits in T08/T30 | "Is every new dependency named in the plan and audited ..." |

Result: every rule has at least one enforcer, and eight of ten also have a checklist question. Two
rules (3 and 5) have an enforcer but no checklist question. The criterion's failure condition is a
rule with neither; none found, so the case passes.

Observations (not defects; advisory to the technical-architect):

- O-1: no checklist question for the py310 target. The config enforces it, so a reviewer rarely
  needs one, but a question "does new code in `scripts/` use only Python 3.10 syntax?" would help.
- O-2: no checklist question confirming the merge-commit-only setting. It is a repository setting
  made in T08; the T08 review should confirm it (review.md condition on fetch-depth 0 is related).
