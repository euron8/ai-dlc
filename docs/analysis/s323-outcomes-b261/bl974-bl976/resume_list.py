"""List every resume (resumes.py's cut and classify) with its step, description and message head.

usage: python3 -I resume_list.py OUT SPRINTS   (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
Imports nothing from resumes.py (a copy of its cut and classify); output is TSV on stdout.
"""
import datetime as dt, glob, json, os, sys
OUT = sys.argv[1]; SPR = {int(x) for x in sys.argv[2].split(",")}
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
def T(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
def classify(c):
    c = c.lower()
    if "api connection error" in c or "api error" in c or "terminated" in c: return "api-error"
    if any(k in c for k in ("join refused", "refused your", "the join", "merge requires", "merge refused")): return "join-refusal"
    if "escalat" in c: return "escalation"
    if "gate" in c and ("fail" in c or "rework" in c): return "gate-rework"
    return "other"
own = {}
for l in open(OUT + "/spawns.jsonl"):
    r = json.loads(l); own[r["unit"]] = r
for p in sorted(glob.glob(ROOT + "/*/subagents/*.jsonl")):
    u = os.path.basename(p)[:-6]
    if u not in own or own[u]["sprint"] not in SPR: continue
    last = None
    for l in open(p, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t > WIN_END: continue
        now = T(t)
        if last and now - last > 300 and r.get("type") == "user":
            c = (r.get("message") or {}).get("content")
            if not (isinstance(c, list) and any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c)):
                txt = c if isinstance(c, str) else json.dumps(c)
                o = own[u]
                print("\t".join([f"s{o['sprint']}", classify(txt), str(o["step"]), str(o["role"]), u[:12], t,
                                 str(o["description"])[:60].replace("\t", " "), txt[:400].replace("\n", " ").replace("\t", " ")]))
        last = now
