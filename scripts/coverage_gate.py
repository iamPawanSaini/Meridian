#!/usr/bin/env python3
"""Check Cobertura XML line coverage against per-component floors (T04a, decision D-1).

The thresholds file lists components: `{"components": [{"path": "<prefix>", "line": 90}]}`.
For each component, the lines of every file whose path contains the prefix are pooled and
the line rate must be at least the floor (inclusive). Branch rate is never read. A file
under a deeper prefix also counts towards the shallower ones (for example a file in
`meridian_engine/scoring/` counts for `meridian_engine/` too).

The gate fails, naming the files, when a component is under its floor, when the report has
no lines at all, when no component matches any file, or when an input cannot be read.

A component that matches no file prints `not measured: PREFIX`. Each component step names the
prefixes it must measure with --require PREFIX (repeatable); an unmatched one fails the gate.
The "line" value is always a percentage.

Usage: coverage_gate.py [--thresholds F] [--require PREFIX ...] COBERTURA.xml [...]
Exit 0 when every measured component meets its floor, else 1.
"""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

DEFAULT_THRESHOLDS = "quality/coverage-thresholds.json"
EPSILON = 1e-9

# filename -> {line number -> hits}
Coverage = dict[str, dict[int, int]]


def load_coverage(paths: list[str]) -> Coverage:
    """Read Cobertura files and merge them into per-file line hits (max hits per line)."""
    coverage: Coverage = {}
    for path in paths:
        root = ET.parse(path).getroot()
        for cls in root.iter("class"):
            name = (cls.get("filename") or "").replace("\\", "/")
            if not name:
                continue
            lines = coverage.setdefault(name, {})
            for line in cls.iter("line"):
                number = int(line.get("number", "0"))
                hits = int(line.get("hits", "0"))
                lines[number] = max(lines.get(number, 0), hits)
    return coverage


def load_thresholds(path: str) -> list[tuple[str, float]]:
    """Return (path prefix, floor as a fraction) pairs from the thresholds file."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    result: list[tuple[str, float]] = []
    for item in data["components"]:
        # "line" is always a percentage (a floor of 1 means 1%, not 100%).
        result.append((str(item["path"]), float(item["line"]) / 100))
    return result


def matches(filename: str, prefix: str) -> bool:
    """True when the file path contains the prefix at a path-segment boundary."""
    return ("/" + filename).find("/" + prefix.lstrip("/")) != -1


def rate(lines: dict[int, int]) -> float:
    """Fraction of the lines with at least one hit (1.0 for no lines)."""
    if not lines:
        return 1.0
    return sum(1 for hits in lines.values() if hits > 0) / len(lines)


def evaluate(
    coverage: Coverage,
    thresholds: list[tuple[str, float]],
    required: list[str] | None = None,
) -> list[str]:
    """Return one failure message per problem; an empty list means the gate passes.

    Every required prefix must match at least one file. Other unmatched components print a
    `not measured` line and are skipped.
    """
    measured = {name: lines for name, lines in coverage.items() if lines}
    if not measured:
        return ["coverage report contains no measured lines"]
    failures: list[str] = []
    matched_any = False
    for prefix, floor in thresholds:
        selected = {n: ln for n, ln in measured.items() if matches(n, prefix)}
        if not selected:
            print(f"coverage gate: not measured: {prefix}")
            continue
        matched_any = True
        pooled = sum(len(ln) for ln in selected.values())
        covered = sum(1 for ln in selected.values() for h in ln.values() if h > 0)
        actual = covered / pooled
        if actual + EPSILON < floor:
            worst = sorted(selected, key=lambda n: rate(selected[n]))
            detail = ", ".join(f"{n} {rate(selected[n]) * 100:.1f}%" for n in worst[:10])
            failures.append(
                f"{prefix}: line coverage {actual * 100:.1f}% is below the {floor * 100:.0f}% "
                f"floor (files: {detail})"
            )
    if not matched_any:
        failures.append("no file in the report matches any configured component")
    for prefix in required or []:
        if not any(matches(name, prefix) for name in measured):
            failures.append(f"required prefix {prefix} matches no file in the report")
    return failures


def main(argv: list[str] | None = None) -> int:
    """Entry point; returns the process exit code."""
    parser = argparse.ArgumentParser(description="Gate Cobertura line coverage on floors.")
    parser.add_argument("--thresholds", default=DEFAULT_THRESHOLDS)
    parser.add_argument(
        "--require",
        action="append",
        default=[],
        metavar="PREFIX",
        help="path prefix that must match at least one file (repeatable)",
    )
    parser.add_argument("xml", nargs="+", help="Cobertura XML file(s)")
    args = parser.parse_args(argv)
    try:
        thresholds = load_thresholds(args.thresholds)
        coverage = load_coverage(args.xml)
    except (OSError, ET.ParseError, ValueError, KeyError, TypeError) as exc:
        print(f"coverage gate cannot read its input: {exc}")
        return 1
    failures = evaluate(coverage, thresholds, args.require)
    for failure in failures:
        print(f"coverage gate FAILED: {failure}")
    if not failures:
        print("coverage gate: all measured components meet their floors")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
