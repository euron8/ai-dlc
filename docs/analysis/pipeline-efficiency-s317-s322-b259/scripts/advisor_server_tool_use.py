"""Count advisor server_tool_use blocks (unique block id) per sprint and transcript kind, records <= EXTRACT_WIN_END.
usage: EXTRACT_WIN_END=2026-11-12T14:41:00Z python3 -I advisor_server_tool_use.py
Sprint edges are extract.py's EDGES for s317..s322; nothing past s322 is counted. Reads the transcript root read-only.
A tool_use of the MCP tool mcp__advisor__consult is a different record and is not counted here."""
import json, glob, os, collections, datetime as dt
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
PIN = os.environ["EXTRACT_WIN_END"]
E = [("2026-10-12T02:30:00Z", 317), ("2026-10-14T22:00:00Z", 318), ("2026-10-23T09:53:00Z", 319), ("2026-10-30T00:10:03Z", 320), ("2026-11-09T00:00:00Z", 321), ("2026-11-13T08:00:00Z", 322)]
def sp(t):
    if t < "2026-10-07": return None
    for e, n in E:
        if t < e: return n
c = collections.Counter(); ids = set()
for p in glob.glob(ROOT + "/*.jsonl") + glob.glob(ROOT + "/*/subagents/*.jsonl"):
    kind = "sub" if "/subagents/" in p else "lead"
    if os.stat(p).st_mtime < dt.datetime(2026, 10, 12).timestamp(): continue
    for l in open(p, errors="replace"):
        if '"server_tool_use"' not in l or "advisor" not in l: continue
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp") or ""
        if t > PIN: continue
        for x in (r.get("message", {}).get("content") or []):
            if isinstance(x, dict) and x.get("type") == "server_tool_use" and x.get("name") == "advisor" and x.get("id") not in ids:
                ids.add(x["id"]); s = sp(t)
                if s: c[(s, kind)] += 1
for s in range(317, 323): print(s, {k: c[(s, k)] for k in ("lead", "sub")})
