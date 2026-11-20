"""Count lead messages that correct a shard directory, in adversary subagent transcripts, per sprint.

A hit is a user record with no tool_result whose text matches PAT (a message to the agent, not tool output).
Reported per sprint and step: hits, distinct agents, hits that follow a gap over 300 s (resumes.py's cut), and
the idle those gaps carry. Also counts lead-side SendMessage tool_use inputs matching PAT as a cross-check.

usage: python3 -I shard_dir_corrections.py OUT SPRINTS [--list]   (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
"""
import collections, datetime as dt, glob, json, os, re, sys
OUT = sys.argv[1]; SPR = {int(x) for x in sys.argv[2].split(",")}; LIST = "--list" in sys.argv
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
PAT = re.compile(r"shard dir(?:ectory)?", re.I)
def T(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
own = {}
for l in open(OUT + "/spawns.jsonl"):
    r = json.loads(l); own[r["unit"]] = r
hit = collections.Counter(); agents = collections.defaultdict(set); gap = collections.Counter(); idle = collections.Counter()
seen = collections.Counter()
for p in sorted(glob.glob(ROOT + "/*/subagents/*.jsonl")):
    u = os.path.basename(p)[:-6]
    if u not in own or own[u]["sprint"] not in SPR: continue
    o = own[u]; seen[o["sprint"]] += 1; last = None
    for l in open(p, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t > WIN_END: continue
        now = T(t)
        if r.get("type") == "user":
            c = (r.get("message") or {}).get("content")
            if not (isinstance(c, list) and any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c)):
                txt = c if isinstance(c, str) else json.dumps(c)
                if "The coordinator sent a message" in txt and PAT.search(txt):
                    k = (o["sprint"], o["step"], o["role"]); hit[k] += 1; agents[k].add(u)
                    if last and now - last > 300: gap[k] += 1; idle[k] += now - last
                    if LIST: print("\t".join([f"s{o['sprint']}", str(o["step"]), str(o["role"]), u[:12], t, str(o["description"])[:50], txt[:300].replace("\n", " ")]))
        last = now
print(f"subagent transcripts read per sprint {dict(seen)}; window end {WIN_END}")
for k in sorted(hit):
    print(f"s{k[0]} {k[1]:24} {k[2]:12} corrections {hit[k]:3d} agents {len(agents[k]):3d} after-gap>300s {gap[k]:3d} idle {idle[k]/3600:5.2f} agent-h")
