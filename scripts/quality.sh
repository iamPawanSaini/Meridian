#!/usr/bin/env bash
# Run every quality check once. This is the only implementation: `ddev quality` and CI (T08)
# call it, and it runs the pre-commit hooks as its first step. Prints PASS, FAIL or SKIP per
# step and a summary, and exits non-zero when any step FAILs.
#
# Usage: scripts/quality.sh
# Environment:
#   QUALITY_RUNNER=native|ddev  where component tools run (default native; `ddev quality` sets
#                               ddev). `ddev` maps to `ddev exec`, `ddev engine`, `ddev next`.
#   QUALITY_STEPS=FILE          replaces the built-in steps. Each line is
#                               NAME<TAB>MANIFEST<TAB>COMMAND. MANIFEST '-' always runs; a
#                               MANIFEST path that does not exist gives SKIP; a present manifest
#                               with a failing or missing command gives FAIL.
# SKIP happens only when a component manifest is absent. A missing tool is a FAIL.
# No -e on purpose: every step's exit status is captured and counted, and a failing step must
# not stop the later steps. The summary and the final exit code carry the result.
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
  local engine drupal drupal_tests web commit_range
  commit_range="git rev-parse --verify -q origin/main >/dev/null"
  commit_range+=" || { echo 'origin/main not found: run git fetch origin'; exit 1; };"
  commit_range+=" python3 scripts/check_commit_msg.py --range origin/main..HEAD"
  # Verify the exact tool commands when T13 (engine) and T21 (web) add the manifests.
  engine="ruff check . && ruff format --check . && mypy meridian_engine"
  engine+=" && pytest --cov=meridian_engine --cov-branch --cov-report=xml:coverage.xml"
  engine+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  engine+=" ../../quality/coverage-thresholds.json --require meridian_engine/ coverage.xml"
  drupal="composer validate --no-check-publish --no-interaction"
  drupal+=" && vendor/bin/phpcs --version && vendor/bin/phpstan --version"
  drupal+=" && vendor/bin/phpcs --standard=phpcs.xml.dist"
  # T05: on a tree with no PHP, PHPStan prints "[ERROR] No files found to analyse" yet exits 0,
  # a vacuous pass. The guard makes the not-run state explicit and runs PHPStan once custom PHP
  # exists. The version calls above always run, so a missing tool is still a FAIL. T09 adds the
  # first module and removes this guard.
  drupal+=" && if [ -n \"\$(find web/modules/custom \\( -name '*.php' -o -name '*.module'"
  drupal+=" -o -name '*.inc' -o -name '*.install' \\) -print -quit)\" ]; then"
  drupal+=" vendor/bin/phpstan analyse -c phpstan.neon.dist;"
  drupal+=" else echo 'phpstan: not run, no custom PHP yet (T09)'; fi"
  drupal_tests="vendor/bin/phpunit --coverage-cobertura=coverage.xml"
  drupal_tests+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  drupal_tests+=" ../../quality/coverage-thresholds.json --require web/modules/custom/meridian_"
  drupal_tests+=" coverage.xml"
  web="npx eslint . && npx tsc --noEmit && npx prettier --check . && npx vitest run --coverage"
  web+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  web+=" ../../quality/coverage-thresholds.json --require apps/web/lib/"
  web+=" coverage/cobertura-coverage.xml"

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
  # T05: PHPUnit and the coverage gate wait for apps/drupal/phpunit.xml.dist (added by T09 with
  # the first module). Until then this step shows a visible SKIP.
  printf '%s\t%s\t%s\n' "component-drupal-tests" "apps/drupal/phpunit.xml.dist" \
    "$(wrap 'ddev exec -d /var/www/html/apps/drupal' apps/drupal "$drupal_tests")"
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
read_count=0
# Steps are read on fd 3 and each step gets stdin from /dev/null, so a step that reads stdin
# (ddev exec, docker exec -i, any pipe reader) cannot swallow the remaining step lines.
while IFS=$'\t' read -r -u 3 name manifest cmd; do
  [[ -z "$name" ]] && continue
  read_count=$((read_count + 1))
  if [[ "$manifest" != "-" && ! -e "$manifest" ]]; then
    echo "SKIP  $name (no $manifest)"
    skip=$((skip + 1))
    continue
  fi
  if output="$(bash -c "$cmd" 2>&1 </dev/null)"; then
    echo "PASS  $name"
    pass=$((pass + 1))
  else
    echo "FAIL  $name"
    printf '%s\n' "$output" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
done 3<"$steps_file"

echo "summary: PASS $pass FAIL $fail SKIP $skip"
if [[ $((pass + fail + skip)) -ne "$read_count" ]]; then
  echo "error: $read_count steps were read but $((pass + fail + skip)) were counted" >&2
  exit 1
fi
[[ "$fail" -eq 0 ]]
