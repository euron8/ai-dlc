"""BL-398 value side: s322 stories-test-strategy adversarial passes, per pass, the MAJOR+ findings that no later
round caught AND whose repair is present in the shipped story or strategy.

usage: python3 -I value.py GRAPH_CLONE [GRAPH_REF=ed61de745]

Reads graph (read only) at GRAPH_REF, under _bmad-output/planning-artifacts/s322/:
  passes   stories-adversarial-p<k>.md, test-strategy-adversarial-p<k>.md (merged shard files)
  repairs  <series>-repair-p<k>.md and <series>-serial-repair-p<k>.md (remediator records)

Finding id = (series, pass, shard, F-n). shard is the shard's ordinal in the merged file (1..n) or `cross`. F-n is the
heading's own `F-<n>` when it carries one, else the heading's ordinal among the shard's severity headings (the
remediator's `source: <shard>.md#F-<n>` uses that ordinal for a keyless heading; checked below).

Caught by a later round: a finding of ANY later pass (either series) whose heading or body references the id:
  `pass-<k> F-<n>` / `pass <k> F-<n>`        pass k of the same series, same shard
  `the F-<n> repair` / `F-<n> repair`         the previous pass of the same series, same shard
  `FANIN-<shard>.md-F-<n>`, `<shard>.md#F-<n>`, `cross F-<n>`   the previous pass, that shard
  `pass-<k> <SEV> "<title prefix>"`           pass k, same shard, the finding whose heading holds the prefix
Repair present: a record with `source:` naming the id, `disposition: repaired`, and a heading severity equal to the
finding's (a sweep or fan-in record of another severity cannot supply it). Its replayable checks
(`$ grep -c -F '<lit>' <artifact>`, `$ grep -n[-o] -F '<lit>' <artifact>`, `$ grep -rn -F '<lit>' <artifact>`) count
only when <artifact> is the record's own `edit:` target and that target is a shipped story file or test-strategy.md;
they must all hold on the blob at GRAPH_REF: a check whose recorded output was a hit must still hit, one whose
recorded output was empty or 0 must still miss. PRESENT needs at least one bound hit-check; a record with none is
UNVERIFIABLE and does not count. A finding counts iff MAJOR+, not caught later, some usable record PRESENT and no
usable record ABSENT.
"""
import re, subprocess, sys
GRAPH = sys.argv[1]; REF = sys.argv[2] if len(sys.argv) > 2 else "ed61de745"
BASE = "_bmad-output/planning-artifacts/s322/"
SEV = ("CRITICAL", "MAJOR", "MINOR")

def show(path):
    r = subprocess.run(["git", "-C", GRAPH, "show", f"{REF}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None
def ls(prefix):
    r = subprocess.run(["git", "-C", GRAPH, "ls-tree", "-r", "--name-only", REF, "--", prefix], capture_output=True, text=True)
    return r.stdout.split()

SERIES = {"stories": "stories-adversarial-p", "test-strategy": "test-strategy-adversarial-p"}
passes = []   # dict(series, k, file, invoked, findings=[...], footer)
for s, pre in SERIES.items():
    k = 1
    while show(BASE + f"{pre}{k}.md") is not None:
        passes.append(dict(series=s, k=k, file=f"{pre}{k}.md")); k += 1

def footer(t, key):
    """The LAST `key: value` line: the merged file's own provenance block closes the file; shard blocks precede it."""
    m = re.findall(rf"^{key}:\s*(\S+)\s*$", t, re.M); return m[-1] if m else None

def parse_pass(P):
    t = show(BASE + P["file"]); P["invoked"] = footer(t, "invoked_at")
    P["footer_major"] = int(footer(t, "findings_major") or 0) + int(footer(t, "findings_critical") or 0)
    shard = None; nshard = 0; ordinal = {}; F = []; cur = None; mism = 0
    for ln in t.splitlines():
        m = re.match(r"^## Shard: (.*)", ln)
        if m:
            if "cross" in m.group(1).lower(): shard = "cross"
            else: nshard += 1; shard = str(nshard)
            cur = None; continue
        if re.match(r"^#{1,2} ", ln): cur = None; continue
        if shard and re.match(r"^### ", ln):
            sev = next((x for x in SEV if re.search(rf"\b{x}\b", ln)), None)
            if sev:
                ordinal[shard] = ordinal.get(shard, 0) + 1
                me = re.match(r"^### F-(\d+)\b", ln)
                n = int(me.group(1)) if me else ordinal[shard]
                if me and n != ordinal[shard]: mism += 1
                cur = dict(id=(P["series"], P["k"], shard, n), sev=sev, head=ln, body=[], keyed=bool(me)); F.append(cur)
                continue
            cur = None; continue
        if cur is not None: cur["body"].append(ln)
    P["findings"] = F; P["ordinal_mismatch"] = mism
for P in passes: parse_pass(P)
passes.sort(key=lambda P: P["invoked"])
order = {(P["series"], P["k"]): i for i, P in enumerate(passes)}

# ---------------------------------------------------------------- later-round references
def refs(f):
    s, k, shard, _ = f["id"]; text = "\n".join([f["head"]] + f["body"]); out = set()
    for m in re.finditer(r"\bpass[- ]?(\d+) F-(\d+)", text): out.add((s, int(m.group(1)), shard, int(m.group(2))))
    for m in re.finditer(r"\b(?:the )?F-(\d+) repair", text): out.add((s, k - 1, shard, int(m.group(1))))
    for m in re.finditer(r"FANIN-(cross|\d+)\.md-F-(\d+)", text): out.add((s, k - 1, m.group(1), int(m.group(2))))
    for m in re.finditer(r"(?<![\w-])(cross|\d+)\.md#F-(\d+)", text): out.add((s, k - 1, m.group(1), int(m.group(2))))
    for m in re.finditer(r"\bcross F-(\d+)", text): out.add((s, k - 1, "cross", int(m.group(1))))
    for m in re.finditer(r'\bpass[- ]?(\d+) (CRITICAL|MAJOR|MINOR) "([^"]{8,})', text):
        prior = next((P for P in passes if P["series"] == s and P["k"] == int(m.group(1))), None)
        for g in (prior or {}).get("findings", []):
            if g["id"][2] == shard and m.group(3)[:40] in g["head"]: out.add(g["id"])
    return {r for r in out if r[1] >= 1 and r != f["id"]}
caught = {}   # earlier id -> [later ids]
for P in passes:
    for f in P["findings"]:
        for r in refs(f):
            if (r[0], r[1]) in order and order[(r[0], r[1])] < order[(P["series"], P["k"])]:
                caught.setdefault(r, []).append(f["id"])
xseries = sum(1 for P in passes for f in P["findings"]
              if re.search(r"stories-adversarial-p|stories-p\d/" if P["series"] == "test-strategy" else r"test-strategy-adversarial-p|test-strategy-p\d/",
                           "\n".join([f["head"]] + f["body"])))

# ---------------------------------------------------------------- repair records and presence
STORIES = [p for p in ls(BASE + "stories/") if p.endswith(".md")]
def blob_lines(art):
    if art.rstrip("/") == "stories": paths = STORIES
    else: paths = [BASE + art]
    out = []
    for p in paths:
        t = show(p)
        if t is None: return None
        out += t.splitlines()
    return out
def artifact(path):
    p = re.sub(r"^/Users/[^/]+/git/graph/", "", path); p = p[len(BASE):] if p.startswith(BASE) else p
    if p == "test-strategy.md" or re.match(r"^stories/story-[\w.-]+\.md$", p) or p.rstrip("/") == "stories": return p
    return None
CMD = re.compile(r"^\$ grep (-c|-n -o|-n|-rn|-o -n|-rn -o) -F '([^']*)' (\S+)\s*$")
def checks(lines):
    out = []; i = 0
    while i < len(lines):
        m = CMD.match(lines[i]); i += 1
        if not m: continue
        res = []
        while i < len(lines) and not lines[i].startswith("$ ") and not lines[i].startswith("```"):
            res.append(lines[i]); i += 1
        art = artifact(m.group(3))
        if not art: continue
        res = [x for x in res if x.strip()]
        if m.group(1) == "-c":
            if not res or not re.match(r"^\d+$", res[0].strip()): continue
            hit = int(res[0]) >= 1
        else: hit = bool(res)
        out.append((art, m.group(2), hit))
    return out
def holds(chk):
    art, lit, hit = chk; L = blob_lines(art)
    if L is None: return False
    n = sum(1 for x in L if lit in x)
    return (n >= 1) if hit else (n == 0)

def verdict(ch):
    pos = [c for c in ch if c[2]]
    return "ABSENT" if not all(holds(c) for c in ch) else ("PRESENT" if pos else "UNVERIFIABLE")
EDIT_RE = re.compile(r"(?:_bmad-output/planning-artifacts/s322/)?(stories/story-[\w.-]+\.md|test-strategy\.md)")
records = {}   # id -> [dict(rf, disp, v, v_unbound, n, key, sev)]
cover = {}     # repair file -> [repaired records, with a shipped edit target, with a recognised check, with a bound check]
for P in passes:
    s, k = P["series"], P["k"]
    for rf in (f"{s}-repair-p{k}.md", f"{s}-serial-repair-p{k}.md"):
        t = show(BASE + rf)
        if t is None: continue
        blocks = re.split(r"(?m)^(?=### |<!-- shard)", t)
        for bi, b in enumerate(blocks):
            src = re.search(r"(?m)^- source:\s*(.+)$", b); dis = re.search(r"(?m)^- disposition:\s*(.+)$", b)
            if not src or not dis: continue
            head = b.splitlines()[0]
            rsev = next((x for x in SEV if re.search(rf"\b{x}\b", head)), None)
            ed = re.search(r"(?m)^- edit:\s*(.+)$", b)
            targets = {m.group(1) for m in EDIT_RE.finditer(ed.group(1))} if ed else set()
            ch_all = checks(b.splitlines())
            ch = [c for c in ch_all if c[0] in targets]   # a check counts only on the record's own edit target
            if dis.group(1).startswith("repaired"):
                v, vu = verdict(ch), verdict(ch_all)
                C = cover.setdefault(rf, [0, 0, 0, 0]); C[0] += 1
                C[1] += bool(targets); C[2] += bool(ch_all); C[3] += bool(ch)
            else: v = vu = "-"
            for m in re.finditer(r"(cross|\d+)\.md#F-(\d+)", src.group(1)):
                records.setdefault((s, k, m.group(1), int(m.group(2))), []).append(
                    dict(rf=rf, disp=dis.group(1).split()[0], v=v, vu=vu, n=len(ch), key=(rf, bi), sev=rsev, head=head))
FIND = {g["id"]: g for P in passes for g in P["findings"]}
def sev_agrees(i, r): return i in FIND and r["sev"] == FIND[i]["sev"]
def shifted_mismatch():
    """Probe: re-key every keyless finding one ordinal up; the severity join must then disagree somewhere."""
    bad = 0
    for i, rs in records.items():
        g = FIND.get(i)
        if not g or g["keyed"]: continue
        j = (i[0], i[1], i[2], i[3] + 1)
        for r in rs:
            if j in FIND and r["sev"] != FIND[j]["sev"]: bad += 1
    return bad

# ---------------------------------------------------------------- report
print(f"graph {REF}; passes in invoked_at order: " + ", ".join(f"{P['series']} p{P['k']} ({P['invoked']})" for P in passes))
print("controls:")
for P in passes:
    mj = sum(1 for f in P["findings"] if f["sev"] in ("CRITICAL", "MAJOR"))
    print(f"   {P['file']}: MAJOR+ headings {mj}, footer findings_major+critical {P['footer_major']}, equal {mj == P['footer_major']}; "
          f"all headings {len(P['findings'])}, keyless {sum(1 for f in P['findings'] if not f['keyed'])}, explicit-id/ordinal mismatches {P['ordinal_mismatch']}")
joined = [(i, r) for i, rs in records.items() for r in rs if i in FIND]
print(f"   repair records keyed to a parsed finding: {len(joined)}; keyed to no parsed finding: "
      f"{sum(len(v) for i, v in records.items() if i not in FIND)}")
print(f"   severity join (record heading vs finding heading): agree {sum(1 for i, r in joined if sev_agrees(i, r))} of {len(joined)}; "
      f"on keyless findings agree {sum(1 for i, r in joined if sev_agrees(i, r) and not FIND[i]['keyed'])} of "
      f"{sum(1 for i, r in joined if not FIND[i]['keyed'])}; probe (keyless re-keyed one ordinal up) mismatches {shifted_mismatch()}")
print("   disagreeing records (cannot supply PRESENT): " + "; ".join(
      f"{r['rf']} {i[2]}#F-{i[3]} {FIND[i]['sev']} vs record {r['sev']}" for i, r in joined if not sev_agrees(i, r)))
print(f"   later findings naming the other series' pass files: {xseries}")
print(f"   presence self-probe: an absent literal as a hit-check holds {holds(('test-strategy.md', 'zq-bl398-absent-token', True))}, "
      f"as a miss-check holds {holds(('test-strategy.md', 'zq-bl398-absent-token', False))}; "
      f"'Strategy Test IDs' as a hit-check over the stories dir holds {holds(('stories', 'Strategy Test IDs', True))}")
pr = [r for r in records.get(("test-strategy", 2, "3", 1), [])]
print("   edit-target probe, test-strategy p2 3#F-1 (edit at test-strategy.md, its only check greps a story): "
      + "; ".join(f"unbound {r['vu']}, bound {r['v']}" for r in pr))
print("   repair-file coverage (repaired records: with an edit target that is a shipped story or test-strategy.md / "
      "with a recognised check on any shipped artifact / with a check bound to its own edit target):")
for rf, C in cover.items(): print(f"     {rf}: {C[0]} repaired, {C[1]} / {C[2]} / {C[3]}")
print("   later-finding F-<n> mentions the grammar did not resolve (settled by hand in the entry):")
for P in passes:
    for f in P["findings"]:
        text = "\n".join([f["head"]] + f["body"]); got = refs(f)
        for m in re.finditer(r"F-(\d+)", text):
            ctx = text[max(0, m.start() - 45):m.end() + 25].replace("\n", " ")
            if re.search(r"(see|filed as|in) F-\d+ (below|above)|F-\d+ (below|above)", ctx): continue
            if f["head"].startswith(f"### F-{m.group(1)} ") and m.start() < len(f["head"]): continue
            if any(g[3] == int(m.group(1)) for g in got): continue
            print(f"     {P['series']} p{P['k']} {f['id'][2]}#F-{f['id'][3]}: ...{ctx}...")
def usable(i, r): return r["disp"] == "repaired" and sev_agrees(i, r)
print("per pass (MAJOR+ only):")
total = 0; counted_ids = []
for P in passes:
    rows = []
    for f in P["findings"]:
        if f["sev"] not in ("CRITICAL", "MAJOR"): continue
        rs = records.get(f["id"], [])
        rep = [r for r in rs if usable(f["id"], r)]
        present = any(r["v"] == "PRESENT" for r in rep) and not any(r["v"] == "ABSENT" for r in rep)
        later = caught.get(f["id"], [])
        rows.append((f, rs, later, present, present and not later))
    n = sum(1 for r in rows if r[4]); total += n
    print(f" {P['series']} p{P['k']}: MAJOR+ {len(rows)}, caught by a later round {sum(1 for r in rows if r[2])}, "
          f"repair PRESENT {sum(1 for r in rows if r[3])}, COUNTED {n}")
    for f, rs, later, present, c in rows:
        i = f["id"]; lab = f"{i[2]}#F-{i[3]}"
        rr = "; ".join(f"{r['rf'].replace('-repair-p', ' r').replace('.md', '')}:{r['disp']}:{r['sev']}:{r['v']}({r['n']} bound checks)"
                       for r in rs) or "no record"
        lt = ", ".join(f"{x[0]} p{x[1]} {x[2]}#F-{x[3]}" for x in later) or "-"
        print(f"   {'COUNT' if c else '     '} {lab:10} {f['head'][4:84]}")
        print(f"            records: {rr} | caught later by: {lt}")
    counted_ids += [r[0]["id"] for r in rows if r[4]]
print(f"VALUE: {total} MAJOR+ finding(s) uncaught by any later round with the repair present at {REF} -> "
      f"{'FOUND' if total >= 1 else 'NOT FOUND'} (a count of findings, not of distinct defects: shards of one pass can file one defect twice)")
# controls fixed before reading: the hand-traced positive and the re-found near-miss
pos = ("stories", 1, "1", 2); near = ("stories", 1, "cross", 2)
print(f"positive control stories p1 1#F-2 (hand-traced, hand-trace.sh: AC3 now spells the five-literal fence) counted: {pos in counted_ids}")
print(f"near-miss control stories p1 cross#F-2 (repair PRESENT, re-found by stories p2 2#F-1) counted: {near in counted_ids}; "
      f"caught by: {caught.get(near)}; would count without the later-round rule: "
      f"{any(r['v'] == 'PRESENT' for r in records.get(near, []) if usable(near, r))}")
