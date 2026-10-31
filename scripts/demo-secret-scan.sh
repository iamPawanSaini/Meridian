#!/usr/bin/env bash
# Demonstrate that the pre-commit secret scan rejects a commit that contains a key.
# This is evidence for T00 (TC-T00-04). It runs in a throwaway repository under a temp
# directory and never touches this repository's history.
#
# Usage: scripts/demo-secret-scan.sh [evidence-file]
# Needs: scripts/bootstrap-dev.sh has been run (.tools/pre-commit exists).
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
pre_commit="$repo_root/.tools/pre-commit"
evidence="${1:-}"

if [[ ! -x "$pre_commit" ]]; then
  echo "ERROR: $pre_commit not found. Run scripts/bootstrap-dev.sh first." >&2
  exit 2
fi

run() {
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  cd "$work"
  git init -q demo && cd demo
  git config user.email "demo@example.invalid"
  git config user.name "Meridian secret-scan demo"
  cp "$repo_root/.gitleaks.toml" .
  # Only the gitleaks hook, with the same pinned revision as the real config.
  python3 - "$repo_root/.pre-commit-config.yaml" > .pre-commit-config.yaml <<'PY'
import re, sys
text = open(sys.argv[1]).read()
rev = re.search(r"gitleaks/gitleaks\n\s+rev:\s*(\S+)", text).group(1)
print("repos:\n  - repo: https://github.com/gitleaks/gitleaks\n"
      f"    rev: {rev}\n    hooks:\n      - id: gitleaks")
PY
  "$pre_commit" install -q

  echo "== Step 1: clean commit (control), expected to SUCCEED"
  git add .gitleaks.toml .pre-commit-config.yaml
  git commit -q -m "T00: demo control commit"
  echo "control commit: OK ($(git rev-parse --short HEAD))"

  echo
  echo "== Step 2: commit containing a fake GitHub token, expected to be REJECTED"
  # The fake token is generated at run time so no key-like string lives in the repo.
  fake="ghp_$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)"
  printf 'GITHUB_TOKEN=%s\n' "$fake" > config.env
  git add config.env
  set +e
  git commit -m "T00: demo commit with a fake key"
  status=$?
  set -e
  echo
  if [[ $status -ne 0 ]] && ! git log --oneline | grep -q "fake key"; then
    echo "RESULT: PASS. Commit rejected (exit $status); history has only the control commit."
    return 0
  fi
  echo "RESULT: FAIL. The commit with a fake key was accepted."
  return 1
}

if [[ -n "$evidence" ]]; then
  mkdir -p "$(dirname "$evidence")"
  {
    echo "# Secret-scan demonstration, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Repo commit: $(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo none)"
    echo
    run
  } 2>&1 | tee "$evidence"
  exit "${PIPESTATUS[0]}"
else
  run
fi
