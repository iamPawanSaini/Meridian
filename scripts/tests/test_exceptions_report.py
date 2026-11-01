"""Tests for scripts/exceptions_report.py."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

import _helpers
import exceptions_report as er


class ScanTests(unittest.TestCase):
    """Run main() inside throwaway repos."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        cwd = os.getcwd()
        self.addCleanup(os.chdir, cwd)
        self.root = Path(self.tmp.name)

    def run_with(self, files: dict[str, str]) -> tuple[int, str]:
        repo = _helpers.make_repo(self.root / "r", files)
        os.chdir(repo)
        out = repo / "report.txt"
        code = er.main(["--out", str(out)])
        return code, out.read_text(encoding="utf-8")

    def test_clean_tree_passes(self) -> None:
        code, report = self.run_with({"ok.py": "x: int = 1\n"})
        self.assertEqual(code, 0)
        self.assertIn("total: 0", report)

    def test_untagged_suppression_fails(self) -> None:
        code, _ = self.run_with({"a.py": "import os  # " + "noqa: F401\n"})
        self.assertEqual(code, 1)

    def test_tagged_suppressions_are_counted(self) -> None:
        text = (
            "import os  # " + "noqa: F401  T32: legacy\n"
            "import sys  # " + "noqa: F401  DEF-001: stub\n"
        )
        code, report = self.run_with({"a.py": text})
        self.assertEqual(code, 0)
        self.assertIn("noqa: 2", report)
        self.assertIn("ticket T32: 1", report)
        self.assertIn("ticket DEF-001: 1", report)

    def test_ticket_rules(self) -> None:
        marker = "import os  # " + "noqa: F401"
        bad = [
            marker + "  DEF-999: x",
            marker + "  T99: x",
            marker + "  T32",
            marker + "  T32:x",
            marker + "  t32: x",
        ]
        for text in bad:
            with self.subTest(text=text):
                tmp = Path(tempfile.mkdtemp(dir=self.tmp.name))
                repo = _helpers.make_repo(tmp, {"a.py": text + "\n"})
                os.chdir(repo)
                self.assertEqual(er.main([]), 1)

    def test_ticket_on_another_line_does_not_count(self) -> None:
        text = "# T32: reason\nimport os  # " + "noqa: F401\n"
        self.assertEqual(self.run_with({"a.py": text})[0], 1)

    def test_every_tool_recognised(self) -> None:
        names = {name for name, _, _ in er.SUPPRESSIONS}
        self.assertEqual(len(names), 11)

    def test_markdown_directive_only_in_markdown(self) -> None:
        directive = "<!-- " + "markdownlint-disable MD013 -->"
        self.assertEqual(self.run_with({"j.md": directive + "\n"})[0], 1)

    def test_failure_names_file_and_line(self) -> None:
        text = "a = 1\nimport os  # " + "noqa\n"
        repo = _helpers.make_repo(self.root / "n", {"pkg/mod.py": text})
        os.chdir(repo)
        self.assertEqual(er.main([]), 1)
        _, _, problems = er.scan_file("pkg/mod.py", {"T32"})
        self.assertTrue(problems[0].startswith("pkg/mod.py:2:"))


class ConfigExcludeTests(unittest.TestCase):
    """config_exclude_lines finds path excludes that need a ticket."""

    def test_inline_exclude(self) -> None:
        self.assertEqual(er.config_exclude_lines(['exclude = ["docs/x"]']), [1])

    def test_yaml_ignores_block(self) -> None:
        lines = ["ignores:", '  - "docs/TASKS.md"', '  - "b"', "other: 1"]
        self.assertEqual(er.config_exclude_lines(lines), [2, 3])

    def test_toml_array_block(self) -> None:
        lines = ["exclude = [", '  "a",', '  "b",', "]", "line-length = 100"]
        self.assertEqual(er.config_exclude_lines(lines), [2, 3])

    def test_unrelated_keys_ignored(self) -> None:
        lines = ["line-length = 100", "per-file-target-version = 1", "ignore_code_blocks: 1"]
        self.assertEqual(er.config_exclude_lines(lines), [])

    def test_config_exclude_requires_ticket(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            os.chdir(tmp)
            Path("ruff.toml").write_text('exclude = ["a"]  # T32: legacy\nextend-exclude = ["b"]\n')
            _, tickets, problems = er.scan_file("ruff.toml", {"T32"})
            self.assertEqual(tickets["T32"], 1)
            self.assertEqual(len(problems), 1)
            os.chdir("/")


if __name__ == "__main__":
    unittest.main()
