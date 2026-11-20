"""s323 ARCHITECTURE-SPINE p1/p2 rounds: adversary dispatch briefs naming a shard dir, and what became of them.

Scans lead transcripts for Agent tool_use inputs (subagent_type adversary) whose prompt names
`planning-artifacts/s<N>/shards/<dir>`, then pairs each tool_use id with its tool_result (drop is_error / denied).
Prints per sprint: briefs, executed (tool_result not an error), denied (error result), shard dirs named.
Control: the same scan over s321 must show the architecture-p1 dispatches.
usage: python3 -I arch_spine_dispatch.py   (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
"""
import collections, glob, json, os, re
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
PAT = re.compile(r"planning-artifacts/(s\d+)/shards/([A-Za-z0-9._-]+)")
uses = {}; res = {}
for p in sorted(glob.glob(ROOT + "/*.jsonl")):
    for l in open(p, errors="replace"):
        if "shards/" not in l and "tool_result" not in l: continue
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t > WIN_END: continue
        c = (r.get("message") or {}).get("content")
        if not isinstance(c, list): continue
        for x in c:
            if not isinstance(x, dict): continue
            if r.get("type") == "assistant" and x.get("type") == "tool_use" and x.get("name") in ("Agent", "Task"):
                i = x.get("input") or {}
                if i.get("subagent_type") == "adversary":
                    d = {m.group(2) for m in PAT.finditer(i.get("prompt") or "")}
                    uses[x["id"]] = (t, os.path.basename(p)[:8], d)
            elif r.get("type") == "user" and x.get("type") == "tool_result":
                res[x.get("tool_use_id")] = bool(x.get("is_error"))
out = collections.defaultdict(lambda: collections.Counter())
dirs = collections.defaultdict(collections.Counter)
for i, (t, s, d) in uses.items():
    sp = "s321" if "2026-10-30" <= t < "2026-11-09" else "s323" if t >= "2026-11-13T08" else "other"
    k = "denied" if res.get(i) else ("executed" if i in res else "no-result")
    out[sp][k] += 1
    for x in d: dirs[sp][x] += 1
for sp in sorted(out):
    print(sp, dict(out[sp]))
    for x, n in sorted(dirs[sp].items()): print("   shard dir named in", n, "brief(s):", x)
