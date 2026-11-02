"""Reference model (NOT production) used only to prove the T04a run-checks harness can pass."""

import argparse
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("--out")
a = ap.parse_args()
TK = r"(?:T\d{2}a?|DEF-\d{3}): \S"
tok = {
    "noqa": r"#\s*noqa",
    "type: ignore": r"#\s*type:\s*ignore",
    "pragma: no cover": r"#\s*pragma:\s*no cover",
    "eslint-disable": r"eslint-disable",
    "@ts-expect-error": r"@ts-expect-error",
    "@ts-ignore": r"@ts-ignore",
    "phpcs:ignore": r"phpcs:ignore",
    "@phpstan-ignore": r"@phpstan-ignore",
    "shellcheck": r"#\s*shellcheck\s+disable",
    "yamllint": r"#\s*yamllint\s+disable",
    "markdownlint": r"markdownlint-disable",
    "hadolint": r"hadolint\s+ignore",
}
form = {
    "noqa": r"#\s*noqa:\s*[A-Z]+[0-9]+(?:[,\s]+[A-Z]+[0-9]+)*\s+#\s*" + TK,
    "type: ignore": r"type:\s*ignore\[[^\]#]+\]\s+#\s*" + TK,
    "pragma: no cover": r"pragma:\s*no cover\s+#\s*" + TK,
    "shellcheck": r"shellcheck\s+disable=\S+\s+#\s*" + TK,
    "hadolint": r"hadolint\s+ignore=\S+\s+#\s*" + TK,
    "eslint-disable": r"eslint-disable\S*\s+[@\w/-]+.*\s--\s+" + TK,
    "phpcs:ignore": r"phpcs:ignore\s+\S+.*\s--\s+" + TK,
    "@phpstan-ignore": r"@phpstan-ignore\s+\S+\s+\(" + TK,
    "@ts-expect-error": r"@ts-expect-error\s+" + TK,
    "markdownlint": r"-->\s*<!--\s*" + TK,
    "yamllint": None,
    "@ts-ignore": None,
}
cfg = re.compile(r"^\s*-\s*[\"']?[\w./*-]+[\"']?\s*(#.*)?$|^exclude\s*=|:\s*\"off\"")
ids = set(re.findall(r"^## (T\d{2}a?):", Path("docs/TASKS.md").read_text(), re.M))
ids |= set(re.findall(r"DEF-\d{3}", Path("docs/tests/defects.md").read_text()))
cfgfiles = (".markdownlint-cli2.yaml", ".yamllint.yaml", ".spectral.yaml", "ruff.toml")
files = subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split()
cnt: Counter = Counter()
tickets: Counter = Counter()
bad = []
for f in files:
    if f.startswith("docs/TASKS.md") or f.startswith("docs/tests/defects"):
        continue
    for n, line in enumerate(Path(f).read_text().splitlines(), 1):
        kind = next((k for k, rx in tok.items() if re.search(rx, line)), None)
        if (
            kind is None
            and f in cfgfiles
            and (
                cfg.search(line)
                and (
                    "ignore" in Path(f).read_text()
                    or "ignores" in Path(f).read_text()
                    or f == "ruff.toml"
                    or f == ".spectral.yaml"
                )
            )
            and (re.match(r"^\s*-\s", line) or line.startswith("exclude") or '"off"' in line)
        ):
            kind = "config exclude"
        if kind is None:
            continue
        ok = None if kind == "config exclude" else form[kind]
        if kind in ("yamllint", "@ts-ignore"):
            bad.append(f"{f}:{n}: {kind} is never allowed")
            continue
        m = re.search(r"\b(T\d{2}a?|DEF-\d{3}): \S", line)
        if (
            (ok is not None and not re.search(ok, line))
            or (ok is None and not m)
            or (m and m.group(0).split(":")[0] not in ids)
        ):
            bad.append(f"{f}:{n}: {kind} without a valid ticket in the tool's comment slot")
        else:
            cnt[kind] += 1
            tickets[m.group(0).split(":")[0]] += 1
if a.out:
    with open(a.out, "w") as fh:
        for k, v in cnt.items():
            fh.write(f"{k}: {v}\n")
        for k, v in tickets.items():
            fh.write(f"ticket {k}: {v}\n")
print("\n".join(bad))
sys.exit(1 if bad else 0)
