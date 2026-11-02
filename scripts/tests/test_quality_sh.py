"""Tests for scripts/quality.sh with fake steps."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

QUALITY = Path(__file__).resolve().parents[1] / "quality.sh"


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


if __name__ == "__main__":
    unittest.main()
