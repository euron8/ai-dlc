"""Cap-rejected lead Agent/Task calls per sprint. Usage: cap_rejections.py

This reads the same corpus root as extract.py ($EXTRACT_ROOT, else ~/.claude/projects/-Users-n8-git-graph), using
extract.py's WIN_START default and EDGES, and honours $EXTRACT_WIN_END: a record later than it is dropped.

For each sprint it counts:
  agent_calls    unique Agent/Task tool_use ids in LEAD transcripts (top-level *.jsonl)
  cap_rejected   those whose matching tool_result carries "Concurrent subagent limit reached"
The sprint is that of the tool_use record's timestamp.
"""
import json, glob, os, collections, datetime as dt

ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_START = os.environ.get("EXTRACT_WIN_START") or "2026-09-26T00:35:00Z"
WIN_END = os.environ.get("EXTRACT_WIN_END") or None
EDGES = [("2026-09-28T19:10:00Z",314),("2026-09-30T20:58:00Z",315),("2026-10-05T14:00:00Z",316),
         ("2026-10-12T02:30:00Z",317),("2026-10-14T22:00:00Z",318),("2026-10-23T09:53:00Z",319),("2099-01-01T00:00:00Z",320)]
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
