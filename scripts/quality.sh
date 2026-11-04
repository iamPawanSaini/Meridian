#!/usr/bin/env bash
# Run every quality check once. This is the only implementation: `ddev quality` and CI (T08)
# call it, and it runs the pre-commit hooks as its first step. Prints PASS, FAIL or SKIP per
# step and a summary, and exits non-zero when any step FAILs.
#
# Usage: scripts/quality.sh [--group GROUP]... | --list
#   --list         print GROUP<TAB>STEP for every built-in step, in run order, and exit 0
#   --group GROUP  run only the built-in steps of GROUP (repeatable). Groups: core, docs, drupal,
#                  engine, web. Without --group every step runs. An unknown group exits 2.
# Environment:
#   QUALITY_RUNNER=native|ddev  where component tools run (default native; `ddev quality` sets
#                               ddev). `ddev` maps to `ddev exec`, `ddev engine`, `ddev next`.
#                               The runner never changes which steps exist or which SKIP.
#   QUALITY_STEPS=FILE          replaces the built-in steps. Each line is
#                               NAME<TAB>MANIFEST<TAB>COMMAND. MANIFEST '-' always runs; a
#                               MANIFEST path that does not exist gives SKIP; a present manifest
#                               with a failing or missing command gives FAIL. Not allowed with
#                               --group, and the expected-skips rule does not apply to it.
#   QUALITY_EXPECTED_SKIPS=FILE replaces quality/expected-skips.txt (test hook).
#   QUALITY_NESTED=1            set by docs-regression for the suites it runs (and a lock file
#                               .tools/docs-regression.lock with its pid, because ddev drops the
#                               environment), so a suite that runs `ddev quality` cannot start
#                               docs-regression again: the docs group is left out, with a note.
#   QUALITY_DOCS_JOBS=N         how many docs suites docs-regression runs at once (an integer
#                               >= 1, default 1; CI sets 4 on a runner with no DDEV). Any other
#                               value exits 2.
#   GITHUB_STEP_SUMMARY=FILE    when set, a Markdown table of the steps is appended to FILE.
# SKIP happens only when a component manifest is absent. A missing tool is a FAIL. A built-in
# step that SKIPs without a line in quality/expected-skips.txt is a FAIL, and so is a step that
# runs while it is still listed there (T08, KD-3).
# A step may print lines that start with "detail: ". They are shown under its result line.
# No -e on purpose: every step's exit status is captured and counted, and a failing step must
# not stop the later steps. The summary and the final exit code carry the result.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 2

known_groups="core docs drupal engine web"
list_only=0
selected=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) list_only=1 ;;
    --group)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: --group needs a group name (one of: $known_groups)" >&2
        exit 2
      fi
      selected+=("$2")
      shift
      ;;
    -h | --help)
      sed -n '2,/^set -uo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1' (use --list, --group GROUP)" >&2
      exit 2
      ;;
  esac
  shift
done
# A docs suite may run `ddev quality`, and ddev does not pass the environment on, so a lock file
# with the pid of the running docs-regression step marks a nested run as well.
nested=0
nest_lock="$root/.tools/docs-regression.lock"
if [[ -n "${QUALITY_NESTED:-}" ]]; then
  nested=1
elif [[ -r "$nest_lock" ]] && kill -0 "$(cat "$nest_lock")" 2>/dev/null; then
  nested=1
fi
if [[ "$nested" -eq 1 ]]; then
  for g in ${selected[@]+"${selected[@]}"}; do
    if [[ "$g" == "docs" ]]; then
      echo "error: the docs group cannot run inside docs-regression (a nested run)" >&2
      exit 2
    fi
  done
fi
for g in ${selected[@]+"${selected[@]}"}; do
  case " $known_groups " in
    *" $g "*) ;;
    *)
      echo "error: unknown group '$g' (use one of: $known_groups)" >&2
      exit 2
      ;;
  esac
done
if [[ -n "${QUALITY_STEPS:-}" && ${#selected[@]} -gt 0 ]]; then
  echo "error: --group cannot be used with QUALITY_STEPS" >&2
  exit 2
fi

if [[ -n "${QUALITY_DOCS_JOBS+x}" && ! "$QUALITY_DOCS_JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: QUALITY_DOCS_JOBS must be a positive integer (got '$QUALITY_DOCS_JOBS')" >&2
  exit 2
fi

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
gitleaks="gitleaks"
if [[ -x "$root/.tools/gitleaks" ]]; then
  gitleaks=".tools/gitleaks"
fi

# step GROUP NAME MANIFEST COMMAND: one built-in step as a tab-separated line. A step with no
# valid group is a programming error (exit 2).
step() {
  local group="$1" name="$2" manifest="$3" cmd="$4"
  case " $known_groups " in
    *" $group "*) ;;
    *) group="" ;;
  esac
  if [[ -z "$group" ]]; then
    echo "error: built-in step '$name' has no valid group" >&2
    exit 2
  fi
  printf '%s\t%s\t%s\t%s\n' "$group" "$name" "$manifest" "$cmd"
}

# Built-in steps as GROUP<TAB>NAME<TAB>MANIFEST<TAB>COMMAND lines, in run order. Which steps
# exist, and which SKIP, depends only on the manifests, never on QUALITY_RUNNER.
builtin_steps() {
  local engine engine_audit drupal drupal_tests drupal_build web web_audit commit_range
  local secret_history docs_regression tooling_tests
  commit_range="git rev-parse --verify -q origin/main >/dev/null"
  commit_range+=" || { echo 'origin/main not found: run git fetch origin'; exit 1; };"
  commit_range+=" python3 scripts/check_commit_msg.py --range origin/main..HEAD"
  tooling_tests="rc=0;"
  tooling_tests+=" python3 -m unittest discover -s scripts/tests || rc=1;"
  tooling_tests+=" python3 -m unittest discover -s .claude/hooks/tests || rc=1; exit \$rc"
  # T08: the full-history scan. --redact is mandatory because the JSON report is uploaded as a
  # CI artifact. A missing gitleaks binary is a FAIL, never a pass.
  secret_history="command -v $gitleaks >/dev/null"
  secret_history+=" || { echo 'gitleaks not found: run scripts/bootstrap-dev.sh'; exit 1; };"
  secret_history+=" mkdir -p .tools/reports &&"
  secret_history+=" $gitleaks git --redact --no-banner --config .gitleaks.toml"
  secret_history+=" --report-format json --report-path .tools/reports/gitleaks.json"
  # T08: every docs-task suite in --regression mode (decision D-5). The logic, the recursion
  # guard and the QUALITY_DOCS_JOBS handling are in scripts/docs_regression.sh, which shellcheck
  # lints as a script.
  docs_regression="bash scripts/docs_regression.sh"
  # Verify the exact tool commands when T13 (engine) and T21 (web) add the manifests.
  engine="ruff check . && ruff format --check . && mypy meridian_engine"
  engine+=" && pytest --cov=meridian_engine --cov-branch --cov-report=xml:coverage.xml"
  engine+=" --junitxml=junit.xml"
  engine+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  engine+=" ../../quality/coverage-thresholds.json --require meridian_engine/ coverage.xml"
  # T13 sets the exact pip-audit command with the lock tool.
  engine_audit="pip-audit"
  drupal_build="composer install --no-interaction --no-progress"
  drupal_build+=" && composer check-platform-reqs --lock"
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
  drupal_tests="vendor/bin/phpunit --log-junit junit.xml --coverage-cobertura=coverage.xml"
  drupal_tests+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  drupal_tests+=" ../../quality/coverage-thresholds.json --require web/modules/custom/meridian_"
  drupal_tests+=" coverage.xml"
  web="npx eslint . && npx tsc --noEmit && npx prettier --check ."
  web+=" && npx vitest run --coverage --reporter=default --reporter=junit"
  web+=" --outputFile.junit=junit.xml"
  web+=" && python3 ../../scripts/coverage_gate.py --thresholds"
  web+=" ../../quality/coverage-thresholds.json --require apps/web/lib/"
  web+=" coverage/cobertura-coverage.xml"
  # T21 sets the exact npm audit command.
  web_audit="npm audit"

  step core "pre-commit" "-" "$precommit run --all-files --show-diff-on-failure"
  step core "branch-name" "-" "python3 scripts/check_branch_name.py"
  step core "commit-range" "-" "$commit_range"
  step core "exceptions" "-" \
    "mkdir -p .tools/reports && python3 scripts/exceptions_report.py \
--out .tools/reports/exceptions-report.txt"
  step core "assets" "-" "python3 scripts/check_assets.py"
  step core "tooling-tests" "-" "$tooling_tests"
  step core "secret-history" "-" "$secret_history"
  step core "ci-config" "-" "python3 scripts/check_ci.py"
  step docs "docs-regression" "-" "$docs_regression"
  step drupal "build-drupal" "apps/drupal/composer.lock" \
    "$(wrap 'ddev exec -d /var/www/html/apps/drupal' apps/drupal "$drupal_build")"
  step drupal "component-drupal" "apps/drupal/composer.json" \
    "$(wrap 'ddev exec -d /var/www/html/apps/drupal' apps/drupal "$drupal")"
  # T05: PHPUnit and the coverage gate wait for apps/drupal/phpunit.xml.dist (added by T09 with
  # the first module). Until then this step shows a visible SKIP.
  step drupal "component-drupal-tests" "apps/drupal/phpunit.xml.dist" \
    "$(wrap 'ddev exec -d /var/www/html/apps/drupal' apps/drupal "$drupal_tests")"
  step drupal "audit-drupal" "apps/drupal/composer.lock" \
    "$(wrap 'ddev exec -d /var/www/html/apps/drupal' apps/drupal \
      'composer audit --locked --abandoned=report --no-interaction')"
  # T13 verifies the build command. Docker runs on the host, so this step is not wrapped.
  step engine "build-engine" "services/engine/Dockerfile" \
    "docker build -t meridian-engine:ci services/engine"
  step engine "component-engine" "services/engine/pyproject.toml" \
    "$(wrap 'ddev engine' services/engine "$engine")"
  step engine "audit-engine" "services/engine/pyproject.toml" \
    "$(wrap 'ddev engine' services/engine "$engine_audit")"
  step web "build-web" "apps/web/package.json" \
    "$(wrap 'ddev next' apps/web 'npm run build')"
  step web "component-web" "apps/web/package.json" \
    "$(wrap 'ddev next' apps/web "$web")"
  step web "audit-web" "apps/web/package.json" \
    "$(wrap 'ddev next' apps/web "$web_audit")"
}

if [[ "$list_only" -eq 1 ]]; then
  builtin_steps | cut -f1,2
  exit "${PIPESTATUS[0]}"
fi

builtin=1
steps_file="$(mktemp)"
trap 'rm -f "$steps_file"' EXIT
if [[ -n "${QUALITY_STEPS:-}" ]]; then
  builtin=0
  if [[ ! -r "$QUALITY_STEPS" ]]; then
    echo "error: QUALITY_STEPS file '$QUALITY_STEPS' is not readable" >&2
    exit 2
  fi
  # The test hook has no group column: give every line the placeholder group '-'.
  sed 's/^/-\t/' "$QUALITY_STEPS" >"$steps_file"
else
  builtin_steps >"$steps_file" || exit $?
fi

# Expected SKIPs (KD-3), built-in steps only.
declare -A expected=()
if [[ "$builtin" -eq 1 ]]; then
  skips_file="${QUALITY_EXPECTED_SKIPS:-$root/quality/expected-skips.txt}"
  if [[ ! -r "$skips_file" ]]; then
    echo "error: expected-skips file '$skips_file' is not readable" >&2
    exit 2
  fi
  declare -A known_steps=()
  while IFS=$'\t' read -r _ sname _; do
    known_steps["$sname"]=1
  done <"$steps_file"
  skip_re='^[[:space:]]*#[[:space:]]*T[0-9]{2}a?:[[:space:]]*[^[:space:]]'
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$trimmed" || "${trimmed:0:1}" == "#" ]] && continue
    sname="${trimmed%%#*}"
    sname="${sname%"${sname##*[![:space:]]}"}"
    comment=""
    [[ "$trimmed" == *"#"* ]] && comment="#${trimmed#*#}"
    if [[ ! "$comment" =~ $skip_re ]]; then
      echo "error: $skips_file:$lineno: '$sname' has no '# Txx: reason' ticket" >&2
      exit 2
    fi
    if [[ -z "${known_steps[$sname]:-}" ]]; then
      echo "error: $skips_file:$lineno: unknown step '$sname'" >&2
      exit 2
    fi
    expected["$sname"]=1
  done <"$skips_file"
fi

reports_dir="$root/.tools/reports"
mkdir -p "$reports_dir"

pass=0
fail=0
skip=0
read_count=0
rows=()
nested_noted=0
# Steps are read on fd 3 and each step gets stdin from /dev/null, so a step that reads stdin
# (ddev exec, docker exec -i, any pipe reader) cannot swallow the remaining step lines.
while IFS=$'\t' read -r -u 3 group name manifest cmd; do
  [[ -z "$name" ]] && continue
  if [[ ${#selected[@]} -gt 0 ]]; then
    in_group=0
    for g in "${selected[@]}"; do
      [[ "$g" == "$group" ]] && in_group=1
    done
    [[ "$in_group" -eq 1 ]] || continue
  fi
  if [[ "$nested" -eq 1 && "$group" == "docs" ]]; then
    if [[ "$nested_noted" -eq 0 ]]; then
      echo "note: group docs not run (nested inside docs-regression)"
      nested_noted=1
    fi
    continue
  fi
  read_count=$((read_count + 1))
  if [[ "$manifest" != "-" && ! -e "$manifest" ]]; then
    if [[ "$builtin" -eq 1 && -z "${expected[$name]:-}" ]]; then
      echo "FAIL  $name"
      echo "      unexpected SKIP: $name (no $manifest)"
      echo "      add the step to quality/expected-skips.txt with a ticket, or add the manifest"
      fail=$((fail + 1))
      rows+=("| $name | FAIL | unexpected SKIP (no \`$manifest\`) |")
    else
      echo "SKIP  $name (no $manifest)"
      skip=$((skip + 1))
      rows+=("| $name | SKIP | no \`$manifest\` |")
    fi
    continue
  fi
  status=0
  output="$(bash -c "$cmd" 2>&1 </dev/null)" || status=1
  details="$(printf '%s\n' "$output" | sed -n 's/^detail: /      /p')"
  note=""
  if [[ "$builtin" -eq 1 && -n "${expected[$name]:-}" ]]; then
    note="$name ran but is listed in quality/expected-skips.txt: remove the line"
    status=1
  fi
  if [[ "$status" -eq 0 ]]; then
    echo "PASS  $name"
    [[ -n "$details" ]] && printf '%s\n' "$details"
    pass=$((pass + 1))
    rows+=("| $name | PASS | |")
  else
    echo "FAIL  $name"
    printf '%s\n' "$output" | sed 's/^/      /'
    [[ -n "$note" ]] && echo "      $note"
    fail=$((fail + 1))
    rows+=("| $name | FAIL | ${note:-see the job log} |")
  fi
done 3<"$steps_file"

echo "summary: PASS $pass FAIL $fail SKIP $skip"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Meridian quality (${selected[*]:-all groups})"
    echo
    echo "| Step | Result | Detail |"
    echo "|---|---|---|"
    for row in ${rows[@]+"${rows[@]}"}; do
      printf '%s\n' "$row"
    done
    echo
    echo "PASS $pass, FAIL $fail, SKIP $skip"
    echo
  } >>"$GITHUB_STEP_SUMMARY"
fi

if [[ $((pass + fail + skip)) -ne "$read_count" ]]; then
  echo "error: $read_count steps were read but $((pass + fail + skip)) were counted" >&2
  exit 1
fi
[[ "$fail" -eq 0 ]]
