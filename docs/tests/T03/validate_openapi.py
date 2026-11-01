#!/usr/bin/env python3
"""Structural validator for docs/architecture/openapi.yaml (T03). Needs python3 + PyYAML only.
Usage: validate_openapi.py [path]   Exit 0 only if every check passes. A missing or
unparseable file fails every dependent check (nothing passes vacuously)."""
import sys, re, urllib.parse
from pathlib import Path

try:
    import yaml
except ImportError:
    print("FAIL  PyYAML not importable"); sys.exit(2)

path = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/architecture/openapi.yaml")
failed = 0
def chk(name, ok, detail=""):
    global failed
    ok = bool(ok)
    print(("  PASS  " if ok else "  FAIL  ") + name + (f"  [{detail}]" if detail and not ok else ""))
    if not ok: failed += 1
    return ok

METHODS = {"get", "put", "post", "delete", "options", "head", "patch", "trace"}

doc = None
if chk("file exists and is non-empty", path.is_file() and path.stat().st_size > 0, str(path)):
    try:
        doc = yaml.safe_load(path.read_text())
    except Exception as e:
        chk("YAML parses", False, str(e)[:120])
    else:
        chk("YAML parses to a mapping", isinstance(doc, dict))
        if not isinstance(doc, dict): doc = None
if doc is None:
    print("  FAIL  no usable document; remaining checks cannot run"); sys.exit(1)

chk("openapi version is 3.1.x", re.fullmatch(r"3\.1\.\d+", str(doc.get("openapi", ""))), str(doc.get("openapi")))
info = doc.get("info") if isinstance(doc.get("info"), dict) else {}
chk("info.title present", info.get("title"))
chk("info.version present", info.get("version"))
chk("paths present and non-empty", isinstance(doc.get("paths"), dict) and doc["paths"])
chk("components present", isinstance(doc.get("components"), dict) and doc["components"])
paths = doc.get("paths") or {}
comps = doc.get("components") or {}

# ---- $ref resolution (internal only)
def resolve(ref):
    if not isinstance(ref, str) or not ref.startswith("#"): return None
    node = doc
    for part in [p for p in ref[1:].split("/") if p != ""]:
        part = urllib.parse.unquote(part).replace("~1", "/").replace("~0", "~")
        if isinstance(node, dict) and part in node: node = node[part]
        elif isinstance(node, list) and part.isdigit() and int(part) < len(node): node = node[int(part)]
        else: return None
    return node
refs = []
def walk(n, loc=""):
    if isinstance(n, dict):
        for k, v in n.items():
            if k == "$ref" and isinstance(v, str): refs.append((loc, v))
            else: walk(v, f"{loc}/{k}")
    elif isinstance(n, list):
        for i, v in enumerate(n): walk(v, f"{loc}/{i}")
walk(doc)
chk("document uses at least one $ref (components reused)", len(refs) > 0)
ext = [r for r in refs if not r[1].startswith("#")]
chk("all $ref are internal (no external files or URLs)", not ext, "; ".join(f"{l}->{r}" for l, r in ext[:3]))
broken = [r for r in refs if r[1].startswith("#") and resolve(r[1]) is None]
chk("every internal $ref resolves", not broken, "; ".join(f"{l}->{r}" for l, r in broken[:3]))

def deref(n, depth=0):
    while isinstance(n, dict) and "$ref" in n and depth < 20:
        n = resolve(n["$ref"]); depth += 1
    return n if n is not None else {}

# ---- operations
ops = []
for p, item in paths.items():
    if not isinstance(item, dict): continue
    for m, op in item.items():
        if str(m).lower() in METHODS and isinstance(op, dict): ops.append((str(m).lower(), p, op))
chk("at least 2 operations (ingest + watchlist read)", len(ops) >= 2, f"found {len(ops)}")
ids = [op.get("operationId") for _, _, op in ops]
chk("every operation has operationId", ops and all(ids), str([f"{m} {p}" for m, p, o in ops if not o.get("operationId")]))
chk("operationIds are unique", ops and len([i for i in ids if i]) == len(set(i for i in ids if i)))
chk("every operation has non-empty responses", ops and all(isinstance(o.get("responses"), dict) and o["responses"] for _, _, o in ops))
gsec = doc.get("security")
def effective_sec(op): return op["security"] if "security" in op else gsec
chk("every operation has security (own or global, non-empty)", ops and all(isinstance(effective_sec(o), list) and effective_sec(o) for _, _, o in ops),
    str([f"{m} {p}" for m, p, o in ops if not effective_sec(o)]))
chk("every operation has tags", ops and all(o.get("tags") for _, _, o in ops))

# ---- security schemes and scopes
schemes = comps.get("securitySchemes") if isinstance(comps.get("securitySchemes"), dict) else {}
chk("securitySchemes declared", schemes)
cc = {}
for n, s in schemes.items():
    s = deref(s)
    if s.get("type") == "oauth2":
        f = (s.get("flows") or {}).get("clientCredentials")
        if isinstance(f, dict): cc[n] = f
chk("an oauth2 clientCredentials scheme is declared", cc)
chk("clientCredentials flow has tokenUrl", cc and all(f.get("tokenUrl") for f in cc.values()))
declared = {n: set((f.get("scopes") or {}).keys()) for n, f in cc.items()}
used, bad_schemes, undeclared = [], [], []
def scan_sec(sec, where):
    for req in sec or []:
        for sname, scopes in (req or {}).items():
            if sname not in schemes: bad_schemes.append(f"{where}:{sname}")
            for sc in scopes or []:
                used.append((where, sname, sc))
                if sc not in declared.get(sname, set()): undeclared.append(f"{where}:{sname}:{sc}")
scan_sec(gsec, "global")
for m, p, o in ops: scan_sec(o.get("security"), f"{m} {p}")
chk("every security requirement names a declared scheme", not bad_schemes, str(bad_schemes[:3]))
chk("every scope used in security is declared in securitySchemes", not undeclared, str(undeclared[:3]))
chk("at least one scope is actually used", len(used) > 0)
badnames = [u[2] for u in used if not re.fullmatch(r"meridian_[a-z_]+", u[2])]
chk("scope names follow meridian_* convention", used and not badnames, str(badnames))
all_declared = set().union(*declared.values()) if declared else set()
for sc in ("meridian_ingest", "meridian_watchlist_read"):
    chk(f"scope {sc} declared", sc in all_declared)

# ---- ingest operation
ingest = [(m, p, o) for m, p, o in ops if m == "post" and p.rstrip("/").endswith("/ingest")]
if chk("exactly one POST .../ingest operation exists", len(ingest) == 1, f"found {len(ingest)}"):
    m, p, op = ingest[0]
    chk("ingest path is /api/meridian/v1/ingest", p == "/api/meridian/v1/ingest", p)
    resp = {str(c): v for c, v in (op.get("responses") or {}).items()}
    codes = set(resp)
    chk("ingest has a 2xx response", any(re.fullmatch(r"2\d\d", c) for c in codes), str(sorted(codes)))
    for c in ("401", "403", "413", "422", "429"):
        chk(f"ingest documents {c}", c in codes)
    sec_scopes = {sc for req in (effective_sec(op) or []) for scs in req.values() for sc in (scs or [])}
    chk("ingest requires scope meridian_ingest", "meridian_ingest" in sec_scopes, str(sec_scopes))
    rb = deref(op.get("requestBody") or {})
    chk("ingest has a required JSON requestBody", rb.get("required") is True and "application/json" in (rb.get("content") or {}))
    media = (rb.get("content") or {}).get("application/json") or {}
    chk("ingest requestBody carries an example or examples", media.get("example") or media.get("examples"))
    seen, arrs = set(), []
    def find_arrays(s, d=0):
        s = deref(s)
        if not isinstance(s, dict) or id(s) in seen or d > 8: return
        seen.add(id(s))
        if s.get("type") == "array" or "maxItems" in s: arrs.append(s)
        for v in (s.get("properties") or {}).values(): find_arrays(v, d + 1)
        for k in ("items", "additionalProperties"):
            if isinstance(s.get(k), dict): find_arrays(s[k], d + 1)
        for k in ("allOf", "oneOf", "anyOf"):
            for v in s.get(k) or []: find_arrays(v, d + 1)
    find_arrays(media.get("schema") or {})
    mx = [a["maxItems"] for a in arrs if isinstance(a.get("maxItems"), int)]
    chk("request batch array declares maxItems", mx, f"arrays={len(arrs)}")
    chk("request batch maxItems >= 500 (NFR-04 / T10)", mx and max(mx) >= 500, str(mx))
    mn = [a["minItems"] for a in arrs if isinstance(a.get("minItems"), int)]
    chk("request batch array declares minItems >= 1", mn and max(mn) >= 1, str(mn))
    chk("typed items use a discriminator", "discriminator" in yaml.safe_dump(doc))
    okc = next((c for c in sorted(codes) if re.fullmatch(r"2\d\d", c)), None)
    if okc:
        rs = deref(resp[okc])
        sch = deref(((rs.get("content") or {}).get("application/json") or {}).get("schema") or {})
        props = {}
        def collect(s, d=0):
            s = deref(s)
            if not isinstance(s, dict) or d > 5: return
            props.update(s.get("properties") or {})
            for v in s.get("allOf") or []: collect(v, d + 1)
        collect(sch)
        chk("2xx response schema has a per-item result list (array property)",
            any(deref(v).get("type") == "array" for v in props.values()), str(list(props)))
    r413 = deref(resp.get("413") or {})
    chk("413 description mentions body size limit", re.search(r"size|bytes|limit|large", str(r413.get("description", "")), re.I))
err_ok = False
for n, s in (comps.get("schemas") or {}).items():
    if re.search(r"error|problem", n, re.I) and re.search(r"\b(path|field|pointer|loc)\b", yaml.safe_dump(s), re.I):
        err_ok = True
chk("an error schema exists that carries field paths", err_ok)

# ---- watchlist read subset
wl = [(m, p, o) for m, p, o in ops if m == "get" and "watchlist_item" in p]
if chk("exactly one GET .../watchlist_item operation exists", len(wl) == 1, f"found {len(wl)}"):
    m, p, op = wl[0]
    chk("watchlist path is /jsonapi/node/watchlist_item", p == "/jsonapi/node/watchlist_item", p)
    sc = {s for req in (effective_sec(op) or []) for scs in req.values() for s in (scs or [])}
    chk("watchlist requires scope meridian_watchlist_read", "meridian_watchlist_read" in sc, str(sc))
    codes = {str(c) for c in (op.get("responses") or {})}
    chk("watchlist documents a 2xx, 401 and 403", any(c.startswith("2") for c in codes) and {"401", "403"} <= codes, str(sorted(codes)))

# ---- examples carry required properties
def check_example(schema, ex, where):
    schema = deref(schema)
    if not (isinstance(schema, dict) and isinstance(ex, dict)): return []
    out = [f"{where}: missing {r}" for r in schema.get("required", []) if r not in ex]
    for k, v in (schema.get("properties") or {}).items():
        if isinstance(ex.get(k), dict): out += check_example(v, ex[k], f"{where}.{k}")
    return out
probs = []
for m, p, o in ops:
    rb = deref(o.get("requestBody") or {})
    for mt, media in (rb.get("content") or {}).items():
        exs = [media["example"]] if "example" in media else []
        for e in (media.get("examples") or {}).values():
            v = deref(e).get("value")
            if v is not None: exs.append(v)
        for ex in exs: probs += check_example(media.get("schema") or {}, ex, f"{m} {p} request")
chk("request examples include their schema's required top-level properties", not probs, str(probs[:3]))

print(); print("RESULT:", "FAIL" if failed else "PASS", f"({failed} failed checks)")
sys.exit(1 if failed else 0)
