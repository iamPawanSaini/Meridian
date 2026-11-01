"""Shared helpers for the script tests: scripts on sys.path and a throwaway git repo."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

TASKS_MD = "## T04: x\n## T04a: y\n## T10: z\n## T32: w\n"
DEFECTS_MD = "# Defects\n\n### DEF-001: fixture\n"


def git(repo: Path, *args: str) -> str:
    """Run git in the repo and return stdout."""
    proc = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True, check=True
    )
    return proc.stdout


def make_repo(root: Path, files: dict[str, str]) -> Path:
    """Create a git repo under root with the fixture task and defect files plus `files`."""
    root.mkdir(parents=True, exist_ok=True)
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "t@example.invalid")
    git(root, "config", "user.name", "t")
    git(root, "config", "commit.gpgsign", "false")
    contents = {"docs/TASKS.md": TASKS_MD, "docs/tests/defects.md": DEFECTS_MD, **files}
    for name, text in contents.items():
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "Initial commit")
    return root
