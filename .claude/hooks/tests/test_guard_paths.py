"""Unit tests for .claude/hooks/guard_paths.py.

Run: python3 -m unittest discover -s .claude/hooks/tests -v
The tests run the guard as a subprocess, the same way Claude Code calls it.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
GUARD = REPO / ".claude" / "hooks" / "guard_paths.py"

# The same arguments the agent frontmatter uses.
PROFILES = {
    "solution-architect": ["--allow", "docs/*", "--bash", "none"],
    "technical-architect": ["--allow", "docs/*", "--bash", "readonly"],
    "developer": [
        "--allow", "*",
        "--deny", "docs/tests/*/test-cases.md",
        "--deny", "docs/tests/*/test-report.md",
        "--bash", "developer",
    ],
    "tester": [
        "--allow", "docs/tests/*", "--allow", "tests/*", "--allow", "*/tests/*",
        "--allow", "*/e2e/*", "--bash", "tester",
    ],
}


def run_guard(agent: str, tool: str, tool_input: dict) -> subprocess.CompletedProcess:
    payload = {
        "hook_event_name": "PreToolUse",
        "tool_name": tool,
        "tool_input": tool_input,
        "cwd": str(REPO),
        "agent_type": agent,
    }
    env = dict(os.environ, CLAUDE_PROJECT_DIR=str(REPO))
    return subprocess.run(
        [sys.executable, str(GUARD), "--agent", agent, *PROFILES[agent]],
        input=json.dumps(payload), capture_output=True, text=True, env=env, check=False,
    )


class GuardTestCase(unittest.TestCase):
    def assertAllowed(self, agent, tool, tool_input):
        result = run_guard(agent, tool, tool_input)
        self.assertEqual(result.returncode, 0, f"expected allow, got: {result.stderr}")

    def assertBlocked(self, agent, tool, tool_input):
        result = run_guard(agent, tool, tool_input)
        self.assertEqual(result.returncode, 2, f"expected block for {tool_input}")
        self.assertIn("Blocked", result.stderr)


class TesterGuard(GuardTestCase):
    """AC2: tester cannot write application source."""

    def test_blocks_edit_of_engine_source(self):
        self.assertBlocked("tester", "Edit", {"file_path": str(REPO / "services/engine/meridian_engine/scoring.py")})

    def test_blocks_write_of_drupal_module_source(self):
        self.assertBlocked("tester", "Write", {"file_path": "apps/drupal/web/modules/custom/meridian_ingest/src/Foo.php"})

    def test_blocks_write_to_task_plan(self):
        self.assertBlocked("tester", "Write", {"file_path": "docs/tasks/T05/plan.md"})

    def test_allows_test_docs(self):
        self.assertAllowed("tester", "Write", {"file_path": "docs/tests/T05/test-cases.md"})

    def test_allows_test_code_folders(self):
        self.assertAllowed("tester", "Write", {"file_path": "services/engine/tests/test_scoring.py"})
        self.assertAllowed("tester", "Write", {"file_path": "apps/web/e2e/login.spec.ts"})
        self.assertAllowed("tester", "Edit", {"file_path": "apps/drupal/web/modules/custom/meridian_ingest/tests/src/Kernel/IngestTest.php"})

    def test_blocks_path_traversal(self):
        self.assertBlocked("tester", "Write", {"file_path": "docs/tests/../../services/engine/x.py"})

    def test_bash_redirect_into_source_blocked(self):
        self.assertBlocked("tester", "Bash", {"command": "echo x > services/engine/meridian_engine/x.py"})

    def test_bash_sed_in_place_on_source_blocked(self):
        self.assertBlocked("tester", "Bash", {"command": "sed -i 's/a/b/' apps/web/app/page.tsx"})

    def test_bash_cp_into_source_blocked(self):
        self.assertBlocked("tester", "Bash", {"command": "cp /tmp/x.py services/engine/meridian_engine/x.py"})

    def test_bash_git_commit_blocked(self):
        self.assertBlocked("tester", "Bash", {"command": "git commit -am 'x'"})

    def test_bash_running_tests_with_evidence_allowed(self):
        self.assertAllowed("tester", "Bash", {"command": "python3 -m pytest services/engine 2>&1 | tee docs/tests/T13/evidence/pytest.txt"})
        self.assertAllowed("tester", "Bash", {"command": "docs/tests/T00/run-checks.sh > /tmp/out.txt 2>&1"})


class ArchitectGuards(GuardTestCase):
    """AC3: architects are read-only on source; writes only under docs/."""

    def test_solution_architect_writes_docs(self):
        self.assertAllowed("solution-architect", "Write", {"file_path": "docs/adr/ADR-0001-headless.md"})

    def test_solution_architect_blocked_on_source(self):
        self.assertBlocked("solution-architect", "Edit", {"file_path": "services/engine/meridian_engine/llm.py"})
        self.assertBlocked("solution-architect", "Write", {"file_path": "CLAUDE.md"})

    def test_solution_architect_has_no_bash(self):
        self.assertBlocked("solution-architect", "Bash", {"command": "ls"})

    def test_technical_architect_readonly_commands_allowed(self):
        for cmd in ["git diff main...HEAD", "git log --oneline -5", "ls -la docs", "grep -rn TODO services | head",
                    "scripts/check-names.sh 2>&1"]:
            self.assertAllowed("technical-architect", "Bash", {"command": cmd})

    def test_technical_architect_mutations_blocked(self):
        for cmd in ["echo x > services/engine/x.py", "rm -rf apps", "git commit -m x", "git checkout main",
                    "sed -i 's/a/b/' README.md", "npm install left-pad", "ls && touch apps/x"]:
            self.assertBlocked("technical-architect", "Bash", {"command": cmd})

    def test_technical_architect_writes_plan(self):
        self.assertAllowed("technical-architect", "Write", {"file_path": "docs/tasks/T05/plan.md"})
        self.assertBlocked("technical-architect", "Write", {"file_path": "apps/web/app/page.tsx"})


class QuotedShellParsing(GuardTestCase):
    """DEF-001: quoted operators must not break parsing or count as redirects."""

    def test_quoted_pipe_and_gt_allowed_for_readonly(self):
        for cmd in ['grep -rnE "kiteconnect|zerodha|upstox" docs', "awk '$1 > 5' docs/x.txt",
                    'git log --format="%h > %s" -3', 'grep -c "a|b" docs/x.md | head -1',
                    "ls docs 2>&1 | head", "grep -rn x docs 2>/dev/null"]:
            self.assertAllowed("technical-architect", "Bash", {"command": cmd})

    def test_real_operators_still_detected(self):
        for cmd in ['grep "a|b" docs > apps/x.txt', 'echo "x" ; touch apps/y', "ls\nrm -rf apps",
                    "echo $(touch apps/z)", "ls `rm apps/q`", "true && git commit -m x"]:
            self.assertBlocked("technical-architect", "Bash", {"command": cmd})

    def test_tester_quoted_pattern_with_tee_into_evidence(self):
        self.assertAllowed("tester", "Bash", {"command": 'grep -rniE "zerodha|upstox" docs 2>&1 | tee docs/tests/T02/evidence/broker.txt'})
        self.assertBlocked("tester", "Bash", {"command": 'grep -E "a|b" x | tee apps/web/out.txt'})

    def test_unbalanced_quote_blocks(self):
        self.assertBlocked("technical-architect", "Bash", {"command": 'grep "abc docs'})


class DeveloperGuard(GuardTestCase):
    def test_developer_writes_source(self):
        self.assertAllowed("developer", "Write", {"file_path": "services/engine/meridian_engine/cli.py"})
        self.assertAllowed("developer", "Bash", {"command": "git commit -m 'T13: add cli'"})

    def test_developer_cannot_edit_test_cases_or_report(self):
        self.assertBlocked("developer", "Edit", {"file_path": "docs/tests/T13/test-cases.md"})
        self.assertBlocked("developer", "Write", {"file_path": "docs/tests/T13/test-report.md"})

    def test_developer_cannot_bypass_hooks(self):
        self.assertBlocked("developer", "Bash", {"command": "git commit --no-verify -m x"})


class CommonGuards(GuardTestCase):
    def test_no_agent_can_write_env_or_guard_rails(self):
        for agent in PROFILES:
            self.assertBlocked(agent, "Write", {"file_path": ".env"})
            self.assertBlocked(agent, "Edit", {"file_path": ".claude/hooks/guard_paths.py"})
            self.assertBlocked(agent, "Edit", {"file_path": ".claude/agents/tester.md"})

    def test_env_example_is_writable_by_developer(self):
        self.assertAllowed("developer", "Edit", {"file_path": ".env.example"})

    def test_outside_repo_blocked_except_temp(self):
        self.assertBlocked("developer", "Write", {"file_path": "/home/someone/.bashrc"})
        self.assertAllowed("developer", "Write", {"file_path": "/tmp/scratch.txt"})

    def test_read_tools_always_allowed(self):
        for agent in PROFILES:
            self.assertAllowed(agent, "Read", {"file_path": "services/engine/meridian_engine/x.py"})

    def test_malformed_input_blocks(self):
        result = subprocess.run([sys.executable, str(GUARD), *PROFILES["tester"]], input="not json",
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 2)


class AgentFrontmatter(unittest.TestCase):
    """AC1: agent files exist with the required fields, and the guard args match PROFILES."""

    def test_agents_wire_guard_with_tested_profiles(self):
        import re
        import shlex

        for agent, expected in PROFILES.items():
            text = (REPO / ".claude" / "agents" / f"{agent}.md").read_text()
            front = text.split("---")[1]
            for field in ("name:", "description:", "tools:", "model:", "hooks:"):
                self.assertIn(field, front, f"{agent} missing {field}")
            self.assertIn(f"name: {agent}\n", front)
            cmd = re.search(r"command: '(.+)'", front).group(1)
            args = shlex.split(cmd)
            self.assertTrue(args[1].endswith(".claude/hooks/guard_paths.py"))
            self.assertEqual(args[2:4], ["--agent", agent])
            self.assertEqual(args[4:], expected, f"{agent} frontmatter args differ from tested profile")


if __name__ == "__main__":
    unittest.main()
