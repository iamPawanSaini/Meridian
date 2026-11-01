#!/usr/bin/env python3
"""Check commit messages against the Meridian convention (T04a, decision D-3).

Rules for a subject line:
- `Txx: text` or `Txxa: text`, where the ID is a heading in the tasks file;
- at most 72 characters;
- `Merge ` and `Revert "` subjects are allowed as they are;
- `fixup!` and `squash!` subjects fail (they must be squashed before push).

Usage:
    check_commit_msg.py --msg-file FILE [--tasks-file F]   (commit-msg hook)
    check_commit_msg.py --range A..B [--tasks-file F]      (CI: only the commits a PR adds)

Exit 0 when every message is accepted, 1 when one is rejected, 2 on a usage or read error.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

from taskids import DEFAULT_TASKS_FILE, task_ids

MAX_SUBJECT = 72
_PREFIX = re.compile(r"^(T\d{2}a?): \S")
_AUTOSQUASH = re.compile(r"^(fixup|squash)! ")


def check_subject(subject: str, known: set[str]) -> str | None:
    """Return a reason the subject is rejected, or None when it is accepted."""
    if subject.startswith("Merge ") or subject.startswith('Revert "'):
        return None
    if _AUTOSQUASH.match(subject):
        return "fixup!/squash! commits must be squashed before push"
    match = _PREFIX.match(subject)
    if match is None:
        return "subject must start with a task ID prefix such as 'T04a: ' followed by text"
    if match.group(1) not in known:
        return f"unknown task ID {match.group(1)} (not a heading in the tasks file)"
    if len(subject) > MAX_SUBJECT:
        return f"subject is {len(subject)} characters; the limit is {MAX_SUBJECT}"
    return None


def subject_of(message: str) -> str:
    """Return the first line of a commit message that is not a git comment ('' if none)."""
    for line in message.splitlines():
        if not line.startswith("#"):
            return line
    return ""


def check_range(rev_range: str, known: set[str]) -> list[str]:
    """Check every commit in the range; return one error line per rejected commit."""
    proc = subprocess.run(
        ["git", "log", "--format=%H%x1f%s", rev_range],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"git log {rev_range} failed: {proc.stderr.strip()}")
    errors: list[str] = []
    for line in proc.stdout.splitlines():
        sha, _, subject = line.partition("\x1f")
        reason = check_subject(subject, known)
        if reason is not None:
            errors.append(f"{sha[:8]} {subject!r}: {reason}")
    return errors


def main(argv: list[str] | None = None) -> int:
    """Entry point; returns the process exit code."""
    parser = argparse.ArgumentParser(description="Check commit message subjects.")
    parser.add_argument("--msg-file", help="commit message file (commit-msg hook)")
    parser.add_argument("--range", dest="rev_range", help="git revision range A..B")
    parser.add_argument("--tasks-file", default=DEFAULT_TASKS_FILE)
    args = parser.parse_args(argv)
    if bool(args.msg_file) == bool(args.rev_range):
        print("error: give exactly one of --msg-file or --range", file=sys.stderr)
        return 2
    try:
        known = task_ids(args.tasks_file)
        if args.msg_file:
            with open(args.msg_file, encoding="utf-8") as handle:
                subject = subject_of(handle.read())
            reason = check_subject(subject, known)
            errors = [] if reason is None else [f"{subject!r}: {reason}"]
        else:
            errors = check_range(args.rev_range, known)
    except (OSError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    for error in errors:
        print(f"commit message rejected: {error}")
    if errors:
        print("Format: 'Txx: short summary' (task ID from docs/TASKS.md, subject <= 72 chars).")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
