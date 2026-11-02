"""Tests for scripts/check_branch_name.py."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import _helpers
import check_branch_name as cbn

KNOWN = {"T04", "T04a", "T10"}


class BranchTests(unittest.TestCase):
    """check_branch accepts and rejects names."""

    def test_accepts(self) -> None:
        for good in ["main", "task/T04a-coding-standards", "task/T10-ingest", "task/T04-a1-b2"]:
            with self.subTest(good=good):
                self.assertIsNone(cbn.check_branch(good, KNOWN))

    def test_rejects(self) -> None:
        bad_names = [
            "feature/x",
            "master",
            "task/T04a",
            "task/T04a-",
            "task/T04a-Bad-Caps",
            "task/T04a-two--dashes",
            "task/T04a-trailing-",
            "task/t04-x",
            "task/T4-x",
            "task/T10-a_b",
            "task/T10-a/b",
            "HEAD",
            "",
        ]
        for bad in bad_names:
            with self.subTest(bad=bad):
                self.assertIsNotNone(cbn.check_branch(bad, KNOWN))

    def test_unknown_task_id(self) -> None:
        for bad in ["task/T99-x", "task/T05a-x"]:
            self.assertIn("unknown", cbn.check_branch(bad, KNOWN) or "")


class MainTests(unittest.TestCase):
    """main() branch sources: --branch, GITHUB_HEAD_REF, git."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.tasks = Path(self.tmp.name) / "TASKS.md"
        self.tasks.write_text(_helpers.TASKS_MD, encoding="utf-8")

    def test_branch_argument(self) -> None:
        base = ["--tasks-file", str(self.tasks)]
        self.assertEqual(cbn.main([*base, "--branch", "task/T10-ingest"]), 0)
        self.assertEqual(cbn.main([*base, "--branch", "feature/x"]), 1)

    def test_github_head_ref(self) -> None:
        base = ["--tasks-file", str(self.tasks)]
        with mock.patch.dict(os.environ, {"GITHUB_HEAD_REF": "task/T10-ingest"}):
            self.assertEqual(cbn.main(base), 0)
        with mock.patch.dict(os.environ, {"GITHUB_HEAD_REF": "feature/x"}):
            self.assertEqual(cbn.main(base), 1)

    def test_current_branch_fallback(self) -> None:
        base = ["--tasks-file", str(self.tasks)]
        env = {k: v for k, v in os.environ.items() if k != "GITHUB_HEAD_REF"}
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(cbn, "current_branch", return_value="task/T04a-demo"):
                self.assertEqual(cbn.main(base), 0)
            with mock.patch.object(cbn, "current_branch", return_value="feature/bad"):
                self.assertEqual(cbn.main(base), 1)
            with mock.patch.object(cbn, "current_branch", return_value=""):
                self.assertEqual(cbn.main(base), 2)


if __name__ == "__main__":
    unittest.main()
