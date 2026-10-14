"""Per-spawn outcome table and lead-model-per-step table for the role/model efficacy evaluation.

Outputs (OUT dir):
  spawns.jsonl   one row per subagent: sprint, step, role, model_ran, model_bound, effort_bound,
                 description, start, end, minutes, calls, tok, usd, final_text (last assistant text, 1500 chars)
  leadmodel.csv  sprint, step, model, calls, tok, usd
"""
import json, os, sys, glob, csv, collections, datetime as dt

OUT = sys.argv[1]
ROOT = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
LEDGER = os.path.expanduser("~/git/graph/_bmad-output/spawn-ledger.jsonl")
P = {"opus": (4, 8, 0.20, 20), "sonnet": (2, 4, 0.20, 10), "haiku": (0.10, 0.20, 0.01, 0.50), "fable": (10, 20, 0.25, 50)}
T = lambda s: dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()

def fam(m):
    m = (m or "").lower()
    for k in P:
        if k in m: return k
    return "local" if "qwen" in m else ("synthetic" if "synthetic" in m else (m or "?"))

def usd(f, d):
    return sum(d[i] * P[f][i] for i in range(4)) / 1e6 if f in P else 0.0

ledger = {}
for l in open(LEDGER):
    try: r = json.loads(l)
    except Exception: continue
    if r.get("tool_use_id"): ledger[r["tool_use_id"]] = r

units = [json.loads(l) for l in open(os.path.join(OUT, "units.jsonl"))]
owner = json.load(open(os.path.join(OUT, "owner.json")))
RELABEL = {("f849d75f-ab2c-43f9-a510-37a2db2b498a", "retro"): "requirements"}
owner = {k: [v[0], RELABEL.get((v[0], v[1]), v[1]), v[2]] for k, v in owner.items()}
path_of = {os.path.basename(p)[:-6]: p for p in glob.glob(ROOT + "/*/subagents/*.jsonl")}

def final_text(p):
    last = ""
    for l in open(p, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        if r.get("type") == "assistant":
            t = " ".join(c.get("text", "") for c in r["message"].get("content") or [] if isinstance(c, dict) and c.get("type") == "text").strip()
            if t: last = t
    return last[-1500:]

n_led = 0
with open(os.path.join(OUT, "spawns.jsonl"), "w") as fo:
    for u in units:
        if u["kind"] != "sub" or u["sprint"] is None: continue
        m = u["meta"] or {}
        tid = m.get("toolUseId")
        o = owner.get(tid)
        led = ledger.get(tid) or {}
        if led: n_led += 1
        tok = [0, 0, 0, 0, 0]; cost = 0.0; ran = collections.Counter()
        for k, d in u["tok"].items():
            f = fam(k.split("|", 1)[1]); ran[f] += d[4]; cost += usd(f, d)
            for i in range(5): tok[i] += d[i]
        fo.write(json.dumps(dict(
            unit=u["unit"], sess=u["sess"][:8], sprint=u["sprint"], step=o[1] if o else "unjoined",
            role=m.get("agentType"), model_ran=ran.most_common(1)[0][0] if ran else "?",
            model_bound=led.get("model_bound"), effort_bound=led.get("effort_bound"),
            description=m.get("description"), start=u["first"], end=u["last"],
            minutes=round((T(u["last"]) - T(u["first"])) / 60, 1), calls=tok[4],
            tok=sum(tok[:4]), out=tok[3], usd=round(cost, 3),
            final_text=final_text(path_of[u["unit"]]) if u["unit"] in path_of else "")) + "\n")

L = collections.defaultdict(lambda: [0, 0, 0.0])
for s in (json.loads(l) for l in open(os.path.join(OUT, "segs.jsonl"))):
    if s["kind"] != "lead" or s["sprint"] is None: continue
    st = RELABEL.get((s["sess"], s["step"]), s["step"])
    for mdl, d in (s.get("tok") or {}).items():
        f = fam(mdl); a = L[(s["sprint"], st, f)]
        a[0] += d[4]; a[1] += sum(d[:4]); a[2] += usd(f, d)
with open(os.path.join(OUT, "leadmodel.csv"), "w") as f:
    w = csv.writer(f); w.writerow(["sprint", "step", "model", "calls", "tok", "usd"])
    for k in sorted(L): w.writerow(list(k) + [L[k][0], L[k][1], round(L[k][2], 2)])
print("spawns written; ledger-joined", n_led, file=sys.stderr)
