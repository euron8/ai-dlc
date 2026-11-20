# ask_lane_names.py -- BL-841 claim 2: how many lead AskUserQuestion asks name a lane.
#
# usage: EXTRACT_WIN_END=<iso> python3 -I ask_lane_names.py <sprint> [<sprint> ...] [--list]
# Reads graph's lead transcripts (read only; EXTRACT_ROOT overrides), takes every AskUserQuestion tool_use
# whose timestamp falls in <sprint> by extract.py's EDGES (read out of its source, as ask_split.py does),
# deduplicated by tool_use id, and counts the asks whose text matches each grammar:
#   NARROW  the word "lane" / "lanes" (case-insensitive) in header + question text
#   NARROW+OPT  the same, with every option label and description added
#   BROAD   NARROW+OPT, or one of: held, holding, meanwhile, in parallel, still running, other stories,
#           other agents, while you, while this
# A count is printed per sprint with the ask index; --list prints each matching ask's header and the match.
import ast, glob, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "9999"
SRC = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")
_src = open(SRC).read()
EDGES = next(ast.literal_eval(n.value) for n in ast.parse(_src).body
             if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", None) == "EDGES")
E = [("2026-10-05T14:00:00Z", None)] + [(e, n) for e, n in EDGES if n >= 317]
def sp(t):
    for e, n in E:
        if t < e: return n
NARROW = re.compile(r"\blanes?\b", re.I)
BROAD = re.compile(r"\b(lanes?|held|holding|meanwhile|in parallel|still running|other stories|other agents|while you|while this)\b", re.I)
asks = {}
nfiles = 0
for p in sorted(glob.glob(ROOT + "/*.jsonl")):
    nfiles += 1
    for line in open(p, errors="replace"):
        if "AskUserQuestion" not in line: continue
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < E[0][0] or t > WIN_END or r.get("type") != "assistant": continue
        for c in (r.get("message", {}).get("content") or []):
            if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "AskUserQuestion":
                asks.setdefault(c["id"], (t, c.get("input") or {}))
want = [int(a) for a in sys.argv[1:] if a.isdigit()]
lst = "--list" in sys.argv
print("lead files scanned", nfiles, "asks (dedup by id)", len(asks))
for n in want:
    rows = sorted((t, i) for _id, (t, i) in asks.items() if sp(t) == n)
    narrow = optn = broad = 0; hits = []
    for t, inp in rows:
        qs = inp.get("questions") or []
        q = " ".join(str(x.get("header", "")) + " " + str(x.get("question", "")) for x in qs)
        o = " ".join(str(op.get("label", "")) + " " + str(op.get("description", "")) for x in qs for op in (x.get("options") or []))
        a = bool(NARROW.search(q)); b = bool(NARROW.search(q + " " + o)); c = bool(BROAD.search(q + " " + o))
        narrow += a; optn += b; broad += c
        if c: hits.append((t, qs[0].get("header", "") if qs else "", [m.group(0) for m in BROAD.finditer(q + " " + o)][:4]))
    print("s%d: asks %d; NARROW(question) %d; NARROW+OPT %d; BROAD %d" % (n, len(rows), narrow, optn, broad))
    if lst:
        for h in hits: print("   ", h)
