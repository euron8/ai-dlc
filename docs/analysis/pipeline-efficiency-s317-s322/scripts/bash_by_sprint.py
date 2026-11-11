"""Bash wall clock by command family, PER SPRINT, lead and subagent separately.

The s317-s318 bash_cost.py keyed the same families over the whole window. This copy keeps its
family regex and adds the sprint, using extract.py's own EDGES (read out of its source, as
cap_rejections.py does). A call is charged to the sprint of its tool_use timestamp.
Latency = tool_result timestamp minus tool_use timestamp: for a FOREGROUND call that is time the
caller was blocked; a backgrounded call returns at once and charges ~0.

usage: python3 -I bash_by_sprint.py [TOP]      (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
"""
import ast, collections, datetime as dt, glob, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
EX = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")
EDGES = next(ast.literal_eval(n.value) for n in ast.parse(open(EX).read()).body
             if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", None) == "EDGES")
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_START = "2026-10-05T14:00:00Z"
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
TOP = int(sys.argv[1]) if len(sys.argv) > 1 else 15
FAM = re.compile(r"(?:pytest|npm (?:run )?\w+|npx \w+|[\w.-]+\.sh|git (?:push|fetch|merge|pull|rebase|commit|log|diff|status|worktree)|cargo \w+|python3? -m \w+|sleep|until|while)")

def sprint_of(t):
    for e, n in EDGES:
        if t < e: return n

def T(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()

lat = collections.Counter(); n = collections.Counter(); files = 0
for p in glob.glob(ROOT + "/*.jsonl") + glob.glob(ROOT + "/*/subagents/*.jsonl"):
    kind = "sub" if "/subagents/" in p else "lead"; pend = {}; files += 1
    for l in open(p, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < WIN_START or t > WIN_END: continue
        if r.get("type") == "assistant":
            for c in r["message"].get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Bash":
                    cmd = (c.get("input") or {}).get("command", "") or ""
                    m = FAM.findall(cmd)
                    key = m[0] if m else (cmd.split()[0] if cmd.split() else "?")
                    pend[c["id"]] = (re.sub(r"^.*/", "", key), T(t), sprint_of(t))
        elif r.get("type") == "user":
            c = r.get("message", {}).get("content")
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "tool_result" and x.get("tool_use_id") in pend:
                        key, t0, s = pend.pop(x["tool_use_id"])
                        lat[(s, kind, key)] += T(t) - t0; n[(s, kind, key)] += 1
print(f"root {ROOT}; transcripts {files}; window {WIN_START} .. {WIN_END}")
for s in sorted({k[0] for k in lat if k[0]}):
    for kind in ("lead", "sub"):
        tot = sum(v for k, v in lat.items() if k[0] == s and k[1] == kind)
        print(f"s{s} {kind}: Bash wall {tot/3600:.1f} h")
        for k, v in sorted(((k, v) for k, v in lat.items() if k[0] == s and k[1] == kind), key=lambda x: -x[1])[:TOP]:
            print(f"   {k[2][:42]:42} {n[k]:6d} calls {v/3600:6.2f} h {v/max(1, n[k]):7.0f} s/call")
