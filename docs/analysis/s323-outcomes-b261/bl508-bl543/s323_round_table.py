"""s323 planning-round table: (step, round, lead session, agent ids) -> engine version -> evidence. b261.
usage: python3 -I s323_round_table.py OUT GRAPH_CLONE OUTCSV
OUT = extract.py + spawns.py output (spawns.jsonl rows carry the agent unit id, lead session, step, role, description).
GRAPH_CLONE = a file:// clone of graph, any checkout; engine stamps are read from commits with `git show <sha>:.claude/.ai-dlc-version`.
Engine per lead session = the `.claude/.ai-dlc-version` stamp at the HEAD that the session's own first session_context
record (record 24, `Recent commits:`) names. ENGINE_HEAD below holds those four shas, read from the transcripts.
Round label: classified from role + description; a serial/adjudicator/lane/fan-in spawn takes the label of the round before it."""
import csv, json, re, subprocess, sys, collections
OUT, G, CSV = sys.argv[1:4]
PLANS = {"carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"}
ENGINE_HEAD = {"0ef7ba46": "c8ab65397", "68cf8de7": "becba072e", "4b34031d": "699bc10f6", "53b4296a": "7f2afcab2"}
def stamp(sha):
    r = subprocess.run(["git", "-C", G, "show", sha + ":.claude/.ai-dlc-version"], capture_output=True, text=True)
    m = re.search(r"^version:\s*(\S+)", r.stdout, re.M)
    return m.group(1) if m else "UNREAD"
ENG = {s: stamp(h) for s, h in ENGINE_HEAD.items()}
def base(st): return st[16:-1] if st.startswith("gate-validation[") else st
sp = [json.loads(l) for l in open(OUT + "/spawns.jsonl")]
P = [x for x in sp if x["sprint"] == 323 and x["sess"] in ENG and base(x["step"]) in PLANS]
P.sort(key=lambda x: x["start"])
state = collections.defaultdict(lambda: {"label": "authoring", "advn": 0, "lastadv": False})
def klass(x, st):
    d, r, step = x["description"].lower(), x["role"], x["step"]
    if step.startswith("gate-validation"): return "planning gate (adjudicators, repair, adversary of the gate)"
    if r in ("ops", "web-fetch"): return "support (live reads, fetch)"
    if r == "analyst" or "authoring chain" in d or r == "pm-escalated" or "draft" in d or (r == "tea" and "author" in d): return "authoring"
    if r == "general-purpose": return "dispatcher"
    if "party seat" in d or r in ("pm", "architect", "dev", "tea", "sm") and "repair" not in d: return "party seats"
    if "elicitation" in d and r == "adversary": return "elicitation adversary"
    if "elicitation" in d and r == "remediator" and not re.search(r"serial|lane|fan-?in|adjudic|fix|joinfix|seal|re-derive", d): return "elicitation repair"
    if r == "adversary":
        m = re.search(r"\bp(\d)\b", d)
        if m: return "adversarial pass " + m.group(1)
        return "adversarial pass ?"
    if "party repair" in d: return "party repair"
    if re.search(r"adjudicat|lane|fan-?in|serial|cross", d): return "SERIAL"
    if re.search(r"repair|remediat|rework|rerun|record-only|fix|post-met", d): return "REPAIR"
    return "other remediator"
rows = []
for x in P:
    key = (x["sess"], base(x["step"])); s = state[key]
    k = klass(x, s)
    if k == "dispatcher": lab = s["label"]
    elif k == "adversarial pass ?":
        if not s["lastadv"]: s["advn"] += 1
        lab = "adversarial pass %d (no pN in description)" % s["advn"]; s["lastadv"] = True; s["label"] = lab
    elif k.startswith("adversarial pass"):
        s["lastadv"] = True; s["advn"] = int(k[-1]); lab = k; s["label"] = lab
    elif k in ("SERIAL",):
        lab = "serial/adjudication after: " + s["label"].replace("serial/adjudication after: ", "").replace("repair of: ", "")
    elif k == "REPAIR":
        prev = s["label"].replace("serial/adjudication after: ", "").replace("repair of: ", "")
        lab = "repair of: " + prev; s["label"] = lab; s["lastadv"] = False
    else:
        lab = k; s["label"] = lab; s["lastadv"] = False
    x["_round"] = lab
agg = collections.OrderedDict()
for x in P:
    k = (base(x["step"]), x["sess"], x["_round"], "gate" if x["step"].startswith("gate-validation") else "")
    a = agg.setdefault(k, {"n": 0, "usd": 0.0, "first": x["start"], "ids": []})
    a["n"] += 1; a["usd"] += x["usd"]; a["ids"].append(x["unit"].replace("agent-", ""))
with open(CSV, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["step", "round", "lead_session", "first_spawn_utc", "n_spawns", "usd_api", "engine_version", "engine_evidence", "agent_ids"])
    for (step, sess, lab, g), a in agg.items():
        ev = ("transcript %s.jsonl record 24 session_context names graph HEAD %s; `git show %s:.claude/.ai-dlc-version` reads version %s; spawn rows spawns.jsonl (unit, sess, step)"
              % (sess, ENGINE_HEAD[sess], ENGINE_HEAD[sess], ENG[sess]))
        w.writerow([step, lab + (" [gate row]" if g else ""), sess, a["first"], a["n"], "%.2f" % a["usd"], ENG[sess], ev, " ".join(a["ids"])])
print("spawns", len(P), "rounds", len(agg), "engines", ENG)
