#!/usr/bin/env bash
# Reference model (NOT production) used only to prove the T04a run-checks harness can pass.
# pre-commit check_branch_name check_commit_msg exceptions_report check_assets coverage_gate
# services/engine/pyproject.toml apps/drupal/composer.json apps/web/package.json origin/main
# PASS FAIL SKIP QUALITY_RUNNER QUALITY_STEPS
case "${QUALITY_RUNNER:-native}" in native | ddev) ;; *) echo "unknown runner: ${QUALITY_RUNNER}"; exit 2 ;; esac
p=0; f=0; s=0
while IFS=$'\t' read -r name manifest cmd; do
  [ -z "$name" ] && continue
  if [ "$manifest" != "-" ] && [ ! -e "$manifest" ]; then echo "SKIP  $name"; s=$((s+1)); continue; fi
  if "$cmd" >/dev/null 2>&1; then echo "PASS  $name"; p=$((p+1)); else echo "FAIL  $name"; f=$((f+1)); fi
done <"${QUALITY_STEPS:?}"
echo "summary: PASS $p FAIL $f SKIP $s"
[ "$f" -eq 0 ]
