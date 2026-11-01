"""Shared lookups for the quality scripts: valid task IDs and defect IDs.

Task IDs are the `## Txx: title` headings of docs/TASKS.md. Defect IDs are the `DEF-nnn`
headings of docs/tests/defects.md. Python 3.10, stdlib only.
"""

from __future__ import annotations

import re
from pathlib import Path

DEFAULT_TASKS_FILE = "docs/TASKS.md"
DEFAULT_DEFECTS_FILE = "docs/tests/defects.md"

_TASK_HEADING = re.compile(r"^#{1,6}\s+(T\d{2}a?)\b", re.MULTILINE)
_DEFECT_HEADING = re.compile(r"^#{1,6}\s+(DEF-\d{3})\b", re.MULTILINE)


def task_ids(tasks_file: str = DEFAULT_TASKS_FILE) -> set[str]:
    """Return the task IDs that are headings in the tasks file.

    Raises OSError when the file cannot be read, so callers can report it.
    """
    text = Path(tasks_file).read_text(encoding="utf-8")
    return set(_TASK_HEADING.findall(text))


def defect_ids(defects_file: str = DEFAULT_DEFECTS_FILE) -> set[str]:
    """Return the defect IDs that are headings in the defects file (empty if absent)."""
    try:
        text = Path(defects_file).read_text(encoding="utf-8")
    except OSError:
        return set()
    return set(_DEFECT_HEADING.findall(text))
