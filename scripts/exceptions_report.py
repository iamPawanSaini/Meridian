#!/usr/bin/env python3
"""List every lint or type suppression and config path exclude, and require a ticket (T04a).

A suppression (`noqa`, `type: ignore`, `pragma: no cover`, `eslint-disable`,
`@ts-expect-error`, `phpcs:ignore`, `@phpstan-ignore`, and the shellcheck, yamllint,
markdownlint and hadolint directives) and every path exclude in a tool config must cite a
ticket on the same line: `Txx: reason`, `Txxa: reason` or `DEF-nnn: reason`. The ticket must
exist (a heading in docs/TASKS.md or docs/tests/defects.md).

The script scans the tracked and untracked, non-ignored files of the git tree in the current
directory. It prints each violation as `path:line: tool: reason`, writes the per-tool counts
and the tickets used to --out, and exits 1 when any violation is found (2 on a read error).

Usage: exceptions_report.py [--out FILE] [--tasks-file F] [--defects-file F]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

from taskids import DEFAULT_DEFECTS_FILE, DEFAULT_TASKS_FILE, defect_ids, task_ids

# (tool name, regex, markdown only). Sorted by name only when printing.
SUPPRESSIONS: list[tuple[str, str, bool]] = [
    ("noqa", r"#\s*noqa", False),
    ("type: ignore", r"#\s*type:\s*ignore", False),
    ("pragma: no cover", r"#\s*pragma:\s*no cover", False),
    ("eslint-disable", r"(//|/\*)\s*eslint-disable", False),
    ("@ts-expect-error", r"(//|/\*)\s*@ts-expect-error", False),
    ("phpcs:ignore", r"(//|#|/\*)\s*phpcs:ignore", False),
    ("@phpstan-ignore", r"@phpstan-ignore", False),
    ("shellcheck", r"#\s*shellcheck\s+disable", False),
    ("yamllint", r"#\s*yamllint\s+disable", False),
    ("markdownlint", r"^\s*<!--\s*markdownlint-disable", True),
    ("hadolint", r"#\s*hadolint\s+ignore", False),
]
SUPPRESSIONS.append(("@ts-ignore", r"@ts-ignore", False))
_COMPILED = [(name, re.compile(rx), md_only) for name, rx, md_only in SUPPRESSIONS]

# D-4 addendum: the ticket counts only in the tool's own comment slot, after its separator.
_TID = r"(T\d{2}a?|DEF-\d{3}): \S"
_CODES = r"[A-Z]+[0-9]+(?:[,\s]+[A-Z]+[0-9]+)*"
SLOT: dict[str, re.Pattern[str]] = {
    "noqa": re.compile(r"#\s*noqa:\s*" + _CODES + r"\s+#\s*" + _TID),
    "type: ignore": re.compile(r"#\s*type:\s*ignore(?:\[[^\]#]*\])?\s+#\s*" + _TID),
    "pragma: no cover": re.compile(r"#\s*pragma:\s*no cover\s+#\s*" + _TID),
    "eslint-disable": re.compile(r"eslint-disable\S*\s+[^\s-].*?\s--\s+" + _TID),
    "@ts-expect-error": re.compile(r"@ts-expect-error\s+" + _TID),
    "phpcs:ignore": re.compile(r"phpcs:ignore\b.*?\s--\s+" + _TID),
    "@phpstan-ignore": re.compile(r"@phpstan-ignore\s+[^(]*\(\s*" + _TID),
    "shellcheck": re.compile(r"#\s*shellcheck\s+disable=[\w,]+\s+#\s*" + _TID),
    "hadolint": re.compile(r"#\s*hadolint\s+ignore=[\w,]+\s+#\s*" + _TID),
    "markdownlint": re.compile(r"-->.*<!--\s*" + _TID),
    "config exclude": re.compile(r"(?:#|//)\s*" + _TID),
}
_NOQA_CODE = re.compile(r"#\s*noqa:\s*[A-Z]+[0-9]+")
_ESLINT_RULE = re.compile(r"eslint-disable\S*\s+[^\s-]")
_FORBIDDEN = {
    "yamllint": "inline yamllint disables are not allowed (use ignore: in .yamllint.yaml)",
    "@ts-ignore": "@ts-ignore is forbidden (use @ts-expect-error with a ticket)",
}


def classify(tool: str, line: str) -> tuple[str | None, str | None]:
    """Return (ticket ID, None) when the tool's ticket slot is filled, else (None, problem).

    A ticket anywhere else on the line (the bare form) does not count.
    """
    if tool in _FORBIDDEN:
        return None, _FORBIDDEN[tool]
    if tool == "noqa" and not _NOQA_CODE.search(line):
        return None, "noqa without a rule code (use 'noqa: CODE  # Txx: reason')"
    if tool == "eslint-disable" and not _ESLINT_RULE.search(line):
        return None, "eslint-disable names no rule"
    match = SLOT[tool].search(line)
    if match is not None:
        return match.group(1), None
    if TICKET.search(line):
        return None, "ticket is not in the tool's comment slot (bare form); see the D-4 addendum"
    return None, "no ticket (expected 'Txx: reason' in the comment slot)"


CODE_FILE = re.compile(
    r"\.(py|sh|bash|ts|tsx|js|jsx|mjs|cjs|php|module|inc|theme|install|ya?ml|toml|ini|cfg"
    r"|neon|md)$|(^|/)Dockerfile"
)
# T04a: these files quote the directives on purpose (the checker, its tests, the T04a test
# design and reference models); captured output under evidence/ is not authored code.
# T04a: task records (plans, decisions, reviews) quote examples, including invalid forms.
SKIP_PATH = re.compile(
    r"^(scripts/exceptions_report\.py|scripts/tests/|docs/tasks/"
    r"|docs/tests/T04a/(run-checks\.sh|test-cases\.md|test-report\.md|reference/)"
    r"|docs/tests/[^/]+/evidence/)"
)
CONFIG_FILE = re.compile(
    r"(^|/)(ruff\.toml|\.ruff\.toml|pyproject\.toml|mypy\.ini|setup\.cfg|\.coveragerc"
    r"|\.yamllint\.ya?ml|\.markdownlint-cli2\.(ya?ml|jsonc?)|phpcs\.xml(\.dist)?"
    r"|phpstan\.neon(\.dist)?|eslint\.config\.m?js|tsconfig[^/]*\.json|\.prettierrc[^/]*"
    r"|\.pre-commit-config\.yaml|\.gitleaks\.toml|\.shellcheckrc|\.hadolint\.ya?ml"
    r"|\.spectral\.ya?ml)$"
)
EXCLUDE_KEY = re.compile(
    r"""^(?P<indent>\s*)(?P<key>"?(?:extend-)?(?:exclude|excludes|ignore|ignores|ignorePatterns"""
    r"""|per-file-ignores|extend-per-file-ignores|excludePaths|disable|ignored)"?)"""
    r"""\s*(?P<sep>[=:])(?P<rest>.*)$"""
)
# gitleaks allowlist paths, and Spectral rules switched off (`rule-name: off`).
ALLOWLIST_PATHS = re.compile(r"^\s*paths\s*=")
RULE_OFF = re.compile(r"""^\s*["']?[\w:./-]+["']?\s*:\s*["']?(off|disable)["']?\s*(#.*)?$""")
XML_EXCLUDE = re.compile(r"<\s*exclude(-pattern)?\b")
TICKET = re.compile(r"\b(T\d{2}a?|DEF-\d{3}): \S")
_OPENERS = {"", "[", "{", "|", ">", "|-", ">-", "|+", ">+"}


def tracked_files() -> list[str]:
    """Return tracked plus untracked, non-ignored files of the git tree in the cwd."""
    proc = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"git ls-files failed: {proc.stderr.strip()}")
    return [name for name in proc.stdout.splitlines() if name]


def strip_comment(text: str) -> str:
    """Return the text with a trailing `#` comment removed (naive, enough for the openers)."""
    return text.split("#", 1)[0].strip()


def config_exclude_lines(lines: list[str]) -> list[int]:
    """Return the 1-based numbers of config lines that exclude a path and so need a ticket."""
    needing: list[int] = []
    block_indent: int | None = None  # indent of a YAML key whose items follow
    in_array = False  # inside a TOML or JSON array that started on an earlier line
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())
        if in_array:
            if stripped and not stripped.startswith("#") and stripped not in ("]", "],", "}"):
                needing.append(number)
            if "]" in stripped:
                in_array = False
            continue
        if block_indent is not None:
            is_item = stripped.startswith("- ") or indent > block_indent
            if stripped == "" or stripped.startswith("#"):
                continue
            if is_item:
                needing.append(number)
                continue
            block_indent = None
        if XML_EXCLUDE.search(line) or RULE_OFF.match(line):
            needing.append(number)
            continue
        match = EXCLUDE_KEY.match(line)
        if match is None and ALLOWLIST_PATHS.match(line):
            match = EXCLUDE_KEY.match(line.replace("paths", "exclude", 1))
        if match is None:
            continue
        rest = strip_comment(match.group("rest"))
        if rest in _OPENERS:
            if "[" in rest or "{" in rest:
                in_array = True
            else:
                block_indent = len(match.group("indent"))
            continue
        needing.append(number)
        if rest.count("[") > rest.count("]"):
            in_array = True
    return needing


def scan_file(path: str, valid: set[str]) -> tuple[Counter[str], Counter[str], list[str]]:
    """Return (tool counts, ticket counts, violations) for one file."""
    try:
        lines = Path(path).read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return Counter(), Counter(), []
    counts: Counter[str] = Counter()
    tickets: Counter[str] = Counter()
    problems: list[str] = []
    is_md = path.endswith(".md")

    def judge(number: int, tool: str) -> None:
        counts[tool] += 1
        ticket, problem = classify(tool, lines[number - 1])
        if problem is not None:
            problems.append(f"{path}:{number}: {tool}: {problem}")
        elif ticket is not None and ticket in valid:
            tickets[ticket] += 1
        else:
            problems.append(f"{path}:{number}: {tool}: unknown ticket {ticket}")

    for number, line in enumerate(lines, 1):
        for tool, rx, md_only in _COMPILED:
            if md_only and not is_md:
                continue
            if rx.search(line):
                judge(number, tool)
    if CONFIG_FILE.search(path):
        for number in config_exclude_lines(lines):
            judge(number, "config exclude")
    return counts, tickets, problems


def build_report(counts: Counter[str], tickets: Counter[str]) -> str:
    """Format the per-tool counts and ticket usage."""
    out = ["Suppression and exclude report (scripts/exceptions_report.py)", ""]
    for tool in sorted(counts):
        out.append(f"{tool}: {counts[tool]}")
    out.append(f"total: {sum(counts.values())}")
    out.append("")
    for ticket in sorted(tickets):
        out.append(f"ticket {ticket}: {tickets[ticket]}")
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    """Entry point; returns the process exit code."""
    parser = argparse.ArgumentParser(description="Require a ticket on every suppression.")
    parser.add_argument("--out", help="write the counts report to this file")
    parser.add_argument("--tasks-file", default=DEFAULT_TASKS_FILE)
    parser.add_argument("--defects-file", default=DEFAULT_DEFECTS_FILE)
    args = parser.parse_args(argv)
    try:
        valid = task_ids(args.tasks_file) | defect_ids(args.defects_file)
        files = tracked_files()
    except (OSError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    counts: Counter[str] = Counter()
    tickets: Counter[str] = Counter()
    problems: list[str] = []
    for path in files:
        if SKIP_PATH.match(path):
            continue
        if not (CODE_FILE.search(path) or CONFIG_FILE.search(path)):
            continue
        c, t, p = scan_file(path, valid)
        counts.update(c)
        tickets.update(t)
        problems.extend(p)
    report = build_report(counts, tickets)
    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
    for problem in problems:
        print(problem)
    print(report, end="")
    if problems:
        print(f"{len(problems)} suppression(s) without a valid ticket")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
