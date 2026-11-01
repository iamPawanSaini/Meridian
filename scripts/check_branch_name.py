#!/usr/bin/env python3
"""Check that a branch is `main` or `task/Txx-slug` with a known task ID (T04a).

The branch comes from --branch, else $GITHUB_HEAD_REF (CI), else the current git branch.
Exit 0 when accepted, 1 when rejected, 2 when the branch or tasks file cannot be read.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

from taskids import DEFAULT_TASKS_FILE, task_ids

_BRANCH = re.compile(r"^task/(T\d{2}a?)-[a-z0-9]+(-[a-z0-9]+)*$")


def check_branch(branch: str, known: set[str]) -> str | None:
    """Return a reason the branch name is rejected, or None when it is accepted."""
    if branch == "main":
        return None
    match = _BRANCH.match(branch)
    if match is None:
        return "must be 'main' or 'task/Txx-slug' (lower-case words joined by single dashes)"
    if match.group(1) not in known:
        return f"unknown task ID {match.group(1)} (not a heading in the tasks file)"
    return None


def current_branch() -> str:
    """Return the checked-out branch name, or '' when it cannot be determined."""
    proc = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    return proc.stdout.strip() if proc.returncode == 0 else ""


def main(argv: list[str] | None = None) -> int:
    """Entry point; returns the process exit code."""
    parser = argparse.ArgumentParser(description="Check the branch naming convention.")
    parser.add_argument("--branch", help="branch name (default: $GITHUB_HEAD_REF, then git)")
    parser.add_argument("--tasks-file", default=DEFAULT_TASKS_FILE)
    args = parser.parse_args(argv)
    branch = args.branch or os.environ.get("GITHUB_HEAD_REF") or current_branch()
    if not branch:
        print("error: cannot determine the branch name", file=sys.stderr)
        return 2
    try:
        known = task_ids(args.tasks_file)
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    reason = check_branch(branch, known)
    if reason is not None:
        print(f"branch name rejected: {branch!r}: {reason}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
