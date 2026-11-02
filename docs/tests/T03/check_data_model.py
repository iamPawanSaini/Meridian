#!/usr/bin/env python3
"""Structure checks for docs/specs/data-model.md (T03). Stdlib only.
Layout assumed (from the plan, steps D1 and D2): a region headed '...Drupal...' with one
subsection per bundle, and a region headed '...Postgres...' with one subsection per table;
each subsection holds a Markdown table. Drupal field tables need Type, Validation, Indexed
columns; Postgres column tables need Column and Type columns. A missing file fails every check."""

import os
import re
import sys
from pathlib import Path

DM = Path(os.environ.get("DM_PATH", "docs/specs/data-model.md"))
fail = 0


def chk(n, ok, d=""):
    global fail
    ok = bool(ok)
    print(("  PASS  " if ok else "  FAIL  ") + n + (f"  [{d}]" if d and not ok else ""))
    fail += not ok
    return ok


if not chk("data-model.md exists and non-empty", DM.is_file() and DM.stat().st_size > 0):
    sys.exit(1)
lines = DM.read_text().splitlines()


def section(rx, within=None, exact_level=None):
    """Lines of the first heading matching rx (case-insensitive) to the next same-or-higher one."""
    pool = within if within is not None else lines
    for i, ln in enumerate(pool):
        m = re.match(r"(#+) (.*)", ln)
        if m and re.search(rx, m.group(2), re.I):
            lv = len(m.group(1))
            out = [ln]
            for j in range(i + 1, len(pool)):
                mm = re.match(r"(#+) ", pool[j])
                if mm and len(mm.group(1)) <= lv:
                    break
                out.append(pool[j])
            return out
    return None


def tables(sec):
    """list of (header_cells_lower, [row cell lists]) for each table in sec"""
    out, cur = [], None
    for ln in sec:
        if ln.startswith("|"):
            c = [x.strip() for x in ln.strip().strip("|").split("|")]
            if re.fullmatch(r"[|:\- ]+", ln.strip()):
                continue
            if cur is None:
                cur = ([x.lower() for x in c], [])
            else:
                cur[1].append(c)
        else:
            if cur:
                out.append(cur)
                cur = None
    if cur:
        out.append(cur)
    return out


def col(h, rx):
    return next((i for i, x in enumerate(h) if re.search(rx, x)), None)


PLACE = re.compile(r"^(tbd|todo|\?|-|)$", re.I)

drupal = section(r"drupal")
pg = section(r"postgres")
chk("Drupal content model region present", drupal)
chk("Postgres schema region present", pg)

# ---- Drupal bundles
bundles = {
    "decision": r"\bdecision\b",
    "position": r"\bposition\b",
    "daily_run": r"daily[_ ]run",
    "price_snapshot": r"price[_ ]snapshot",
    "watchlist_item": r"watchlist[_ ]item",
}
dsecs = {}
for b, rx in bundles.items():
    s = section(rx, drupal) if drupal else None
    dsecs[b] = s
    if not chk(f"[drupal] subsection for bundle {b}", s):
        continue
    tb = [
        t
        for t in tables(s)
        if col(t[0], r"type") is not None
        and col(t[0], r"valid") is not None
        and col(t[0], r"index") is not None
    ]
    if not chk(f"[drupal:{b}] field table with Type, Validation and Indexed columns", tb):
        continue
    h, rows = tb[0]
    chk(f"[drupal:{b}] at least 5 fields listed", len(rows) >= 5, str(len(rows)))
    empties = []
    for r in rows:
        for k, rx in (("type", r"type"), ("validation", r"valid"), ("indexed", r"index")):
            i = col(h, rx)
            if i >= len(r) or PLACE.match(r[i].strip("`* ")):
                empties.append(f"{r[0]}:{k}")
    chk(
        f"[drupal:{b}] every field has non-empty type, validation and indexed cells (no TBD)",
        not empties,
        str(empties[:6]),
    )
    names = [r[0].strip("`* ") for r in rows]
    chk(f"[drupal:{b}] has external_id field", "external_id" in names)
    ei = next((r for r in rows if r[0].strip("`* ") == "external_id"), None)
    chk(
        f"[drupal:{b}] external_id: unique + regex validation + indexed",
        ei
        and re.search(r"unique", " ".join(ei), re.I)
        and re.search(r"\^|regex|pattern", " ".join(ei), re.I)
        and not re.fullmatch(r"(?i)\s*no\s*", ei[col(h, "index")]),
        str(ei),
    )
    chk(
        f"[drupal:{b}] has field-level visible-to roles info",
        any(col(t[0], r"visible|role|access") is not None for t in tables(s))
        or re.search(r"visible", " ".join(s), re.I),
    )
    chk(
        f"[drupal:{b}] states a bundle-level uniqueness rule for external_id",
        re.search(r"unique", " ".join(s), re.I),
    )
# decision-specific
d = " ".join(dsecs["decision"] or [])
for label, rx in [
    ("inputs snapshot", r"inputs?_?snapshot"),
    ("raw LLM output", r"raw_?llm|llm_?raw|raw_?output"),
    ("prompt version", r"prompt_?version"),
    ("model name", r"model_?name|llm_?model"),
    ("rule version", r"rule_?version"),
]:
    chk(f"[drupal:decision] FR-12 provenance field: {label}", re.search(rx, d, re.I))
rawrow = next(
    (
        ln
        for ln in (dsecs["decision"] or [])
        if ln.startswith("|") and re.search(r"raw_?llm|llm_?raw|raw_?output", ln, re.I)
    ),
    "",
)
chk(
    "[drupal:decision] raw LLM output visible to administrator only",
    re.search(r"administrator", rawrow, re.I)
    and not re.search(r"analyst|dashboard|engine", rawrow, re.I),
    rawrow[:120],
)
for b in ("decision", "position"):
    chk(
        f"[drupal:{b}] references daily run by external_id",
        re.search(r"run", " ".join(dsecs[b] or []), re.I)
        and re.search(r"external_id", " ".join(dsecs[b] or []), re.I)
        and re.search(r"reference", " ".join(dsecs[b] or []), re.I),
    )
chk(
    "[drupal:decision] decision references position/run by external_id",
    re.search(r"reference", d, re.I),
)
chk(
    "[drupal:decision] mode field validated to long|short",
    re.search(r"long", d, re.I) and re.search(r"short", d, re.I),
)
chk(
    "[drupal:*] symbol validated by regex in decision, position, price_snapshot, watchlist_item",
    all(
        re.search(r"symbol", " ".join(dsecs[b] or []), re.I)
        and re.search(r"\^|regex|pattern", " ".join(dsecs[b] or []), re.I)
        for b in ("decision", "position", "price_snapshot", "watchlist_item")
    ),
)

# ---- Postgres tables
pgt = [
    "runs",
    "watchlist_snapshots",
    "prices",
    "decisions",
    "positions",
    "outbox",
    "alembic_version",
]
psecs = {}
for t in pgt:
    s = section(rf"\b{t}\b", pg) if pg else None
    psecs[t] = s
    if not chk(f"[pg] subsection for table {t}", s):
        continue
    txt = " ".join(s)
    tb = [
        x
        for x in tables(s)
        if col(x[0], r"column|name") is not None and col(x[0], r"type") is not None
    ]
    if not chk(f"[pg:{t}] column table with Column and Type", tb):
        continue
    h, rows = tb[0]
    chk(
        f"[pg:{t}] at least {1 if t == 'alembic_version' else 4} columns listed",
        len(rows) >= (1 if t == "alembic_version" else 4),
        str(len(rows)),
    )
    chk(
        f"[pg:{t}] no empty type cells",
        all(
            len(r) > col(h, "type") and not PLACE.match(r[col(h, "type")].strip("`* "))
            for r in rows
        ),
    )
    chk(f"[pg:{t}] primary key stated", re.search(r"primary key|\bPK\b", txt, re.I))
    if t != "alembic_version":
        chk(
            f"[pg:{t}] at least one index specified (name or columns)",
            re.search(r"\bindex|\bidx_|\bix_", txt, re.I),
        )
        chk(
            f"[pg:{t}] NOT NULL / nullability stated",
            re.search(r"not null|nullable|null", txt, re.I),
        )
dec = " ".join(psecs["decisions"] or [])
chk(
    "[pg:decisions] unique constraint on (trade_date, symbol, mode)",
    re.search(r"unique", dec, re.I)
    and re.search(r"trade_date.{0,20}symbol.{0,20}mode", dec, re.I | re.S),
)
for label, rx in [
    ("inputs snapshot", r"inputs?_?snapshot"),
    ("raw LLM output", r"raw_?llm|llm_?raw|raw_?output"),
    ("prompt version", r"prompt_?version"),
    ("model name", r"model_?name|llm_?model"),
    ("rule version", r"rule_?version"),
]:
    row = next(
        (ln for ln in (psecs["decisions"] or []) if ln.startswith("|") and re.search(rx, ln, re.I)),
        "",
    )
    chk(
        f"[pg:decisions] provenance column NOT NULL: {label}",
        row and re.search(r"not null", row, re.I),
        row[:120],
    )
chk(
    "[pg:decisions/positions] foreign key to runs",
    all(
        re.search(r"foreign key|\bFK\b|references", " ".join(psecs[t] or []), re.I)
        for t in ("decisions", "positions")
    ),
)
ob = " ".join(psecs["outbox"] or [])
chk(
    "[pg:outbox] columns: record_type, external_id, payload, status, attempts, next_attempt",
    all(
        re.search(x, ob, re.I)
        for x in (r"record_type", r"external_id", r"payload", r"status", r"attempt", r"next_")
    ),
)
chk(
    "[pg:outbox] status values pending, sent, dead",
    all(re.search(x, ob, re.I) for x in ("pending", "sent", "dead")),
)
chk(
    "[pg:outbox] at most one pending row per (record_type, external_id) (partial unique)",
    re.search(r"unique", ob, re.I)
    and re.search(r"record_type.{0,20}external_id", ob, re.I | re.S)
    and re.search(r"pending|where", ob, re.I),
)
chk(
    "[pg:runs] has status and published (incl. partial) columns",
    re.search(r"status", " ".join(psecs["runs"] or []), re.I)
    and re.search(r"partial", " ".join(psecs["runs"] or []), re.I),
)
chk(
    "[pg:prices] unique per (symbol, trade_date)",
    re.search(r"unique", " ".join(psecs["prices"] or []), re.I)
    and re.search(
        r"symbol.{0,20}(trade_)?date|(trade_)?date.{0,20}symbol",
        " ".join(psecs["prices"] or []),
        re.I | re.S,
    ),
)
chk(
    "[pg:positions] unique constraint stated",
    re.search(r"unique", " ".join(psecs["positions"] or []), re.I),
)
alltxt = "\n".join(lines)
chk(
    "Postgres 16 and no vendor-only features stated",
    re.search(r"postgres(ql)?\s*16", alltxt, re.I) and re.search(r"vendor", alltxt, re.I),
)
print()
print("RESULT:", "FAIL" if fail else "PASS")
sys.exit(1 if fail else 0)
