"""Reference model (NOT production) used only to prove the T04a run-checks harness can pass."""

import re
import subprocess
import sys
from pathlib import Path

TOKENS = "apps/web/styles/tokens.css"
hosts = re.compile(
    r"(https?:)?//(fonts\.googleapis|fonts\.gstatic|cdn\.jsdelivr|unpkg|cdnjs\.cloudflare|use\.fontawesome)"
)
hexre = re.compile(
    r"(?<![&\w])#[0-9a-fA-F]{8}\b|(?<![&\w])#[0-9a-fA-F]{6}\b|(?<![&\w])#[0-9a-fA-F]{3}\b"
)
files = [
    f
    for f in subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split()
    if f.startswith("apps/web/") or f.startswith("apps/drupal/web/themes/custom/")
]
bad = []
for f in files:
    for n, line in enumerate(Path(f).read_text().splitlines(), 1):
        if hosts.search(line):
            bad.append(f"{f}:{n}: third-party host")
        if f != TOKENS and re.search(r"(:|\")\s*#[0-9a-fA-F]{3,8}\b", line) and hexre.search(line):
            bad.append(f"{f}:{n}: hard-coded colour")
print("\n".join(bad))
sys.exit(1 if bad else 0)
