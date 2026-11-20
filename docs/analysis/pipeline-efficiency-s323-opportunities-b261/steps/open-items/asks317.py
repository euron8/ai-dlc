"""open-items item 1: every lead AskUserQuestion (tool_use paired with tool_result by id, errored kept+flagged) s317..s323.
usage: python3 -I asks317.py OUT.jsonl   Window start = s316 end 2026-10-05T13:58:27Z; edges are sprint END times (extract.py:64)."""
import glob, json, os, re, sys, datetime as dt
ROOT = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
W0, W1 = "2026-10-05T13:58:27Z", "2026-11-20T04:20:00Z"
EDGES = [("2026-10-12T02:30:00Z",317),("2026-10-14T22:00:00Z",318),("2026-10-23T09:53:00Z",319),("2026-10-30T00:10:03Z",320),("2026-11-09T00:00:00Z",321),("2026-11-13T08:00:00Z",322),("2026-11-20T04:20:00Z",323)]
def sp(t):
    for e, n in EDGES:
        if t < e: return n
def ts(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
def txt(c):
    if isinstance(c, str): return c
    if isinstance(c, list): return " ".join(y.get("text", "") for y in c if isinstance(y, dict))
    return ""
STEP_RE = re.compile(r"steps/([a-z0-9-]+)\.md")
out = {}; nsess = 0
for p in sorted(glob.glob(ROOT + "/*.jsonl")):
    if os.path.getmtime(p) < ts(W0): continue
    sess = os.path.basename(p)[:8]; nsess += 1
    step = "pre-step"; pend = {}
    for l in open(p, errors="replace"):
        if '"AskUserQuestion"' not in l and '"tool_result"' not in l and 'steps/' not in l: continue
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < W0 or t > W1: continue
        typ = r.get("type")
        if typ == "assistant":
            cont = r.get("message", {}).get("content") or []
            for c in cont:
                if not isinstance(c, dict) or c.get("type") != "tool_use": continue
                if c.get("name") == "Read":
                    mm = STEP_RE.search(json.dumps(c.get("input", {})))
                    if mm and "offset" not in c["input"] and "limit" not in c["input"] and not mm.group(1).startswith("_"): step = mm.group(1)
                if c.get("name") == "AskUserQuestion":
                    pend[c["id"]] = dict(start=t, step=step, qs=(c.get("input") or {}).get("questions") or [])
        elif typ == "user":
            c = r.get("message", {}).get("content")
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "tool_result" and x.get("tool_use_id") in pend:
                        a = pend.pop(x["tool_use_id"])
                        o = dict(id=x["tool_use_id"], sess=sess, sprint=sp(a["start"]), start=a["start"], end=t, wait=ts(t) - ts(a["start"]),
                                 step=a["step"], err=bool(x.get("is_error")), qs=a["qs"], ans=txt(x.get("content")))
                        out.setdefault(o["id"], o)
res = sorted(out.values(), key=lambda o: o["start"])
with open(sys.argv[1], "w") as f:
    for o in res: f.write(json.dumps(o) + "\n")
from collections import Counter
print("sessions scanned", nsess, dict(Counter(o["sprint"] for o in res)))
