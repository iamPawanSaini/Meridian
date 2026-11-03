"""T08 demo (KD-11, TC-T08-54): a deliberately failing test.

This file exists only on task/T08-demo-failing-test. Its pull request must be blocked by the
required check ci-ok and closed without merging. It must never reach main.
"""

import unittest


class T08DemoFailure(unittest.TestCase):
    """TC-T08-54: the failing test that branch protection must block."""

    def test_deliberately_fails(self) -> None:
        self.fail("T08 demo: deliberately failing test, do not merge")


if __name__ == "__main__":
    unittest.main()
