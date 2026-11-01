#!/usr/bin/env python3
"""Self-test of check_trace.py: a good miniature passes every check; each seeded defect is
rejected by the check meant to catch it. Passes today (it guards the checker, not the content).
The environment variable MINI=1 relaxes only the 49-row and 12-R-row size guards for the miniature."""
import os, sys, tempfile, subprocess
H = os.path.dirname(os.path.abspath(__file__))
SA = """| ID | R | Requirement | Pri | Target | Verifying tasks |
|---|---|---|---|---|---|
| FR-01 | R-01 | a | Must | t | T10, T12 |
| NFR-01 | R-01 | b | Must | t | T21a |
"""
GOOD = """# Traceability
| Req | Requirement | Refined IDs (T02) | Tasks | Design element (T03) | Test cases | Evidence | Status |
|---|---|---|---|---|---|---|---|
| R-01 | x | FR-01, NFR-01 | T10 | d | see FR-01, NFR-01 | | Open |

## Planned tests
| ID | Parent R | Verifying task | Level(s) | Planned test | Planned case ID or pattern | Status |
|---|---|---|---|---|---|---|
| FR-01 | R-01 | T10, T12 | unit, contract | Watchlist change takes effect next run | TC-T10-*, TC-T12-* | Planned |
| NFR-01 | R-01 | T21a | performance | Measure run time with fake LLM | TC-T21a-* | Planned |
"""
LAST = "| NFR-01 | R-01 | T21a | performance | Measure run time with fake LLM | TC-T21a-* | Planned |\n"
MUT = [  # (name, check expected to fail, transform)
    ("drop row", "ids", lambda t: t.replace(LAST, "")),
    ("extra row", "ids", lambda t: t + "| FR-99 | R-01 | T10 | unit | Something quite long here | TC-T10-* | Planned |\n"),
    ("duplicate row", "ids", lambda t: t + LAST),
    ("empty cell", "nocells", lambda t: t.replace("| unit, contract |", "|  |")),
    ("placeholder cell", "nocells", lambda t: t.replace("| unit, contract |", "| TBD |")),
    ("wrong parent", "parents", lambda t: t.replace("| FR-01 | R-01 | T10", "| FR-01 | R-02 | T10")),
    ("wrong task", "tasks", lambda t: t.replace("T10, T12 | unit", "T10, T13 | unit")),
    ("task order", "tasks", lambda t: t.replace("T10, T12 | unit", "T12, T10 | unit")),
    ("bad level", "levels", lambda t: t.replace("performance", "load")),
    ("pattern missing task", "patterns", lambda t: t.replace("TC-T10-*, TC-T12-*", "TC-T10-*")),
    ("bad status", "status", lambda t: t.replace("| Planned |\n| NFR", "| Maybe |\n| NFR")),
    ("stub text", "text", lambda t: t.replace("Measure run time with fake LLM", "TBD")),
    ("R link missing", "rlinks", lambda t: t.replace("see FR-01, NFR-01", "see FR-01")),
    ("R header changed", "rtable", lambda t: t.replace("| Evidence |", "| Proof |")),
    ("no planned section", "header", lambda t: t.replace("## Planned tests", "## Other")),
]


def run(chk, tr, sa, mini=True):
    with tempfile.TemporaryDirectory() as d:
        a, b = os.path.join(d, "sa.md"), os.path.join(d, "tr.md")
        open(a, "w").write(sa); open(b, "w").write(tr)
        env = dict(os.environ)
        if mini: env["MINI"] = "1"
        else: env.pop("MINI", None)
        return subprocess.run([sys.executable, "-I", os.path.join(H, "check_trace.py"), chk, "--sa", a, "--tr", b],
                              capture_output=True, text=True, env=env).returncode


bad = 0
for c in ("header", "ids", "nocells", "parents", "tasks", "levels", "patterns", "status", "text", "rtable", "rlinks"):
    ok = run(c, GOOD, SA) == 0; bad += not ok
    print(f"  {'PASS' if ok else 'FAIL'}  good miniature accepted by '{c}'")
for name, c, f in MUT:
    ok = run(c, f(GOOD), SA) == 1; bad += not ok
    print(f"  {'PASS' if ok else 'FAIL'}  seeded defect rejected: {name} (check '{c}')")
ok = run("ids", "", SA) == 1; bad += not ok
print(f"  {'PASS' if ok else 'FAIL'}  empty TRACEABILITY rejected")
ok = run("ids", GOOD, SA, mini=False) == 1; bad += not ok
print(f"  {'PASS' if ok else 'FAIL'}  a 2-row table is rejected against the real 49-row size guard")
sys.exit(1 if bad else 0)
