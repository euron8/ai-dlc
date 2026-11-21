import re, sys, json, glob, os, collections as C
EXT, PROJ = sys.argv[1], sys.argv[2]
def writes(ag):
    w = []
    for f in glob.glob(os.path.join(PROJ, "*", "subagents", f"agent-{ag}.jsonl")):
        for l in open(f, errors="replace"):
            if '"tool_use"' not in l: continue
            try: d = json.loads(l)
            except Exception: continue
            for b in (d.get("message") or {}).get("content") or []:
                if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") in ("Write", "Edit", "MultiEdit"):
                    w.append(str((b.get("input") or {}).get("file_path", "")))
    return w
c = C.Counter()
for l in open(EXT):
    if not l.startswith(("EXT DIS", "EXT agr")): continue
    p = l.split()
    ag = p[4]
    m = re.search(r"\| brief: (\S+) \| lead: (\S+) \|", l)
    b, ld = m.group(1), m.group(2)
    w = writes(ag)
    wb = any(x.endswith(b) for x in w); wl = any(x.endswith(ld) for x in w)
    c[(l[:7], "wrote-brief" if wb else "no-brief", "wrote-lead-cell" if wl else "no-lead-cell")] += 1
for k, v in sorted(c.items()): print(k, v)
print("impossible", len(writes("aQZX9impossible00")))
