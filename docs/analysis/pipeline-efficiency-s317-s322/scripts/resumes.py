"""Why finished subagents were resumed, and how long they sat idle first, per sprint.

A resume is a gap over 300 s in a subagent transcript that is closed by a user record carrying no
tool_result (the same cut poles.py makes). Each is classified by the resume message's text, first
match wins:
  api-error      "api connection error", "api error" or "terminated"
  join-refusal   "join refused", "refused your", "the join", "merge requires", "merge refused"
  escalation     "escalat"
  gate-rework    "gate" together with "fail" or "rework"
  other          anything else (task notifications, coordinator notes)
The classes are text heuristics, not an enumeration of refusal codes. Idle is agent idle: an upper
bound on wall clock, because other agents may be running meanwhile.

usage: python3 -I resumes.py OUT [sprint,sprint,...]   (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
"""
import collections, datetime as dt, glob, json, os, sys
OUT = sys.argv[1]
SPR = {int(x) for x in sys.argv[2].split(",")} if len(sys.argv) > 2 else None
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
    r = json.loads(l); own[r["unit"]] = (r["sprint"], r["role"])
n = collections.Counter(); idle = collections.Counter(); role = collections.defaultdict(collections.Counter); seen = 0
for p in glob.glob(ROOT + "/*/subagents/*.jsonl"):
    u = os.path.basename(p)[:-6]
    if u not in own or (SPR and own[u][0] not in SPR): continue
    seen += 1; last = None
    for l in open(p, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t > WIN_END: continue
        now = T(t)
        if last and now - last > 300 and r.get("type") == "user":
            c = (r.get("message") or {}).get("content")
            if not (isinstance(c, list) and any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c)):
                k = (own[u][0], classify(c if isinstance(c, str) else json.dumps(c)))
                n[k] += 1; idle[k] += now - last; role[k][own[u][1]] += 1
        last = now
print(f"root {ROOT}; subagent transcripts read {seen}; window end {WIN_END}")
for k in sorted(n, key=lambda k: (k[0], -idle[k])):
    print(f"s{k[0]} {k[1]:13} {n[k]:4d} resumes {idle[k]/3600:6.1f} agent-h idle {idle[k]/n[k]/60:5.0f} min each | "
          + ", ".join(f"{r} {c}" for r, c in role[k].most_common(3)))
