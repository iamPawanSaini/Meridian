#!/usr/bin/env python3
"""T04 checks on docs/TRACEABILITY.md against solution-architecture.md (python3 stdlib only).

Usage: python3 -I check_trace.py CHECK [--sa PATH] [--tr PATH] [--base GITREF]
Exit 0 = pass, 1 = fail, 2 = usage. A missing file or missing table always FAILS.
CHECK is one of: header, ids, nocells, parents, tasks, levels, patterns, status, text,
rtable, rlinks, unchanged, all
Designed from docs/TASKS.md T04, the plan and decision D-1, not from the finished table.
"""
import re, subprocess, sys, os

LEVELS = {"unit", "integration", "contract", "end-to-end", "security", "performance",
          "data reconciliation", "manual simulation", "docs check"}
STATUS_RE = re.compile(r"^(Planned|Partially verified|Verified|Blocked \(accepted, re-run in T\d+a?\))$")
PLACEHOLDER = re.compile(r"^(tbd|todo|n/?a|-+|\?+|none|\.\.\.)$", re.I)
RHDR = ["Req", "Requirement", "Refined IDs (T02)", "Tasks", "Design element (T03)",
        "Test cases", "Evidence", "Status"]
PHDR_WORDS = ["id", "parent", "verifying", "level", "planned test", "case", "status"]
ID_RE = re.compile(r"^(FR|NFR)-\d{2}$")


def cells(line):
    s = line.strip()
    if s.startswith("|"): s = s[1:]
    if s.endswith("|"): s = s[:-1]
    return [c.strip() for c in s.split("|")]


def table_after(lines, start):
    """rows (list of cell lists) of the first table at/after line index start; header first."""
    i = start
    while i < len(lines) and not lines[i].lstrip().startswith("|"):
        i += 1
    rows = []
    while i < len(lines) and lines[i].lstrip().startswith("|"):
        c = cells(lines[i])
        if not all(re.fullmatch(r":?-{3,}:?", x) for x in c):
            rows.append(c)
        i += 1
    return rows


def parse_sa(text):
    out = {}
    for ln in text.splitlines():
        if not ln.lstrip().startswith("|"): continue
        c = cells(ln)
        if len(c) >= 6 and ID_RE.match(c[0]):
            tasks = [t.strip() for t in c[-1].split(",") if t.strip()]
            out[c[0]] = (c[1], tasks)
    return out


def parse_planned(text):
    lines = text.splitlines()
    for i, ln in enumerate(lines):
        if re.match(r"^#+ .*planned tests", ln, re.I):
            rows = table_after(lines, i + 1)
            if rows: return rows[0], rows[1:]
    return None, None


def parse_rtable(text):
    lines = text.splitlines()
    for i, ln in enumerate(lines):
        if ln.lstrip().startswith("| Req |"):
            rows = table_after(lines, i)
            return rows[0], rows[1:]
    return None, None


def split_levels(cell):
    return [x.strip().lower() for x in re.split(r"[;,/]", cell) if x.strip()]


def need(tr):
    return parse_planned(tr)[1]


# each check returns a list of failure strings
def ck_header(sa, tr):
    h, rows = parse_planned(tr)
    if h is None: return ["no heading containing 'Planned tests' followed by a table"]
    errs = []
    if len(h) != 7: errs.append(f"planned table has {len(h)} columns, expected 7")
    else:
        for w, c in zip(PHDR_WORDS, h):
            if w not in c.lower(): errs.append(f"column '{c}' should contain '{w}'")
    return errs


def ck_ids(sa, tr):
    rows = need(tr)
    if rows is None: return ["planned table missing"]
    s = parse_sa(sa)
    if len(s) < 49 and "MINI" not in os.environ:
        return [f"solution-architecture has only {len(s)} FR/NFR rows (expected at least 49)"]
    ids = [r[0] for r in rows]
    errs = []
    dup = sorted({i for i in ids if ids.count(i) > 1})
    if dup: errs.append(f"duplicate ids {dup}")
    miss = sorted(set(s) - set(ids)); extra = sorted(set(ids) - set(s))
    if miss: errs.append(f"missing rows {miss}")
    if extra: errs.append(f"rows not in solution-architecture {extra}")
    return errs


def ck_nocells(sa, tr):
    rows = need(tr)
    if rows is None: return ["planned table missing"]
    errs = []
    for r in rows:
        if len(r) != 7: errs.append(f"{r[0]}: {len(r)} cells"); continue
        for k, c in enumerate(r):
            if not c or PLACEHOLDER.match(c): errs.append(f"{r[0]}: empty/placeholder cell {k+1}")
    return errs


def ck_parents(sa, tr):
    rows = need(tr); s = parse_sa(sa)
    if rows is None or not s: return ["table or SA missing"]
    return [f"{r[0]}: parent {r[1]} != {s[r[0]][0]}" for r in rows
            if r[0] in s and len(r) > 1 and r[1] != s[r[0]][0]]


def ck_tasks(sa, tr):
    rows = need(tr); s = parse_sa(sa)
    if rows is None or not s: return ["table or SA missing"]
    errs = []
    for r in rows:
        if r[0] in s and len(r) == 7:
            got = [t.strip() for t in r[2].split(",") if t.strip()]
            if got != s[r[0]][1]: errs.append(f"{r[0]}: tasks {got} != {s[r[0]][1]}")
    return errs


def ck_levels(sa, tr):
    rows = need(tr)
    if rows is None: return ["planned table missing"]
    errs = []
    for r in rows:
        if len(r) != 7: continue
        lv = split_levels(r[3])
        if not lv: errs.append(f"{r[0]}: no level")
        for x in lv:
            if x not in LEVELS: errs.append(f"{r[0]}: level '{x}' not in controlled vocabulary")
    return errs


def ck_patterns(sa, tr):
    rows = need(tr); s = parse_sa(sa)
    if rows is None or not s: return ["table or SA missing"]
    errs = []
    for r in rows:
        if r[0] in s and len(r) == 7:
            pats = re.findall(r"TC-(T\d+a?)-(?:\*|nn|\d+|\w+)", r[5])
            if pats != s[r[0]][1]:
                errs.append(f"{r[0]}: case patterns name tasks {pats}, expected {s[r[0]][1]} in order")
    return errs


def ck_status(sa, tr):
    rows = need(tr)
    if rows is None: return ["planned table missing"]
    return [f"{r[0]}: status '{r[6]}' not in vocabulary" for r in rows
            if len(r) == 7 and not STATUS_RE.match(r[6])]


def ck_text(sa, tr):
    rows = need(tr)
    if rows is None: return ["planned table missing"]
    return [f"{r[0]}: planned test text too short to be a test" for r in rows
            if len(r) == 7 and len(r[4]) < 20]


def ck_rtable(sa, tr):
    h, rows = parse_rtable(tr)
    if h is None: return ["R table not found"]
    errs = []
    if h != RHDR: errs.append(f"R table header changed: {h}")
    ids = [r[0] for r in rows]
    if "MINI" not in os.environ and ids != [f"R-{n:02d}" for n in range(1, 13)]:
        errs.append(f"R rows are {ids}")
    return errs


def ck_rlinks(sa, tr):
    h, rows = parse_rtable(tr)
    s = parse_sa(sa)
    if h is None or not s: return ["R table or SA missing"]
    errs = []
    for r in rows:
        if len(r) < 8: errs.append(f"{r[0]}: short row"); continue
        refined = [x.strip() for x in r[2].split(",") if x.strip()]
        sa_ids = sorted(i for i, (p, _) in s.items() if p == r[0])
        if sorted(refined) != sa_ids: errs.append(f"{r[0]}: refined IDs {refined} != SA children {sa_ids}")
        for i in sa_ids:
            if i not in r[5]: errs.append(f"{r[0]}: Test cases cell does not link {i}")
    return errs


def ck_unchanged(sa, tr, base="task/T03-technical-design"):
    try:
        old = subprocess.run(["git", "show", f"{base}:docs/TRACEABILITY.md"], capture_output=True,
                             text=True, check=True).stdout
    except Exception as e:
        return [f"cannot read base TRACEABILITY from {base}: {e}"]
    oh, orows = parse_rtable(old); nh, nrows = parse_rtable(tr)
    if oh is None or nh is None: return ["R table not found in base or current"]
    errs = []
    if oh != nh: errs.append("header changed")
    new = {r[0]: r for r in nrows}
    for r in orows:
        n = new.get(r[0])
        if not n: errs.append(f"{r[0]} removed"); continue
        for k in range(5):
            if r[k] != n[k]: errs.append(f"{r[0]}: column '{oh[k]}' changed")
        for k in (5, 6):  # Test cases / Evidence may gain links but must keep old text
            if r[k] and r[k] not in n[k]: errs.append(f"{r[0]}: old '{oh[k]}' text no longer present")
    return errs


CHECKS = {"header": ck_header, "ids": ck_ids, "nocells": ck_nocells, "parents": ck_parents,
          "tasks": ck_tasks, "levels": ck_levels, "patterns": ck_patterns, "status": ck_status,
          "text": ck_text, "rtable": ck_rtable, "rlinks": ck_rlinks}


def main(argv):
    if len(argv) < 2: print(__doc__); return 2
    name = argv[1]
    opt = {"--sa": "docs/architecture/solution-architecture.md",
           "--tr": "docs/TRACEABILITY.md", "--base": "task/T03-technical-design"}
    a = argv[2:]
    while a:
        if a[0] in opt and len(a) > 1: opt[a[0]] = a[1]; a = a[2:]
        else: print("bad arg", a[0]); return 2
    for p in (opt["--sa"], opt["--tr"]):
        if not os.path.isfile(p) or os.path.getsize(p) == 0:
            print(f"FAIL missing or empty {p}"); return 1
    sa = open(opt["--sa"]).read(); tr = open(opt["--tr"]).read()
    names = list(CHECKS) + ["unchanged"] if name == "all" else [name]
    bad = 0
    for n in names:
        if n == "unchanged": errs = ck_unchanged(sa, tr, opt["--base"])
        elif n in CHECKS: errs = CHECKS[n](sa, tr)
        else: print("unknown check", n); return 2
        for e in errs[:8]: print(f"  [{n}] {e}")
        if len(errs) > 8: print(f"  [{n}] ... {len(errs)-8} more")
        bad += bool(errs)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
