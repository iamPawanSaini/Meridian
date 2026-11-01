# docs/standards

Coding standards and the review checklist (T04a, covers R-12).

| File | Purpose | Used by |
|---|---|---|
| [CODING_STANDARDS.md](CODING_STANDARDS.md) | Rules per language and cross-cutting rules, tool pins, coverage floors, exception policy, commit and branch rules, how to run the checks | Everyone who writes code or docs |
| [REVIEW_CHECKLIST.md](REVIEW_CHECKLIST.md) | Yes/no checks derived from the standards, C1 to C7 and the simulation-only rule | `technical-architect` in `/review-task` |

Machine enforcement: `scripts/quality.sh` (and `ddev quality` from T05) runs every check. The
coverage floors live in `quality/coverage-thresholds.json`.

Decisions behind the standards: `docs/tasks/T04a/decision-t04a-standards.md`. Change the
standards only through a task plan; see "Changing these standards" in the standards.
