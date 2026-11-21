"""Lead hand-written In-Flight rows vs the subagent's own Write/Edit paths (ground truth).
Population: lead transcripts (non-sidechain assistant tool_use, deduped per id), Bash snapshot-update.sh
--row-add/--row-replace; first row per agentId; window by record timestamp. Truth: Write/Edit/MultiEdit
file_path in <proj>/*/subagents/agent-<id>.jsonl."""
import json, os, re, sys, glob, collections as C
TX, PROJ = sys.argv[1], sys.argv[2]
CUT = "2026-11-12T07:40:00Z"; START = "2026-11-09T00:00:00Z"
ROW = re.compile(r"--row-(?:add|replace)\s+(?:[A-Za-z0-9_]+\s+)?'([^']*)'")
def norm(x): return re.sub(r"^.*?/(_bmad-output/)", r"\1", x.strip().strip("`"))
def same(a, b): a, b = norm(a), norm(b); return bool(a) and bool(b) and (a == b or a.endswith(b) or b.endswith(a))
rows = {}
for f in sorted(glob.glob(os.path.join(TX, "*.jsonl"))):
    seen = set()
    for l in open(f, errors="replace"):
        if "--row-" not in l: continue
        try: d = json.loads(l)
        except Exception: continue
        if d.get("isSidechain") or d.get("type") != "assistant": continue
        t = d.get("timestamp", "")
        for b in (d.get("message") or {}).get("content") or []:
            if not isinstance(b, dict) or b.get("type") != "tool_use" or b.get("name") != "Bash" or b.get("id") in seen: continue
            seen.add(b.get("id")); cmd = (b.get("input") or {}).get("command", "")
            if "snapshot-update.sh" not in cmd: continue
            for m in ROW.finditer(cmd):
                cells = [x.strip() for x in m.group(1).split("|")]
                if len(cells) >= 5 and cells[0]:
                    ag = cells[0].split()[0]
                    if re.fullmatch(r"a[0-9a-f]{16}", ag): rows.setdefault(ag, (t, cells[2].strip("`")))
def writes(ag):
    fs = glob.glob(os.path.join(PROJ, "*", "subagents", f"agent-{ag}.jsonl")); w = []
    for f in fs:
        for l in open(f, errors="replace"):
            if '"tool_use"' not in l: continue
            try: d = json.loads(l)
            except Exception: continue
            for b in (d.get("message") or {}).get("content") or []:
                if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") in ("Write", "Edit", "MultiEdit"):
                    w.append(norm(str((b.get("input") or {}).get("file_path", ""))))
    return fs, w
print("control impossible agent subagent files:", len(writes("aQZX9impossible00")[0]))
res = C.Counter(); allw = {}
for ag, (t, cell) in rows.items():
    if t < START: continue
    win = "pre-cut" if t < CUT else "post-cut"
    fs, w = writes(ag); allw[ag] = w
    if not fs: res[(win, "no subagent transcript")] += 1; continue
    md = [x for x in w if x.endswith(".md")]
    if not md: res[(win, "subagent wrote no .md")] += 1; continue
    if any(same(x, cell) for x in w): res[(win, "AGREE")] += 1
    else:
        res[(win, "DISAGREE")] += 1
        print("DIS", win, t, ag, "cell", norm(cell), "| wrote", sorted(set(md))[:3])
for k in sorted(res): print(k, res[k])
# Of the pre-cut DISAGREE rows, those where the agent wrote the file named in ANOTHER lead row's cell (permuted).
cells = {}
for ag, (t, cell) in rows.items():
    if t >= START: cells.setdefault(norm(cell), []).append(ag)
perm = 0
for ag, (t, cell) in rows.items():
    if t < START or t >= CUT: continue
    w = allw.get(ag, [])
    if not [x for x in w if x.endswith(".md")] or any(same(x, cell) for x in w): continue
    if any(norm(x) in cells and ag not in cells[norm(x)] for x in w): perm += 1
print("pre-cut DISAGREE rows that wrote another lead row's cell:", perm)
