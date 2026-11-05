#!/usr/bin/env python3
"""Cut the full Kernel testdox run (TC-T09-54-kernel.txt) into per-case evidence files.

Each file keeps the run header, the testdox block of the test classes that cover the case, and
the closing summary line, so a case has its own non-empty evidence. The full raw output stays in
TC-T09-54-kernel.txt.
"""

import pathlib
import re

EVD = pathlib.Path(__file__).resolve().parent / "evidence"
RAW = (EVD / "TC-T09-54-kernel.txt").read_text(encoding="utf-8").split("\n")

CASES = {
    3: ["Content Model Structure"],
    5: ["Content Model Structure"],
    10: ["Decision Validation"],
    11: ["Decision Validation"],
    12: ["Decision Validation"],
    13: ["Decision Validation"],
    14: ["Decision Validation"],
    15: ["Decision Validation"],
    16: ["Decision Validation"],
    17: ["Position Validation"],
    18: ["Position Validation"],
    19: ["Position Validation"],
    20: ["Position Validation"],
    21: ["Daily Run Validation"],
    22: ["Daily Run Validation"],
    23: ["Price Snapshot Validation", "Daily Run Validation"],
    24: ["Watchlist Item Validation"],
    25: ["Watchlist Item Validation"],
    26: [
        "Decision Validation",
        "Position Validation",
        "Daily Run Validation",
        "Price Snapshot Validation",
        "Watchlist Item Validation",
        "Lifecycle Rules",
    ],
    27: ["Lifecycle Rules"],
    28: ["Violation Contract"],
    31: ["External Id Uniqueness"],
    32: ["External Id Uniqueness"],
    33: ["External Id Uniqueness", "Watchlist Item Validation"],
    34: ["External Id Uniqueness"],
    35: ["External Id Uniqueness"],
    36: ["External Id Uniqueness"],
    39: ["Permissions Matrix"],
    40: ["Permissions Matrix"],
    41: ["Permissions Matrix"],
    42: ["Permissions Matrix"],
    43: ["Permissions Matrix"],
    44: ["Permissions Matrix"],
}


def block(title):
    out, on = [], False
    for line in RAW:
        if re.match(r"^\S.*\(Drupal\\Tests", line):
            on = line.startswith(title)
        if on:
            out.append(line)
    return out


for num, classes in CASES.items():
    lines = [
        f"TC-T09-{num:02d}: extract of the full Kernel run (PU-K --testdox)"
        " on HEAD 83ed38f, 2026-11-05.",
        "Full raw output: docs/tests/T09/evidence/TC-T09-54-kernel.txt",
        "",
    ]
    for c in classes:
        lines += block(c) + [""]
    lines += [line for line in RAW if line.startswith("OK (") or line.startswith("EXIT=")]
    target = EVD / f"TC-T09-{num:02d}-kernel.txt"
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(target.name, len(lines))
