import sys, re, json, glob, os, collections as C, subprocess
G, PROJ, since, until, TX = sys.argv[1:6]
sys.argv = ["x", G, PROJ, since, until]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "snaprows2.py")).read().split("res = C.Counter()")[0])
ROW = re.compile(r"--row-(?:add|replace)\s+(?:[A-Za-z0-9_]+\s+)?'([^']*)'")
lead = set()
for f in glob.glob(os.path.join(TX, "*.jsonl")):
    for l in open(f, errors="replace"):
        if "--row-" not in l: continue
        try: d = json.loads(l)
        except Exception: continue
        if d.get("isSidechain") or d.get("type") != "assistant": continue
        for b in (d.get("message") or {}).get("content") or []:
            if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "Bash":
                for m in ROW.finditer((b.get("input") or {}).get("command", "")):
                    w = m.group(1).split("|")[0].strip().strip("`").split()
                    if w: lead.add(w[0])
print("lead-row agentIds (all time)", len(lead), "| control impossible in lead set:", "aQZX9impossible00" in lead)
cells = {norm(c): a for a,(t,c,h) in rows.items()}
res = C.Counter(); fans = C.Counter()
for ag,(t,cell,hook) in rows.items():
    prov = "lead-written" if ag in lead else "hook-written"
    if FAN.get(ag): fans[(prov, FAN[ag])] += 1
    fs,w = writes(ag)
    if not fs or not [x for x in w if x.endswith(".md")]: res[(prov,"unchecked")] += 1; continue
    if any(same(x,cell) for x in w): res[(prov,"agree")] += 1; continue
    other = [cells[norm(x)] for x in w if norm(x) in cells and cells[norm(x)] != ag]
    k = "same-fan-permuted" if other and FAN.get(ag) and FAN.get(ag)==FAN.get(other[0]) else ("other-dispatch-shared-file" if other else "disagree-other")
    res[(prov,k)] += 1
for k in sorted(res): print(k, res[k])
for p in ("hook-written","lead-written"):
    g = [n for (pp,f),n in fans.items() if pp==p and n>=2]
    print(p, "fan groups >=2 members:", len(g), "members in them:", sum(g))
# which of the hook-classified same-fan-permuted agents appear in ANY lead snapshot-update.sh command, and by which op
ops = C.Counter()
targets = []
for ag,(t,cell,hook) in rows.items():
    if ag in lead: continue
    fs,w = writes(ag)
    if not fs or any(same(x,cell) for x in w): continue
    other = [cells[norm(x)] for x in w if norm(x) in cells and cells[norm(x)] != ag]
    if other and FAN.get(ag) and FAN.get(ag)==FAN.get(other[0]): targets.append(ag)
for f in glob.glob(os.path.join(TX, "*.jsonl")):
    for l in open(f, errors="replace"):
        if not any(a in l for a in targets): continue
        try: d = json.loads(l)
        except Exception: continue
        if d.get("isSidechain") or d.get("type") != "assistant": continue
        for b in (d.get("message") or {}).get("content") or []:
            if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "Bash":
                c = (b.get("input") or {}).get("command", "")
                if "snapshot-update.sh" in c and any(a in c for a in targets):
                    ops[tuple(sorted(set(re.findall(r"--[a-z][a-z-]+", c))))] += 1
print("hook-classified same-fan-permuted:", len(targets), "lead snapshot-update ops naming them:", dict(ops))
for ag in targets:
    t,cell,hook = rows[ag]; fs,w = writes(ag)
    print("T", t, ag, FAN.get(ag), norm(cell)[-60:], "| wrote", sorted(set(x[-50:] for x in w if x.endswith('.md')))[:3])
