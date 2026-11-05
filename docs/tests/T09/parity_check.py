#!/usr/bin/env python3
"""TC-T09-45: parse docs/specs/permissions.md and compare it with config/sync role YAML.

Usage: parity_check.py [DOC] [SYNC_DIR]. Exit 0 when every parsed cell equals the role YAML,
1 otherwise. Mutation (tester): run it against a scratch copy of the doc with one cell changed.
"""

import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[3]
DOC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/specs/permissions.md"
SYNC = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "apps/drupal/config/sync"
ROLES = [
    "administrator",
    "analyst",
    "engine_ingest",
    "dashboard_read",
    "anonymous",
    "authenticated",
]
PERMS = [
    "access content",
    "bypass node access",
    "view meridian records",
    "view meridian watchlist",
    "view meridian inputs",
    "view meridian raw llm output",
    "administer meridian records",
    "ingest meridian records",
    "export meridian records",
]
BUNDLES = ["decision", "position", "daily_run", "price_snapshot", "watchlist_item"]
OPS = ["view", "create", "update", "delete"]


def rows(text):
    for line in text.splitlines():
        if line.startswith("|") and not line.startswith("|---"):
            yield [c.strip() for c in line.strip().strip("|").split("|")]


def main():
    text = DOC.read_text(encoding="utf-8")
    roles = {}
    for r in ROLES:
        d = yaml.safe_load((SYNC / f"user.role.{r}.yml").read_text(encoding="utf-8"))
        roles[r] = (bool(d.get("is_admin")), set(d.get("permissions") or []))

    def has(role, perm):
        admin, perms = roles[role]
        return admin or perm in perms

    errors = []
    seen_perm, seen_op, seen_field = set(), set(), 0
    for c in rows(text):
        if len(c) == 3 and c[0] in ROLES and c[1] in PERMS and c[2] in ("yes", "no"):
            seen_perm.add((c[0], c[1]))
            if (c[2] == "yes") != has(c[0], c[1]):
                errors.append(f"permission cell {c}: yaml says {has(c[0], c[1])}")
        elif len(c) == 4 and c[0] in ROLES and c[1] in BUNDLES and c[2] in OPS:
            seen_op.add((c[0], c[1], c[2]))
            if c[2] == "view":
                perm = (
                    "view meridian watchlist"
                    if c[1] == "watchlist_item"
                    else "view meridian records"
                )
                want = has(c[0], perm) and has(c[0], "access content")
            else:
                want = roles[c[0]][0]
            if (c[3] == "yes") != want:
                errors.append(f"bundle cell {c}: derived {want}")
        elif len(c) == 9 and c[0] in BUNDLES and c[1].startswith("field_") and c[2] in PERMS:
            seen_field += 1
            for role, val in zip(ROLES, c[3:], strict=False):
                if (val == "yes") != has(role, c[2]):
                    errors.append(f"field cell {c[:3]} {role}: yaml says {has(role, c[2])}")
    if len(seen_perm) != len(ROLES) * len(PERMS):
        errors.append(
            f"permission cells parsed: {len(seen_perm)}, expected {len(ROLES) * len(PERMS)}"
        )
    if len(seen_op) != len(ROLES) * len(BUNDLES) * len(OPS):
        errors.append(
            f"bundle cells parsed: {len(seen_op)}, expected {len(ROLES) * len(BUNDLES) * len(OPS)}"
        )
    if seen_field != 13:
        errors.append(f"field rows parsed: {seen_field}, expected 13")
    print(
        f"parsed: {len(seen_perm)} permission cells, {len(seen_op)} bundle cells, "
        f"{seen_field} field rows"
    )
    for e in errors:
        print("MISMATCH", e)
    print("PARITY OK" if not errors else f"PARITY FAILED ({len(errors)})")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
