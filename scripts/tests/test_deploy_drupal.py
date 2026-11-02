"""Offline tests for scripts/deploy-drupal.sh (T07, TH-1 to TH-5, TH-9).

A fixture repository stands in for the monorepo, a local bare repository for Pantheon, and fake
`terminus`, `curl` and `git` wrappers on PATH record every call. No network, no credentials.
The tester's wider set is docs/tests/T07/run-checks.sh (TC-T07-11 to 19).
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "deploy-drupal.sh"
SITE = "meridian-trade"
GIT = shutil.which("git") or "git"
SECRET = "fake-token-T07UNITTESTMARKER0123456789"

FAKE_TERMINUS = r"""#!/usr/bin/env bash
printf 'terminus' >>"$FAKE_LOG"; printf ' %s' "$@" >>"$FAKE_LOG"; printf '\n' >>"$FAKE_LOG"
case "${1:-}" in
  auth:login) echo "Logging in via machine token" ;;
  auth:whoami) [[ -z ${FAKE_NO_SESSION:-} ]] || exit 1; echo "fake@example.invalid" ;;
  connection:info) echo "$FAKE_BARE" ;;
  backup:create) [[ -z ${FAKE_BACKUP_FAIL:-} ]] || exit 1 ;;
  workflow:wait)
    [[ -z ${FAKE_WAIT_FAIL:-} ]] || exit 1
    [[ -z ${FAKE_WAIT_TIMEOUT:-} ]] || echo "Waited '900' seconds, giving up waiting" ;;
  env:code-log)
    real=$("$FAKE_REALGIT" --git-dir "$FAKE_BARE" rev-parse refs/heads/master 2>/dev/null \
      || echo none)
    [[ -z ${FAKE_CODELOG_OTHER:-} ]] || real=0000000000000000000000000000000000000001
    printf '[{"hash":"%s"}]\n' "$real" ;;
  remote:drush)
    if [[ "$*" == *"-- config:status"* ]]; then
      if [[ -n ${FAKE_CONFIG_DIFF:-} ]]; then echo " system.site Only in sync dir"
      else echo " [OK] No differences between DB and sync directory."; fi
    fi ;;
esac
exit 0
"""

FAKE_CURL = r"""#!/usr/bin/env bash
printf 'curl' >>"$FAKE_LOG"; printf ' %s' "$@" >>"$FAKE_LOG"; printf '\n' >>"$FAKE_LOG"
args=("$@"); out=""
for ((i = 0; i < ${#args[@]}; i++)); do [[ ${args[$i]} == -o ]] && out=${args[$((i + 1))]}; done
printf '%s' "${FAKE_SMOKE_BODY-<form id=\"user-login-form\">}" >"$out"
printf '%s' "${FAKE_SMOKE_CODE:-200}"
"""

FAKE_GIT = r"""#!/usr/bin/env bash
printf 'git' >>"$FAKE_LOG"; printf ' %s' "$@" >>"$FAKE_LOG"; printf '\n' >>"$FAKE_LOG"
exec "$FAKE_REALGIT" "$@"
"""


def git(cwd: Path, *args: str) -> str:
    """Run real git with a fixed identity and return stdout."""
    proc = subprocess.run(
        [
            GIT,
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@example.invalid",
            "-c",
            "commit.gpgsign=false",
            *args,
        ],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout.strip()


class Fixture:
    """One fixture monorepo plus a bare repository that plays Pantheon."""

    def __init__(self, base: Path) -> None:
        self.base = base
        self.work = base / "work"
        self.pan = base / "pan.git"
        self.log = base / "log.txt"
        self.stub = base / "stub"
        self.stub.mkdir()
        for name, text in (("terminus", FAKE_TERMINUS), ("curl", FAKE_CURL), ("git", FAKE_GIT)):
            path = self.stub / name
            path.write_text(text, encoding="utf-8")
            path.chmod(0o755)
        self.work.mkdir()
        git(self.work, "init", "-q", "-b", "main", ".")
        files = {
            "apps/drupal/composer.json": "{}\n",
            "apps/drupal/composer.lock": "{}\n",
            "apps/drupal/pantheon.yml": "api_version: 1\n",
            "apps/drupal/config/sync/system.site.yml": "name: fixture\n",
            "README.md": "x\n",
        }
        for name, text in files.items():
            self.write(name, text)
        git(self.work, "add", "-A")
        git(self.work, "commit", "-q", "-m", "c1")
        (self.work / "scripts").mkdir()
        shutil.copy(SCRIPT, self.work / "scripts" / "deploy-drupal.sh")
        git(self.work, "init", "-q", "--bare", "-b", "main", str(base / "origin.git"))
        git(self.work, "init", "-q", "--bare", "-b", "master", str(self.pan))
        git(self.pan, "config", "receive.denyNonFastForwards", "true")
        git(self.work, "remote", "add", "origin", str(base / "origin.git"))
        git(self.work, "push", "-q", "origin", "main")

    def write(self, name: str, text: str) -> None:
        """Write a file under the work tree."""
        path = self.work / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def commit(self, name: str, text: str = "y\n") -> str:
        """Add a file under apps/drupal, commit and push to origin main; return the commit."""
        self.write(f"apps/drupal/{name}", text)
        git(self.work, "add", "-A", "-f")
        git(self.work, "commit", "-q", "-m", f"add {name}")
        git(self.work, "push", "-q", "origin", "main")
        return git(self.work, "rev-parse", "HEAD")

    def run(self, *args: str, **env: str) -> subprocess.CompletedProcess[str]:
        """Run the fixture copy of the script with the fakes first on PATH."""
        self.log.write_text("", encoding="utf-8")
        environment = {
            "HOME": str(self.base),
            "PATH": f"{self.stub}:{os.environ['PATH']}",
            "LC_ALL": "C",
            "FAKE_LOG": str(self.log),
            "FAKE_BARE": str(self.pan),
            "FAKE_REALGIT": GIT,
            "PANTHEON_SITE": SITE,
            "DEPLOY_SMOKE_BUDGET": "0",
            **env,
        }
        return subprocess.run(
            ["bash", "scripts/deploy-drupal.sh", *args],
            cwd=self.work,
            env=environment,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )

    def calls(self) -> list[str]:
        """Return the recorded fake calls, one per line."""
        return self.log.read_text(encoding="utf-8").splitlines()

    def master(self) -> str:
        """Return the Pantheon master commit, or an empty string."""
        proc = subprocess.run(
            [GIT, "--git-dir", str(self.pan), "rev-parse", "-q", "--verify", "refs/heads/master"],
            capture_output=True,
            text=True,
            check=False,
        )
        return proc.stdout.strip()


class DeployDrupalTests(unittest.TestCase):
    """TC-T07-11 to TC-T07-19 in miniature."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.fx = Fixture(Path(self._tmp.name))

    def test_dry_run_prints_split_without_network_or_refs(self) -> None:
        before = git(self.fx.work, "for-each-ref")
        out = self.fx.run("--dry-run")
        self.assertEqual(out.returncode, 0, out.stderr)
        split = re.findall(r"\b[0-9a-f]{40}\b", out.stdout)[0]
        self.assertEqual(
            git(self.fx.work, "rev-parse", f"{split}^{{tree}}"),
            git(self.fx.work, "rev-parse", "HEAD:apps/drupal"),
        )
        self.assertEqual(before, git(self.fx.work, "for-each-ref"))
        self.assertNotRegex(
            "\n".join(self.fx.calls()), r"(?m)^(terminus|curl)|^git (push|ls-remote)"
        )
        self.assertIn(SITE, out.stdout)

    def test_split_tree_guard_exits_1_before_network(self) -> None:
        for bad in ("vendor/x", ".env", "web/core/x", "keys/a.pem"):
            with self.subTest(bad=bad):
                fx = Fixture(Path(tempfile.mkdtemp(dir=self._tmp.name)))
                fx.commit(bad)
                out = fx.run()
                self.assertEqual(out.returncode, 1, out.stdout)
                self.assertNotRegex("\n".join(fx.calls()), r"(?m)^(terminus|curl)|^git push")

    def test_ancestor_guard_and_override(self) -> None:
        git(self.fx.work, "checkout", "-q", "-b", "feat")
        self.fx.write("apps/drupal/z.txt", "z\n")
        git(self.fx.work, "add", "-A")
        git(self.fx.work, "commit", "-q", "-m", "feat")
        self.assertEqual(self.fx.run("--ref", "feat").returncode, 2)
        out = self.fx.run("--ref", "feat", "--allow-unmerged", "--dry-run")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("merge commit", out.stdout)
        self.assertIn("squash", out.stdout)

    def test_usage_errors_exit_2(self) -> None:
        self.assertEqual(self.fx.run("--bogus").returncode, 2)
        self.assertEqual(self.fx.run("--ref", "no-such-ref").returncode, 2)
        self.assertEqual(self.fx.run(PANTHEON_SITE="").returncode, 2)
        git(self.fx.work, "update-ref", "-d", "refs/remotes/origin/main")
        out = self.fx.run()
        self.assertEqual(out.returncode, 2)
        self.assertIn("git fetch origin", out.stderr)

    def test_first_deploy_then_idempotent_rerun(self) -> None:
        out = self.fx.run()
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        sha = self.fx.master()
        self.assertTrue(sha)
        self.assertEqual(out.stdout.strip().splitlines()[-1].split()[-1], sha)
        calls = self.fx.calls()
        pushes = [c for c in calls if c.startswith("git push")]
        self.assertEqual(len(pushes), 1)
        self.assertTrue(pushes[0].endswith(f"{sha}:refs/heads/master"))
        self.assertNotRegex(pushes[0], r" (-f|--force)|\+")
        backup = [c for c in calls if c.startswith("terminus backup:create")]
        self.assertIn("--element=db --keep-for=30", backup[0])
        order = [
            next(i for i, c in enumerate(calls) if re.search(pattern, c))
            for pattern in (
                "^terminus backup:create",
                "^git push",
                "^terminus workflow:wait .*--commit=" + sha,
                "^terminus env:code-log",
                "-- updatedb",
                "-- config:import -y",
                "-- cache:rebuild",
                "-- config:status",
                "^curl .*https://dev-meridian-trade.pantheonsite.io/user/login",
            )
        ]
        self.assertEqual(order, sorted(order))
        again = self.fx.run()
        self.assertEqual(again.returncode, 0, again.stdout + again.stderr)
        self.assertEqual(self.fx.master(), sha)
        self.assertNotRegex(
            "\n".join(self.fx.calls()), r"(?m)^terminus backup:create|^git push|workflow:wait"
        )
        self.assertIn("-- config:status", "\n".join(self.fx.calls()))

    def test_rewind_is_rejected_and_never_forced(self) -> None:
        first = git(self.fx.work, "rev-parse", "HEAD")
        self.fx.commit("second.txt")
        self.assertEqual(self.fx.run().returncode, 0)
        master = self.fx.master()
        out = self.fx.run("--ref", first)
        self.assertEqual(out.returncode, 1)
        self.assertEqual(self.fx.master(), master)
        self.assertIn("Emergency force push", out.stderr)
        self.assertIn("docs/runbooks/deploy.md", out.stderr)
        self.assertNotRegex("\n".join(self.fx.calls()), r"workflow:wait|remote:drush")

    def test_failed_backup_stops_before_push(self) -> None:
        out = self.fx.run(FAKE_BACKUP_FAIL="1")
        self.assertEqual(out.returncode, 1)
        self.assertEqual(self.fx.master(), "")
        self.assertNotIn("git push", "\n".join(self.fx.calls()))

    def test_verification_failures_exit_1(self) -> None:
        cases = {
            "FAKE_CODELOG_OTHER": "remote:drush",
            "FAKE_WAIT_FAIL": "remote:drush",
            "FAKE_WAIT_TIMEOUT": "remote:drush",
        }
        for var, absent in cases.items():
            with self.subTest(var=var):
                fx = Fixture(Path(tempfile.mkdtemp(dir=self._tmp.name)))
                out = fx.run(**{var: "1"})
                self.assertEqual(out.returncode, 1, out.stdout)
                self.assertNotIn(absent, "\n".join(fx.calls()))
        fx = Fixture(Path(tempfile.mkdtemp(dir=self._tmp.name)))
        self.assertEqual(fx.run(FAKE_CONFIG_DIFF="1").returncode, 1)
        self.assertNotIn("curl", "\n".join(fx.calls()))

    def test_smoke_check_needs_status_200_and_the_marker(self) -> None:
        interstitial = self.fx.run(FAKE_SMOKE_BODY="warning page")
        self.assertEqual(interstitial.returncode, 1)
        fx = Fixture(Path(tempfile.mkdtemp(dir=self._tmp.name)))
        self.assertEqual(fx.run(FAKE_SMOKE_CODE="503", FAKE_SMOKE_BODY="").returncode, 1)

    def test_token_is_never_printed(self) -> None:
        out = self.fx.run(TERMINUS_MACHINE_TOKEN=SECRET)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertNotIn("T07UNITTESTMARKER", out.stdout + out.stderr)
        self.assertIn("terminus auth:login", "\n".join(self.fx.calls()))
        fx = Fixture(Path(tempfile.mkdtemp(dir=self._tmp.name)))
        self.assertEqual(fx.run().returncode, 0)
        self.assertIn("terminus auth:whoami", "\n".join(fx.calls()))
        self.assertNotIn("auth:login", "\n".join(fx.calls()))

    def test_no_session_and_no_token_fails_without_push(self) -> None:
        out = self.fx.run(FAKE_NO_SESSION="1")
        self.assertNotEqual(out.returncode, 0)
        self.assertEqual(self.fx.master(), "")


class StaticConsistencyTests(unittest.TestCase):
    """TH-4 and TH-9: files that must agree, and must not hold forbidden constructs."""

    def test_script_has_no_force_trace_or_alternate_nameserver(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertNotRegex(text, r"--force|\+refs/|(^|[ ;])set -x|TERMINUS_ALTERNATE_NAMESERVER=")
        decided = "ssh -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR"
        self.assertIn(f"TERMINUS_SSH_COMMAND='{decided}'", text)
        self.assertIn("StrictHostKeyChecking=yes", text)

    def test_pantheon_site_agrees_in_ddev_config_and_env_example(self) -> None:
        config = (ROOT / ".ddev" / "config.yaml").read_text(encoding="utf-8")
        example = (ROOT / ".env.example").read_text(encoding="utf-8")
        self.assertIn(f"- PANTHEON_SITE={SITE}", config)
        self.assertRegex(example, rf"(?m)^PANTHEON_SITE={SITE}$")
        self.assertNotIn("TERMINUS_MACHINE_TOKEN=", config)

    def test_provider_is_pull_only(self) -> None:
        text = (ROOT / ".ddev" / "providers" / "pantheon.yaml").read_text(encoding="utf-8")
        self.assertNotRegex(text, r"(?m)^(db|files)_push_command|set -x|#ddev-generated")
        self.assertEqual(text.count("backup:create"), 2)

    def test_workflow_skips_without_variable_and_uses_env_for_secrets(self) -> None:
        text = (ROOT / ".github" / "workflows" / "deploy-drupal.yml").read_text(encoding="utf-8")
        self.assertIn("vars.PANTHEON_SITE", text)
        self.assertIn("not configured (PANTHEON_SITE unset), skipped", text)
        self.assertNotIn("--allow-unmerged", text)
        for use in re.findall(r"uses: (\S+)", text):
            self.assertRegex(use, r"^actions/[\w.-]+@[0-9a-f]{40}$")
        for run in re.findall(r"(?ms)^\s+run: (.*?)(?=^\s+\w[\w-]*:|\Z)", text):
            self.assertNotRegex(run, r"\$\{\{\s*(secrets|vars)\.")


if __name__ == "__main__":
    unittest.main()
