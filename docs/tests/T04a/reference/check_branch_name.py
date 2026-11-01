"""Reference model (NOT production) used only to prove the T04a run-checks harness can pass."""
import argparse
import os
import re
import subprocess
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--branch")
ap.add_argument("--tasks-file", default="docs/TASKS.md")
a = ap.parse_args()
b = a.branch or os.environ.get("GITHUB_HEAD_REF") or subprocess.run(
    ["git", "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True).stdout.strip()
ids = set(re.findall(r"^## (T\d{2}a?):", open(a.tasks_file).read(), re.M))
m = re.match(r"^task/(T\d{2}a?)-[a-z0-9]+(-[a-z0-9]+)*$", b)
if b == "main" or (m and m.group(1) in ids):
    sys.exit(0)
print(f"branch name {b!r} must be main or task/Txx-slug with a known task id")
sys.exit(1)
