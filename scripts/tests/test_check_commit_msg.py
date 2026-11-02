"""Tests for scripts/check_commit_msg.py."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

import _helpers
import check_commit_msg as ccm

KNOWN = {"T04", "T04a", "T10"}


class SubjectTests(unittest.TestCase):
    """check_subject accepts and rejects single subjects."""

    def test_accepts_task_prefix(self) -> None:
        self.assertIsNone(ccm.check_subject("T04a: add thing", KNOWN))
        self.assertIsNone(ccm.check_subject("T10: x", KNOWN))

    def test_rejects_malformed(self) -> None:
        bad_subjects = [
            "bad message",
            "",
            "T04a:x",
            "T04a: ",
            "t04: x",
            "T4: x",
            "T04ab: x",
            " T04a: x",
        ]
        for bad in bad_subjects:
            with self.subTest(bad=bad):
                self.assertIsNotNone(ccm.check_subject(bad, KNOWN))

    def test_length_boundary(self) -> None:
        ok = "T10: " + "a" * 67
        self.assertEqual(len(ok), 72)
        self.assertIsNone(ccm.check_subject(ok, KNOWN))
        self.assertIsNotNone(ccm.check_subject(ok + "a", KNOWN))

    def test_merge_and_revert_allowed_but_not_fixup(self) -> None:
        long_merge = "Merge pull request #12 from x/" + "y" * 80
        self.assertIsNone(ccm.check_subject(long_merge, KNOWN))
        self.assertIsNone(ccm.check_subject('Revert "T10: x"', KNOWN))
        self.assertIsNotNone(ccm.check_subject("Revert it", KNOWN))
        self.assertIsNotNone(ccm.check_subject("Merged things", KNOWN))
        self.assertIsNotNone(ccm.check_subject("fixup! T04a: x", KNOWN))
        self.assertIsNotNone(ccm.check_subject("squash! T04a: x", KNOWN))

    def test_unknown_id_is_named(self) -> None:
        reason = ccm.check_subject("T99: x", KNOWN)
        self.assertIsNotNone(reason)
        self.assertIn("T99", reason or "")

    def test_subject_of_skips_comments(self) -> None:
        self.assertEqual(ccm.subject_of("# comment\nT10: x\n\nbody"), "T10: x")
        self.assertEqual(ccm.subject_of(""), "")


class MainTests(unittest.TestCase):
    """main() with a message file and a git range."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.tasks = self.dir / "TASKS.md"
        self.tasks.write_text(_helpers.TASKS_MD, encoding="utf-8")

    def run_msg(self, text: str) -> int:
        msg = self.dir / "msg"
        msg.write_text(text, encoding="utf-8")
        return ccm.main(["--tasks-file", str(self.tasks), "--msg-file", str(msg)])

    def test_msg_file(self) -> None:
        self.assertEqual(self.run_msg("T04a: x\n"), 0)
        self.assertEqual(self.run_msg("bad message\n"), 1)
        self.assertEqual(self.run_msg("T04: x\n\n" + "b" * 150 + "\n"), 0)

    def test_requires_exactly_one_mode(self) -> None:
        self.assertEqual(ccm.main(["--tasks-file", str(self.tasks)]), 2)

    def test_range_checks_only_new_commits(self) -> None:
        repo = _helpers.make_repo(self.dir / "repo", {})
        _helpers.git(repo, "commit", "-q", "--allow-empty", "-m", "legacy bad " + "x" * 90)
        base = _helpers.git(repo, "rev-parse", "HEAD").strip()
        _helpers.git(repo, "commit", "-q", "--allow-empty", "-m", "T10: fine")
        cwd = os.getcwd()
        os.chdir(repo)
        self.addCleanup(os.chdir, cwd)
        args = ["--tasks-file", str(self.tasks), "--range", f"{base}..HEAD"]
        self.assertEqual(ccm.main(args), 0)
        _helpers.git(repo, "commit", "-q", "--allow-empty", "-m", "fixup! T10: fine")
        self.assertEqual(ccm.main(args), 1)

    def test_rule_start_exempts_older_history(self) -> None:
        repo = _helpers.make_repo(self.dir / "rs", {})
        _helpers.git(repo, "commit", "-q", "--allow-empty", "-m", "old bad subject")
        boundary = _helpers.git(repo, "rev-parse", "HEAD").strip()
        _helpers.git(repo, "commit", "-q", "--allow-empty", "-m", "T10: fine")
        first = _helpers.git(repo, "rev-list", "--max-parents=0", "HEAD").strip()
        cwd = os.getcwd()
        os.chdir(repo)
        self.addCleanup(os.chdir, cwd)
        base = ["--tasks-file", str(self.tasks), "--range", f"{first}..HEAD"]
        self.assertEqual(ccm.main([*base, "--rule-start", boundary]), 0)
        self.assertEqual(ccm.main(base), 1)  # no boundary in this repo: the full range counts
        _helpers.git(repo, "commit", "-q", "--allow-empty", "-m", "bad after boundary")
        self.assertEqual(ccm.main([*base, "--rule-start", boundary]), 1)

    def test_missing_explicit_boundary_exits_2(self) -> None:
        repo = _helpers.make_repo(self.dir / "mb", {})
        cwd = os.getcwd()
        os.chdir(repo)
        self.addCleanup(os.chdir, cwd)
        argv = ["--tasks-file", str(self.tasks), "--range", "HEAD..HEAD", "--rule-start", "1" * 40]
        self.assertEqual(ccm.main(argv), 2)

    def test_merge_subject_needs_two_parents_in_range(self) -> None:
        repo = _helpers.make_repo(self.dir / "mp", {})
        base = _helpers.git(repo, "rev-parse", "HEAD").strip()
        _helpers.git(repo, "commit", "-q", "--allow-empty", "-m", "Merge my local fixes")
        cwd = os.getcwd()
        os.chdir(repo)
        self.addCleanup(os.chdir, cwd)
        argv = ["--tasks-file", str(self.tasks), "--range", f"{base}..HEAD"]
        self.assertEqual(ccm.main(argv), 1)
        self.assertIsNone(ccm.check_subject("Merge my local fixes", KNOWN))

    def test_unreadable_tasks_file(self) -> None:
        msg = self.dir / "m"
        msg.write_text("T10: x\n", encoding="utf-8")
        argv = ["--tasks-file", str(self.dir / "none.md"), "--msg-file", str(msg)]
        self.assertEqual(ccm.main(argv), 2)


if __name__ == "__main__":
    unittest.main()
