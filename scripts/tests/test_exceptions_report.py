"""Tests for scripts/exceptions_report.py."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

import _helpers
import exceptions_report as er

# Directive text is built from pieces so this file holds no real suppression comment.
H = "# "
NOQA = H + "noqa"
TYPE_IGNORE = H + "type: " + "ignore"
SLASH = "// "


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
        code, _ = self.run_with({"a.py": f"import os  {NOQA}: F401\n"})
        self.assertEqual(code, 1)

    def test_tagged_suppressions_are_counted(self) -> None:
        text = (
            f"import os  {NOQA}: F401  {H}T32: legacy\nimport sys  {NOQA}: F401  {H}DEF-001: stub\n"
        )
        code, report = self.run_with({"a.py": text})
        self.assertEqual(code, 0)
        self.assertIn("noqa: 2", report)
        self.assertIn("ticket T32: 1", report)
        self.assertIn("ticket DEF-001: 1", report)

    def test_ticket_rules(self) -> None:
        marker = f"import os  {NOQA}: F401  {H}"
        bad = [
            marker + "DEF-999: x",
            marker + "T99: x",
            marker + "T32",
            marker + "T32:x",
            marker + "t32: x",
        ]
        for text in bad:
            with self.subTest(text=text):
                tmp = Path(tempfile.mkdtemp(dir=self.tmp.name))
                repo = _helpers.make_repo(tmp, {"a.py": text + "\n"})
                os.chdir(repo)
                self.assertEqual(er.main([]), 1)

    def test_bare_form_now_fails(self) -> None:
        bare = {
            "noqa": f"import os  {NOQA}: F401  T32: legacy",
            "type: ignore": f"x: int = 'a'  {TYPE_IGNORE}[assignment]  T32: legacy",
            "eslint-disable": f"{SLASH}eslint-disable-next-line no-console T32: legacy",
            "phpcs:ignore": f"{SLASH}phpcs:ignore Drupal.Commenting T32: legacy",
            "shellcheck": f"{H}shellcheck disable=SC2086  T32: legacy",
        }
        for tool, text in bare.items():
            with self.subTest(tool=tool):
                ticket, problem = er.classify(tool, text)
                self.assertIsNone(ticket)
                self.assertIn("bare form", problem or "")
        code, _ = self.run_with({"a.py": bare["noqa"] + "\n"})
        self.assertEqual(code, 1)

    def test_corrected_forms_pass(self) -> None:
        forms = {
            "noqa": f"x = call()  {NOQA}: S603  {H}T32: fixed argument list",
            "type: ignore": f"import yaml  {TYPE_IGNORE}[import-untyped]  {H}T32: stubs later",
            "pragma: no cover": f"if debug:  {H}pragma: no cover  {H}T32: debug only",
            "eslint-disable": f"{SLASH}eslint-disable-next-line no-console -- T32: logger",
            "@ts-expect-error": f"{SLASH}@ts-expect-error T32: upstream type",
            "phpcs:ignore": f"{SLASH}phpcs:ignore Drupal.Commenting.X -- T32: reason",
            "@phpstan-ignore": f"{SLASH}@phpstan-ignore method.notFound (T32: stub)",
            "shellcheck": f"{H}shellcheck disable=SC2034 {H}T32: read by caller",
            "hadolint": f"{H}hadolint ignore=DL3008 {H}T32: distro pins",
            "markdownlint": "<!-- markdownlint-disable-next-line MD013 --> <!-- T32: wording -->",
        }
        for tool, text in forms.items():
            with self.subTest(tool=tool):
                self.assertEqual(er.classify(tool, text), ("T32", None))

    def test_forbidden_and_incomplete_forms(self) -> None:
        self.assertIsNotNone(er.classify("noqa", f"import os  {NOQA}  {H}T32: x")[1])
        self.assertIsNotNone(er.classify("eslint-disable", f"{SLASH}eslint-disable -- T32: x")[1])
        yl = f"{H}yamllint disable-line rule:line-length"
        self.assertIsNotNone(er.classify("yamllint", yl + f" {H}T32: x")[1])
        self.assertIsNotNone(er.classify("@ts-ignore", SLASH + "@ts-" + "ignore")[1])

    def test_task_records_may_quote_invalid_forms(self) -> None:
        bare = f"import os  {NOQA}: F401  T32: legacy\n"
        code, report = self.run_with({"docs/tasks/T04a/notes.md": bare})
        self.assertEqual(code, 0)
        self.assertIn("total: 0", report)
        self.assertTrue(er.SKIP_PATH.match("docs/tasks/T04a/review.md"))
        self.assertFalse(er.SKIP_PATH.match("docs/standards/CODING_STANDARDS.md"))
        self.assertEqual(self.run_with_new({"docs/standards/x.md": bare})[0], 1)

    def run_with_new(self, files: dict[str, str]) -> tuple[int, str]:
        self.root = Path(tempfile.mkdtemp(dir=self.tmp.name))
        return self.run_with(files)

    def test_ticket_on_another_line_does_not_count(self) -> None:
        text = f"# T32: reason\nimport os  {NOQA}: F401\n"
        self.assertEqual(self.run_with({"a.py": text})[0], 1)

    def test_every_tool_recognised(self) -> None:
        names = {name for name, _, _ in er.SUPPRESSIONS}
        self.assertEqual(len(names), 12)

    def test_markdown_directive_only_in_markdown(self) -> None:
        directive = "<!-- " + "markdownlint-disable MD013 -->"
        self.assertEqual(self.run_with({"j.md": directive + "\n"})[0], 1)

    def test_failure_names_file_and_line(self) -> None:
        text = f"a = 1\nimport os  {NOQA}\n"
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

    def test_more_config_files_are_covered(self) -> None:
        for name in [
            ".pre-commit-config.yaml",
            ".gitleaks.toml",
            ".shellcheckrc",
            ".hadolint.yaml",
            ".spectral.yaml",
        ]:
            with self.subTest(name=name):
                self.assertIsNotNone(er.CONFIG_FILE.search(name))
        self.assertEqual(er.config_exclude_lines(["disable=SC1090"]), [1])
        self.assertEqual(er.config_exclude_lines(["ignored:", "  - DL3008"]), [2])
        self.assertEqual(er.config_exclude_lines(["paths = ['x']"]), [1])
        self.assertEqual(er.config_exclude_lines(["  some-rule: off"]), [1])

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
