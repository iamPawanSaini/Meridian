#!/usr/bin/env python3
"""Check front-end assets: no third-party hosts, no hard-coded colours (T04a, section 0b).

Scope: tracked and untracked, non-ignored style, script and template files under `apps/web/`
and the Drupal custom theme `apps/drupal/web/themes/custom/`. A file fails when it

- loads a font, style, script or icon from a third-party host (a known CDN host, or any
  absolute or protocol-relative URL in `url()`, `@import`, `<script src>` or a stylesheet,
  icon or preload `<link>`), or
- contains a hex colour literal outside the tokens file.

Links to documentation (`<a href>`) and in-page anchors are not assets and are allowed.

The tokens file is `apps/web/styles/tokens.css` (T21a owns the final allowlist and may add
paths to TOKEN_FILES). Exit 0 when clean, 1 with `path:line: reason` lines otherwise.

Usage: check_assets.py   (scans the git tree of the current directory)
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

TOKEN_FILES = frozenset(
    {
        "apps/web/styles/tokens.css",
        "apps/drupal/web/themes/custom/meridian_theme/css/tokens.css",
    }
)
SCOPES = ("apps/web/", "apps/drupal/web/themes/custom/")
ASSET_FILE = re.compile(r"\.(css|scss|sass|less|ts|tsx|js|jsx|mjs|cjs|html|twig|svg)$")
SKIP_DIRS = re.compile(r"(^|/)(node_modules|\.next|vendor|dist|build)/")

KNOWN_HOSTS = re.compile(
    r"//(fonts\.googleapis\.com|fonts\.gstatic\.com|cdn\.jsdelivr\.net|unpkg\.com"
    r"|cdnjs\.cloudflare\.com|use\.fontawesome\.com|kit\.fontawesome\.com"
    r"|ajax\.googleapis\.com|stackpath\.bootstrapcdn\.com|maxcdn\.bootstrapcdn\.com"
    r"|use\.typekit\.net|p\.typekit\.net|code\.jquery\.com|cdn\.tailwindcss\.com)",
    re.IGNORECASE,
)
EXTERNAL = r"(?:https?:)?//[A-Za-z0-9]"
ASSET_CONTEXTS = [
    re.compile(r"url\(\s*['\"]?" + EXTERNAL, re.IGNORECASE),
    re.compile(r"@import\s+(?:url\(\s*)?['\"]?" + EXTERNAL, re.IGNORECASE),
    re.compile(r"<script\b[^>]*\bsrc\s*=\s*['\"]?" + EXTERNAL, re.IGNORECASE),
    re.compile(
        r"<link\b(?=[^>]*\brel\s*=\s*['\"]?(?:stylesheet|icon|shortcut|apple-touch-icon"
        r"|preload|preconnect|dns-prefetch|modulepreload|manifest))[^>]*\bhref\s*=\s*['\"]?"
        + EXTERNAL,
        re.IGNORECASE,
    ),
]
# Hex colour: 3, 4, 6 or 8 digits, not part of a word or an HTML entity such as &#39;
HEX = re.compile(r"(?<![&\w#])#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b")
# In-page references that look like hex but are not colours.
NOT_COLOUR = re.compile(
    r"""(?:href|xlink:href|id|for)\s*=\s*['"]#[^'"]*['"]|url\(\s*['"]?#[^)]*\)""",
    re.IGNORECASE,
)
ID_SELECTOR = re.compile(r"^\s*#[\w-]+\s*[{,]")


def candidate_files() -> list[str]:
    """Return tracked and untracked, non-ignored files in the asset scopes."""
    proc = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"git ls-files failed: {proc.stderr.strip()}")
    return [
        name
        for name in proc.stdout.splitlines()
        if name.startswith(SCOPES) and ASSET_FILE.search(name) and not SKIP_DIRS.search(name)
    ]


def check_line(line: str, allow_hex: bool) -> list[str]:
    """Return the reasons a single line is rejected."""
    reasons: list[str] = []
    if KNOWN_HOSTS.search(line) or any(rx.search(line) for rx in ASSET_CONTEXTS):
        reasons.append("third-party host (self-host fonts, styles, scripts and icons)")
    if not allow_hex and not ID_SELECTOR.match(line):
        if HEX.search(NOT_COLOUR.sub("", line)):
            reasons.append("hex colour outside the tokens file (use a design token)")
    return reasons


def check_file(path: str) -> list[str]:
    """Return `path:line: reason` problems for one file."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    allow_hex = path in TOKEN_FILES
    problems: list[str] = []
    for number, line in enumerate(text.splitlines(), 1):
        for reason in check_line(line, allow_hex):
            problems.append(f"{path}:{number}: {reason}")
    return problems


def main() -> int:
    """Entry point; returns the process exit code."""
    try:
        files = candidate_files()
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    problems = [problem for path in files for problem in check_file(path)]
    for problem in problems:
        print(problem)
    if problems:
        print(f"{len(problems)} asset problem(s) in {len(files)} file(s) checked")
        return 1
    print(f"check_assets: OK ({len(files)} file(s) checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
