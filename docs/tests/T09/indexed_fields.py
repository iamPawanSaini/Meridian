#!/usr/bin/env python3
"""TC-T09-05 helper: list the fields marked "Indexed: yes" in the amended data-model."""

import re

SECTIONS = {
    "decision": (85, 117),
    "position": (117, 148),
    "daily_run": (148, 180),
    "price_snapshot": (180, 202),
    "watchlist_item": (202, 217),
}
with open("docs/specs/data-model.md", encoding="utf-8") as handle:
    lines = handle.read().split("\n")
for bundle, (a, z) in SECTIONS.items():
    for line in lines[a:z]:
        m = re.match(r"\|\s*`(\w+)`\s*\|", line)
        if not m:
            continue
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cols) > 5 and cols[-2].lower().startswith("yes"):
            print(bundle, m.group(1), "->", cols[-2])
