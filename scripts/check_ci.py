#!/usr/bin/env python3
"""Check the CI rules that YAML cannot check itself (T08, plan KD-6). Standard library only.

The workflow files are read line by line with regular expressions: no YAML parser, which is
enough for our own files. Rules (each prints PASS or FAIL with a message):

1. Group coverage: the `scripts/quality.sh --group G` calls in ci.yml equal the groups of
   `quality.sh --list`, and each group is called by exactly one job.
2. Toolchain parity (SA-2 condition 3): ci.yml `php-version` equals `php_version` in
   `.ddev/config.yaml` and `apps/drupal/pantheon.yml` (major.minor); the setup-php Composer
   version equals the DDEV Composer version recorded in `.github/README.md`; once present, the
   engine job `python-version` and the web job `node-version` equal the image tags in
   `.ddev/docker-compose.*.yaml`.
3. Action pins: every non-local `uses:` is `owner/repo@<40 hex>` with a `# owner/repo vX.Y.Z`
   comment on the line above.
4. Secret names: every `secrets.NAME` and `vars.NAME` is named in `docs/runbooks/ci-secrets.md`
   (`GITHUB_TOKEN` is exempt).
5. Least privilege: every workflow has a top-level `permissions:`, and no `write` grant lacks a
   `# Txx:` comment.
6. Heavier-set tripwire (SA-3): if a heavier-set marker exists, ci.yml needs a job whose id
   starts with `heavier-`, and no such job may be in the `needs` of `ci-ok`.

Usage: check_ci.py [--workflows DIR] [--secrets-doc FILE] [--ddev-dir DIR] [--ddev-config FILE]
                   [--pantheon-config FILE] [--github-readme FILE] [--root DIR] [--quality CMD]
Exit 0 when every rule passes, 1 when any rule fails, 2 on a usage error.
"""

from __future__ import annotations

import argparse
import re
import shlex
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

JOB_ID = re.compile(r"^  ([A-Za-z0-9_-]+):\s*(#.*)?$")
GROUP_CALL = re.compile(r"quality\.sh\s+--group\s+(\S+)")
USES = re.compile(r"^\s*(?:-\s+)?uses:\s*(\S+)")
PIN = re.compile(r"^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(?:/[^@\s]+)?@([0-9a-f]{40})$")
PIN_COMMENT = re.compile(r"^\s*#\s*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)\s+v?\d+(?:\.\d+)+\s*$")
NAME_REF = re.compile(r"\b(?:secrets|vars)\.([A-Za-z_][A-Za-z0-9_]*)")
WRITE = re.compile(r"^\s*(?:[A-Za-z-]+:\s*write|permissions:\s*write-all)\s*(?:#.*)?$")
TICKET_COMMENT = re.compile(r"#\s*T\d{2}a?:\s*\S")
HEAVIER_MESSAGE = (
    "heavier-set tests exist but ci.yml has no heavier-* job (decision-heavier-set.md)"
)


def read(path: Path) -> str | None:
    """Return the file text, or None when it cannot be read."""
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def code_lines(text: str) -> list[tuple[int, str]]:
    """Return (1-based line number, line) for every line that is not a comment-only line."""
    return [(n, ln) for n, ln in enumerate(text.splitlines(), 1) if not ln.lstrip().startswith("#")]


def split_jobs(text: str) -> dict[str, list[tuple[int, str]]]:
    """Return the lines of each job in the top-level `jobs:` section, keyed by job id."""
    jobs: dict[str, list[tuple[int, str]]] = {}
    in_jobs = False
    current: str | None = None
    for number, line in enumerate(text.splitlines(), 1):
        if re.match(r"^jobs:\s*$", line):
            in_jobs = True
            current = None
            continue
        if in_jobs and re.match(r"^\S", line) and not line.startswith("#"):
            in_jobs = False
            current = None
        if not in_jobs:
            continue
        match = JOB_ID.match(line)
        if match is not None:
            current = match.group(1)
            jobs[current] = []
            continue
        if current is not None:
            jobs[current].append((number, line))
    return jobs


def quality_groups(quality_cmd: str) -> tuple[list[str] | None, str]:
    """Return the group names printed by `quality.sh --list`, or (None, error)."""
    try:
        proc = subprocess.run(
            [*shlex.split(quality_cmd), "--list"],
            capture_output=True,
            text=True,
            check=False,
            cwd=REPO,
        )
    except OSError as exc:
        return None, f"cannot run {quality_cmd} --list: {exc}"
    if proc.returncode != 0:
        return None, f"{quality_cmd} --list exited {proc.returncode}: {proc.stderr.strip()}"
    groups: list[str] = []
    for line in proc.stdout.splitlines():
        group = line.split("\t", 1)[0]
        if group and group not in groups:
            groups.append(group)
    return groups, ""


def rule1(ci_text: str | None, quality_cmd: str) -> list[str]:
    """Group coverage."""
    if ci_text is None:
        return ["ci.yml not found"]
    groups, error = quality_groups(quality_cmd)
    if groups is None:
        return [error]
    calls: dict[str, list[str]] = {}
    for job, lines in split_jobs(ci_text).items():
        for _, line in lines:
            if line.lstrip().startswith("#"):
                continue
            for group in GROUP_CALL.findall(line):
                calls.setdefault(group, []).append(job)
    problems = []
    for group in groups:
        jobs = calls.get(group, [])
        if not jobs:
            problems.append(f"group '{group}' is in quality.sh --list but no job calls it")
        elif len(jobs) > 1:
            problems.append(f"group '{group}' is called {len(jobs)} times ({', '.join(jobs)})")
    for group in calls:
        if group not in groups:
            problems.append(f"ci.yml calls unknown group '{group}' (quality.sh --list has none)")
    return problems


def first_match(text: str | None, pattern: str) -> str | None:
    """Return group 1 of the first match of pattern in text, else None."""
    if text is None:
        return None
    match = re.search(pattern, text, re.MULTILINE)
    return match.group(1) if match else None


def major_minor(version: str) -> str:
    """Return 'X.Y' of a version string."""
    return ".".join(version.split(".")[:2])


def image_tag(compose: str | None, image: str) -> str | None:
    """Return the version in `image: <image>:<version>` of a compose file."""
    return first_match(compose, rf"^\s*image:\s*{re.escape(image)}:([0-9][0-9.]*)")


def nested_value(text: str | None, parent: str, key: str) -> str | None:
    """Return the value of `key:` inside the top-level mapping `parent:` of a small YAML file."""
    if text is None:
        return None
    inside = False
    for line in text.splitlines():
        if re.match(rf"^{re.escape(parent)}:\s*$", line):
            inside = True
        elif inside and re.match(r"^\S", line):
            inside = False
        elif inside:
            match = re.match(rf"^\s+{re.escape(key)}:\s*['\"]?([A-Za-z0-9.]+)", line)
            if match:
                return match.group(1)
    return None


def database_problems(ci_text: str, ddev_config: Path, pantheon_config: Path) -> list[str]:
    """Database parity (T09): DDEV, Pantheon and the CI MariaDB service share one major.minor."""
    problems = []
    ddev_text = read(ddev_config)
    ddev_type = nested_value(ddev_text, "database", "type")
    ddev_version = nested_value(ddev_text, "database", "version")
    pantheon_version = nested_value(read(pantheon_config), "database", "version")
    ci_version = first_match(
        ci_text, r"^\s*image:\s*['\"]?mariadb:([0-9]+\.[0-9]+\.[0-9]+)(?![0-9.])"
    )
    if ddev_type != "mariadb":
        problems.append(f".ddev/config.yaml: database type is {ddev_type}, expected mariadb")
    if ci_version is None:
        problems.append("ci.yml has no 'image: mariadb:X.Y.Z' service (exact tag, T09)")
    for label, value in (
        (".ddev/config.yaml", ddev_version),
        ("apps/drupal/pantheon.yml", pantheon_version),
    ):
        if value is None:
            problems.append(f"{label}: database version not found")
        elif ci_version is not None and major_minor(value) != major_minor(ci_version):
            problems.append(f"database: ci.yml mariadb {ci_version} differs from {label} {value}")
    return problems


def rule2(
    ci_text: str | None,
    ddev_config: Path,
    pantheon_config: Path,
    github_readme: Path,
    ddev_dir: Path,
) -> list[str]:
    """Toolchain parity."""
    if ci_text is None:
        return ["ci.yml not found"]
    problems = []
    ci_php = first_match(ci_text, r"^\s*php-version:\s*['\"]?([0-9][0-9.]*)")
    ddev_php = first_match(read(ddev_config), r"^php_version:\s*['\"]?([0-9][0-9.]*)")
    pantheon_php = first_match(read(pantheon_config), r"^php_version:\s*['\"]?([0-9][0-9.]*)")
    if ci_php is None:
        problems.append("ci.yml has no php-version (setup-php)")
    for label, value in (
        (".ddev/config.yaml", ddev_php),
        ("apps/drupal/pantheon.yml", pantheon_php),
    ):
        if value is None:
            problems.append(f"{label}: php_version not found")
        elif ci_php is not None and major_minor(value) != major_minor(ci_php):
            problems.append(f"php: ci.yml php-version {ci_php} differs from {label} {value}")
    problems += database_problems(ci_text, ddev_config, pantheon_config)
    ci_composer = first_match(ci_text, r"^\s*tools:.*\bcomposer:([0-9][0-9.]*)")
    readme = read(github_readme)
    readme_composer = None
    if readme is not None:
        match = re.search(
            r"DDEV Composer version:\s*(\d+\.\d+\.\d+)[^\n]*\d{4}-\d{2}-\d{2}", readme
        )
        readme_composer = match.group(1) if match else None
    if ci_composer is None:
        problems.append("ci.yml has no 'tools: composer:<version>' (setup-php)")
    if readme_composer is None:
        problems.append(
            "github README: no 'DDEV Composer version: X.Y.Z' line with a date "
            "(record `ddev exec composer --version`)"
        )
    if ci_composer is not None and readme_composer is not None and ci_composer != readme_composer:
        problems.append(
            f"composer: ci.yml {ci_composer} differs from the DDEV version {readme_composer} "
            "recorded in .github/README.md"
        )
    jobs = split_jobs(ci_text)
    for job, key, compose_file, image in (
        ("engine", "python-version", "docker-compose.engine.yaml", "python"),
        ("web", "node-version", "docker-compose.next.yaml", "node"),
    ):
        block = "\n".join(line for _, line in jobs.get(job, []))
        used = first_match(block, rf"^\s*{key}:\s*['\"]?([0-9][0-9.]*)")
        if used is None:
            continue  # not applicable until the job has a setup step (T13, T21)
        tag = image_tag(read(ddev_dir / compose_file), image)
        if tag is None:
            problems.append(f"{compose_file}: no {image} image tag found")
        elif tag != used:
            problems.append(f"{image}: ci.yml {job} job {key} {used} differs from image {tag}")
    return problems


def workflow_files(workflows: Path) -> list[Path]:
    """Return the workflow YAML files in a directory."""
    return sorted([*workflows.glob("*.yml"), *workflows.glob("*.yaml")])


def rule3(files: list[Path]) -> list[str]:
    """Action pins."""
    problems = []
    for path in files:
        lines = (read(path) or "").splitlines()
        for index, line in enumerate(lines):
            if line.lstrip().startswith("#"):
                continue
            match = USES.match(line)
            if match is None:
                continue
            ref = match.group(1).strip("'\"")
            if ref.startswith("./"):
                continue
            where = f"{path.name}:{index + 1}"
            pin = PIN.match(ref)
            if pin is None:
                problems.append(f"{where}: '{ref}' is not owner/repo@<40 hex commit SHA>")
                continue
            above = lines[index - 1] if index > 0 else ""
            comment = PIN_COMMENT.match(above)
            if comment is None:
                problems.append(f"{where}: no '# owner/repo vX.Y.Z' comment on the line above")
            elif comment.group(1) != f"{pin.group(1)}/{pin.group(2)}":
                problems.append(
                    f"{where}: comment names {comment.group(1)}, not {ref.split('@')[0]}"
                )
    return problems


def rule4(files: list[Path], secrets_doc: Path) -> list[str]:
    """Secret and variable names documented."""
    doc = read(secrets_doc)
    if doc is None:
        return [f"{secrets_doc} not found"]
    problems = []
    for path in files:
        for number, line in code_lines(read(path) or ""):
            for name in NAME_REF.findall(line):
                if name == "GITHUB_TOKEN":
                    continue
                if not re.search(rf"\b{re.escape(name)}\b", doc):
                    problems.append(f"{path.name}:{number}: '{name}' is not in {secrets_doc.name}")
    return problems


def rule5(files: list[Path]) -> list[str]:
    """Least privilege."""
    problems = []
    for path in files:
        text = read(path) or ""
        if not re.search(r"^permissions:", text, re.MULTILINE):
            problems.append(f"{path.name}: no top-level 'permissions:'")
        for number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            if WRITE.match(line.split("#", 1)[0]) and not TICKET_COMMENT.search(line):
                problems.append(
                    f"{path.name}:{number}: write permission without a '# Txx:' comment"
                )
    return problems


def heavier_markers(root: Path) -> list[str]:
    """Return the heavier-set markers found under root (SA-3)."""
    found: list[str] = []
    custom = root / "apps/drupal/web/modules/custom"
    for kind in ("Functional", "FunctionalJavascript"):
        for hit in sorted(custom.glob(f"*/tests/src/{kind}/**/*Test.php")):
            found.append(str(hit.relative_to(root)))
    tests = root / "services/engine/tests"
    if tests.is_dir():
        for hit in sorted(tests.rglob("*")):
            if hit.is_file() and "drupal_live" in (read(hit) or ""):
                found.append(str(hit.relative_to(root)))
    for hit in sorted((root / "apps/web").glob("playwright.config.*")):
        found.append(str(hit.relative_to(root)))
    for hit in sorted((root / ".ddev/commands").glob("*/e2e")):
        found.append(str(hit.relative_to(root)))
    return found


def ci_ok_needs(lines: list[tuple[int, str]]) -> list[str]:
    """Return the job ids listed in `needs:` of a job block."""
    needs: list[str] = []
    collecting = False
    for _, line in lines:
        stripped = line.strip()
        match = re.match(r"^\s{4}needs:\s*(.*)$", line)
        if match is not None:
            rest = match.group(1).split("#", 1)[0].strip()
            if rest:
                needs.extend(x.strip(" '\"") for x in rest.strip("[]").split(",") if x.strip())
                collecting = False
            else:
                collecting = True
            continue
        if collecting:
            if stripped.startswith("- "):
                needs.append(stripped[2:].split("#", 1)[0].strip(" '\""))
            elif stripped and not stripped.startswith("#"):
                collecting = False
    return needs


def rule6(ci_text: str | None, root: Path) -> list[str]:
    """Heavier-set tripwire."""
    markers = heavier_markers(root)
    jobs = split_jobs(ci_text) if ci_text is not None else {}
    heavier = [job for job in jobs if job.startswith("heavier-")]
    problems = []
    if markers and not heavier:
        problems.append(f"{HEAVIER_MESSAGE}: {', '.join(markers)}")
    bad = [n for n in ci_ok_needs(jobs.get("ci-ok", [])) if n.startswith("heavier-")]
    if bad:
        problems.append(f"ci-ok needs {', '.join(bad)}: the heavier set is never a required check")
    return problems


def main(argv: list[str] | None = None) -> int:
    """Entry point; returns the process exit code."""
    parser = argparse.ArgumentParser(description="Check the CI configuration rules (T08).")
    parser.add_argument("--workflows", type=Path, default=REPO / ".github/workflows")
    parser.add_argument("--secrets-doc", type=Path, default=REPO / "docs/runbooks/ci-secrets.md")
    parser.add_argument("--ddev-dir", type=Path, default=REPO / ".ddev")
    parser.add_argument("--ddev-config", type=Path, default=None)
    parser.add_argument("--pantheon-config", type=Path, default=REPO / "apps/drupal/pantheon.yml")
    parser.add_argument("--github-readme", type=Path, default=REPO / ".github/README.md")
    parser.add_argument("--root", type=Path, default=REPO, help="tree scanned for rule 6 markers")
    parser.add_argument("--quality", default=str(REPO / "scripts/quality.sh"))
    args = parser.parse_args(argv)
    ddev_config: Path = args.ddev_config or args.ddev_dir / "config.yaml"

    ci_text = read(args.workflows / "ci.yml")
    files = workflow_files(args.workflows)
    results: list[tuple[int, str, list[str]]] = [
        (1, "group coverage", rule1(ci_text, args.quality)),
        (
            2,
            "toolchain parity",
            rule2(ci_text, ddev_config, args.pantheon_config, args.github_readme, args.ddev_dir),
        ),
        (3, "action pins", rule3(files) if files else [f"no workflows in {args.workflows}"]),
        (4, "secret names documented", rule4(files, args.secrets_doc)),
        (5, "least privilege", rule5(files) if files else [f"no workflows in {args.workflows}"]),
        (6, "heavier-set tripwire", rule6(ci_text, args.root)),
    ]
    failed = False
    for number, title, problems in results:
        if problems:
            failed = True
            print(f"FAIL  rule {number}: {title}")
            for problem in problems:
                print(f"      {problem}")
        else:
            print(f"PASS  rule {number}: {title}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
