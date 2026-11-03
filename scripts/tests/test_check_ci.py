"""Tests for scripts/check_ci.py: one passing and one failing fixture per rule (T08, KD-6)."""

from __future__ import annotations

import ast
import contextlib
import io
import shutil
import tempfile
import unittest
from pathlib import Path

import _helpers  # noqa: F401  # T08: puts scripts/ on sys.path
import check_ci

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "ci"
GOOD = FIXTURES / "good"
BAD = FIXTURES / "bad"
HEAVIER_FAIL = "heavier-set tests exist but ci.yml has no heavier-* job (decision-heavier-set.md)"


class Tree:
    """A temp copy of the good fixture set that a test can edit."""

    def __init__(self, tmp: Path) -> None:
        self.base = tmp / "t"
        shutil.copytree(GOOD, self.base)
        self.root = tmp / "empty-root"
        self.root.mkdir()

    def use(self, bad_name: str) -> None:
        shutil.copy(BAD / bad_name, self.base / "workflows" / "ci.yml")

    def edit(self, rel: str, old: str, new: str) -> None:
        path = self.base / rel
        text = path.read_text(encoding="utf-8")
        if old not in text:
            raise AssertionError(f"{old!r} not in {rel}")
        path.write_text(text.replace(old, new), encoding="utf-8")

    def run(self, *extra: str) -> tuple[int, str]:
        args = [
            "--workflows", str(self.base / "workflows"),
            "--secrets-doc", str(self.base / "ci-secrets.md"),
            "--ddev-dir", str(self.base / "ddev"),
            "--pantheon-config", str(self.base / "pantheon.yml"),
            "--github-readme", str(self.base / "github-readme.md"),
            "--root", str(self.root),
            *extra,
        ]  # fmt: skip
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = check_ci.main(args)
        return code, out.getvalue()


class CheckCiTestCase(unittest.TestCase):
    """Common setup."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tree = Tree(Path(tmp.name))

    def assertFails(self, rule: int, needle: str, code_out: tuple[int, str]) -> None:
        code, out = code_out
        self.assertEqual(code, 1, out)
        self.assertIn(f"FAIL  rule {rule}", out)
        self.assertIn(needle, out)


class GoodTreeTests(CheckCiTestCase):
    """TC-T08-32: The good fixture set and the real repository pass."""

    def test_good_fixture_passes_every_rule(self) -> None:
        code, out = self.tree.run()
        self.assertEqual(code, 0, out)
        self.assertEqual(out.count("PASS  rule"), 6)

    def test_real_repository_passes(self) -> None:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = check_ci.main([])
        self.assertEqual(code, 0, out.getvalue())

    def test_standard_library_only(self) -> None:
        tree = ast.parse(Path(check_ci.__file__).read_text(encoding="utf-8"))
        names = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names |= {a.name.split(".")[0] for a in node.names}
            elif isinstance(node, ast.ImportFrom) and node.module:
                names.add(node.module.split(".")[0])
        self.assertTrue(
            names <= {"argparse", "re", "shlex", "subprocess", "sys", "pathlib", "__future__"},
            names,
        )


class Rule1Tests(CheckCiTestCase):
    """TC-T08-33: Rule 1, group coverage."""

    def test_missing_group(self) -> None:
        self.tree.use("group-missing.yml")
        self.assertFails(1, "group 'docs'", self.tree.run())

    def test_group_called_twice(self) -> None:
        self.tree.use("group-twice.yml")
        self.assertFails(1, "group 'core' is called 2 times", self.tree.run())

    def test_unknown_group(self) -> None:
        self.tree.use("group-unknown.yml")
        self.assertFails(1, "unknown group 'nosuch'", self.tree.run())

    def test_groups_come_from_the_quality_listing(self) -> None:
        stub = self.tree.base / "quality-stub.sh"
        stub.write_text("#!/bin/sh\nprintf 'core\\ta\\nextra\\tb\\n'\n", encoding="utf-8")
        stub.chmod(0o755)
        self.assertFails(1, "group 'extra'", self.tree.run("--quality", str(stub)))

    def test_missing_workflow(self) -> None:
        (self.tree.base / "workflows" / "ci.yml").unlink()
        self.assertFails(1, "ci.yml not found", self.tree.run())


class Rule2Tests(CheckCiTestCase):
    """TC-T08-34: Rule 2, toolchain parity."""

    def test_php_mismatch_with_ci(self) -> None:
        self.tree.use("php-mismatch.yml")
        self.assertFails(
            2, "ci.yml php-version 8.2 differs from .ddev/config.yaml 8.3", self.tree.run()
        )

    def test_php_mismatch_in_ddev_and_pantheon(self) -> None:
        self.tree.edit("ddev/config.yaml", '"8.3"', '"8.4"')
        self.assertFails(2, ".ddev/config.yaml 8.4", self.tree.run())
        self.tree.edit("ddev/config.yaml", '"8.4"', '"8.3"')
        self.tree.edit("pantheon.yml", "8.3", "8.2")
        self.assertFails(2, "apps/drupal/pantheon.yml 8.2", self.tree.run())

    def test_composer_mismatch_and_missing_record(self) -> None:
        self.tree.use("composer-mismatch.yml")
        self.assertFails(
            2, "composer: ci.yml 2.0.0 differs from the DDEV version 2.11.1", self.tree.run()
        )
        self.tree.edit("github-readme.md", "DDEV Composer version", "Something else")
        self.assertFails(2, "no 'DDEV Composer version: X.Y.Z' line", self.tree.run())

    def test_composer_record_needs_a_date(self) -> None:
        self.tree.edit("github-readme.md", ", checked 2026-11-03", "")
        self.assertFails(2, "no 'DDEV Composer version", self.tree.run())

    def test_python_and_node_versions_checked_once_present(self) -> None:
        self.tree.edit(
            "workflows/ci.yml",
            "  engine:\n    name: engine\n    runs-on: ubuntu-24.04\n",
            "  engine:\n    name: engine\n    runs-on: ubuntu-24.04\n"
            "    env:\n      python-version: '3.11.1'\n",
        )
        self.assertFails(
            2,
            "python: ci.yml engine job python-version 3.11.1 differs from image 3.12.16",
            self.tree.run(),
        )
        self.tree.edit("workflows/ci.yml", "3.11.1", "3.12.16")
        self.assertEqual(self.tree.run()[0], 0)
        self.tree.edit(
            "workflows/ci.yml",
            "  web:\n    name: web\n    runs-on: ubuntu-24.04\n",
            "  web:\n    name: web\n    runs-on: ubuntu-24.04\n"
            "    env:\n      node-version: '22.1.0'\n",
        )
        self.assertFails(
            2,
            "node: ci.yml web job node-version 22.1.0 differs from image 22.23.4",
            self.tree.run(),
        )


class Rule3Tests(CheckCiTestCase):
    """TC-T08-35: Rule 3, action pins and comments."""

    def test_unpinned_short_branch_and_missing_comment_fail(self) -> None:
        for name, needle in (
            ("unpinned.yml", "not owner/repo@<40 hex"),
            ("short-sha.yml", "not owner/repo@<40 hex"),
            ("branch-ref.yml", "not owner/repo@<40 hex"),
            ("no-comment.yml", "no '# owner/repo vX.Y.Z' comment"),
        ):
            with self.subTest(name=name):
                self.tree.use(name)
                self.assertFails(3, needle, self.tree.run())

    def test_wrong_comment_repo_fails(self) -> None:
        self.tree.edit(
            "workflows/ci.yml", "# shivammathur/setup-php 2.40.0", "# actions/cache 2.40.0"
        )
        self.assertFails(3, "comment names actions/cache", self.tree.run())

    def test_local_action_is_allowed(self) -> None:
        self.tree.edit(
            "workflows/other.yml", "      - env:", "      - uses: ./local-action\n      - env:"
        )
        self.assertEqual(self.tree.run()[0], 0)

    def test_failure_names_file_and_line(self) -> None:
        self.tree.use("unpinned.yml")
        self.assertIn("ci.yml:", self.tree.run()[1])


class Rule4Tests(CheckCiTestCase):
    """TC-T08-39: Rule 4, secret and variable names."""

    def test_undocumented_secret_and_variable_fail(self) -> None:
        shutil.copy(BAD / "undocumented-secret.yml", self.tree.base / "workflows" / "x.yml")
        code, out = self.tree.run()
        self.assertFails(4, "'NEW_UNLISTED_NAME'", (code, out))
        self.assertIn("'NEW_UNLISTED_VAR'", out)

    def test_github_token_is_exempt(self) -> None:
        # other.yml already uses secrets.GITHUB_TOKEN and the good doc does not name it.
        self.assertNotIn("GITHUB_TOKEN", (self.tree.base / "ci-secrets.md").read_text())
        self.assertEqual(self.tree.run()[0], 0)

    def test_missing_doc_fails(self) -> None:
        (self.tree.base / "ci-secrets.md").unlink()
        self.assertFails(4, "not found", self.tree.run())

    def test_names_in_comments_are_ignored(self) -> None:
        self.tree.edit("workflows/other.yml", "jobs:", "# uses secrets.COMMENTED_ONLY\njobs:")
        self.assertEqual(self.tree.run()[0], 0)


class Rule5Tests(CheckCiTestCase):
    """TC-T08-37: Rule 5, least privilege."""

    def test_missing_top_level_permissions(self) -> None:
        self.tree.use("no-top-permissions.yml")
        self.assertFails(5, "no top-level 'permissions:'", self.tree.run())

    def test_write_without_ticket_fails_and_with_ticket_passes(self) -> None:
        self.tree.use("write-no-ticket.yml")
        self.assertFails(5, "write permission without a '# Txx:' comment", self.tree.run())
        self.tree.use("write-with-ticket.yml")
        self.assertEqual(self.tree.run()[0], 0)

    def test_write_all_fails(self) -> None:
        self.tree.edit(
            "workflows/other.yml", "permissions:\n  contents: read", "permissions: write-all"
        )
        self.assertFails(5, "write permission", self.tree.run())


MOD = "apps/drupal/web/modules/custom/x/tests/src/"


class Rule6Tests(CheckCiTestCase):
    """TC-T08-40: Rule 6, heavier-set tripwire."""

    def make_marker(self, rel: str, text: str = "x\n") -> None:
        path = self.tree.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    MARKERS = (
        ("functional", MOD + "Functional/FooTest.php", "x\n"),
        ("functional js", MOD + "FunctionalJavascript/a/BarTest.php", "x\n"),
        ("engine live", "services/engine/tests/test_x.py", "mark = 'drupal_live'\n"),
        ("playwright", "apps/web/playwright.config.ts", "x\n"),
        ("e2e", ".ddev/commands/web/e2e", "x\n"),
    )  # fmt: skip

    def test_every_marker_without_a_heavier_job_fails(self) -> None:
        for label, rel, text in self.MARKERS:
            with self.subTest(marker=label):
                tmp = tempfile.TemporaryDirectory()
                self.addCleanup(tmp.cleanup)
                tree = Tree(Path(tmp.name))
                path = tree.root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
                self.assertFails(6, HEAVIER_FAIL, tree.run())
                tree.use("heavier-needed.yml")
                self.assertEqual(tree.run()[0], 0)

    def test_heavier_job_in_ci_ok_needs_fails(self) -> None:
        self.tree.use("heavier-in-ci-ok.yml")
        self.assertFails(6, "never a required check", self.tree.run())

    def test_block_style_needs_is_read(self) -> None:
        self.tree.use("heavier-needed.yml")
        self.tree.edit(
            "workflows/ci.yml",
            "    needs: [core, docs, drupal, engine, web]\n",
            "    needs:\n      - core\n      - heavier-drupal\n",
        )
        self.assertFails(6, "never a required check", self.tree.run())

    def test_non_markers_do_not_trip(self) -> None:
        for rel, text in (
            ("apps/drupal/web/modules/custom/x/tests/src/Unit/FooTest.php", "x\n"),
            ("apps/drupal/web/modules/custom/x/tests/src/Kernel/FooTest.php", "x\n"),
            ("apps/drupal/web/modules/custom/x/tests/src/Functional/helper.txt", "x\n"),
            ("services/engine/meridian_engine/main.py", "drupal_live\n"),
            ("scripts/drupal_live.txt", "drupal_live\n"),
        ):
            self.make_marker(rel, text)
        self.assertEqual(self.tree.run()[0], 0)

    def test_fixture_tree_trips_the_rule(self) -> None:
        code, out = self.tree.run("--root", str(FIXTURES / "tree-functional"))
        self.assertEqual(code, 1, out)
        self.assertIn(HEAVIER_FAIL, out)

    def test_real_tree_has_no_marker(self) -> None:
        self.assertEqual(check_ci.heavier_markers(check_ci.REPO), [])


if __name__ == "__main__":
    unittest.main()
