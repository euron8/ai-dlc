"""Per-round spawns, dollars and agent-hours for graph s319/s320 carry-over evaluation.

Usage: python3 -I cost2.py <extract-out-dir>
  <extract-out-dir> is the output directory of
  docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py (it reads spawns.jsonl).
s320's adversarial p1 spawns the extractor charged to `route` (BL-813) are re-added here.
Control: the last line prints the s320 `route` row total.
"""
import json, sys, collections, re
OUT = sys.argv[1]
rows = [json.loads(l) for l in open(OUT + "/spawns.jsonl")]
def rnd(d, role):
    d = (d or "").lower()
    if role == "gate-adjudicator": return "EXCLUDED gate"
    if role == "analyst": return "0 analyst draft"
    if role == "remediator" or "repair" in d:
        if "elicit" in d: return "2r elicitation repair"
        if "party" in d: return "1r party repair"
        if "operator decisions" in d or "lead decisions" in d: return "2d decisions folds"
        m = re.search(r"p(?:ass)?\s*(\d)", d); return f"{2+int(m.group(1)) if m else 9}r adv p{m.group(1) if m else '?'} repair"
    if "elicit" in d: return "2 elicitation " + ("cross" if "cross" in d else "part")
    if role == "adversary":
        m = re.search(r"p(?:ass)?\s*(\d)", d)
        return f"{2+int(m.group(1))} adv p{m.group(1)} " + ("cross" if "cross" in d else "part")
    return "1 party " + ("cross" if "cross" in d else "part")
agg = collections.defaultdict(lambda: [0, 0.0, 0.0, "9", "0"])
for r in rows:
    if r["sprint"] not in (319, 320): continue
    st = r["step"]
    if not ("carry" in st and not st.startswith("gate")) and not (r["sprint"] == 320 and st == "route"): continue
    k = (r["sprint"], rnd(r.get("description"), r.get("role")))
    a = agg[k]; a[0] += 1; a[1] += r.get("usd") or 0; a[2] += r.get("minutes") or 0
    a[3] = min(a[3], str(r["start"])); a[4] = max(a[4], str(r["end"]))
tot = collections.Counter(); totu = collections.Counter()
for k in sorted(agg):
    n, u, m, s, e = agg[k]
    if not k[1].startswith("EXCL"): tot[k[0]] += n; totu[k[0]] += u
    print(f"{k[0]} | {k[1]:26s} | {n:3d} | ${u:6.2f} | agent-h {m/60:4.1f} | {s[5:16]} -> {e[5:16]}")
print("totals excl gate:", dict(tot), {k: round(v, 2) for k, v in totu.items()})
print("control: s320 route rows total", sum(1 for r in rows if r["sprint"] == 320 and r["step"] == "route"))
