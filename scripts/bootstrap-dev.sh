#!/usr/bin/env bash
# Install the pinned repository tooling into .tools/ and install the git hooks.
# Usage: scripts/bootstrap-dev.sh
# Needs: python3 (3.9 or newer), curl, git, tar.
# Installs pre-commit, gitleaks, actionlint and shellcheck into .tools/ with SHA-256 checks
# (scripts/tool-versions.env). Run it again after a pin changes (T08).
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
if [[ -z "${PRE_COMMIT_SHA256:-}" ]]; then
  echo "ERROR: PRE_COMMIT_SHA256 is not pinned in scripts/tool-versions.env." >&2
  exit 1
fi
if [[ "$actual_sha" != "$PRE_COMMIT_SHA256" ]]; then
  echo "ERROR: checksum mismatch for $pyz" >&2
  echo "  expected $PRE_COMMIT_SHA256" >&2
  echo "  actual   $actual_sha" >&2
  rm -f "$pyz"
  exit 1
fi

cat >"$wrapper" <<EOF
#!/usr/bin/env bash
exec python3 "$pyz" "\$@"
EOF
chmod +x "$wrapper"

# install_release_binary NAME VERSION URL SHA256 MEMBER
# Downloads the release tarball into .tools/ and checks its SHA-256 every run (a mismatch is
# fatal and the tarball is removed). Then always installs MEMBER from that verified tarball to
# .tools/NAME, so a binary restored from a CI cache is replaced by the one that was checked
# (it takes milliseconds).
install_release_binary() {
  local name="$1" version="$2" url="$3" sha="$4" member="$5"
  local archive="$tools_dir/${name}-${version}.tar.gz" actual stage
  if [[ -z "$sha" ]]; then
    echo "ERROR: the SHA-256 of $name is not pinned in scripts/tool-versions.env." >&2
    exit 1
  fi
  if [[ ! -f "$archive" ]]; then
    echo "Downloading $name $version"
    curl --fail --silent --show-error --location -o "$archive.part" "$url"
    mv "$archive.part" "$archive"
  fi
  actual="$(sha256sum "$archive" | cut -d' ' -f1)"
  if [[ "$actual" != "$sha" ]]; then
    echo "ERROR: checksum mismatch for $archive" >&2
    echo "  expected $sha" >&2
    echo "  actual   $actual" >&2
    rm -f "$archive"
    exit 1
  fi
  stage="$(mktemp -d)"
  tar -xzf "$archive" -C "$stage" "$member"
  install -m 0755 "$stage/$member" "$tools_dir/$name"
  rm -rf "$stage"
}

# The gitleaks, actionlint and shellcheck binaries are pinned for Linux x86_64 only. The
# supported dev platform is WSL2 Linux, and CI runs ubuntu-24.04.
if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "ERROR: the gitleaks, actionlint and shellcheck binaries are pinned for" >&2
  echo "  Linux x86_64 only." >&2
  echo "  This is $(uname -s) $(uname -m). Use WSL2 Linux (docs/runbooks/local-setup.md)." >&2
  exit 1
fi
gl_url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}"
install_release_binary gitleaks "$GITLEAKS_VERSION" \
  "${gl_url}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  "${GITLEAKS_SHA256:-}" gitleaks
al_url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}"
install_release_binary actionlint "$ACTIONLINT_VERSION" \
  "${al_url}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" \
  "${ACTIONLINT_SHA256:-}" actionlint
sc_url="https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}"
install_release_binary shellcheck "$SHELLCHECK_VERSION" \
  "${sc_url}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.gz" \
  "${SHELLCHECK_SHA256:-}" "shellcheck-v${SHELLCHECK_VERSION}/shellcheck"
"$tools_dir/gitleaks" version
"$tools_dir/actionlint" -version | head -n 1
"$tools_dir/shellcheck" --version | sed -n 2p

"$wrapper" --version
"$wrapper" install --install-hooks --hook-type pre-commit --hook-type commit-msg
echo "Done. Hooks installed (pre-commit and commit-msg)."
echo "Run 'scripts/quality.sh' to check the tree."
