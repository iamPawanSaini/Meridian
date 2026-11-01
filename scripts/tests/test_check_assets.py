"""Tests for scripts/check_assets.py."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

import _helpers
import check_assets as ca

APP = "apps/web/app"
THEME = "apps/drupal/web/themes/custom/meridian_theme/css"


class LineTests(unittest.TestCase):
    """check_line on single lines."""

    def test_rejects_third_party_hosts(self) -> None:
        bad = [
            '<link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet" />',
            "@font-face { src: url(https://fonts.gstatic.com/s/inter.woff2); }",
            '<script src="https://cdn.jsdelivr.net/npm/x.js"></script>',
            '<script src="https://unpkg.com/x"></script>',
            '@import url("https://cdnjs.cloudflare.com/x.css");',
            '<link rel="stylesheet" href="https://use.fontawesome.com/releases/x.css">',
            '<link href="//fonts.googleapis.com/css" rel="stylesheet" />',
            '<link rel="stylesheet" href="https://example.org/site.css">',
        ]
        for line in bad:
            with self.subTest(line=line):
                self.assertTrue(ca.check_line(line, False))

    def test_rejects_hex_forms(self) -> None:
        for line in ["color: #1a2b3c;", "background: #fff;", "a { color: #1a2b3cff }",
                     'export const s = { color: "#ff0000" };']:
            with self.subTest(line=line):
                self.assertTrue(ca.check_line(line, False))

    def test_accepts_legitimate_use(self) -> None:
        good = [
            "@font-face { src: url(/fonts/inter.woff2); }",
            "body { color: var(--color-fg); }",
            '<a href="#main-content">Skip</a>',
            'export const t = "it&#39;s";',
            '<a href="https://example.org/doc">Docs</a>',
            '<link rel="canonical" href="https://example.org/">',
            '<use href="#icon-add" />',
        ]
        for line in good:
            with self.subTest(line=line):
                self.assertEqual(ca.check_line(line, False), [])

    def test_tokens_file_may_hold_hex(self) -> None:
        self.assertEqual(ca.check_line(":root { --color-bg: #0b1020; }", True), [])
        self.assertTrue(ca.check_line(":root { src: url(https://unpkg.com/x); }", True))


class TreeTests(unittest.TestCase):
    """main() in a throwaway repo."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        cwd = os.getcwd()
        self.addCleanup(os.chdir, cwd)

    def run_with(self, files: dict[str, str]) -> int:
        repo = _helpers.make_repo(Path(tempfile.mkdtemp(dir=self.tmp.name)), files)
        os.chdir(repo)
        return ca.main()

    def test_clean_page_passes(self) -> None:
        self.assertEqual(self.run_with({f"{APP}/layout.tsx": '<a href="/x">x</a>\n'}), 0)

    def test_hex_in_app_and_theme_fails(self) -> None:
        self.assertEqual(self.run_with({f"{APP}/globals.css": "a { color: #123456; }\n"}), 1)
        self.assertEqual(self.run_with({f"{THEME}/base.css": "a { color: #123456; }\n"}), 1)

    def test_tokens_file_is_allowed(self) -> None:
        self.assertEqual(self.run_with({"apps/web/styles/tokens.css": ":root{--a:#0b1020;}\n"}), 0)

    def test_out_of_scope_files_ignored(self) -> None:
        files = {
            "docs/note.md": "https://fonts.googleapis.com/css\n",
            "services/engine/x.py": 'U = "https://fonts.googleapis.com/css"  # #ffffff\n',
        }
        self.assertEqual(self.run_with(files), 0)

    def test_failure_names_file(self) -> None:
        problems = self._problems(f"{APP}/globals.css", "body { color: #1a2b3c; }\n")
        self.assertTrue(problems[0].startswith(f"{APP}/globals.css:1:"))

    def _problems(self, name: str, text: str) -> list[str]:
        repo = _helpers.make_repo(Path(tempfile.mkdtemp(dir=self.tmp.name)), {name: text})
        os.chdir(repo)
        return ca.check_file(name)


if __name__ == "__main__":
    unittest.main()
