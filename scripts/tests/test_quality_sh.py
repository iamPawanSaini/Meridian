"""Tests for scripts/quality.sh with fake steps."""

from __future__ import annotations

import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

QUALITY = Path(__file__).resolve().parents[1] / "quality.sh"
REPO = QUALITY.parents[1]
EXPECTED_SKIPS = REPO / "quality" / "expected-skips.txt"
GROUPS = ["core", "docs", "drupal", "engine", "web"]
ORIGINAL_STEPS = {
    "pre-commit",
    "branch-name",
    "commit-range",
    "exceptions",
    "assets",
    "component-engine",
    "component-drupal",
    "component-drupal-tests",
    "component-web",
}


def run_steps(steps: str, runner: str = "native") -> subprocess.CompletedProcess[str]:
    """Run quality.sh with a steps file made of NAME, MANIFEST, COMMAND lines."""
    with tempfile.TemporaryDirectory() as tmp:
        steps_file = Path(tmp) / "steps"
        steps_file.write_text(steps, encoding="utf-8")
        env = {**os.environ, "QUALITY_STEPS": str(steps_file), "QUALITY_RUNNER": runner}
        return subprocess.run(
            ["bash", str(QUALITY)], capture_output=True, text=True, env=env, check=False
        )


class QualityShTests(unittest.TestCase):
    """PASS, FAIL and SKIP accounting."""

    def test_pass_fail_skip_and_exit_code(self) -> None:
        out = run_steps("a\t-\ttrue\nb\t-\tfalse\nc\t/nonexistent/manifest\tfalse\n")
        self.assertEqual(out.returncode, 1)
        self.assertIn("PASS  a", out.stdout)
        self.assertIn("FAIL  b", out.stdout)
        self.assertIn("SKIP  c", out.stdout)
        self.assertIn("summary: PASS 1 FAIL 1 SKIP 1", out.stdout)

    def test_missing_tool_with_manifest_is_fail(self) -> None:
        out = run_steps("m\t/\tmeridian-no-such-tool-xyz\n")
        self.assertEqual(out.returncode, 1)
        self.assertIn("FAIL  m", out.stdout)

    def test_stdin_reading_step_cannot_swallow_later_steps(self) -> None:
        out = run_steps("one\t-\tcat\ntwo\t-\ttrue\nthree\t-\tfalse\n")
        self.assertEqual(out.returncode, 1)
        self.assertIn("PASS  one", out.stdout)
        self.assertIn("PASS  two", out.stdout)
        self.assertIn("FAIL  three", out.stdout)
        self.assertIn("summary: PASS 2 FAIL 1 SKIP 0", out.stdout)

    def test_unknown_runner_exits_2(self) -> None:
        out = run_steps("a\t-\ttrue\n", runner="bogus")
        self.assertEqual(out.returncode, 2)
        self.assertIn("QUALITY_RUNNER", out.stderr)


def make_tree(tmp: Path, skips: str | None = None) -> Path:
    """Copy quality.sh and expected-skips into a bare tree: no component manifest exists."""
    (tmp / "scripts").mkdir(parents=True, exist_ok=True)
    (tmp / "quality").mkdir(parents=True, exist_ok=True)
    shutil.copy(QUALITY, tmp / "scripts" / "quality.sh")
    if skips is None:
        shutil.copy(EXPECTED_SKIPS, tmp / "quality" / "expected-skips.txt")
    else:
        (tmp / "quality" / "expected-skips.txt").write_text(skips, encoding="utf-8")
    return tmp


def run_in(
    tree: Path, *args: str, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    """Run the copy of quality.sh in a tree with a clean environment plus `env`."""
    full = {k: v for k, v in os.environ.items() if not k.startswith("QUALITY_")}
    full.pop("GITHUB_STEP_SUMMARY", None)
    full.update(env or {})
    return subprocess.run(
        ["bash", str(tree / "scripts" / "quality.sh"), *args],
        capture_output=True,
        text=True,
        env=full,
        check=False,
    )


class ListAndGroupTests(unittest.TestCase):
    """--list, --group and the step to group mapping (T08, KD-2)."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tree = make_tree(Path(tmp.name))

    def listing(self) -> list[tuple[str, str]]:
        out = run_in(self.tree, "--list")
        self.assertEqual(out.returncode, 0, out.stderr)
        rows = [tuple(line.split("\t")) for line in out.stdout.splitlines()]
        return [(group, step) for group, step in rows]

    def test_list_has_every_step_once_in_the_five_groups(self) -> None:
        rows = self.listing()
        steps = [step for _, step in rows]
        self.assertEqual(len(rows), 19)
        self.assertEqual(len(set(steps)), 19)
        self.assertEqual(sorted({group for group, _ in rows}), GROUPS)
        self.assertTrue(set(steps) >= ORIGINAL_STEPS)
        by_group = {g: [s for gg, s in rows if gg == g] for g in GROUPS}
        self.assertEqual(by_group["drupal"][0], "build-drupal")
        self.assertEqual(by_group["docs"], ["docs-regression"])
        self.assertIn("ci-config", by_group["core"])
        self.assertIn("secret-history", by_group["core"])
        self.assertIn("tooling-tests", by_group["core"])

    def test_list_runs_nothing_and_ignores_group_order(self) -> None:
        out = run_in(self.tree, "--list")
        self.assertNotIn("PASS", out.stdout)
        self.assertNotIn("summary", out.stdout)

    def test_group_runs_only_that_group(self) -> None:
        out = run_in(self.tree, "--group", "engine", "--group", "web")
        self.assertEqual(out.returncode, 0, out.stdout)
        skipped = [line.split()[1] for line in out.stdout.splitlines() if line.startswith("SKIP")]
        self.assertEqual(len(skipped), 6)
        self.assertTrue(all(step.endswith(("-engine", "-web")) for step in skipped))
        self.assertIn("summary: PASS 0 FAIL 0 SKIP 6", out.stdout)

    def test_unknown_group_missing_argument_and_case_exit_2(self) -> None:
        for args in (["--group", "nosuch"], ["--group", "Core"], ["--group"], ["--bogus"]):
            with self.subTest(args=args):
                out = run_in(self.tree, *args)
                self.assertEqual(out.returncode, 2)
        self.assertIn("nosuch", run_in(self.tree, "--group", "nosuch").stderr)

    def test_group_is_not_allowed_with_the_test_hook(self) -> None:
        steps = self.tree / "steps"
        steps.write_text("a\t-\ttrue\n", encoding="utf-8")
        out = run_in(self.tree, "--group", "core", env={"QUALITY_STEPS": str(steps)})
        self.assertEqual(out.returncode, 2)

    def test_step_without_a_group_exits_2(self) -> None:
        script = self.tree / "scripts" / "quality.sh"
        text = script.read_text(encoding="utf-8")
        self.assertIn('step core "assets"', text)
        script.write_text(text.replace('step core "assets"', 'step "" "assets"'), encoding="utf-8")
        for args in (["--list"], ["--group", "engine"]):
            with self.subTest(args=args):
                out = run_in(self.tree, *args)
                self.assertEqual(out.returncode, 2)
                self.assertIn("no valid group", out.stderr)


class RunnerIndependenceTests(unittest.TestCase):
    """SA-2 condition 2: the runner never changes the step set or the SKIP decisions."""

    def test_list_and_skips_are_the_same_under_native_and_ddev(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            tree = make_tree(tmp / "tree")
            bin_dir = tmp / "bin"
            bin_dir.mkdir()
            calls = tmp / "ddev-calls.txt"
            fake = bin_dir / "ddev"
            fake.write_text(f'#!/bin/sh\necho "$@" >>"{calls}"\nexit 0\n', encoding="utf-8")
            fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
            path = f"{bin_dir}:{os.environ['PATH']}"
            results = {}
            for runner in ("native", "ddev"):
                env = {"QUALITY_RUNNER": runner, "PATH": path}
                listing = run_in(tree, "--list", env=env)
                skips = run_in(tree, "--group", "engine", "--group", "web", env=env)
                results[runner] = (listing.stdout, skips.stdout, skips.returncode)
            self.assertEqual(results["native"], results["ddev"])
            self.assertIn("SKIP", results["ddev"][1])
            self.assertFalse(calls.exists(), "a SKIP step must not call ddev")


class ExpectedSkipsTests(unittest.TestCase):
    """KD-3: a SKIP is never silent."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.tmp_path = Path(self.tmp.name)

    def test_real_file_lists_known_steps_with_tickets(self) -> None:
        lines = [x for x in EXPECTED_SKIPS.read_text(encoding="utf-8").splitlines() if x.strip()]
        data = [x for x in lines if not x.startswith("#")]
        self.assertEqual(len(data), 7)
        for line in data:
            self.assertRegex(line, r"^[a-z-]+\s+# T\d{2}a?: \S")

    def test_unlisted_skip_fails_and_names_the_manifest(self) -> None:
        keep = "".join(
            x + "\n"
            for x in EXPECTED_SKIPS.read_text(encoding="utf-8").splitlines()
            if not x.startswith("audit-web")
        )
        tree = make_tree(self.tmp_path / "t", skips=keep)
        out = run_in(tree, "--group", "web")
        self.assertEqual(out.returncode, 1, out.stdout)
        self.assertIn("unexpected SKIP: audit-web (no apps/web/package.json)", out.stdout)
        self.assertNotIn("unexpected SKIP: build-web", out.stdout)
        self.assertIn("summary: PASS 0 FAIL 1 SKIP 2", out.stdout)
        ok = run_in(make_tree(self.tmp_path / "ok"), "--group", "web")
        self.assertEqual(ok.returncode, 0, ok.stdout)

    def test_listed_step_that_runs_fails(self) -> None:
        tree = make_tree(self.tmp_path / "t")
        manifest = tree / "services" / "engine" / "pyproject.toml"
        manifest.parent.mkdir(parents=True)
        manifest.write_text("", encoding="utf-8")
        out = run_in(tree, "--group", "engine")
        self.assertEqual(out.returncode, 1, out.stdout)
        msg = "component-engine ran but is listed in quality/expected-skips.txt: remove the line"
        self.assertIn(msg, out.stdout)
        self.assertIn("audit-engine ran but is listed", out.stdout)
        self.assertNotIn("build-engine ran", out.stdout)

    def test_bad_lines_exit_2(self) -> None:
        bad = {
            "no ticket": "component-engine\n",
            "no ticket id": "component-engine  # reason only\n",
            "unknown step": "nosuch-step  # T99: x\n",
        }
        for label, text in bad.items():
            with self.subTest(label=label):
                tree = make_tree(self.tmp_path / label.replace(" ", "_"), skips=text)
                self.assertEqual(run_in(tree, "--group", "engine").returncode, 2)
                self.assertEqual(run_in(tree, "--group", "docs").returncode, 2)

    def test_only_selected_groups_are_checked(self) -> None:
        tree = make_tree(self.tmp_path / "t", skips="audit-web  # T21: x\n")
        docs = run_in(tree, "--group", "docs")
        self.assertNotIn("unexpected SKIP", docs.stdout)
        out = run_in(tree, "--group", "engine")
        self.assertIn("unexpected SKIP: build-engine", out.stdout)
        self.assertNotIn("unexpected SKIP: build-web", out.stdout)

    def test_hook_mode_ignores_the_expected_skips_file(self) -> None:
        steps = self.tmp_path / "steps"
        steps.write_text("c\t/nonexistent/manifest\tfalse\n", encoding="utf-8")
        out = run_steps(steps.read_text(encoding="utf-8"))
        self.assertEqual(out.returncode, 0)
        self.assertIn("SKIP  c", out.stdout)


class SummaryAndDetailTests(unittest.TestCase):
    """GITHUB_STEP_SUMMARY table and the detail lines."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)

    def test_summary_table_has_every_step_and_reasons(self) -> None:
        tree = make_tree(self.tmp / "t")
        summary = self.tmp / "sum.md"
        out = run_in(tree, "--group", "engine", env={"GITHUB_STEP_SUMMARY": str(summary)})
        self.assertEqual(out.returncode, 0)
        text = summary.read_text(encoding="utf-8")
        self.assertIn("| Step | Result | Detail |", text)
        self.assertIn("| build-engine | SKIP | no `services/engine/Dockerfile` |", text)
        self.assertEqual(text.count("| SKIP |"), 3)

    def test_no_summary_file_without_the_variable(self) -> None:
        tree = make_tree(self.tmp / "t")
        out = run_in(tree, "--group", "engine")
        self.assertEqual(out.returncode, 0)
        self.assertEqual(sorted(p.name for p in self.tmp.iterdir()), ["t"])

    def test_failing_step_is_in_the_summary_and_keeps_exit_1(self) -> None:
        steps = self.tmp / "steps"
        steps.write_text("good\t-\ttrue\nbad\t-\tfalse\n", encoding="utf-8")
        summary = self.tmp / "sum.md"
        env = {"QUALITY_STEPS": str(steps), "GITHUB_STEP_SUMMARY": str(summary)}
        tree = make_tree(self.tmp / "t")
        out = run_in(tree, env=env)
        self.assertEqual(out.returncode, 1)
        self.assertIn("| bad | FAIL |", summary.read_text(encoding="utf-8"))

    def test_detail_lines_show_on_pass(self) -> None:
        out = run_steps("d\t-\techo 'detail: three suites ran'; echo noise\n")
        self.assertEqual(out.returncode, 0)
        self.assertIn("      three suites ran", out.stdout)
        self.assertNotIn("noise", out.stdout)

    def test_nested_run_leaves_docs_out_and_refuses_the_docs_group(self) -> None:
        tree = make_tree(self.tmp / "t")
        refused = run_in(tree, "--group", "docs", env={"QUALITY_NESTED": "1"})
        self.assertEqual(refused.returncode, 2)
        self.assertIn("nested", refused.stderr)
        nested = run_in(tree, env={"QUALITY_NESTED": "1"})
        self.assertIn("note: group docs not run (nested inside docs-regression)", nested.stdout)
        self.assertNotIn(
            "docs-regression", nested.stdout.replace("nested inside docs-regression", "")
        )
        self.assertIn("component-engine", nested.stdout)

    def test_live_lock_file_marks_a_nested_run_and_a_stale_one_does_not(self) -> None:
        tree = make_tree(self.tmp / "t")
        lock = tree / ".tools" / "docs-regression.lock"
        lock.parent.mkdir()
        lock.write_text(f"{os.getpid()}\n", encoding="utf-8")
        self.assertEqual(run_in(tree, "--group", "docs").returncode, 2)
        proc = subprocess.Popen(["true"])
        proc.wait()
        lock.write_text(f"{proc.pid}\n", encoding="utf-8")  # a pid that has exited
        out = run_in(tree, "--group", "docs")
        self.assertEqual(out.returncode, 1)  # docs-regression ran: no suites in the bare tree
        self.assertIn("no docs suites found", out.stdout)

    def test_docs_regression_names_a_failing_suite(self) -> None:
        tree = make_tree(self.tmp / "t")
        for name, code in (("T98", 0), ("T99", 1)):
            suite = tree / "docs" / "tests" / name / "run-checks.sh"
            suite.parent.mkdir(parents=True)
            suite.write_text(f'#!/bin/sh\n[ "$1" = --regression ] || exit 3\nexit {code}\n')
            suite.chmod(suite.stat().st_mode | stat.S_IXUSR)
        out = run_in(tree, "--group", "docs")
        self.assertEqual(out.returncode, 1, out.stdout)
        self.assertIn("FAILED: docs/tests/T99/run-checks.sh --regression", out.stdout)
        self.assertNotIn("FAILED: docs/tests/T98", out.stdout)


if __name__ == "__main__":
    unittest.main()
