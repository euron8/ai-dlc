"""Per-width carry-over findings: cross vs part, REFOUND by token overlap, survival by shipped-text token presence.
Usage: python3 -I width.py <graph> <shipped319> <shipped320> <out.json>"""
import re, glob, os, sys, json, collections
G = sys.argv[1].rstrip("/") + "/_bmad-output"
SH = {319: open(sys.argv[2], errors="replace").read(), 320: open(sys.argv[3], errors="replace").read()}
norm = lambda s: re.sub(r"\s+", " ", s)
HP = re.compile(r"^(#{2,4})\s+(F-\d+)\s*[\(—-]+\s*\(?(critical|major|minor)\b", re.I)
HP2 = re.compile(r"^(#{2,4})\s+(F-\d+)\b.*?\b(CRITICAL|MAJOR|MINOR)\b", re.I)
TOK = re.compile(r"`([^`\n]{6,80})`|(CO-S\d+[A-Z0-9-]*)|(\w+\.(?:py|md|sh|json):\d+)")
def toks(body):
    s = set()
    for a, b, c in TOK.findall(body):
        t = a or b or c
        if t.startswith(("$ ", "grep", "sed ")): continue
        s.add(t.strip())
    return s
def parse(path):
    lines = open(path, errors="replace").read().split("\n")
    out = []; i = 0
    while i < len(lines):
        m = HP2.match(lines[i])
        if not m or m.group(3).upper() == "MINOR": i += 1; continue
        lvl = len(m.group(1)); j = i + 1
        while j < len(lines):
            mm = re.match(r"^(#{1,4})\s", lines[j])
            if mm and len(mm.group(1)) <= lvl: break
            j += 1
        body = "\n".join(lines[i:j])
        out.append(dict(sev=m.group(3).upper(), head=lines[i][:140], toks=sorted(toks(body)), body=body))
        i = j
    return out
rounds = []
for sp in (319, 320):
    pm = f"{G}/party-mode/s{sp}"
    for f in sorted(glob.glob(pm + "/carry-over-evaluation-*.md")):
        b = os.path.basename(f)[len("carry-over-evaluation-"):-3]
        seat, rest = b.split("-", 1)
        rounds.append((sp, "party", seat, "cross" if rest.startswith("cross") else "part", rest, f))
    for rn, d in (("elic", "coe-elicitation" if sp == 320 else "carry-over-evaluation-elicitation"), ("p1", "coe-p1"), ("p2", "coe-p2"), ("p3", "coe-p3")):
        for f in sorted(glob.glob(f"{G}/planning-artifacts/s{sp}/shards/{d}/*.md")):
            b = os.path.basename(f)[:-3]
            rounds.append((sp, rn, "adv", "cross" if b.startswith("cross") else "part", b, f))
F = []
for sp, rn, seat, kind, shard, f in rounds:
    for x in parse(f):
        x.update(sprint=sp, round=rn, seat=seat, kind=kind, shard=shard); F.append(x)
for x in F:
    x["sets"] = set(x["toks"])
def overlap(a, b):
    s = a["sets"] & b["sets"]
    return len(s) >= 2 or any(t.startswith("CO-S") for t in s)
for x in F:
    same = [y for y in F if y is not x and y["sprint"] == x["sprint"] and y["round"] == x["round"]]
    other = [y for y in F if y["sprint"] == x["sprint"] and y["round"] != x["round"]]
    x["refound_part_same_round"] = sum(1 for y in same if y["kind"] == "part" and overlap(x, y))
    x["refound_cross_same_round"] = sum(1 for y in same if y["kind"] == "cross" and y is not x and overlap(x, y))
    x["refound_other_round"] = sorted({y["round"] for y in other if overlap(x, y)})
    gone = [t for t in x["toks"] if t not in norm(SH[x["sprint"]]) and t not in SH[x["sprint"]]]
    x["toks_absent_shipped"] = len(gone); x["ntoks"] = len(x["toks"])
agg = collections.defaultdict(lambda: collections.Counter())
for x in F:
    k = (x["sprint"], x["round"], x["kind"] + ("" if x["kind"] == "part" else "-" + x["shard"].split("-")[-1]))
    a = agg[k]; a["n"] += 1; a["crit"] += x["sev"] == "CRITICAL"
    a["refound_by_part"] += x["refound_part_same_round"] > 0
    a["refound_other_round"] += bool(x["refound_other_round"])
    a["unique_in_cross"] += (x["kind"] == "cross" and x["refound_part_same_round"] == 0 and not x["refound_other_round"])
    a["unique_in_part"] += (x["kind"] == "part" and x["refound_cross_same_round"] == 0 and not x["refound_other_round"])
for k in sorted(agg):
    print(k, dict(agg[k]))
json.dump([{k: v for k, v in x.items() if k not in ("sets", "body")} for x in F], open(sys.argv[4], "w"), indent=1)
print("total findings", len(F), "control: min tokens/finding", min(x["ntoks"] for x in F), "with 0 toks", sum(1 for x in F if x["ntoks"] == 0))
