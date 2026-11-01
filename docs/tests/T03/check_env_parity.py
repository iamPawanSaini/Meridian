#!/usr/bin/env python3
"""Env-matrix vs .env.example name parity (T03). Stdlib only.
Matrix = the Markdown table in docs/architecture/technical-design.md (section whose heading
contains 'environment' and 'secret') whose first header cell is Name/Variable.
Names must equal .env.example names, in both directions."""
import re, sys
from pathlib import Path
TD = Path("docs/architecture/technical-design.md"); EX = Path(".env.example")
fail = 0
def chk(n, ok, d=""):
    global fail
    ok = bool(ok)
    print(("  PASS  " if ok else "  FAIL  ") + n + (f"  [{d}]" if d and not ok else ""))
    fail += (not ok); return ok
if not chk("technical-design.md exists and non-empty", TD.is_file() and TD.stat().st_size > 0): sys.exit(1)
if not chk(".env.example exists", EX.is_file()): sys.exit(1)
lines = TD.read_text().splitlines()
start = next((i for i, l in enumerate(lines) if re.match(r"#+ ", l) and re.search(r"environment", l, re.I) and re.search(r"secret", l, re.I)), None)
if not chk("section heading with 'environment' and 'secrets' found", start is not None): sys.exit(1)
lvl = len(re.match(r"#+", lines[start]).group())
end = len(lines)
for j in range(start + 1, len(lines)):
    m = re.match(r"(#+) ", lines[j])
    if m and len(m.group(1)) <= lvl: end = j; break
rows = [l for l in lines[start:end] if l.startswith("|")]
cells = lambda l: [c.strip() for c in l.strip().strip("|").split("|")]
hdr_i = next((i for i, l in enumerate(rows) if re.search(r"\b(name|variable)\b", cells(l)[0], re.I)), None)
if not chk("matrix table with Name/Variable first column found", hdr_i is not None): sys.exit(1)
hdr = [h.lower() for h in cells(rows[hdr_i])]
need = {"consumer": r"consumer", "purpose": r"purpose", "secret": r"secret", "ddev": r"ddev|local", "pantheon": r"pantheon",
        "vercel": r"vercel", "github": r"github", "task": r"task|introduc"}
col = {}
for k, rx in need.items():
    idx = next((i for i, h in enumerate(hdr) if re.search(rx, h)), None)
    chk(f"matrix column present: {k}", idx is not None); col[k] = idx
body = [cells(l) for l in rows[hdr_i + 1:] if not re.fullmatch(r"[|:\- ]+", l)]
names, bad = [], []
for r in body:
    n = r[0].strip("`* ")
    if re.fullmatch(r"[A-Z][A-Z0-9_]*", n):
        names.append(n)
        for k, i in col.items():
            if i is None or i >= len(r) or not r[i].strip(): bad.append(f"{n}:{k}")
        si = col.get("secret")
        if si is not None and si < len(r) and not re.fullmatch(r"(?i)yes|no", r[si].strip("`* ")): bad.append(f"{n}:secret-not-yes/no")
    else: bad.append(f"non-variable first cell {n!r}")
chk("matrix has at least 12 variables", len(names) >= 12, str(len(names)))
chk("no duplicate variable names in matrix", names and len(names) == len(set(names)))
chk("no empty cells or malformed rows (use 'n/a' explicitly)", not bad, str(bad[:5]))
envn = [m.group(1) for l in EX.read_text().splitlines() if (m := re.match(r"\s*([A-Z][A-Z0-9_]*)=", l))]
chk(".env.example has no duplicate names", envn and len(envn) == len(set(envn)))
chk(".env.example has at least 12 variables", len(envn) >= 12, str(len(envn)))
mx, ex = set(names), set(envn)
chk("every .env.example name is in the matrix", ex and not (ex - mx), "not in matrix: " + ", ".join(sorted(ex - mx)))
chk("every matrix name is in .env.example", mx and not (mx - ex), "not in .env.example: " + ", ".join(sorted(mx - ex)))
chk("no NEXT_PUBLIC_ variable names Drupal (FR-21, server-only base URL)", not any(n.startswith("NEXT_PUBLIC_") and "DRUPAL" in n for n in mx | ex))
for label, rx in [("revalidation secret", r"REVALIDATE.*SECRET|SECRET.*REVALIDATE"), ("revalidate interval", r"REVALIDATE.*(INTERVAL|SECONDS)"),
                  ("Terminus token", r"TERMINUS"), ("Pantheon deploy key", r"DEPLOY_KEY|PANTHEON.*(KEY|SSH)"), ("Postgres URL", r"DATABASE_URL|POSTGRES"),
                  ("Claude key", r"ANTHROPIC_API_KEY"), ("OAuth ingest client", r"INGEST_CLIENT"), ("OAuth read client", r"READ_CLIENT"),
                  ("OAuth key files/paths", r"OAUTH.*(KEY|PATH)|(PRIVATE|PUBLIC)_KEY")]:
    chk(f"matrix lists {label}", any(re.search(rx, n) for n in mx))
leaks = []
for l in EX.read_text().splitlines():
    m = re.match(r"([A-Z][A-Z0-9_]*)=(.*)$", l)
    if m and re.search(r"SECRET|TOKEN|API_KEY|PRIVATE", m.group(1)) and m.group(2).strip() and not re.search(r"change|placeholder|example|your|xxx|<", m.group(2), re.I):
        leaks.append(m.group(1))
chk(".env.example secret-like variables are blank or obvious placeholders", not leaks, str(leaks))
print(); print("RESULT:", "FAIL" if fail else "PASS"); sys.exit(1 if fail else 0)
