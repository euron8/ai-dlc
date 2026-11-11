"""BL-716: which serial step the remediator solo-role hours sit in, and what splitting adjudication from
writing predicts. Reads OUT/spawns.jsonl (extract.py + spawns.py) and the subagent and lead transcripts
under EXTRACT_ROOT (default ~/.claude/projects/-Users-n8-git-graph).

busy_intervals and the sweep are poles.py's, copied, so the per-sprint remediator total must equal
poles.py's `solo-role h: remediator` (the self-check line says whether it does).

  width        the remediator-solo time split by how many remediators were alive (1, or 2 and more)
  after-join   each width-1 second, joined to the LAST round-one join the same lead session printed
               before that spawn started (a tool_result carrying `LANE-COUNT: <n>`): LANES=1 rounds,
               the fan-in after a multi-lane round, a straggler lane, or no join in that session
  turns        each width-1 agent's model and tool time split into WRITER turns (an Edit/Write of an
               artifact or record, --mark-repair, the join) and every other turn (adjudication:
               claim greps, cite reads); width-1 time is apportioned by that split
  predicted    writer + adjudication/k, k = 2 and 4: an UPPER BOUND, assuming even item splits and
               counting the time that decides an edit as writer time
Usage: serial_tail.py OUT [first_sprint]   (first_sprint defaults to 320, the first sprint with lanes)
"""
import collections, datetime as dt, glob, json, os, re, sys
OUT = sys.argv[1]
FIRST = int(sys.argv[2]) if len(sys.argv) > 2 else 320
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
def T(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
PATH = {os.path.basename(p)[:-6]: p for p in glob.glob(ROOT + "/*/subagents/*.jsonl")}
def busy_intervals(path):
    out = []; a = last = None
    for l in open(path, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t > WIN_END: continue
        now = T(t)
        if a is None: a = last = now; continue
        if now - last > 300 and r.get("type") == "user":
            c = (r.get("message") or {}).get("content")
            if not (isinstance(c, list) and any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c)):
                out.append((a, last)); a = now
        last = now
    if a is not None and last > a: out.append((a, last))
    return out
def cls(d):
    d = (d or "").lower()
    if "fan-in" in d or "fanin" in d: return "fan-in"
    if "lane" in d: return "lane"
    if "serial" in d: return "serial"
    return "other"
SP = {}; by = collections.defaultdict(list)
for l in open(OUT + "/spawns.jsonl"):
    r = json.loads(l); SP[r["unit"]] = r
    if not r.get("start") or not r.get("end") or r["unit"] not in PATH: continue
    for a, b in busy_intervals(PATH[r["unit"]]):
        if b > a: by[(r["sprint"], r["step"])].append((a, b, r.get("role") or "?", r["unit"]))
solo = collections.Counter(); width = collections.defaultdict(collections.Counter); w1 = collections.Counter(); w1s = {}
for (s, st), sp in sorted(by.items()):
    ev = sorted([(x[0], 1, i) for i, x in enumerate(sp)] + [(x[1], -1, i) for i, x in enumerate(sp)])
    live = set(); last = None
    for t, d, i in ev:
        if last is not None and live:
            dtm = t - last
            if {sp[j][2] for j in live} == {"remediator"}:
                solo[s] += dtm
                if len(live) == 1: u = sp[next(iter(live))][3]; w1[u] += dtm; w1s[u] = s; width[s]["1"] += dtm
                else: width[s]["2+"] += dtm
        if d > 0: live.add(i)
        else: live.discard(i)
        last = t
# round-one joins: every lead tool_result carrying a LANE-COUNT: and a SERIAL-REQUIRED: line (a lane round's join prints neither)
def texts(c):
    if isinstance(c, str): yield c
    elif isinstance(c, list):
        for x in c:
            if isinstance(x, dict):
                if x.get("type") == "tool_result": yield from texts(x.get("content"))
                elif x.get("type") == "text": yield x.get("text", "")
J = collections.defaultdict(list)
for f in glob.glob(ROOT + "/*.jsonl"):
    sess = os.path.basename(f)[:8]
    for l in open(f, errors="replace"):
        if "LANE-COUNT" not in l: continue
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp") or ""
        if r.get("type") != "user" or t > WIN_END: continue
        for s in texts((r.get("message") or {}).get("content")):
            m = re.search(r"LANE-COUNT:\s*(\d+)", s)  # unanchored: lead outputs can carry a line prefix
            if m and re.search(r"SERIAL-REQUIRED:\s*\d", s):
                J[sess].append((t, int(m.group(1))))
for v in J.values(): v.sort()
WR = {"Edit", "Write", "MultiEdit"}
def writer(name, inp):
    if name in WR: return True
    c = inp.get("command", "") if name == "Bash" else ""
    return bool(re.search(r"wait-for-deliverable\.sh\s+--mark|join-remediator-shards\.sh", c))
def split(u):
    recs = []
    for l in open(PATH[u], errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        if r.get("timestamp"): recs.append(r)
    acc = wt = at = 0.0; pend = {}
    for a, b in zip(recs, recs[1:]):
        g = T(b["timestamp"]) - T(a["timestamp"]); c = (b.get("message") or {}).get("content")
        is_tr = b.get("type") == "user" and isinstance(c, list) and any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c)
        if b.get("type") == "user" and not is_tr and g > 300: acc = 0.0; continue
        if is_tr:
            k = next((pend.pop(x.get("tool_use_id")) for x in c if isinstance(x, dict) and x.get("tool_use_id") in pend), False)
            if k: wt += g
            else: at += g
            continue
        if b.get("type") in ("assistant", "attachment"):
            acc += g
            if b.get("type") == "assistant" and isinstance(c, list):
                tu = [x for x in c if isinstance(x, dict) and x.get("type") == "tool_use"]
                if tu:
                    k = writer(tu[0].get("name"), tu[0].get("input") or {}); pend[tu[0]["id"]] = k
                    if k: wt += acc
                    else: at += acc
                    acc = 0.0
    return wt, at + acc
step = collections.defaultdict(collections.Counter); pred = collections.defaultdict(lambda: [0.0, 0.0, 0.0])
for u, d in w1.items():
    s = w1s[u]
    if s < FIRST: continue
    r = SP[u]; prior = [j for j in J.get(r["sess"], []) if j[0] <= r["start"]]
    c = cls(r["description"])
    if not prior: k = "no round-one join in the session"
    elif prior[-1][1] == 1: k = "LANES=1 round (one document or one lane)"
    elif c == "fan-in": k = "fan-in after a multi-lane round"
    elif c == "lane": k = "straggler lane of a multi-lane round"
    else: k = "other, after a multi-lane round"
    step[s][k] += d
    wt, at = split(u); tot = wt + at
    if tot > 0: p = pred[s]; p[0] += d; p[1] += d * wt / tot; p[2] += d * at / tot
H = lambda v: f"{v/3600:.2f}"
for s in sorted(solo):
    print(f"s{s} remediator-solo {H(solo[s])} h = width-1 {H(width[s]['1'])} + width-2+ {H(width[s]['2+'])}")
    if s < FIRST: continue
    for k, v in step[s].most_common(): print(f"    {H(v):>5} h  {k}")
    w, wr, ad = pred[s]
    if w: print(f"    turns: writer {H(wr)} h ({100*wr/w:.0f}%), adjudication {H(ad)} h"
                f" | predicted width-1 tail (upper bound) k=2 {H(wr+ad/2)} h, k=4 {H(wr+ad/4)} h")
print("self-check: the remediator-solo figures above must equal poles.py's `solo-role h: remediator` per sprint")
