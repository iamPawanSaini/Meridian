#!/usr/bin/env bash
# Run every quality check once. This is the only implementation: `ddev quality`, the
# pre-commit hooks and CI (T08) all call it. Prints PASS, FAIL or SKIP per step and a summary,
# and exits non-zero when any step FAILs.
#
# Usage: scripts/quality.sh
# Environment:
#   QUALITY_RUNNER=native|ddev  where component tools run (default native). T05/T06 map `ddev`
#                               to `ddev exec`, `ddev engine` and `ddev next`.
#   QUALITY_STEPS=FILE          replaces the built-in steps. Each line is
#                               NAME<TAB>MANIFEST<TAB>COMMAND. MANIFEST '-' always runs; a
#                               MANIFEST path that does not exist gives SKIP; a present manifest
#                               with a failing or missing command gives FAIL.
# SKIP happens only when a component manifest is absent. A missing tool is a FAIL.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 2

runner="${QUALITY_RUNNER:-native}"
case "$runner" in
  native | ddev) ;;
  *)
    echo "error: unknown QUALITY_RUNNER '$runner' (use native or ddev)" >&2
    exit 2
    ;;
esac

# wrap RUNNER-COMMAND DIR COMMAND: native runs COMMAND in DIR, ddev runs it through the
# project command (for example `ddev engine`).
wrap() {
  local ddev_cmd="$1" dir="$2" cmd="$3"
  if [[ "$runner" == "ddev" ]]; then
    printf '%s bash -c %q' "$ddev_cmd" "$cmd"
  else
    printf 'cd %q && %s' "$dir" "$cmd"
  fi
}

precommit="pre-commit"
if [[ -x "$root/.tools/pre-commit" ]]; then
  precommit="$root/.tools/pre-commit"
fi

# Built-in steps as NAME<TAB>MANIFEST<TAB>COMMAND lines.
builtin_steps() {
  local engine drupal web commit_range
  commit_range="git rev-parse --verify -q origin/main >/dev/null"
  commit_range+=" || { echo 'origin/main not found: run git fetch origin'; exit 1; };"
  commit_range+=" python3 scripts/check_commit_msg.py --range origin/main..HEAD"
  # Verify the exact tool commands when T05 (Drupal), T13 (engine) and T21 (web) add the manifests.
  engine="ruff check . && ruff format --check . && mypy meridian_engine"
  engine+=" && pytest --cov=meridian_engine --cov-branch --cov-report=xml:coverage.xml"
  engine+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  engine+=" ../../quality/coverage-thresholds.json coverage.xml"
  drupal="vendor/bin/phpcs --standard=phpcs.xml.dist"
  drupal+=" && vendor/bin/phpstan analyse -c phpstan.neon.dist"
  drupal+=" && vendor/bin/phpunit --coverage-cobertura=coverage.xml"
  drupal+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  drupal+=" ../../quality/coverage-thresholds.json coverage.xml"
  web="npx eslint . && npx tsc --noEmit && npx prettier --check . && npx vitest run --coverage"
  web+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  web+=" ../../quality/coverage-thresholds.json coverage/cobertura-coverage.xml"

  printf '%s\t%s\t%s\n' "pre-commit" "-" "$precommit run --all-files"
  printf '%s\t%s\t%s\n' "branch-name" "-" "python3 scripts/check_branch_name.py"
  printf '%s\t%s\t%s\n' "commit-range" "-" "$commit_range"
  printf '%s\t%s\t%s\n' "exceptions" "-" \
    "mkdir -p .tools && python3 scripts/exceptions_report.py --out .tools/exceptions-report.txt"
  printf '%s\t%s\t%s\n' "assets" "-" "python3 scripts/check_assets.py"
  printf '%s\t%s\t%s\n' "component-engine" "services/engine/pyproject.toml" \
    "$(wrap 'ddev engine' services/engine "$engine")"
  printf '%s\t%s\t%s\n' "component-drupal" "apps/drupal/composer.json" \
    "$(wrap 'ddev exec -d /var/www/html/apps/drupal' apps/drupal "$drupal")"
  printf '%s\t%s\t%s\n' "component-web" "apps/web/package.json" \
    "$(wrap 'ddev next' apps/web "$web")"
}

if [[ -n "${QUALITY_STEPS:-}" ]]; then
  steps_file="$QUALITY_STEPS"
  if [[ ! -r "$steps_file" ]]; then
    echo "error: QUALITY_STEPS file '$steps_file' is not readable" >&2
    exit 2
  fi
else
  steps_file="$(mktemp)"
  trap 'rm -f "$steps_file"' EXIT
  builtin_steps >"$steps_file"
fi

pass=0
fail=0
skip=0
while IFS=$'\t' read -r name manifest cmd; do
  [[ -z "$name" ]] && continue
  if [[ "$manifest" != "-" && ! -e "$manifest" ]]; then
    echo "SKIP  $name (no $manifest)"
    skip=$((skip + 1))
    continue
  fi
  if output="$(bash -c "$cmd" 2>&1)"; then
    echo "PASS  $name"
    pass=$((pass + 1))
  else
    echo "FAIL  $name"
    printf '%s\n' "$output" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
done <"$steps_file"

echo "summary: PASS $pass FAIL $fail SKIP $skip"
[[ "$fail" -eq 0 ]]
