"""One seat's spawns by the binding it actually ran on, per sprint, and its passes per step.

Reads spawns.jsonl from an extract.py + spawns.py output dir. Use it to compare a role before and
after a model or effort rebinding. Minutes are first-to-last timestamp per spawn, so they include
idle before a resume (poles.py reports that idle per sprint).

Table 1, per (sprint, model_ran, effort_bound): spawns, median and p90 minutes, minutes per API
call, summed hours, dollars, dollars per spawn, spawns over LONG minutes.
Table 2, per (sprint, step), for ROLE and for remediator: spawns, hours and dollars by pass kind,
read from the spawn description (elicit, pN, other).

usage: python3 -I seats.py OUT [ROLE=adversary] [sprint,sprint,...] [LONG=45]
"""
import collections, json, re, statistics, sys
OUT = sys.argv[1]
ROLE = sys.argv[2] if len(sys.argv) > 2 else "adversary"
SPR = [int(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else None
LONG = float(sys.argv[4]) if len(sys.argv) > 4 else 45.0
sp = [json.loads(l) for l in open(OUT + "/spawns.jsonl")]
if SPR is None: SPR = sorted({r["sprint"] for r in sp if r["sprint"]})

def kind(d):
    d = (d or "").lower()
    if "elicit" in d: return "elicit"
    m = re.search(r"(?:pass[ -_]?|\bp)(\d+)", d)
    return "p" + m.group(1) if m else "other"

print(f"{ROLE} by binding; LONG = {LONG:.0f} min")
print("sprint | binding | spawns | median min | p90 min | min/call | sum h | $ | $/spawn | over LONG")
for s in SPR:
    d = collections.defaultdict(list)
    for r in sp:
        if r["sprint"] == s and r["role"] == ROLE: d[(r.get("model_ran"), r.get("effort_bound"))].append(r)
    for k, v in sorted(d.items(), key=lambda x: -len(x[1])):
        m = sorted(x["minutes"] for x in v); calls = sum(x["calls"] for x in v); usd = sum(x["usd"] for x in v)
        print(f"s{s} | {k[0]}/{k[1]} | {len(v)} | {statistics.median(m):.1f} | {m[max(0, int(.9 * len(m)) - 1)]:.1f} | "
              f"{sum(m) / max(1, calls):.2f} | {sum(m) / 60:.1f} | {usd:.0f} | {usd / len(v):.2f} | {sum(1 for x in m if x >= LONG)}")
print()
print(f"{ROLE} and remediator by pass kind (spawns, hours, $)")
for s in SPR:
    steps = sorted({r["step"] for r in sp if r["sprint"] == s and r["role"] in (ROLE, "remediator")})
    for st in steps:
        c = collections.Counter(); h = collections.Counter(); u = collections.Counter()
        for r in sp:
            if r["sprint"] == s and r["step"] == st and r["role"] in (ROLE, "remediator"):
                k = (r["role"], kind(r.get("description"))); c[k] += 1; h[k] += r["minutes"] / 60; u[k] += r["usd"]
        print(f"s{s} {st}: " + "; ".join(f"{k[0]}:{k[1]} n{c[k]} {h[k]:.1f}h ${u[k]:.0f}" for k in sorted(c)))
