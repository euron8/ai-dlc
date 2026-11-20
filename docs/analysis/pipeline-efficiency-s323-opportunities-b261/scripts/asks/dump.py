"""c10 ask dump: every lead AskUserQuestion (tool_use paired with tool_result) and every >300 s human-prompt wait
after a lead turn, s321..s323. Read only on graph transcripts. python3 -I dump.py OUTFILE"""
import glob, json, os, re, sys, datetime as dt
ROOT = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
W0, W1 = "2026-10-30T00:10:03Z", "2026-11-20T04:20:00Z"
EDGES = [("2026-11-09T00:00:00Z", 321), ("2026-11-13T08:00:00Z", 322), ("2026-11-20T04:20:00Z", 323)]
def sp(t):
    for e, n in EDGES:
        if t < e: return n
def ts(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
STEP_RE = re.compile(r"steps/([a-z0-9-]+)\.md")
def human(r):
    if r.get("type") != "user" or r.get("toolUseResult") is not None or r.get("isMeta"): return None
    c = r.get("message", {}).get("content")
    if isinstance(c, list):
        if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c): return None
        c = " ".join(x.get("text", "") for x in c if isinstance(x, dict))
    if not isinstance(c, str): return None
    s = c.lstrip()
    if s.startswith(("<task-notification", "<system-reminder", "<local-command", "Caveat:", "<teammate-message", "<cross-session")): return None
    return c
def txt(c):
    if isinstance(c, str): return c
    if isinstance(c, list): return " ".join(y.get("text", "") for y in c if isinstance(y, dict))
    return ""
out = []; seen = set()
for p in sorted(glob.glob(ROOT + "/*.jsonl")):
    if os.path.getmtime(p) < ts(W0): continue
    sess = os.path.basename(p)[:8]
    recs = []
    for l in open(p, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < W0 or t > W1: continue
        recs.append(r)
    step = "pre-step"; pend = {}; prev_t = None; last_as = None; asks = {}
    for i, r in enumerate(recs):
        t = r["timestamp"]; tt = ts(t); typ = r.get("type")
        if typ == "assistant":
            m = r.get("message", {}); cont = m.get("content") or []
            texts = [c.get("text", "") for c in cont if isinstance(c, dict) and c.get("type") == "text"]
            uses = [c for c in cont if isinstance(c, dict) and c.get("type") == "tool_use"]
            for c in uses:
                if c.get("name") == "Read":
                    mm = STEP_RE.search(json.dumps(c.get("input", {})))
                    if mm and "offset" not in c["input"] and "limit" not in c["input"] and not mm.group(1).startswith("_"): step = mm.group(1)
                if c.get("name") == "AskUserQuestion":
                    pend[c["id"]] = dict(start=t, step=step, qs=(c.get("input") or {}).get("questions") or [], pre=" ".join(texts)[-1500:], idx=i)
            last_as = dict(t=t, texts=texts, nuse=len(uses), idx=i)
        elif typ == "user":
            c = r.get("message", {}).get("content")
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "tool_result" and x.get("tool_use_id") in pend:
                        a = pend.pop(x["tool_use_id"])
                        if a["start"] in seen and False: continue
                        # next 5 minutes of lead tool_uses after the answer
                        nxt = []
                        for r2 in recs[i + 1:]:
                            if ts(r2["timestamp"]) - tt > 300: break
                            if r2.get("type") == "assistant":
                                for c2 in r2["message"].get("content") or []:
                                    if isinstance(c2, dict) and c2.get("type") == "tool_use":
                                        inp = c2.get("input") or {}
                                        d = inp.get("description") or inp.get("command") or inp.get("file_path") or json.dumps(inp)
                                        nxt.append(f"{c2['name']}: {str(d)[:110]}")
                        out.append(dict(kind="ask", id=x["tool_use_id"], sess=sess, sprint=sp(a["start"]), start=a["start"], end=t,
                                        wait=tt - ts(a["start"]), step=a["step"], err=bool(x.get("is_error")), qs=a["qs"], pre=a["pre"],
                                        ans=txt(x.get("content")), next5=nxt[:14]))
            h = human(r)
            if h is not None and prev_t is not None:
                gap = tt - prev_t
                if gap > 300 and not pend and last_as is not None:
                    nxt = []
                    for r2 in recs[i + 1:]:
                        if ts(r2["timestamp"]) - tt > 300: break
                        if r2.get("type") == "assistant":
                            for c2 in r2["message"].get("content") or []:
                                if isinstance(c2, dict) and c2.get("type") == "tool_use":
                                    inp = c2.get("input") or {}
                                    d = inp.get("description") or inp.get("command") or inp.get("file_path") or json.dumps(inp)
                                    nxt.append(f"{c2['name']}: {str(d)[:110]}")
                    out.append(dict(kind="prompt", sess=sess, sprint=sp(t), start=recs[i - 1]["timestamp"], end=t, wait=gap, step=step,
                                    last_as=" ".join(last_as["texts"])[-1800:], last_nuse=last_as["nuse"], human=h[:700], next5=nxt[:14]))
        prev_t = tt
# dedupe asks by tool_use id (resumed sessions copy parent records)
res = []; ids = set()
for o in out:
    if o["kind"] == "ask":
        if o["id"] in ids: continue
        ids.add(o["id"])
    res.append(o)
res.sort(key=lambda o: o["start"])
with open(sys.argv[1], "w") as f:
    for o in res: f.write(json.dumps(o) + "\n")
from collections import Counter
c = Counter((o["kind"], o["sprint"]) for o in res); print(dict(c))
