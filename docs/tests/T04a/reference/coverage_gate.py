"""Reference model (NOT production) used only to prove the T04a run-checks harness can pass."""
import argparse
import json
import sys
import xml.etree.ElementTree as ET

ap = argparse.ArgumentParser()
ap.add_argument("--thresholds", required=True)
ap.add_argument("xml")
a = ap.parse_args()
try:
    root = ET.parse(a.xml).getroot()
except (OSError, ET.ParseError) as e:
    print(f"cannot read coverage: {e}")
    sys.exit(1)
files = [(c.get("filename", ""), [int(ln.get("hits", "0")) for ln in c.iter("line")]) for c in root.iter("class")]
if not files:
    print("no files in coverage report")
    sys.exit(1)
floors = []


def walk(o: object, ctx: str) -> None:
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                floors.append((ctx + " " + k, v))
            else:
                walk(v, ctx + " " + k)


walk(json.load(open(a.thresholds)), "")
bad = []
for ctx, v in floors:
    fl = v / 100 if v > 1 else v
    for key in ("scoring", "risk", "lib", "components", "meridian_engine", "meridian_"):
        pass
# generic: every threshold carries a path prefix string next to the number
d = json.load(open(a.thresholds))


def prefixes(o: object):
    if isinstance(o, dict):
        p = [v for k, v in o.items() if isinstance(v, str) and "/" in v]
        n = [v for k, v in o.items() if isinstance(v, (int, float)) and not isinstance(v, bool)]
        if p and n:
            yield p[0], n[0]
        for v in o.values():
            yield from prefixes(v)
    elif isinstance(o, list):
        for v in o:
            yield from prefixes(v)


for prefix, floor in prefixes(d):
    fl = floor / 100 if floor > 1 else floor
    sel = [h for f, h in files if prefix.rstrip("/") in f]
    if sel:
        hits = [x for h in sel for x in h]
        rate = sum(1 for x in hits if x) / len(hits)
        if rate + 1e-9 < fl:
            names = ",".join(f for f, _ in files if prefix.rstrip("/") in f)
            bad.append(f"{prefix}: {rate:.3f} < {fl} ({names})")
print("\n".join(bad))
sys.exit(1 if bad else 0)
