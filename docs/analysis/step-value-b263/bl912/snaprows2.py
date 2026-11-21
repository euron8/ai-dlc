"""In-Flight rows in graph's committed _bmad-output/pipeline-snapshot.md, every commit (git log --all) in a window,
first (agent, deliverable) per agentId; hook-format = agent cell '<a+16hex> toolu_...'. Truth: subagent Write/Edit paths."""
import sys, re, os, glob, subprocess, json, collections as C
G, PROJ, since, until = sys.argv[1:5]
P = "_bmad-output/pipeline-snapshot.md"
shas = subprocess.run(["git","-C",G,"log","--all","--since",since,"--until",until,"--format=%H %cI","--",P],capture_output=True,text=True).stdout.split("\n")
rows = {}; FAN = {}
for line in shas:
    if not line: continue
    h, t = line.split()
    body = subprocess.run(["git","-C",G,"show",f"{h}:{P}"],capture_output=True,text=True).stdout
    sec = False
    for l in body.splitlines():
        if l.startswith("## "): sec = "In-Flight" in l; continue
        if not sec or "|" not in l: continue
        cells = [c.strip() for c in l.strip("|").split("|")]
        if len(cells) < 3: continue
        w = cells[0].strip("`").split()
        if not w or not re.fullmatch(r"a[0-9a-f]{16}", w[0]): continue
        hook = len(w) > 1 and w[1].startswith("toolu_")
        rows.setdefault(w[0], (t, cells[2].strip("`"), hook)); FAN[w[0]] = (w[1].rsplit("_",1)[0] if hook else None)
def norm(x): return re.sub(r"^.*?/(_bmad-output/)", r"\1", x.strip().strip("`"))
def same(a, b): a, b = norm(a), norm(b); return bool(a) and bool(b) and (a == b or a.endswith(b) or b.endswith(a))
def writes(ag):
    fs = glob.glob(os.path.join(PROJ,"*","subagents",f"agent-{ag}.jsonl")); w=[]
    for f in fs:
        for l in open(f, errors="replace"):
            if '"tool_use"' not in l: continue
            try: d=json.loads(l)
            except Exception: continue
            for b in (d.get("message") or {}).get("content") or []:
                if isinstance(b,dict) and b.get("type")=="tool_use" and b.get("name") in ("Write","Edit","MultiEdit"):
                    w.append(norm(str((b.get("input") or {}).get("file_path",""))))
    return fs, w
res = C.Counter()
for ag,(t,cell,hook) in rows.items():
    fs,w = writes(ag); k = "hook-row" if hook else "hand-row"
    md=[x for x in w if x.endswith(".md")]
    if not fs: res[(k,"no transcript")]+=1; continue
    if not md: res[(k,"no .md write")]+=1; continue
    if any(same(x,cell) for x in w): res[(k,"AGREE")]+=1; continue
    perm = any(os.path.dirname(x)==os.path.dirname(norm(cell)) for x in md)
    res[(k,"DISAGREE-permuted" if perm else "DISAGREE-other")]+=1
    print("DIS",k,t,ag,norm(cell),"|",sorted(set(md))[:2])
print("commits",len([s for s in shas if s]),"agents",len(rows))
for k in sorted(res): print(k,res[k])
cells = {norm(c): a for a,(t,c,h) in rows.items()}
strict = C.Counter()
for ag,(t,cell,hook) in rows.items():
    fs,w = writes(ag)
    if not fs or any(same(x,cell) for x in w): continue
    other = [cells[norm(x)] for x in w if norm(x) in cells and cells[norm(x)] != ag]
    if other: strict["same-fan" if FAN.get(ag) and FAN.get(ag)==FAN.get(other[0]) else "different-dispatch"] += 1
    if other: strict["strict-permuted (wrote another agent's row cell)"] += 1; print("STRICT", ag, norm(cell), "-> wrote cell of", other[0])
print(dict(strict) or "strict-permuted 0")
