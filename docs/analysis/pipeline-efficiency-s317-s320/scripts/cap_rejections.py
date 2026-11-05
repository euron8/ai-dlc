"""Cap-rejected lead Agent/Task calls per sprint. Usage: cap_rejections.py

This reads the same corpus root as extract.py ($EXTRACT_ROOT, else ~/.claude/projects/-Users-n8-git-graph), using
extract.py's WIN_START default and EDGES, and honours $EXTRACT_WIN_END: a record later than it is dropped.

For each sprint it counts:
  agent_calls    unique Agent/Task tool_use ids in LEAD transcripts (top-level *.jsonl)
  cap_rejected   those whose matching tool_result carries "Concurrent subagent limit reached"
The sprint is that of the tool_use record's timestamp.
"""
import ast, json, glob, os, collections, datetime as dt

ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_START = os.environ.get("EXTRACT_WIN_START") or "2026-09-26T00:35:00Z"
WIN_END = os.environ.get("EXTRACT_WIN_END") or None
# extract.py owns EDGES. It runs on import, so its EDGES assignment is read out of the source, not executed.
_src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract.py")).read()
EDGES = next(ast.literal_eval(n.value) for n in ast.parse(_src).body
             if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", None) == "EDGES")
CAP = "Concurrent subagent limit reached"

def ts(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
END_TS = ts(WIN_END) if WIN_END else None

def sprint_of(t):
    if t < WIN_START: return None
    for e, n in EDGES:
        if t < e: return n

use = collections.Counter(); cap = collections.Counter(); seen = set(); nfiles = 0
for p in sorted(glob.glob(ROOT + "/*.jsonl")):
    nfiles += 1
    ids = {}
    for line in open(p, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp") or ""
        if not t or t < WIN_START: continue
        if END_TS is not None and ts(t) > END_TS: continue
        c = r.get("message", {}).get("content")
        if not isinstance(c, list): continue
        for x in c:
            if not isinstance(x, dict): continue
            if x.get("type") == "tool_use" and x.get("name") in ("Agent", "Task"):
                if x["id"] in seen: continue
                seen.add(x["id"]); ids[x["id"]] = sprint_of(t); use[sprint_of(t)] += 1
            elif x.get("type") == "tool_result" and x.get("tool_use_id") in ids:
                s = x.get("content"); s = s if isinstance(s, str) else json.dumps(s)
                if CAP in s: cap[ids[x["tool_use_id"]]] += 1

print(f"root {ROOT}; lead transcripts {nfiles}; WIN_START {WIN_START}; WIN_END {WIN_END or 'unbounded'}")
for n in sorted(k for k in use if k is not None):
    print(f"s{n} agent_calls {use[n]} cap_rejected {cap[n]}")
