#!/usr/bin/env python3
"""T04 checks: severity levels and defect workflow states agree across
docs/tests/master-test-plan.md, docs/tests/defects.md and docs/templates/defect.md.
Usage: python3 -I check_defects.py severity|states|workflow|legacy
Exit 0 pass, 1 fail. Missing files FAIL. Stdlib only."""

import os
import re
import sys

MP, DF, TP = "docs/tests/master-test-plan.md", "docs/tests/defects.md", "docs/templates/defect.md"
SEV = ["Critical", "High", "Medium", "Low"]
STATES = [
    "Open",
    "Triaged",
    "In progress",
    "Fixed",
    "Retest passed",
    "Closed",
    "Reopened",
    "Won't fix",
]


def rd(p):
    if not os.path.isfile(p) or os.path.getsize(p) == 0:
        print(f"FAIL missing or empty {p}")
        sys.exit(1)
    return open(p).read()


def cells(ln):
    return [c.strip() for c in ln.strip().strip("|").split("|")]


def sev_rows(t):
    out = []
    for ln in t.splitlines():
        if ln.lstrip().startswith("|"):
            c = cells(ln)
            if len(c) >= 2 and c[0] in SEV:
                out.append((c[0], re.sub(r"\s+", " ", c[1]).lower()))
    return out


def section(t, rx):
    on = False
    lv = 0
    out = []
    for ln in t.splitlines():
        m = re.match(r"^(#+) ", ln)
        if m:
            if on and len(m.group(1)) <= lv:
                on = False
            if not on and re.search(rx, ln, re.I):
                on = True
                lv = len(m.group(1))
        if on:
            out.append(ln)
    return "\n".join(out)


def severity():
    mp, df, tp = rd(MP), rd(DF), rd(TP)
    bad = []
    ms = sev_rows(section(mp, r"severity"))
    if [s for s, _ in ms] != SEV:
        bad.append(f"master plan severity rows {[s for s, _ in ms]} != {SEV}")
    ds = sev_rows(df)
    if ds:
        if [s for s, _ in ds] != SEV:
            bad.append(f"defects.md severity rows {[s for s, _ in ds]}")
        elif ds != ms:
            bad.append("severity meanings differ between master plan and defects.md")
    if not re.search(r"\]\([^)]*master-test-plan\.md", df):
        bad.append("defects.md must link to master-test-plan.md as the single source")
    m = re.search(r"^\|\s*Severity\s*\|(.*)\|\s*$", tp, re.M)
    if not m:
        bad.append("template has no Severity row")
    else:
        got = [x.strip() for x in m.group(1).split("/")]
        if got != SEV:
            bad.append(f"template Severity line {got}")
    for b in bad:
        print("  " + b)
    return 1 if bad else 0


def states():
    mp, df, tp = rd(MP), rd(DF), rd(TP)
    bad = []
    m = re.search(r"^\|\s*Status\s*\|(.*)\|\s*$", tp, re.M)
    if not m:
        bad.append("template has no Status row")
    else:
        got = [x.strip() for x in m.group(1).split("/")]
        if got != STATES:
            bad.append(f"template Status line {got} != {STATES}")
    for name, t in (
        ("defects.md", df),
        ("master-test-plan.md defect section", section(mp, r"defect")),
    ):
        for s in STATES:
            if not re.search(r"(?<![A-Za-z])" + re.escape(s) + r"(?![A-Za-z])", t):
                bad.append(f"{name}: state '{s}' missing")
    for b in bad:
        print("  " + b)
    return 1 if bad else 0


def workflow():
    df = rd(DF)
    bad = []
    rows = {}
    for ln in df.splitlines():
        if ln.lstrip().startswith("|"):
            c = cells(ln)
            if c and c[0] in STATES:
                rows[c[0]] = ln
    for s in STATES:
        if s not in rows:
            bad.append(f"no table row for state {s}")
        elif not re.search(
            r"tester|developer|technical-architect|solution-architect|owner|main session",
            rows[s],
            re.I,
        ):
            bad.append(f"state {s}: row names no role (who moves it)")
    sla = section(df, r"triage|sla")
    for s in SEV:
        if not re.search(
            r"^\|\s*" + s + r"\s*\|.*\d+\s*(hours?|h|days?|working days?|business days?)",
            sla,
            re.I | re.M,
        ):
            bad.append(f"triage SLA row for {s} missing or without a number and unit")
    low = df.lower()
    if not re.search(r"retest[^.\n]{0,80}tester|tester[^.\n]{0,80}retest", low):
        bad.append("rule: retest by the tester missing")
    if "evidence" not in low:
        bad.append("rule: retest evidence missing")
    if not re.search(
        r"won.t fix[^.\n]{0,160}solution-architect|solution-architect[^.\n]{0,160}won.t fix", low
    ):
        bad.append("rule: Won't fix for Critical/High needs solution-architect missing")
    if not (re.search(r"review finding", low) and "blocker" in low and "note" in low):
        bad.append("section on defects vs review findings (Blocker to Note) missing")
    for b in bad:
        print("  " + b)
    return 1 if bad else 0


def meanings():
    mp = rd(MP)
    ms = sev_rows(section(mp, r"severity"))
    bad = [f"{n}: meaning too short" for n, m in ms if len(m) < 15]
    if len(ms) < 4:
        bad.append("fewer than 4 severity rows")
    for b in bad:
        print("  " + b)
    return 1 if bad else 0


def legacy():
    df = rd(DF)
    bad = []
    for d in ("DEF-001", "DEF-002"):
        if f"### {d}:" not in df:
            bad.append(f"{d} entry removed")
    for m in re.finditer(r"^\|\s*Status\s*\|\s*([^|]+?)\s*\|", df, re.M):
        if m.group(1) not in STATES:
            bad.append(f"entry status '{m.group(1)}' not a workflow state")
    for b in bad:
        print("  " + b)
    return 1 if bad else 0


if __name__ == "__main__":
    f = {
        "severity": severity,
        "states": states,
        "workflow": workflow,
        "legacy": legacy,
        "meanings": meanings,
    }.get(sys.argv[1] if len(sys.argv) > 1 else "")
    sys.exit(f() if f else 2)
