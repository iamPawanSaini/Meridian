"""Reference model (NOT production) used only to prove the T04a run-checks harness can pass."""
import argparse
import re
import subprocess
import sys
from collections import Counter

ap = argparse.ArgumentParser()
ap.add_argument("--out")
a = ap.parse_args()
tok = {"noqa": r"#\s*noqa", "type: ignore": r"#\s*type:\s*ignore", "pragma: no cover": r"#\s*pragma:\s*no cover",
       "eslint-disable": r"eslint-disable", "@ts-expect-error": r"@ts-expect-error", "phpcs:ignore": r"phpcs:ignore",
       "@phpstan-ignore": r"@phpstan-ignore", "shellcheck": r"#\s*shellcheck\s+disable", "yamllint": r"#\s*yamllint\s+disable",
       "markdownlint": r"markdownlint-disable", "hadolint": r"hadolint\s+ignore"}
cfg = re.compile(r"^\s*-\s*[\"'].*(TASKS|evidence)|^exclude\s*=")
ids = set(re.findall(r"^## (T\d{2}a?):", open("docs/TASKS.md").read(), re.M))
ids |= set(re.findall(r"DEF-\d{3}", open("docs/tests/defects.md").read()))
files = subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split()
cnt: Counter = Counter()
tickets: Counter = Counter()
bad = []
for f in files:
    if f.startswith("docs/TASKS.md") or f.startswith("docs/tests/defects"):
        continue
    for n, line in enumerate(open(f).read().splitlines(), 1):
        kind = next((k for k, rx in tok.items() if re.search(rx, line)), None)
        if kind is None and cfg.search(line):
            kind = "config exclude"
        if kind is None:
            continue
        m = re.search(r"\b(T\d{2}a?|DEF-\d{3}): \S", line)
        if not m or m.group(1) not in ids:
            bad.append(f"{f}:{n}: {kind} without a valid ticket")
        else:
            cnt[kind] += 1
            tickets[m.group(1)] += 1
if a.out:
    with open(a.out, "w") as fh:
        for k, v in cnt.items():
            fh.write(f"{k}: {v}\n")
        for k, v in tickets.items():
            fh.write(f"ticket {k}: {v}\n")
print("\n".join(bad))
sys.exit(1 if bad else 0)
