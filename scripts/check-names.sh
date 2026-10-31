#!/usr/bin/env bash
# Fail if any stale placeholder project name appears in the repository.
# Section 0 of docs/TASKS.md defines the names to use.
# docs/TASKS.md is excluded because its T00 criterion quotes the old names.
# The patterns are split so this script does not match itself.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

pattern="trading""-agent|trading""_engine|trading""_ingest"

# --untracked also scans new files that are not ignored by .gitignore.
matches="$(git grep --untracked -I -n -i -E "$pattern" -- . ':!docs/TASKS.md' || true)"
if [[ -n "$matches" ]]; then
  echo "Stale placeholder names found (use the names in docs/TASKS.md section 0):" >&2
  echo "$matches" >&2
  exit 1
fi
echo "check-names: OK (no stale placeholder names)"
