"""Carry-over-evaluation, s322 against s319: cost partition, per-width C/M yield and a survival floor (BL-812 item 1,
Projection (c): "Per-width catch yield was not measured").  Also the gate label gate-validation[carry-over-evaluation].

usage: python3 -I co_yield_s322.py <OUT dir holding spawns.jsonl> <graph clone> [<graph transcript dir>]

Read-only: <OUT>/spawns.jsonl, `git show`/`git ls-tree` of the graph clone, and (optional, third argument, default
~/.claude/projects/-Users-n8-git-graph) one subagent transcript. Writes nothing. Stdlib only.

Helpers are imported from the files beside this one, not restated: bl812_rederive.spawns/agg and
party_ts_yield.claim_spans/blocks/git.  width.py (step-value-carry-over-s319-s320/scripts) is a script and not importable;
its HP2 heading regex, TOK token regex and overlap rule are restated below, with the same meaning.

Method.
 1 Cost: s322 and s319 carry-over-evaluation spawns partitioned by description; the partition must sum to the label total.
 2 Yield: every CRITICAL/MAJOR (C/M) finding heading in each review file (party seat part and cross files; adversarial
   shards p1, p2, p3; s319 also elicitation shards), counted two ways (a heading parse and an independent /usr/bin/grep -c
   of the severity heading lines; adversarial files also by their findings_major provenance field).
   Join to the repair records: each repair block carries `- source:` keys (`<review file>#F-n`); a finding is REPAIRED when
   a block citing it has disposition repaired.  Per repair block the raisers are the distinct seats / shards citing it.
   Marginal catch of a width: blocks whose raisers all lie in one seat, one section shard, or the cross files.
   REFOUND (token proxy, width.py rule): the finding shares 2+ backtick tokens (or a CO-S id) with a finding of another round.
   REPAIR-INTRODUCED (token proxy): a finding token absent from the analyst draft and present in the previous repair record.
 3 Survival floor, per repair block of C/M severity with disposition repaired: the claim spans (claim_spans) of its
   `- claim now asserted:` line, classed by presence in the analyst draft, in the text p2 read (shards/coe-repair-p2/sections/.before,
   verified by sha256 against the record) and at the ship ref e0ebaf019.  Token presence is not correctness.
NOT in git and so not measured here: the document text between the draft and the p2 text (the squash merge keeps only the
draft file, the p2 `.before` copy and the shipped file; the transcripts hold the writes).
"""
import hashlib, importlib.util, json, os, re, subprocess, sys, collections, datetime

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m


if len(sys.argv) < 3:
    print(__doc__); raise SystemExit(2)
OUT, G = sys.argv[1], sys.argv[2].rstrip("/")
TDIR = sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
B = load("bl812_rederive")
PT = load("party_ts_yield")
SHIP322, SHIP319 = "e0ebaf019", "1da426ef9"
P322 = "_bmad-output/planning-artifacts/s322"
LABEL, GLABEL = "carry-over-evaluation", "gate-validation[carry-over-evaluation]"
GREP = "/usr/bin/grep"
IMPOSSIBLE_FINDING = "F-9999"
IMPOSSIBLE_KEY = ("carry-over-evaluation-zz-9", "F-1")


def show(ref, path):
    p = subprocess.run(["git", "-C", G, "show", "%s:%s" % (ref, path)], capture_output=True)
    return p.stdout.decode("utf-8", "replace") if p.returncode == 0 else None


def ls(ref, prefix):
    p = subprocess.run(["git", "-C", G, "ls-tree", "-r", "--name-only", ref, prefix], capture_output=True)
    return [x for x in p.stdout.decode().split("\n") if x]


def gcount(pattern, text):
    p = subprocess.run([GREP, "-c", "-i", "-E", pattern], input=text.encode(), capture_output=True)
    return int(p.stdout.decode().strip() or 0)


rows = B.spawns(OUT)

# ---------------------------------------------------------------- 1 cost
PARTS_322 = [
    ("analyst draft", r"^S322 carry-over evaluation draft"),
    ("party dispatcher", r"^Round-dispatcher"),
    ("party cross (4 seats)", r"^(pm|architect|dev|tea) cross$"),
    ("party part (4 seats x 7)", r"^(pm|architect|dev|tea) \d/7$"),
    ("party repair, section shards + reruns", r"^(Party repair section|Repair re-run part|Second re-run of part)"),
    ("party repair, serial lane + fan-in", r"^(Serial lane 1 of party repair|Fan-in party repair remediator)"),
    ("adv p1 part (7 shards)", r"^coe p1 shard \d$"),
    ("adv p1 cross", r"^coe p1 cross shard$"),
    ("S7-cap edit (between p1 and its repair)", r"^Add S7 cap to Base config"),
    ("adv p1 repair, section shards + rerun", r"^coe repair p1 shard"),
    ("adv p1 repair, serial lane + fan-in", r"^coe serial (lane 1|fan-in)$"),
    ("adv p2 part (6 shards)", r"^coe p2 shard \d$"),
    ("adv p2 cross (3 runs)", r"^coe p2 cross"),
    ("adv p2 repair, section shards", r"^coe repair p2 shard"),
    ("adv p2 repair, serial lane", r"^coe serial lane p2$"),
    ("adv p3 part (6 shards)", r"^coe p3 shard"),
    ("adv p3 cross", r"^coe p3 cross shard$"),
    ("adv p3 deferral record", r"^Write coe deferral record"),
    ("route: s321 minors triage rows", r"^Route s321 minors"),
]
PARTS_319 = [
    ("analyst draft", r"^Carry-over evaluation draft"),
    ("party part", r"^(PM|Architect|Dev|TEA) part"),
    ("party cross", r"^(PM|Architect|Dev|TEA) cross"),
    ("party repair (serial party remediator)", r"^Serial cross-section party remediator"),
    ("elicitation part", r"^Elicitation part"),
    ("elicitation cross", r"^Elicitation cross"),
    ("elicitation repair (sections + serial)", r"^(Elicitation repair section|Serial cross-section elicitation remediator)"),
    ("adv p1 part", r"^Adversarial pass \d part"),
    ("adv p1 cross", r"^Adversarial pass \d cross"),
    ("adv p1 repair (sections + re-run)", r"^(Remediate section|Re-run section)"),
]


def partition(sp, step, parts):
    s = [r for r in rows if int(r["sprint"]) == sp and r["step"] == step]
    acc = collections.OrderedDict((n, [0, 0.0, 0.0]) for n, _ in parts); acc["UNMATCHED"] = [0, 0.0, 0.0]
    for r in s:
        d = r.get("description") or ""; name = "UNMATCHED"
        for n, rx in parts:
            if re.search(rx, d):
                name = n; break
        a = acc[name]; a[0] += 1; a[1] += r.get("usd") or 0; a[2] += r.get("minutes") or 0
    return s, acc


def cost_block(sp, step, parts, stories):
    s, acc = partition(sp, step, parts)
    n, usd, mins, _ = B.agg(rows, sp, {step})
    print("\n== COST s%d %s (%d stories)" % (sp, step, stories))
    for k, (c, u, m) in acc.items():
        if c:
            print("  %-46s %3d spawns  $%7.2f  %7.1f agent-min" % (k, c, u, m))
    sc = sum(v[0] for v in acc.values()); su = sum(v[1] for v in acc.values()); sm = sum(v[2] for v in acc.values())
    print("  %-46s %3d spawns  $%7.2f  %7.1f agent-min  ($%.2f per story)" % ("PARTITION SUM", sc, su, sm, su / stories))
    print("  label total (bl812_rederive.agg)               %3d spawns  $%7.2f  %7.1f agent-min" % (n, usd, sum(r.get("minutes") or 0 for r in s)))
    ok = sc == n and abs(su - usd) < 0.005 and abs(sm - sum(r.get("minutes") or 0 for r in s)) < 0.05 and acc["UNMATCHED"][0] == 0
    print("  control partition sums to label totals, no UNMATCHED: %s" % ("MATCH" if ok else "DIFFERS"))
    return acc


print("== CONTROLS (cost): impossible description token reads %d spawns; a real token ('coe p1 shard') reads %d"
      % (sum(1 for r in rows if r["step"] == LABEL and int(r["sprint"]) == 322 and B.IMPOSSIBLE in (r.get("description") or "")),
         sum(1 for r in rows if r["step"] == LABEL and int(r["sprint"]) == 322 and "coe p1 shard" in (r.get("description") or ""))))
el = lambda sp: sum(1 for r in rows if int(r["sprint"]) == sp and r["step"] == LABEL and re.search("elicit", r.get("description") or "", re.I))
print("== CONTROL elicitation: s322 carry-over-evaluation spawns naming elicitation %d (s322 ran none); s319 reads %d (known present)" % (el(322), el(319)))
A322 = cost_block(322, LABEL, PARTS_322, 8)
A319 = cost_block(319, LABEL, PARTS_319, 20)

# ---------------------------------------------------------------- 2 findings
HP2 = re.compile(r"^(#{2,4})\s+(F-\d+)\b.*?\b(CRITICAL|MAJOR|MINOR)\b", re.I)
HP3 = re.compile(r"^(#{2,4})\s+((CRITICAL|MAJOR|MINOR)\s+\d+)\b", re.I)   # adversarial shards that head findings "### MAJOR 3: ..."
TOK = re.compile(r"`([^`\n]{6,80})`|(CO-S\d+[A-Z0-9-]*)|(\w+\.(?:py|md|sh|json):\d+)")


def toks(body):
    s = set()
    for a, b, c in TOK.findall(body):
        t = a or b or c
        if t.startswith(("$ ", "grep", "sed ")): continue
        s.add(t.strip())
    return s


def parse(text):
    lines = text.split("\n"); out = []; i = 0
    while i < len(lines):
        m = HP2.match(lines[i]); m3 = None if m else HP3.match(lines[i])
        if not m and not m3: i += 1; continue
        if m3:
            fid = re.sub(r"\s+", " ", m3.group(2).upper()); sev = m3.group(3).upper(); lvl = len(m3.group(1))
        else:
            fid = m.group(2); sev = m.group(3).upper(); lvl = len(m.group(1))
        j = i + 1
        while j < len(lines):
            mm = re.match(r"^(#{1,4})\s", lines[j])
            if mm and len(mm.group(1)) <= lvl: break
            j += 1
        out.append(dict(fid=fid, sev=sev, toks=toks("\n".join(lines[i:j]))))
        i = j
    return out


def collect(sp, ref):
    """[(round, kind, seat, key, text)] review files of sprint sp at ref."""
    R = []
    pm = "_bmad-output/party-mode/s%d/" % sp
    for f in ls(ref, pm):
        b = os.path.basename(f)
        m = re.match(r"carry-over-evaluation-(pm|architect|dev|tea)-(.+)\.md$", b)
        if m and "repair" not in b:
            R.append(("party", "cross" if m.group(2).startswith("cross") else "part", m.group(1), b[:-3], show(ref, f)))
    pa = "_bmad-output/planning-artifacts/s%d/shards/" % sp
    for rn, d in (("elic", "carry-over-evaluation-elicitation"), ("p1", "coe-p1"), ("p2", "coe-p2"), ("p3", "coe-p3")):
        for f in ls(ref, pa + d + "/"):
            if f.endswith(".md") and "/sections/" not in f:
                b = os.path.basename(f)[:-3]
                R.append((rn, "cross" if b.startswith("cross") else "part", "adv" if rn != "elic" else "elic", "%s/%s" % (d, b), show(ref, f)))
    return R


def findings(sp, ref):
    F = []; per = collections.defaultdict(lambda: [0, 0, 0, 0])
    for rn, kind, seat, key, text in collect(sp, ref):
        fs = parse(text)
        for x in fs:
            x.update(round=rn, kind=kind, seat=seat, key=key, sprint=sp)
        cm = [x for x in fs if x["sev"] in ("CRITICAL", "MAJOR")]
        F += cm
        p = per[rn]
        p[0] += len(cm)
        p[1] += gcount(r"^#{2,4}[[:space:]]+(F-[0-9]+.*(critical|major)|(critical|major)[[:space:]]+[0-9]+)", text)
        p[2] += sum(int(v) for k, v in re.findall(r"^findings_(critical|major): (\d+)", text, re.M))
        p[3] += 1
    return F, per


def counts_block(sp, ref):
    F, per = findings(sp, ref)
    print("\n== FINDINGS s%d at %s: C/M by round x width (heading parse | independent grep -c | provenance findings_critical+major)" % (sp, ref))
    for rn in ("party", "elic", "p1", "p2", "p3"):
        if rn not in per: continue
        k = collections.Counter(x["kind"] for x in F if x["round"] == rn)
        c = sum(1 for x in F if x["round"] == rn and x["sev"] == "CRITICAL")
        print("  %-6s files %3d  C/M heading parse %3d (part %3d, cross %3d; CRITICAL %d)  grep -c %3d  provenance %s" % (
            rn, per[rn][3], per[rn][0], k["part"], k["cross"], c, per[rn][1], per[rn][2] if rn != "party" and rn != "elic" else "n/a (party/elic files carry none)"))
        agree = per[rn][0] == per[rn][1] and (rn in ("party", "elic") or per[rn][0] == per[rn][2])
        print("         control two counts agree: %s" % ("MATCH" if agree else "DIFFERS"))
    print("  control impossible finding token %s found in %d findings (must be 0); real token F-1 found in %d" % (
        IMPOSSIBLE_FINDING, sum(1 for x in F if x["fid"] == IMPOSSIBLE_FINDING), sum(1 for x in F if x["fid"] == "F-1")))
    return F


F319 = counts_block(319, SHIP319)
F322 = counts_block(322, SHIP322)

# per-seat / per-shard distribution for s322 (the width the question asks about)
print("\n== s322 C/M per raiser (party seat x section 1..7 + cross; adversarial shard)")
for rn in ("party", "p1", "p2", "p3"):
    c = collections.Counter();
    for x in F322:
        if x["round"] == rn:
            c[x["key"].replace("carry-over-evaluation-", "")] += 1
    print("  %-5s %s" % (rn, " ".join("%s=%d" % (k, c[k]) for k in sorted(c))))
    if rn == "party":
        seats = collections.Counter(x["seat"] for x in F322 if x["round"] == "party")
        print("        by seat: %s" % dict(seats))
        for sec in range(1, 8):
            print("        section %d: %d C/M over 4 seats" % (sec, sum(1 for x in F322 if x["round"] == "party" and x["key"].endswith("-%d" % sec))))

# ---------------------------------------------------------------- repair records, join
REC322 = [
    ("party", "carry-over-evaluation-party-repair-p1.md"), ("party", "carry-over-evaluation-party-serial-repair-p1.md"),
    ("p1", "coe-repair-p1.md"), ("p1", "coe-serial-repair-p1.md"),
    ("p2", "coe-repair-p2.md"), ("p2", "coe-serial-repair-p2.md"),
]
SRC = re.compile(r"(\S+?)\.md#(F-\d+|(?:CRITICAL|MAJOR|MINOR) \d+)")
REPAIR = []   # dicts: record, round, head, sev, disp, keys (set of (review key, fid)), claim, body, unresolved
RECTEXT = {}
for rn, f in REC322:
    t = show(SHIP322, "%s/%s" % (P322, f)); RECTEXT[f] = t
    for head, body, art in PT.blocks(t):
        m = re.search(r"— (CRITICAL|MAJOR|MINOR|NOTE)", head)
        sev = m.group(1) if m else "?"
        disp = re.search(r"^- disposition: (\S+)", body, re.M)
        keys = set(); unres = 0
        for line in re.findall(r"^- source: (.*)$", body, re.M):
            ms = list(SRC.finditer(line))
            for mm in ms: keys.add((mm.group(1), mm.group(2)))
            if not ms: unres += 1
        claim = "\n".join(re.findall(r"^- claim now asserted:.*$", body, re.M))
        REPAIR.append(dict(record=f, round=rn, head=head, sev=sev, disp=disp.group(1) if disp else "?", keys=keys, claim=claim, unres=unres))
by_key = collections.defaultdict(list)
for b in REPAIR:
    for k in b["keys"]:
        by_key[k].append(b)
print("\n== REPAIR RECORDS (s322): blocks by record, severity, disposition, unresolvable source tokens")
for rn, f in REC322:
    bs = [b for b in REPAIR if b["record"] == f]
    print("  %-52s blocks %3d  sev %s  disp %s  unresolved source tokens %d" % (
        f, len(bs), dict(collections.Counter(b["sev"] for b in bs)), dict(collections.Counter(b["disp"] for b in bs)), sum(b["unres"] for b in bs)))
print("  control impossible source key cited by %d blocks (must be 0); real key %s cited by %d" % (
    len(by_key.get(IMPOSSIBLE_KEY, [])), "('carry-over-evaluation-pm-1','F-1')", len(by_key.get(("carry-over-evaluation-pm-1", "F-1"), []))))

print("\n== s322 C/M findings joined to repair blocks (REPAIRED = a citing block has disposition repaired)")
status = {}
for x in F322:
    bl = by_key.get((x["key"], x["fid"]), [])
    st = "REPAIRED" if any(b["disp"] == "repaired" for b in bl) else ("ESCALATED-ONLY" if bl else "NO-BLOCK")
    status[(x["key"], x["fid"])] = st; x["status"] = st
for rn in ("party", "p1", "p2", "p3"):
    xs = [x for x in F322 if x["round"] == rn]
    c = collections.Counter(x["status"] for x in xs)
    print("  %-5s C/M %3d: REPAIRED %3d  ESCALATED-ONLY %2d  NO-BLOCK %2d   %s" % (rn, len(xs), c["REPAIRED"], c["ESCALATED-ONLY"], c["NO-BLOCK"],
          "control sum MATCH" if sum(c.values()) == len(xs) else "control sum DIFFERS"))
nb = [x for x in F322 if x["status"] == "NO-BLOCK"]
print("  NO-BLOCK detail (key F-id): %s" % ", ".join("%s %s" % (x["key"].replace("carry-over-evaluation-", ""), x["fid"]) for x in nb))
print("  p3 has no repair record by design: coe-deferral-p3.md defers its 2 MAJORs to the requirements step (not repaired here)")

# ---------------------------------------------------------------- per-width marginal catch
print("\n== s322 which record repaired each C/M finding, by round x width (a finding cited by blocks of several records is listed under each)")
cmset = {(x["key"], x["fid"]): x for x in F322}
for rn in ("party", "p1", "p2", "p3"):
    for kind in ("part", "cross"):
        xs = [x for x in F322 if x["round"] == rn and x["kind"] == kind]
        c = collections.Counter()
        for x in xs:
            recs = {b["record"] for b in by_key.get((x["key"], x["fid"]), []) if b["disp"] == "repaired"}
            for r_ in recs: c[r_] += 1
            if not recs: c["(no repaired block)"] += 1
        print("  %-5s %-5s C/M %3d -> %s" % (rn, kind, len(xs), dict(sorted(c.items()))))
print("\n== s322 per-width marginal catch over DEFECTS (union-find: C/M findings of one round that share a repair block are one defect; a ceiling on defect count)")
for rn in ("party", "p1", "p2", "p3"):
    xs = [x for x in F322 if x["round"] == rn]
    par = {(x["key"], x["fid"]): (x["key"], x["fid"]) for x in xs}
    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for b in REPAIR:
        ks = [k for k in b["keys"] if k in par]
        for k in ks[1:]:
            par[find(k)] = find(ks[0])
    comp = collections.defaultdict(list)
    for x in xs: comp[find((x["key"], x["fid"]))].append(x)
    cs = list(comp.values())
    only_cross = sum(1 for c in cs if all(x["kind"] == "cross" for x in c))
    only_part = sum(1 for c in cs if all(x["kind"] == "part" for x in c))
    print("  round %-5s C/M findings %3d -> defects %3d (control findings in components %d MATCH=%s); only cross %d, only part files %d, both %d" % (
        rn, len(xs), len(cs), sum(len(c) for c in cs), sum(len(c) for c in cs) == len(xs), only_cross, only_part, len(cs) - only_cross - only_part))
    print("    raised by exactly one review file: %d of %d; by 2+ files: %d" % (sum(1 for c in cs if len({x["key"] for x in c}) == 1), len(cs), sum(1 for c in cs if len({x["key"] for x in c}) > 1)))
    if rn == "party":
        print("    distinct seats per defect: %s" % dict(sorted(collections.Counter(len({x["seat"] for x in c}) for c in cs).items())))
        for seat in ("pm", "architect", "dev", "tea"):
            print("    seat %-9s is the ONLY seat on %2d defects (those defects are lost if the seat is dropped)" % (seat, sum(1 for c in cs if {x["seat"] for x in c} == {seat})))
        for sec in range(1, 8):
            print("    section %d: %2d defects touch it, %2d are raised by that section's files alone" % (sec,
                  sum(1 for c in cs if any(x["key"].endswith("-%d" % sec) for x in c)),
                  sum(1 for c in cs if {x["key"].rsplit("-", 1)[1] for x in c} == {str(sec)} and all(x["kind"] == "part" for x in c))))
        print("    cross-file defects, per seat file: %s" % dict(collections.Counter(x["key"].replace("carry-over-evaluation-", "") for c in cs for x in c if x["kind"] == "cross")))
    else:
        sole = collections.Counter(); multi = 0
        for c in cs:
            ks = {x["key"].split("/")[1] for x in c}
            if len(ks) == 1: sole[next(iter(ks))] += 1
            else: multi += 1
        print("    defects with ONE shard as sole raiser, per shard: %s; raised by 2+ shards: %d" % (dict(sorted(sole.items())), multi))

# ---------------------------------------------------------------- REFOUND / REPAIR-INTRODUCED proxies
DRAFT = show(SHIP322, P322 + "/carry-over-evaluation.md.draft") or ""
SHIP_TXT = show(SHIP322, P322 + "/carry-over-evaluation.md") or ""
BEFORE_P2 = show(SHIP322, P322 + "/shards/coe-repair-p2/sections/.before") or ""
sha = lambda s: hashlib.sha256(s.encode()).hexdigest()
print("\n== TEXTS: draft %d B sha %s...; p2 .before %d B sha %s... (record says c4be61ba: %s); ship %d B sha %s... (record says 97b1a95e: %s)" % (
    len(DRAFT), sha(DRAFT)[:8], len(BEFORE_P2), sha(BEFORE_P2)[:8], "MATCH" if sha(BEFORE_P2).startswith("c4be61ba") else "DIFFERS",
    len(SHIP_TXT), sha(SHIP_TXT)[:8], "MATCH" if sha(SHIP_TXT).startswith("97b1a95e") else "DIFFERS"))
print("   party read sha 86906f13, the .draft file is sha %s: the draft is a stand-in for the party's text, not that text" % sha(DRAFT)[:8])
for x in F322: x["sets"] = x["toks"]


def overlap(a, b):
    s = a["toks"] & b["toks"]
    return len(s) >= 2 or any(t.startswith("CO-S") for t in s)


ORDER = {"party": 0, "p1": 1, "p2": 2, "p3": 3}
PREV_REC = {"p1": ("carry-over-evaluation-party-repair-p1.md", "carry-over-evaluation-party-serial-repair-p1.md"),
            "p2": ("coe-repair-p1.md", "coe-serial-repair-p1.md"), "p3": ("coe-repair-p2.md", "coe-serial-repair-p2.md")}
print("\n== s322 REFOUND and REPAIR-INTRODUCED token proxies, per round (C/M)")
for rn in ("party", "p1", "p2", "p3"):
    xs = [x for x in F322 if x["round"] == rn]
    ref_e = sum(1 for x in xs if any(ORDER[y["round"]] < ORDER[rn] and overlap(x, y) for y in F322))
    ref_l = sum(1 for x in xs if any(ORDER[y["round"]] > ORDER[rn] and overlap(x, y) for y in F322))
    ref_same = sum(1 for x in xs if any(y is not x and y["round"] == rn and y["key"] != x["key"] and overlap(x, y) for y in F322))
    intro = 0; indraft = 0; unres = 0
    for x in xs:
        if rn == "party":
            continue
        prev = "\n".join(RECTEXT[f] for f in PREV_REC[rn])
        new = [t for t in x["toks"] if t not in DRAFT]
        if any(t in prev for t in new): intro += 1
        elif x["toks"] and not new: indraft += 1
        else: unres += 1
    print("  %-5s C/M %3d: shares tokens with an EARLIER round's finding %3d, a LATER round's %3d, another file of the same round %3d" % (rn, len(xs), ref_e, ref_l, ref_same))
    if rn != "party":
        print("        token proxy: REPAIR-INTRODUCED %3d (a token absent from the draft, present in the previous repair record)  all-tokens-in-draft %3d  neither %3d" % (intro, indraft, unres))
print("  control: zero-token findings %d of %d (a zero-token finding can never be REFOUND by this rule)" % (sum(1 for x in F322 if not x["toks"]), len(F322)))

# ---------------------------------------------------------------- 3 survival floor
print("\n== s322 SURVIVAL FLOOR per repair record (C/M blocks, disposition repaired): claim spans at the draft / at the p2 .before / at ship")
print("   before-text for p1 and party repairs is NOT in git (squash merge); draft arm overstates NEW for later repairs, ship arm is the survival floor")
for rn, f in REC322:
    bs = [b for b in REPAIR if b["record"] == f and b["sev"] in ("CRITICAL", "MAJOR") and b["disp"] == "repaired"]
    c = collections.Counter(); newship = 0; new2 = 0
    for b in bs:
        sp = PT.claim_spans(b["claim"])
        if not sp: c["NO-SPAN"] += 1; continue
        ship = any(s in SHIP_TXT for s in sp); gone = not ship
        c["SHIPPED" if ship else "GONE"] += 1
        if ship and not all(s in DRAFT for s in sp) and any(s not in DRAFT and s in SHIP_TXT for s in sp): newship += 1
        if f.startswith("coe-") and f.endswith("p2.md") and any(s not in BEFORE_P2 and s in SHIP_TXT for s in sp): new2 += 1
    extra = "  absent-at-draft AND at-ship %d" % newship
    if "p2" in f: extra += "; absent-at-p2-before AND at-ship %d" % new2
    print("  %-52s C/M repaired blocks %2d: SHIPPED %2d GONE %2d NO-SPAN %2d%s" % (f, len(bs), c["SHIPPED"], c["GONE"], c["NO-SPAN"], extra))
print("  control impossible span at ship: %s (must be False); real span 'Section 1a' at ship: %s" % (PT.IMPOSSIBLE in SHIP_TXT, "Section 1a" in SHIP_TXT))

# ---------------------------------------------------------------- p2 remediator
print("\n== the p2 remediator Projection (c) names (coe serial lane p2)")
r = [x for x in rows if int(x["sprint"]) == 322 and x["description"] == "coe serial lane p2"]
print("  spawn rows: %d; control impossible description reads %d" % (len(r), sum(1 for x in rows if x["description"] == B.IMPOSSIBLE)))
if r:
    r = r[0]
    print("  %s start %s end %s minutes %.1f calls %s usd $%.2f" % (r["unit"], r["start"], r["end"], r["minutes"], r["calls"], r["usd"]))
    tf = None
    for dp, _, fs in os.walk(TDIR):
        for f in fs:
            if f == "%s.jsonl" % r["unit"]: tf = os.path.join(dp, f)
    if tf is None:
        print("  transcript NOT FOUND under %s (available on the operator's box; not measured here)" % TDIR)
    else:
        T = [json.loads(l) for l in open(tf)]; T = [t for t in T if "timestamp" in t]
        ts = lambda t: datetime.datetime.fromisoformat(t["timestamp"].replace("Z", "+00:00"))
        g = sorted(((ts(T[i]) - ts(T[i - 1])).total_seconds() / 60, i) for i in range(1, len(T)))[::-1]
        tools = collections.Counter(); edits = 0
        for t in T:
            c = t.get("message", {}).get("content")
            if isinstance(c, list):
                for b in c:
                    if b.get("type") == "tool_use":
                        tools[b["name"]] += 1
                        if b["name"] == "Edit" and "carry-over-evaluation.md" in b["input"].get("file_path", ""): edits += 1
        print("  transcript records %d, tool calls %s, Edits on carry-over-evaluation.md %d" % (len(T), dict(tools), edits))
        print("  largest gap %.1f min before record %d (%s); next gap %.1f min; active time %.1f min = lifetime %.1f - largest gap %.1f" % (
            g[0][0], g[0][1], ts(T[g[0][1]]).time(), g[1][0], r["minutes"] - g[0][0], r["minutes"], g[0][0]))
        c = T[g[0][1]].get("message", {}).get("content")
        print("  record %d (the message that ended the gap): %s" % (g[0][1], str(c)[:260].replace("\n", " ")))
        print("  last record of the work before the gap (%s): %s" % (ts(T[g[0][1] - 1]).time(), str(T[g[0][1] - 1].get("message", {}).get("content"))[:260].replace("\n", " ")))
    rec = RECTEXT["coe-serial-repair-p2.md"]
    bs = [b for b in REPAIR if b["record"] == "coe-serial-repair-p2.md"]
    print("  produced: coe-serial-repair-p2.md, %d entries, sev %s, disp %s, sha before %s after %s (the shipped sha)" % (
        len(bs), dict(collections.Counter(b["sev"] for b in bs)), dict(collections.Counter(b["disp"] for b in bs)),
        re.search(r"artifact_sha_before: (\w{8})", rec).group(1), re.search(r"artifact_sha_after: (\w{8})", rec).group(1)))
    print("  closes lines in the record: %d; `- advisor:` %s; `- derivations:` %s" % (len(re.findall(r"^- closes:", rec, re.M)),
          re.search(r"^- advisor: (.*)$", rec, re.M).group(1), re.search(r"^- derivations: (.*)$", rec, re.M).group(1)))
    print("  C/M findings (any round) cited by its blocks: %s" % sorted({"%s#%s" % k for b in bs for k in b["keys"] if k in cmset}))
    print("  its block headings: %s" % "; ".join(b["head"][4:] for b in bs))

# ---------------------------------------------------------------- gate label
print("\n== GATE LABEL %s" % GLABEL)
for sp in (322, 319):
    s = [x for x in rows if int(x["sprint"]) == sp and x["step"] == GLABEL]
    n, usd, mins, _ = B.agg(rows, sp, {GLABEL})
    print("  s%d: %d spawns $%.2f %.1f agent-min; first start %s last start %s" % (sp, n, usd, sum(x["minutes"] or 0 for x in s), min(x["start"] for x in s), max(x["start"] for x in s)))
    kinds = collections.Counter(re.sub(r"\d+/\d+", "N/N", x["description"]) for x in s)
    for k, v in sorted(kinds.items()):
        print("      %-28s %2d spawns $%.2f" % (k, v, sum(x["usd"] for x in s if re.sub(r"\d+/\d+", "N/N", x["description"]) == k)))
s = [x for x in rows if int(x["sprint"]) == 322 and x["step"] == GLABEL]
verd = collections.Counter()
for x in s:
    ft = x.get("final_text") or ""
    first = x["description"].startswith("Gate adjudicator")
    verd[("wave 1" if first else "re-adjudication", "FAIL" if re.search(r"\bjudged it FAIL\b|\bjudged FAIL\b|I judged it FAIL", ft) else "no FAIL")] += 1
print("  s322 final_text FAIL reads by wave (final_text is each adjudicator's closing message): %s" % dict(verd))
V = json.loads(show("f7e60625b", "_bmad-output/implementation-artifacts/s322/gate-adjudication/planning-20261109T134906Z.verdict.json"))
print("  planning verdict file planning-20261109T134906Z: %s, series %s" % (dict(collections.Counter(v["verdict"] for v in V["verdicts"])), V["gate_series_id"]))
w1 = [x for x in s if x["description"].startswith("Gate adjudicator")]
fails = [x for x in w1 if re.search(r"judged it FAIL", x.get("final_text") or "")]
print("  wave 1 FAIL spawns: %s" % [x["description"] for x in fails])
PEND = show(SHIP322, "docs/escalations/pending.md") or ""
ent = PEND.find("S322-L2-SCOPE-RECONFIRMATION-BASE-ENABLE-PREMISE-FALSIFIED")
seg = PEND[ent:ent + 4000]
print("  the FAIL's entry S322-L2-SCOPE-RECONFIRMATION-BASE-ENABLE-PREMISE-FALSIFIED in docs/escalations/pending.md at e0ebaf019: found %s, `Status:** RESOLVED` within it %s (control impossible entry id found: %s)" % (
    ent >= 0, bool(re.search(r"\*\*Status:\*\*\s*RESOLVED", seg)), "QZXV-NO-SUCH-ENTRY-5512" in PEND))
