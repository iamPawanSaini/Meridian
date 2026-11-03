#!/usr/bin/env bash
# Automated structural checks for T00 (TC-T00-01, 02, 03, 06, 07, 08).
# Usage: docs/tests/T00/run-checks.sh [--regression]   (exits non-zero if any check fails)
#   --regression  invariant checks only (ckp); snapshot checks (cka) are excluded and counted (decision D-5).
#   T00 has no snapshot check: every check is invariant, so the excluded count is 0. (T08 retrofit)
# shellcheck disable=SC2329 # T08: ckp and cka are the D-5 tag helpers; T00 has no snapshot check yet
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

MODE=static
case "${1:-}" in
  "") ;;
  --regression) MODE=reg ;;
  *) echo "usage: $0 [--regression]" >&2; exit 2 ;;
esac

fail=0; excluded=0
pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
# ckp = invariant check (runs in every mode); cka = snapshot check (skipped, counted, by --regression)
ckp() { check "$@"; }
cka() { if [ "$MODE" = reg ]; then excluded=$((excluded+1)); else check "$@"; fi; }
check() { if eval "$2" >/dev/null 2>&1; then pass "$1"; else bad "$1"; fi; }

echo "== TC-T00-01 folder structure and READMEs"
for d in .claude/agents .claude/commands .ddev apps/drupal apps/web services/engine \
         docs/architecture docs/adr docs/specs docs/tasks docs/tests docs/runbooks \
         docs/process .github/workflows; do
  check "dir $d" "[ -d '$d' ]"
done
for f in .claude .ddev apps services docs .github scripts \
         docs/architecture docs/adr docs/specs docs/tasks docs/tests docs/runbooks \
         docs/process docs/templates docs/design docs/standards; do
  check "README in $f" "[ -s '$f/README.md' ]"
done
for f in CLAUDE.md README.md .env.example .gitignore docs/PROGRESS.md docs/TRACEABILITY.md; do
  check "file $f" "[ -s '$f' ]"
done

echo "== TC-T00-02 templates with Appendix B fields"
t=docs/templates
fields() { local file=$1; shift; for k in "$@"; do check "$file has '$k'" "grep -qi -- '$k' '$t/$file'"; done; }
fields test-cases.md  "TC-Txx-" "Linked criterion" "Preconditions" "Steps" "Expected result" \
                      "Actual result" "Evidence" "Status" "Date" "Executed by"
fields test-report.md "Task" "Build or commit" "Environment" "Summary" "Defects raised" \
                      "Coverage notes" "Sign-off"
fields defect.md      "ID" "Severity" "Found in" "Steps to reproduce" "Expected" "Actual" \
                      "Status" "Fix commit" "Retest result"
fields adr.md         "Status" "Context" "Decision" "Alternatives considered" "Consequences" "Date"
fields plan.md        "Goal" "Scope" "Non-goals" "Steps" "Interfaces touched" "Risks" \
                      "Test hooks needed" "Definition of done"
fields review.md      "Commit range" "Findings" "Severity" "File" "Resolution" "Approval"
fields runbook.md     "When to use" "Prerequisites" "Steps" "Verification" "Rollback"

echo "== TC-T00-03 progress board and traceability"
expected="$(grep -oE '^## T[0-9]+a?:' docs/TASKS.md | tr -d '#: ' | sort)"
# shellcheck disable=SC2034 # T04a: actual is read by the eval'd check string below
actual="$(grep -oE '^\| T[0-9]+a? \|' docs/PROGRESS.md | tr -d '| ' | sort)"
check "PROGRESS task IDs match TASKS.md ($(echo "$expected" | wc -l) tasks)" "[ \"\$expected\" = \"\$actual\" ]"
check "PROGRESS includes T00 and T33" "grep -q '^| T00 |' docs/PROGRESS.md && grep -q '^| T33 |' docs/PROGRESS.md"
for i in $(seq -w 1 12); do
  check "TRACEABILITY has R-$i" "grep -q '^| R-$i |' docs/TRACEABILITY.md"
done

echo "== TC-T00-06 ignore rules"
for p in .env x.sql x.sql.gz x.dump x.db node_modules/x vendor/x records/x \
         apps/web/node_modules/x apps/drupal/vendor/x; do
  check "ignored: $p" "git check-ignore -q --no-index '$p'"
done
check "not ignored: .env.example" "! git check-ignore -q --no-index .env.example"

echo "== TC-T00-07 naming"
check "check-names.sh passes on tree" "scripts/check-names.sh"
tmp="zz-t00-negative-$$.txt"
printf '%s\n' "trading""_ingest" > "$tmp"
check "check-names.sh rejects a stale name" "! scripts/check-names.sh"
rm -f "$tmp"

echo "== TC-T00-08 CLAUDE.md content"
for h in "## Goal" "simulation only" "## Repository layout" "## Commands" \
         "## Per-task loop" "## Where documents live"; do
  check "CLAUDE.md has '$h'" "grep -qi -- '$h' CLAUDE.md"
done

echo
if [ "$MODE" = reg ]; then echo "regression mode: $excluded snapshot (cka) checks excluded (decision D-5)"; fi
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "$fail"
