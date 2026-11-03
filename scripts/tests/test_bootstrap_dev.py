"""Tests for scripts/bootstrap-dev.sh without network: fake curl and uname first on PATH."""

from __future__ import annotations

import hashlib
import io
import os
import stat
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

from _helpers import make_repo

BOOTSTRAP = Path(__file__).resolve().parents[1] / "bootstrap-dev.sh"
VERSIONS = {
    "PRE_COMMIT": "9.9.9",
    "GITLEAKS": "8.8.8",
    "ACTIONLINT": "1.1.1",
    "SHELLCHECK": "0.0.1",
}
FAKE_CURL = """#!/usr/bin/env bash
# Fake curl: copies the fixture named like the URL into the -o target and logs the URL.
out="" url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift ;;
    -*) ;;
    *) url="$1" ;;
  esac
  shift
done
echo "$url" >>"$FAKE_CURL_LOG"
cp "$FAKE_DOWNLOADS/$(basename "$url")" "$out"
"""
FAKE_UNAME = """#!/usr/bin/env bash
case "$1" in
  -s) echo "$FAKE_UNAME_S" ;;
  -m) echo "$FAKE_UNAME_M" ;;
esac
"""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def tarball(member: str, text: str) -> bytes:
    """A .tar.gz holding one executable shell script called `member`."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        data = f"#!/bin/sh\necho {text}\n".encode()
        info = tarfile.TarInfo(member)
        info.size = len(data)
        info.mode = 0o755
        tar.addfile(info, io.BytesIO(data))
    return buf.getvalue()


class BootstrapTestCase(unittest.TestCase):
    """A temp repo with a copy of the script, fixture pins and fake downloads."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.downloads = self.tmp / "downloads"
        self.downloads.mkdir()
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        for name, text in (("curl", FAKE_CURL), ("uname", FAKE_UNAME)):
            fake = self.bin / name
            fake.write_text(text, encoding="utf-8")
            fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
        self.curl_log = self.tmp / "curl.log"
        v = VERSIONS
        self.assets = {
            f"pre-commit-{v['PRE_COMMIT']}.pyz": b"import sys\nprint('pre-commit fake')\n",
            f"gitleaks_{v['GITLEAKS']}_linux_x64.tar.gz": tarball("gitleaks", "gitleaks-fake"),
            f"actionlint_{v['ACTIONLINT']}_linux_amd64.tar.gz": tarball(
                "actionlint", "actionlint-fake"
            ),
            f"shellcheck-v{v['SHELLCHECK']}.linux.x86_64.tar.gz": tarball(
                f"shellcheck-v{v['SHELLCHECK']}/shellcheck", "shellcheck-fake"
            ),
        }
        for name, data in self.assets.items():
            (self.downloads / name).write_bytes(data)
        self.shas = dict(zip(VERSIONS, (sha256(d) for d in self.assets.values()), strict=True))
        self.repo = make_repo(self.tmp / "repo", {})
        self.write_versions()
        script = self.repo / "scripts" / "bootstrap-dev.sh"
        script.write_text(BOOTSTRAP.read_text(encoding="utf-8"), encoding="utf-8")
        script.chmod(script.stat().st_mode | stat.S_IXUSR)

    def write_versions(self, **sha_override: str) -> None:
        lines = []
        for key, version in VERSIONS.items():
            sha = sha_override.get(key, self.shas[key])
            lines += [f"{key}_VERSION={version}", f"{key}_SHA256={sha}"]
        target = self.repo / "scripts" / "tool-versions.env"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def run_bootstrap(
        self, uname_s: str = "Linux", uname_m: str = "x86_64"
    ) -> subprocess.CompletedProcess[str]:
        env = {
            **os.environ,
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "FAKE_DOWNLOADS": str(self.downloads),
            "FAKE_CURL_LOG": str(self.curl_log),
            "FAKE_UNAME_S": uname_s,
            "FAKE_UNAME_M": uname_m,
        }
        return subprocess.run(
            ["bash", "scripts/bootstrap-dev.sh"],
            cwd=self.repo,
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )

    @property
    def tools(self) -> Path:
        return self.repo / ".tools"

    def downloaded(self) -> list[str]:
        if not self.curl_log.exists():
            return []
        return self.curl_log.read_text(encoding="utf-8").split()


class PinTests(BootstrapTestCase):
    """SHA-256 pins and the platform guard (TC-T08-22, TC-T08-23)."""

    def test_good_pins_install_every_tool(self) -> None:
        """TC-T08-22: with matching pins all three binaries and the wrapper are installed."""
        out = self.run_bootstrap()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(len(self.downloaded()), 4)
        for name in ("gitleaks", "actionlint", "shellcheck", "pre-commit"):
            self.assertTrue(os.access(self.tools / name, os.X_OK), name)

    def test_empty_pre_commit_sha_fails(self) -> None:
        """TC-T08-22: an empty PRE_COMMIT_SHA256 is an error, never a pass."""
        self.write_versions(PRE_COMMIT="")
        out = self.run_bootstrap()
        self.assertEqual(out.returncode, 1)
        self.assertIn("PRE_COMMIT_SHA256 is not pinned", out.stderr)
        self.assertFalse((self.tools / "pre-commit").exists())

    def test_empty_binary_sha_fails_and_installs_nothing(self) -> None:
        """TC-T08-22: an empty SHA-256 for a release binary exits 1."""
        self.write_versions(GITLEAKS="")
        out = self.run_bootstrap()
        self.assertEqual(out.returncode, 1)
        self.assertIn("SHA-256 of gitleaks is not pinned", out.stderr)
        self.assertFalse((self.tools / "gitleaks").exists())

    def test_pre_commit_mismatch_fails_and_removes_the_download(self) -> None:
        """TC-T08-23: a wrong pre-commit checksum exits 1, removes the file, no wrapper."""
        self.write_versions(PRE_COMMIT="0" * 64)
        out = self.run_bootstrap()
        self.assertEqual(out.returncode, 1)
        self.assertIn("checksum mismatch", out.stderr)
        self.assertFalse((self.tools / "pre-commit").exists())
        self.assertEqual(list(self.tools.glob("*.pyz")), [])

    def test_binary_mismatch_fails_and_installs_nothing(self) -> None:
        """TC-T08-23: a wrong tarball checksum exits 1, removes the archive, installs nothing."""
        self.write_versions(ACTIONLINT="f" * 64)
        out = self.run_bootstrap()
        self.assertEqual(out.returncode, 1)
        self.assertIn("checksum mismatch", out.stderr)
        self.assertFalse((self.tools / "actionlint").exists())
        self.assertFalse((self.tools / "shellcheck").exists())
        self.assertEqual(list(self.tools.glob("actionlint-*.tar.gz")), [])

    def test_not_linux_x86_64_exits_with_a_message(self) -> None:
        """TC-T08-22: any other platform exits 1 before a binary is installed."""
        for uname_s, uname_m in (("Darwin", "x86_64"), ("Linux", "aarch64")):
            with self.subTest(platform=f"{uname_s} {uname_m}"):
                out = self.run_bootstrap(uname_s, uname_m)
                self.assertEqual(out.returncode, 1)
                self.assertIn("Linux x86_64 only", out.stderr)
                self.assertIn(f"This is {uname_s} {uname_m}", out.stderr)
                self.assertFalse((self.tools / "gitleaks").exists())


class RerunTests(BootstrapTestCase):
    """Second runs: cached tarballs and cached binaries (TC-T08-23)."""

    def test_cached_tarball_is_verified_again(self) -> None:
        """TC-T08-23: a corrupted cached tarball fails the next run without a download."""
        self.assertEqual(self.run_bootstrap().returncode, 0)
        before = self.downloaded()
        archive = self.tools / f"gitleaks-{VERSIONS['GITLEAKS']}.tar.gz"
        archive.write_bytes(b"corrupted")
        out = self.run_bootstrap()
        self.assertEqual(out.returncode, 1)
        self.assertIn("checksum mismatch", out.stderr)
        self.assertFalse(archive.exists())
        self.assertEqual(self.downloaded(), before)

    def test_untrusted_installed_binary_is_replaced_from_the_verified_tarball(self) -> None:
        """TC-T08-23: a cached binary with the right version string is not kept as is."""
        self.assertEqual(self.run_bootstrap().returncode, 0)
        genuine = (self.tools / "gitleaks").read_bytes()
        planted = f"#!/bin/sh\necho gitleaks version {VERSIONS['GITLEAKS']} planted\n"
        (self.tools / "gitleaks").write_text(planted, encoding="utf-8")
        out = self.run_bootstrap()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual((self.tools / "gitleaks").read_bytes(), genuine)
        self.assertNotIn("planted", out.stdout)


if __name__ == "__main__":
    unittest.main()
