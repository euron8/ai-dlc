"""Count lead-side messages (SendMessage / Agent tool_use inputs) naming a shard directory correction, per sprint.

A hit is a tool_use named SendMessage whose input text matches PAT ("merge requires shard dir" or "shard dir"
with "correction"). Sprint is by the record timestamp against extract.py's s321/s322/s323 edges.
usage: python3 -I lead_shard_dir_sends.py [--list]   (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
"""
import collections, glob, json, os, re, sys
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
LIST = "--list" in sys.argv
EDGES = [("2026-10-30T00:10:03Z", 320), ("2026-11-09T00:00:00Z", 321), ("2026-11-13T08:00:00Z", 322), ("2099", 323)]
PAT = re.compile(r"shard dir(?:ectory)?", re.I)
def sprint(t):
    for e, n in EDGES:
        if t < e: return n
n = collections.Counter(); files = collections.defaultdict(set); filesn = 0
for p in sorted(glob.glob(ROOT + "/*.jsonl")):
    filesn += 1
    for l in open(p, errors="replace"):
        if "shard dir" not in l.lower(): continue
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t > WIN_END or r.get("type") != "assistant": continue
        for c in (r.get("message") or {}).get("content") or []:
            if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "SendMessage":
                s = json.dumps(c.get("input"))
                if PAT.search(s) and re.search(r"correct|requires|refus", s, re.I):
                    k = sprint(t); n[k] += 1; files[k].add(os.path.basename(p)[:8])
                    if LIST: print(f"s{k}\t{os.path.basename(p)[:8]}\t{t}\t{s[:260]}")
print(f"lead transcripts read {filesn}; window end {WIN_END}")
for k in sorted(n): print(f"s{k} SendMessage corrections naming a shard dir: {n[k]} in lead sessions {sorted(files[k])}")
