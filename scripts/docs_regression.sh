#!/usr/bin/env bash
# Run every docs-task suite in --regression mode (T08, decision D-5). Called by the
# docs-regression step of scripts/quality.sh from the repository root; it prints "detail: "
# lines that the step shows under its result line.
#
# Usage: scripts/docs_regression.sh
# Environment:
#   QUALITY_DOCS_JOBS=N  how many suites run at once (integer >= 1, default 1). The suites share
#                        pre-commit and DDEV, so parallel runs on a developer machine can
#                        clash. CI sets 4 because one after another they would use most of the
#                        10 minute budget (NFR-07). An invalid value exits 2.
# A suite that exits non-zero fails the run and is named, with the last 40 lines of its output.
# BLOCKED and optional-tool SKIP lines inside a suite do not change its exit code.
# Each suite writes to its own file and the results are reported in suite order. The full
# output of every suite is kept in .tools/reports/docs/<Txx>.txt.
# Recursion guard: a docs suite (T04a, T05, T06) may run `ddev quality`. QUALITY_NESTED=1 and
# the lock file .tools/docs-regression.lock (ddev drops the environment, so the pid is also in
# a file) make a nested quality.sh leave out the docs group.
# T07_SKIP_NESTED=1: T07 would run T02 to T06 again, and this run already runs each once.
# .tools/suite-bin (the pinned shellcheck only) goes first on PATH when it is installed.
# No -e on purpose: every suite's exit status is captured and counted, and a failing suite must
# not stop the later suites. The final exit code carries the result.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

max="${QUALITY_DOCS_JOBS-1}"
if [[ ! "$max" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: QUALITY_DOCS_JOBS must be a positive integer (got '$max')" >&2
  exit 2
fi

mkdir -p .tools
echo $$ >.tools/docs-regression.lock
d="$(mktemp -d)"
trap 'rm -f .tools/docs-regression.lock; rm -rf "$d"' EXIT
if [[ -x .tools/shellcheck ]]; then
  mkdir -p .tools/suite-bin
  ln -sf ../shellcheck .tools/suite-bin/shellcheck
  export PATH="$PWD/.tools/suite-bin:$PATH"
fi
export QUALITY_NESTED=1 T07_SKIP_NESTED=1
rm -rf .tools/reports/docs
mkdir -p .tools/reports/docs

rc=0
n=0
for s in docs/tests/T*/run-checks.sh; do
  if [[ ! -f "$s" ]]; then
    echo "no docs suites found: $s"
    exit 1
  fi
  n=$((n + 1))
  k="${s#docs/tests/}"
  k="${k%%/*}"
  ("$s" --regression >"$d/$k.out" 2>&1 </dev/null; echo $? >"$d/$k.rc") &
  while [[ "$(jobs -rp | wc -l)" -ge "$max" ]]; do
    wait -n
  done
done
wait
for s in docs/tests/T*/run-checks.sh; do
  k="${s#docs/tests/}"
  k="${k%%/*}"
  cp "$d/$k.out" ".tools/reports/docs/$k.txt"
  if [[ "$(cat "$d/$k.rc")" == 0 ]]; then
    echo "detail: ok $s"
  else
    echo "FAILED: $s --regression"
    tail -n 40 "$d/$k.out"
    rc=1
  fi
done
echo "detail: $n docs suites run"
exit "$rc"
