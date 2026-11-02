#!/usr/bin/env python3
"""PreToolUse guard that limits where a Meridian subagent may write.

Each agent's frontmatter wires this hook, so it runs only while that agent is active.
Claude Code passes the tool call as JSON on stdin. Exit code 2 blocks the call, and
stderr is shown to the agent as the reason.

Usage (from agent frontmatter):
    guard_paths.py --allow 'docs/*' --bash readonly
    guard_paths.py --allow 'docs/tests/*' --allow '*/tests/*' --bash tester
    guard_paths.py --allow '*' --deny 'docs/tests/*/test-cases.md' --bash developer

Path globs use fnmatch on repo-relative POSIX paths, so '*' also matches '/'.

Limitation: shell analysis is heuristic. It blocks the usual ways to write files
(redirects, tee, cp/mv/rm, in-place edits, git history changes), but an interpreter
one-liner can still write. Code review and git diff are the backstop
(docs/process/WORKFLOW.md).
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import shlex
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR") or Path(__file__).resolve().parents[2])

# Paths no agent may write, whatever its allow list: secrets and the guard rails themselves.
ALWAYS_DENY = [
    ".env",
    ".env.*",
    "*/.env",
    ".claude/agents/*",
    ".claude/hooks/*",
    ".claude/settings.json",
    ".claude/settings.local.json",
    ".git/*",
]
ALWAYS_DENY_EXCEPT = [".env.example"]

TEMP_PREFIXES = ("/tmp/", "/var/tmp/", "/dev/null")

WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

# Commands that change files or state. Used in readonly mode.
MUTATING_COMMANDS = {
    "rm",
    "rmdir",
    "mv",
    "cp",
    "touch",
    "mkdir",
    "chmod",
    "chown",
    "ln",
    "tee",
    "truncate",
    "dd",
    "install",
    "patch",
    "unzip",
    "tar",
}
GIT_MUTATING = {
    "commit",
    "push",
    "reset",
    "checkout",
    "switch",
    "rebase",
    "merge",
    "add",
    "rm",
    "mv",
    "stash",
    "tag",
    "clean",
    "apply",
    "am",
    "cherry-pick",
    "restore",
    "pull",
    "revert",
    "worktree",
    "update-ref",
    "filter-branch",
    "gc",
    "prune",
}
PKG_MUTATING = re.compile(
    r"^(npm|pnpm|yarn)\s+(i|install|add|remove|uninstall|update|ci)\b"
    r"|^composer\s+(install|require|remove|update)\b"
    r"|^(pip|pip3|uv|poetry)\s+(install|uninstall|add|remove|sync)\b"
    r"|^python3?\s+-m\s+pip\s+(install|uninstall)\b"
)


class Denied(Exception):
    """Raised with the reason a tool call is blocked."""


def rel_path(raw: str, cwd: str | None) -> tuple[str, bool]:
    """Return (path relative to repo root or absolute, inside_repo)."""
    path = Path(raw)
    if not path.is_absolute():
        path = Path(cwd or REPO_ROOT) / path
    resolved = Path(os.path.normpath(str(path)))
    try:
        return resolved.relative_to(REPO_ROOT).as_posix(), True
    except ValueError:
        return resolved.as_posix(), False


def matches(rel: str, globs: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(rel, g) for g in globs)


def check_path(raw: str, cwd: str | None, allow: list[str], deny: list[str]) -> None:
    rel, inside = rel_path(raw, cwd)
    if not inside:
        if rel.startswith(TEMP_PREFIXES) or rel == "/dev/null":
            return
        raise Denied(f"'{raw}' is outside the repository; only temp dirs are allowed.")
    if rel not in ALWAYS_DENY_EXCEPT and matches(rel, ALWAYS_DENY):
        raise Denied(f"'{rel}' is protected (secrets, git internals or agent guard rails).")
    if matches(rel, deny):
        raise Denied(f"'{rel}' is outside this agent's write area (denied by rule).")
    if not matches(rel, allow):
        raise Denied(f"'{rel}' is outside this agent's write area. Allowed: {', '.join(allow)}")


OPERATOR_CHARS = set(";&|()<>")
WRAPPERS = {"sudo", "env", "command", "exec", "time", "nice", "xargs"}
SAFE_TARGETS = {"/dev/null", "/dev/stdout", "/dev/stderr", "-"}


def parse_command(command: str) -> tuple[list[list[str]], list[str]]:
    """Tokenise a shell command, respecting quotes.

    Returns (segments, write_targets): segments are simple-command token lists split on
    control operators; write_targets are files named by output redirects.
    Quoted text such as grep "a|b" or awk '$1 > 5' stays inside one word (DEF-001).
    """
    # Newlines and backticks separate commands; replacing them inside quotes only alters
    # literal text, which does not affect the checks.
    text = command.replace("\n", " ; ").replace("`", " ; ")
    lexer = shlex.shlex(text, posix=True, punctuation_chars=";&|()<>")
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        tokens = list(lexer)
    except ValueError as exc:
        raise Denied(f"could not parse shell command safely ({exc}).") from exc

    segments: list[list[str]] = []
    targets: list[str] = []
    current: list[str] = []
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok and set(tok) <= OPERATOR_CHARS:
            if ">" in tok or "<" in tok:
                if current and current[-1].isdigit():
                    current.pop()  # file descriptor, as in 2>&1
                nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
                if (
                    ">" in tok
                    and nxt
                    and nxt not in SAFE_TARGETS
                    and not (tok.endswith("&") and nxt.isdigit())
                ):
                    targets.append(nxt)
                i += 2
                continue
            if current:
                segments.append(current)
            current = []
            i += 1
            continue
        current.append(tok)
        i += 1
    if current:
        segments.append(current)

    cleaned = []
    for seg in segments:
        while seg and (
            re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[0]) or seg[0] in WRAPPERS or seg[0] == "$"
        ):
            seg = seg[1:]
        if seg:
            cleaned.append(seg)
    return cleaned, targets


def file_args(tokens: list[str]) -> list[str]:
    return [t for t in tokens[1:] if not t.startswith("-")]


def check_bash(command: str, mode: str, cwd: str | None, allow: list[str], deny: list[str]) -> None:
    if mode == "full":
        return
    if re.search(r"--no-verify\b", command) or re.search(r"\bgit\s+commit\b.*\s-n\b", command):
        raise Denied("bypassing git hooks (--no-verify) is not allowed.")
    segments, targets = parse_command(command)
    if mode == "developer":
        for target in targets:
            check_path(target, cwd, allow, deny)
        return

    readonly = mode == "readonly"

    for target in targets:
        if readonly:
            raise Denied(
                f"read-only agent: output redirect to '{target}' is not allowed. "
                "Use the Write tool for docs/."
            )
        check_path(target, cwd, allow, deny)

    for tokens in segments:
        name = os.path.basename(tokens[0])
        joined = " ".join(tokens)
        if name == "git" and len(tokens) > 1:
            sub = next((t for t in tokens[1:] if not t.startswith("-")), "")
            if sub in GIT_MUTATING or (
                sub == "branch" and any(t in {"-d", "-D", "-m", "-M"} for t in tokens)
            ):
                raise Denied(
                    f"'git {sub}' changes repository state; "
                    "only the main session or developer may do that."
                )
            continue
        if PKG_MUTATING.search(joined):
            raise Denied("installing or removing packages is not allowed for this agent.")
        in_place = name in {"sed", "perl", "ruby"} and any(
            t == "-i" or t.startswith("-i") for t in tokens[1:]
        )
        if readonly and (name in MUTATING_COMMANDS or in_place):
            raise Denied(f"read-only agent: '{name}' modifies files. Use the Write tool for docs/.")
        if not readonly:
            if name == "tee" or name in {"touch", "mkdir", "rm", "rmdir", "truncate"}:
                for arg in file_args(tokens):
                    check_path(arg, cwd, allow, deny)
            elif name in {"cp", "mv", "install", "ln"}:
                args = file_args(tokens)
                if args:
                    check_path(args[-1], cwd, allow, deny)
            elif in_place:
                for arg in file_args(tokens)[1:]:
                    check_path(arg, cwd, allow, deny)


def evaluate(payload: dict[str, Any], allow: list[str], deny: list[str], bash_mode: str) -> None:
    tool = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}
    cwd = payload.get("cwd")
    if tool in WRITE_TOOLS:
        raw = tool_input.get("file_path") or tool_input.get("notebook_path")
        if not raw:
            raise Denied(f"{tool} call without a file path.")
        check_path(raw, cwd, allow, deny)
    elif tool == "Bash":
        if bash_mode == "none":
            raise Denied("this agent may not run shell commands.")
        check_bash(tool_input.get("command", ""), bash_mode, cwd, allow, deny)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agent", default="subagent", help="agent name for messages")
    parser.add_argument("--allow", action="append", default=[], help="glob of writable paths")
    parser.add_argument("--deny", action="append", default=[], help="glob of protected paths")
    parser.add_argument(
        "--bash", choices=["none", "readonly", "tester", "developer", "full"], default="readonly"
    )
    args = parser.parse_args(argv)

    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("guard_paths: invalid hook input; blocking to be safe.", file=sys.stderr)
        return 2

    try:
        evaluate(payload, args.allow, args.deny, args.bash)
    except Denied as reason:
        print(f"[{args.agent} guard] Blocked: {reason}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
