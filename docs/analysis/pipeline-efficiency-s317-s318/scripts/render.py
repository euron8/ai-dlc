"""Render markdown tables from extractor CSVs (no hand-typed figures)."""
import csv, sys, collections, json, os
OUT = sys.argv[1]
P = {"opus": (4, 8, 0.20, 20), "sonnet": (2, 4, 0.20, 10), "haiku": (0.10, 0.20, 0.01, 0.50), "fable": (10, 20, 0.25, 50)}
IDX = {"in": 0, "cw": 1, "cr": 2, "out": 3}
ORDER = ["pre-step", "route", "artifact-consolidation", "carry-over-evaluation", "requirements", "architecture",
         "stories-test-strategy", "ui-direction", "implementation", "sprint-review", "deploy-validate", "retro", "handoff"]

def fam(m):
    for k in P:
        if k in m: return k
    return None

rows = list(csv.DictReader(open(os.path.join(OUT, "steps.csv"))))
def base(step):
    return step[len("gate-validation["):-1] if step.startswith("gate-validation[") else step

T = collections.defaultdict(lambda: collections.defaultdict(float))
for x in rows:
    key = (x["sprint"], "ai-dlc-update (reconcile)" if x["bucket"] == "ai-dlc-update" else
           ("operator ad-hoc" if x["bucket"] == "other" else x["step"]))
    a = T[key]
    for c in ("elapsed_h", "active_h", "op_wait_h", "agent_wait_h", "compactions"):
        a[c] += float(x.get(c) or 0)
    for k, v in x.items():
        p = k.split("_")
        if len(p) != 3 or p[0] not in ("lead", "sub") or p[2] not in IDX: continue
        v = float(v or 0)
        a[p[2]] += v
        a[p[0] + "_tok"] += v
        f = fam(p[1])
        if f: a["usd"] += v * P[f][IDX[p[2]]] / 1e6

def sortkey(k):
    s = k[1]
    b = base(s)
    return (k[0], ORDER.index(b) if b in ORDER else 99, s.startswith("gate-validation"), s)

print("| Sprint | Step | Elapsed h | Lead active h | Waiting on agents h | Operator wait h | Compactions | Lead tok M | Subagent tok M | cache-read % | Output M | API-equiv $ |")
print("|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|")
tot = collections.defaultdict(lambda: collections.defaultdict(float))
for k in sorted(T, key=sortkey):
    a = T[k]; t = a["in"] + a["cw"] + a["cr"] + a["out"]
    if t < 1e5 and a["elapsed_h"] < 0.05: continue
    for c in a: tot[k[0]][c] += a[c]
    print(f"| {k[0]} | {k[1]} | {a['elapsed_h']:.1f} | {a['active_h']:.1f} | {a['agent_wait_h']:.1f} | {a['op_wait_h']:.1f} | "
          f"{int(a['compactions'])} | {a['lead_tok']/1e6:.0f} | {a['sub_tok']/1e6:.0f} | {a['cr']/t:.0%} | {a['out']/1e6:.1f} | {a['usd']:.0f} |")
for sp, a in sorted(tot.items()):
    t = a["in"] + a["cw"] + a["cr"] + a["out"]
    print(f"| **{sp}** | **total** | {a['elapsed_h']:.1f} | {a['active_h']:.1f} | {a['agent_wait_h']:.1f} | {a['op_wait_h']:.1f} | "
          f"{int(a['compactions'])} | {a['lead_tok']/1e6:.0f} | {a['sub_tok']/1e6:.0f} | {a['cr']/t:.0%} | {a['out']/1e6:.1f} | **{a['usd']:.0f}** |")

# Role table
print()
R = list(csv.DictReader(open(os.path.join(OUT, "roles.csv"))))
G = collections.defaultdict(lambda: collections.defaultdict(float)); models = collections.defaultdict(set)
for r in R:
    k = (r["sprint"], r["role"]); g = G[k]
    if r["model"] == "_all":
        g["spawns"] += float(r["spawns"]); g["span_h"] += float(r["span_h"])
    else:
        f = fam(r["model"])
        if f: models[k].add(f)
        for c in IDX:
            v = float(r[c]); g[c] += v
            if f: g["usd"] += v * P[f][IDX[c]] / 1e6
print("| Sprint | Role | Spawns | Summed agent h | Tok M | Output M | API-equiv $ | $/spawn | Models observed |")
print("|---|---|--:|--:|--:|--:|--:|--:|---|")
for k in sorted(G, key=lambda k: (k[0], -G[k]["usd"])):
    g = G[k]; t = sum(g[c] for c in IDX)
    if g["spawns"] == 0: continue
    print(f"| {k[0]} | {k[1]} | {int(g['spawns'])} | {g['span_h']:.1f} | {t/1e6:.0f} | {g['out']/1e6:.1f} | {g['usd']:.0f} | {g['usd']/g['spawns']:.2f} | {','.join(sorted(models[k]))} |")

# Step x role top cells
print()
SR = collections.defaultdict(lambda: collections.defaultdict(float))
for r in R:
    k = (r["sprint"], r["step"], r["role"])
    if r["model"] == "_all": SR[k]["spawns"] += float(r["spawns"]); continue
    f = fam(r["model"])
    for c in IDX:
        if f: SR[k]["usd"] += float(r[c]) * P[f][IDX[c]] / 1e6
print("| Sprint | Step (spawning segment) | Role | Spawns | API-equiv $ |")
print("|---|---|---|--:|--:|")
for k in sorted(SR, key=lambda k: -SR[k]["usd"])[:25]:
    print(f"| {k[0]} | {k[1]} | {k[2]} | {int(SR[k]['spawns'])} | {SR[k]['usd']:.0f} |")
