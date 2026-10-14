"""Aggregate extractor output into per-sprint, per-step tables (CSV + printed summary)."""
import json, os, sys, collections, csv

OUT = sys.argv[1]
def rows(n): return [json.loads(l) for l in open(os.path.join(OUT, n + ".jsonl"))]
units, segs, hooks, tools = rows("units"), rows("segs"), rows("hooks"), rows("tools")
owner = json.load(open(os.path.join(OUT, "owner.json")))

# Segment relabels, each justified by the subagent descriptions spawned inside the segment.
# f849d75f "retro": 37 spawns, all "Elicitation part N" / "Elicitation repair N" -- the
# requirements validation cycle; the lead Read retro.md mid-requirements (10:04Z).
# 1feefd46 "stories-test-strategy" 08:53-10:53Z on 10-10: the lead re-read the stories step file
# mid-implementation; its 11 spawns are "gate-# cross-#" implementation reviews (story 2.5).
RELABEL = {("f849d75f-ab2c-43f9-a510-37a2db2b498a", "retro"): "requirements",
           ("1feefd46-c902-4fb2-8d42-04c14ed43bc7", "stories-test-strategy"): "implementation"}
for s in segs:
    if s["kind"] == "lead": s["step"] = RELABEL.get((s["sess"], s["step"]), s["step"])
owner = {k: [v[0], RELABEL.get((v[0], v[1]), v[1]), v[2]] for k, v in owner.items()}

# Lead session bucket: the dominant attributionSkill across its assistant lines.
bucket = {}
for u in units:
    if u["kind"] != "lead": continue
    sk = u["skills"]
    stepped = any(k.split("|", 1)[0] != "pre-step" for k in u["tok"])
    if stepped: bucket[u["sess"]] = "pipeline"
    elif sk.get("ai-dlc-update"): bucket[u["sess"]] = "ai-dlc-update"
    else: bucket[u["sess"]] = "other"

def fam(m):
    m = (m or "?").lower()
    for k in ("opus", "sonnet", "haiku", "fable"):
        if k in m: return k
    return "synthetic" if "synthetic" in m else m

# Subagent -> parent step via toolUseId, role via meta.agentType.
sub_step = {}
unjoined = 0
for u in units:
    if u["kind"] != "sub": continue
    tid = (u["meta"] or {}).get("toolUseId")
    o = owner.get(tid)
    if o: sub_step[u["unit"]] = o[1]
    else:
        unjoined += 1
        sub_step[u["unit"]] = "unjoined"

agg = collections.defaultdict(lambda: collections.defaultdict(float))
def add(key, **kv):
    for k, v in kv.items(): agg[key][k] += v

for s in segs:
    sp = s["sprint"]
    if sp is None: continue
    if s["kind"] == "lead":
        key = (sp, bucket.get(s["sess"], "?"), s["step"])
        add(key, elapsed_h=(s["active"] + s["op_wait"] + s["agent_wait"]) / 3600,
            active_h=s["active"] / 3600, op_wait_h=s["op_wait"] / 3600, agent_wait_h=s["agent_wait"] / 3600,
            compactions=s["compactions"], humans=s["humans"], hook_kb=s["hook_bytes"] / 1024,
            lead_tool_kb=s["tool_bytes"] / 1024, segments=1)
        for m, d in (s.get("tok") or {}).items():
            f = fam(m)
            add(key, **{f"lead_{f}_in": d[0], f"lead_{f}_cw": d[1], f"lead_{f}_cr": d[2], f"lead_{f}_out": d[3], f"lead_{f}_calls": d[4]})
    else:
        key = (sp, bucket.get(s["sess"], "?"), sub_step.get(s["unit"], "unjoined"))
        add(key, sub_active_h=s["active"] / 3600, sub_tool_kb=s["tool_bytes"] / 1024, sub_hook_kb=s["hook_bytes"] / 1024,
            sub_compactions=s["compactions"])
        for m, d in (s.get("tok") or {}).items():
            f = fam(m)
            add(key, **{f"sub_{f}_in": d[0], f"sub_{f}_cw": d[1], f"sub_{f}_cr": d[2], f"sub_{f}_out": d[3], f"sub_{f}_calls": d[4]})

# Per-role subagent rollup, keyed by sprint/step/role/model.
role = collections.defaultdict(lambda: collections.defaultdict(float))
for u in units:
    if u["kind"] != "sub" or u["sprint"] is None: continue
    r = (u["meta"] or {}).get("agentType") or "?"
    st = sub_step.get(u["unit"], "unjoined")
    for k, d in u["tok"].items():
        f = fam(k.split("|", 1)[1])
        key = (u["sprint"], bucket.get(u["sess"], "?"), st, r, f)
        R = role[key]
        R["in"] += d[0]; R["cw"] += d[1]; R["cr"] += d[2]; R["out"] += d[3]; R["calls"] += d[4]
    import datetime as dt
    f0 = dt.datetime.fromisoformat(u["first"].replace("Z", "+00:00")); f1 = dt.datetime.fromisoformat(u["last"].replace("Z", "+00:00"))
    for m in {k.split("|", 1)[1] for k in u["tok"]} or {"?"}:
        pass
    key0 = (u["sprint"], bucket.get(u["sess"], "?"), st, r, "_all")
    role[key0]["spawns"] += 1
    role[key0]["span_h"] += (f1 - f0).total_seconds() / 3600
    role[key0]["compactions"] += u["compactions"]

cols = sorted({k for v in agg.values() for k in v})
with open(os.path.join(OUT, "steps.csv"), "w") as f:
    w = csv.writer(f); w.writerow(["sprint", "bucket", "step"] + cols)
    for k in sorted(agg): w.writerow(list(k) + [round(agg[k].get(c, 0), 3) for c in cols])
rcols = ["spawns", "span_h", "compactions", "in", "cw", "cr", "out", "calls"]
with open(os.path.join(OUT, "roles.csv"), "w") as f:
    w = csv.writer(f); w.writerow(["sprint", "bucket", "step", "role", "model"] + rcols)
    for k in sorted(role): w.writerow(list(k) + [round(role[k].get(c, 0), 3) for c in rcols])

# Hooks: per hook/event totals.
H = collections.defaultdict(lambda: [0, 0.0, 0])
for h in hooks:
    if h["sprint"] is None: continue
    k = (h["sprint"], h["kind"], h["att"], h["hook"], h["event"])
    H[k][0] += 1; H[k][1] += h["ms"]; H[k][2] += h["bytes"]
with open(os.path.join(OUT, "hooks.csv"), "w") as f:
    w = csv.writer(f); w.writerow(["sprint", "kind", "att", "hook", "event", "firings", "ms_total", "bytes_total"])
    for k in sorted(H): w.writerow(list(k) + [H[k][0], round(H[k][1]), H[k][2]])

T = collections.defaultdict(lambda: [0, 0.0, 0])
for t in tools:
    if t["sprint"] is None: continue
    k = (t["sprint"], t["kind"], t["tool"])
    T[k][0] += 1; T[k][1] += t["lat"]; T[k][2] += t["bytes"]
with open(os.path.join(OUT, "tools.csv"), "w") as f:
    w = csv.writer(f); w.writerow(["sprint", "kind", "tool", "calls", "latency_s_total", "result_bytes_total"])
    for k in sorted(T): w.writerow(list(k) + [T[k][0], round(T[k][1]), T[k][2]])

# Controls.
nlead = sum(1 for u in units if u["kind"] == "lead"); nsub = sum(1 for u in units if u["kind"] == "sub")
print("units lead", nlead, "sub", nsub, "sub unjoined", unjoined)
print("buckets", collections.Counter(bucket.values()))
def tsum(it):
    return sum(sum(d[:4]) for x in it for d in (x.get("tok") or {}).values())
print("token control units==segs:", tsum(units), tsum(segs))
