"""Reference model (NOT production) used only to prove the T04a run-checks harness can pass."""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("--msg-file")
ap.add_argument("--range")
ap.add_argument("--tasks-file", default="docs/TASKS.md")
a = ap.parse_args()
ids = set(re.findall(r"^## (T\d{2}a?):", Path(a.tasks_file).read_text(), re.M))


def check(subject: str, rng: bool) -> str:
    if subject.startswith("Merge ") or subject.startswith('Revert "'):
        return ""
    m = re.match(r"^(T\d{2}a?): \S", subject)
    if not m:
        return "subject must start with a task id prefix like 'T04a: '"
    if m.group(1) not in ids:
        return f"unknown task id {m.group(1)}"
    if len(subject) > 72:
        return "subject longer than 72 characters"
    return ""


bad = 0
if a.msg_file:
    subj = Path(a.msg_file).read_text().split("\n")[0]
    e = check(subj, False)
    if e:
        print(f"{e}: {subj!r}")
        bad = 1
else:
    out = subprocess.run(
        ["git", "log", "--format=%H%x09%s", a.range], capture_output=True, text=True
    ).stdout
    for line in out.splitlines():
        sha, subj = line.split("\t", 1)
        e = "fixup/squash commit" if re.match(r"(fixup|squash)! ", subj) else check(subj, True)
        if e:
            print(f"{sha[:8]} {subj!r}: {e}")
            bad = 1
sys.exit(bad)
