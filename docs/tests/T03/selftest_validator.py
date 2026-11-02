#!/usr/bin/env python3
"""Proves validate_openapi.py is not vacuous: the good fixture must pass, and each mutation
must make it fail on the named check. Needs python3 + PyYAML only."""

import copy
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

here = Path(__file__).resolve().parent
good = yaml.safe_load((here / "fixtures" / "good-openapi.yaml").read_text())
V = str(here / "validate_openapi.py")


def run(doc_or_text):
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "o.yaml"
        p.write_text(doc_or_text if isinstance(doc_or_text, str) else yaml.safe_dump(doc_or_text))
        r = subprocess.run([sys.executable, V, str(p)], capture_output=True, text=True)
        return r.returncode, r.stdout


def ing(d):
    return d["paths"]["/api/meridian/v1/ingest"]["post"]


def m(f):
    d = copy.deepcopy(good)
    f(d)
    return d


muts = {
    "openapi 3.0.3": (lambda d: d.__setitem__("openapi", "3.0.3"), "openapi version is 3.1.x"),
    "no info.version": (lambda d: d["info"].pop("version"), "info.version present"),
    "dangling $ref": (
        lambda d: ing(d)["responses"]["422"]["content"]["application/json"]["schema"].__setitem__(
            "$ref", "#/components/schemas/Nope"
        ),
        "every internal $ref resolves",
    ),
    "external $ref": (
        lambda d: ing(d)["responses"]["422"]["content"]["application/json"]["schema"].__setitem__(
            "$ref", "other.yaml#/Error"
        ),
        "all $ref are internal",
    ),
    "missing operationId": (lambda d: ing(d).pop("operationId"), "every operation has operationId"),
    "duplicate operationId": (
        lambda d: d["paths"]["/jsonapi/node/watchlist_item"]["get"].__setitem__(
            "operationId", "ingestBatch"
        ),
        "operationIds are unique",
    ),
    "no security": (
        lambda d: (d.pop("security"), ing(d).pop("security")),
        "every operation has security",
    ),
    "undeclared scope": (
        lambda d: ing(d)["security"][0].__setitem__("oauth2", ["meridian_bogus"]),
        "every scope used in security is declared",
    ),
    "missing 413": (lambda d: ing(d)["responses"].pop("413"), "ingest documents 413"),
    "missing 429": (lambda d: ing(d)["responses"].pop("429"), "ingest documents 429"),
    "missing 401": (lambda d: ing(d)["responses"].pop("401"), "ingest documents 401"),
    "no 2xx": (lambda d: ing(d)["responses"].pop("200"), "ingest has a 2xx response"),
    "maxItems 100": (
        lambda d: d["components"]["schemas"]["IngestBatch"]["properties"]["items"].__setitem__(
            "maxItems", 100
        ),
        "maxItems >= 500",
    ),
    "no maxItems": (
        lambda d: d["components"]["schemas"]["IngestBatch"]["properties"]["items"].pop("maxItems"),
        "declares maxItems",
    ),
    "not clientCredentials": (
        lambda d: d["components"]["securitySchemes"]["oauth2"]["flows"].__setitem__(
            "password",
            d["components"]["securitySchemes"]["oauth2"]["flows"].pop("clientCredentials"),
        ),
        "clientCredentials scheme",
    ),
    "example lacks required": (
        lambda d: ing(d)["requestBody"]["content"]["application/json"]["example"].pop(
            "run_external_id"
        ),
        "request examples include",
    ),
}
bad = 0
rc, out = run(good)
print(("  PASS  " if rc == 0 else "  FAIL  ") + "good fixture accepted (exit 0)")
bad += rc != 0
if rc != 0:
    print(out)
for name, (f, expect) in muts.items():
    rc, out = run(m(f))
    hit = any(ln.startswith("  FAIL") and expect in ln for ln in out.splitlines())
    ok = rc != 0 and hit
    print(("  PASS  " if ok else "  FAIL  ") + f"mutation '{name}' rejected on '{expect}'")
    bad += not ok
rc, out = run("a: [unclosed")
print(("  PASS  " if rc != 0 else "  FAIL  ") + "unparseable YAML rejected")
bad += rc == 0
rc, out = (
    subprocess.run(
        [sys.executable, V, "/nonexistent/openapi.yaml"], capture_output=True, text=True
    ).returncode,
    "",
)
print(("  PASS  " if rc != 0 else "  FAIL  ") + "missing file rejected")
bad += rc == 0
print()
print("RESULT:", "FAIL" if bad else "PASS")
sys.exit(1 if bad else 0)
