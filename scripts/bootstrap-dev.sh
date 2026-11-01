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
# Python older than 3.11 (DEF-003). Fail early with a clear message instead of a traceback.
if ! python3 - <<'PY'
import sys

if sys.version_info >= (3, 11):
    sys.exit(0)
try:
    from importlib.metadata import version

    parts = version("typing_extensions").split(".")
    sys.exit(0 if (int(parts[0]), int(parts[1])) >= (4, 16) else 1)
except Exception:
    sys.exit(1)
PY
then
  echo "ERROR: Python $(python3 -c 'import sys; print(sys.version.split()[0])') needs typing_extensions >= 4.16." >&2
  echo "  Use Python 3.11 or newer, or run:" >&2
  echo "  sudo apt install python3-pip && python3 -m pip install --user 'typing_extensions>=4.16'" >&2
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
