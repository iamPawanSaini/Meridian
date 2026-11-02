#!/usr/bin/env bash
# Install the pinned repository tooling into .tools/ and install the git hooks.
# Usage: scripts/bootstrap-dev.sh
# Needs: python3 (3.9 or newer), curl, git.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# shellcheck source=scripts/tool-versions.env
source scripts/tool-versions.env

# The pinned pre-commit zipapp bundles virtualenv 21, which needs typing_extensions >= 4.16 on
# Python older than 3.11 (DEF-003). The zipapp shim drops every site-packages directory from
# sys.path, so the check does the same. Fail early with a clear message instead of a traceback.
if ! python3 - <<'PY'
import os
import sys

if sys.version_info >= (3, 11):
    sys.exit(0)
sys.path[:] = [p for p in sys.path if os.path.basename(p) not in ("site-packages", "dist-packages")]
from importlib.metadata import distributions

for dist in distributions(path=sys.path):
    if (dist.metadata["Name"] or "").lower().replace("-", "_") == "typing_extensions":
        major, minor = (int(x) for x in dist.version.split(".")[:2])
        sys.exit(0 if (major, minor) >= (4, 16) else 1)
sys.exit(1)
PY
then
  echo "ERROR: Python $(python3 -c 'import sys; print(sys.version.split()[0])') needs typing_extensions >= 4.16" >&2
  echo "  on a path outside site-packages (the pre-commit zipapp ignores site-packages)." >&2
  echo "  Use Python 3.11 or newer, or see DEF-003 in docs/tests/defects.md and" >&2
  echo "  docs/runbooks/local-setup.md (Prerequisites) for the workaround." >&2
  exit 1
fi

tools_dir="$repo_root/.tools"
pyz="$tools_dir/pre-commit-${PRE_COMMIT_VERSION}.pyz"
wrapper="$tools_dir/pre-commit"
base_url="https://github.com/pre-commit/pre-commit/releases/download"
url="${base_url}/v${PRE_COMMIT_VERSION}/pre-commit-${PRE_COMMIT_VERSION}.pyz"

mkdir -p "$tools_dir"

if [[ ! -f "$pyz" ]]; then
  echo "Downloading pre-commit ${PRE_COMMIT_VERSION}"
  curl --fail --silent --show-error --location -o "$pyz.part" "$url"
  mv "$pyz.part" "$pyz"
fi

actual_sha="$(sha256sum "$pyz" | cut -d' ' -f1)"
if [[ -n "${PRE_COMMIT_SHA256:-}" ]]; then
  if [[ "$actual_sha" != "$PRE_COMMIT_SHA256" ]]; then
    echo "ERROR: checksum mismatch for $pyz" >&2
    echo "  expected $PRE_COMMIT_SHA256" >&2
    echo "  actual   $actual_sha" >&2
    rm -f "$pyz"
    exit 1
  fi
else
  echo "WARNING: PRE_COMMIT_SHA256 is not pinned in scripts/tool-versions.env." >&2
  echo "  Downloaded file SHA-256: $actual_sha" >&2
  echo "  Compare it with the GitHub release, then record it in tool-versions.env." >&2
fi

cat >"$wrapper" <<EOF
#!/usr/bin/env bash
exec python3 "$pyz" "\$@"
EOF
chmod +x "$wrapper"

"$wrapper" --version
"$wrapper" install --install-hooks --hook-type pre-commit --hook-type commit-msg
echo "Done. Hooks installed (pre-commit and commit-msg)."
echo "Run 'scripts/quality.sh' to check the tree."
