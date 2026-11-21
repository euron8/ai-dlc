"""carry-over-evaluation, graph s323 against s319 and s322: cost partition, per-round x width C/M yield, the step-value
classification (REFOUND / MISSED-BY-PRIOR / REPAIR-INTRODUCED / UNIQUE-SURVIVED), repair survival at ship, and the label
gate-validation[carry-over-evaluation].  Port of co_yield_s322.py (BL-812 item 1, docs/analysis/step-value-s317-s319.md:20-35).

usage: python3 -I co_yield_s323.py <OUT dir holding spawns.jsonl> <graph repo or clone>

Read-only: <OUT>/spawns.jsonl and `git show` / `git ls-tree` of the graph repo.  Writes nothing.  Stdlib only.
Environment: SV_HELPERS = dir holding bl812_rederive.py and party_ts_yield.py (default: ../../pipeline-efficiency-s317-s322/scripts
beside this file); WIDTH_TXT = the committed width.py output used as the C/M control (default: ../../s323-outcomes-b261/
bl810-bl1005/out/width-319-320-323.txt beside this file).

Refs.  s323 ship = eabdc576e (sprint PR #1337 squash merge; the analogue of e0ebaf019 for s322).  The planning branch keeps one
commit per round, so the document text each round READ is in git and is verified against the round's own artifact_sha:
  elic read 9440942a = a95acd791; p1 read ef0df5fb = ede525729; p1 repaired 77fc057a = c2cbf4105; p2 read f70f0bd2 = 8347e51b0;
  p3 read 374d866b = 360fc1c2a; p3 repaired 083f6544 = 91b74ac1; p3 second link 11d48234 = e41959d61; ship 52130ff6.
NOT in git: the text the party round read (657 lines, the analyst draft) and the party repair's before text (sha 6f80202a).
So party MISSED-BY-PRIOR / REPAIR-INTRODUCED are not measurable, and the elicitation round has no measurable previous round.

Classification proxies (token presence is not correctness; every one is printed with its population):
  REFOUND        the finding shares 2+ backtick/file:line tokens (or a CO-S id) with a finding of another round (width.py rule);
                 later / earlier / other-width-same-round are printed apart.
  text tokens    backtick spans of 6+ characters and CO-S ids, minus line-number spans and file:line tokens (a line number moves
                 with every edit, so it cannot test presence in text).
  REPAIR-INTRODUCED  every text token of the finding that is in the text the round read is ABSENT from the text the previous
                 measurable round read (the previous round's repair, a fold or an operator edit wrote it).
  MIXED          some tokens new, some old.     MISSED-BY-PRIOR  every in-text token was already in the previous round's text.
  NO-TOKEN       no text token of the finding is in the text the round read.
  UNIQUE-SURVIVED  not REFOUND by a later round, not REPAIR-INTRODUCED/MIXED, REPAIRED, and a claim span of its repair block
                 is at ship.
"""
import collections, hashlib, importlib.util, json, os, re, subprocess, sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) != 3:
    print(__doc__); raise SystemExit(2)
OUT, G = sys.argv[1], sys.argv[2].rstrip("/")
HELP = os.environ.get("SV_HELPERS") or os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s322", "scripts")
WIDTH_TXT = os.environ.get("WIDTH_TXT") or os.path.join(HERE, "..", "..", "s323-outcomes-b261", "bl810-bl1005", "out", "width-319-320-323.txt")


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HELP, name + ".py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m


B = load("bl812_rederive"); PT = load("party_ts_yield")
SHIP = "eabdc576e"
P = "_bmad-output/planning-artifacts/s323"
DOC = P + "/carry-over-evaluation.md"
LABEL, GLABEL = "carry-over-evaluation", "gate-validation[carry-over-evaluation]"
GREP = "/usr/bin/grep"
GLOG_REF = "16fd227d9"   # s323 close: gate-adjudication verdict files and the gate-log archive are there, not at the sprint merge
STATES = [("elic read", "a95acd791", "9440942a"), ("p1 read", "ede525729", "ef0df5fb"), ("p1 repaired", "c2cbf4105", "77fc057a"),
          ("p2 read", "8347e51b0", "f70f0bd2"), ("p3 read", "360fc1c2a", "374d866b"), ("p3 repaired", "91b74ac19", "083f6544"),
          ("p3 second link", "e41959d61", "11d48234"), ("ship", SHIP, "52130ff6")]


def show(ref, path):
    p = subprocess.run(["git", "-C", G, "show", "%s:%s" % (ref, path)], capture_output=True)
    return p.stdout.decode("utf-8", "replace") if p.returncode == 0 else None


def ls(ref, prefix):
    p = subprocess.run(["git", "-C", G, "ls-tree", "-r", "--name-only", ref, prefix], capture_output=True)
    return sorted(x for x in p.stdout.decode().split("\n") if x)


def gcount(pattern, text):
    p = subprocess.run([GREP, "-c", "-i", "-E", pattern], input=text.encode(), capture_output=True)
    return int(p.stdout.decode().strip() or 0)


def sha(s): return hashlib.sha256(s.encode()).hexdigest()


rows = B.spawns(OUT)

# ================================================================ 1 cost
RND = r"(?:p\d)"
PARTS_323 = [
    ("analyst draft", r"^Sprint \d+ carry-over evaluation draft$"),
    ("party dispatcher", r"^Dispatch \d+-seat party round$"),
    ("party cross (4 seats)", r"^(pm|architect|dev|tea) cross$"),
    ("party part (4 seats x 6)", r"^(pm|architect|dev|tea) \d$"),
    ("party repair, section shards", r"^Party repair section \d$"),
    ("party repair, serial after assembly", r"^Serial repair after assembly$"),
    ("route: live reads and read-only checks", r"^(Day-\d live reads for s\d+|Verify Merkl Base distributor address|Read-only Base task-def APP_ENV check|Read live Base config keys)$"),
    ("route: adjudication and closure remediators", r"^(Adjudication remediator for CoE|Dispatch closure-writer remediator)$"),
    ("elicitation part (4 shards)", r"^Elicitation shard \d/\d part \d$"),
    ("elicitation cross (1 agent)", r"^Elicitation cross shard$"),
    ("elicitation repair, section shards", r"^Elicitation repair part \d$"),
    ("elicitation repair, serial", r"^(Serial cross-section remediator p1|Serial remediator pass 2 X-F-2)$"),
    ("adv p1 part (3 shards)", r"^Adversarial p1 shard \d/\d$"),
    ("adv p1 cross", r"^Adversarial p1 cross shard$"),
    ("adv p1 repair, section shards", r"^Adversarial repair p1 shard \d$"),
    ("adv p1 repair, adjudicator lanes + serial", r"^(Adjudicator lane-1 batch \d|Lane-1 serial remediator)$"),
    ("operator-decision closer correction", r"^Operator-decision closer correction$"),
    ("adv p2 part (4 shards)", r"^Adversarial p2 shard \d/\d$"),
    ("adv p2 cross", r"^Adversarial p2 cross shard$"),
    ("adv p2 repair, section shards", r"^Repair p2 section \d/\d$"),
    ("adv p2 repair, serial lane + record fixes", r"^(Serial lane repair p2|Lane record-only rewrite|Fix stale fence in repair record)$"),
    ("adv p3 part (3 shards)", r"^Adversarial p3 shard \d/\d$"),
    ("adv p3 cross", r"^Adversarial p3 cross shard$"),
    ("adv p3 repair + step 4a record", r"^(Repair p3 open MAJOR, write record|Record step 4a recurrence cross-check)$"),
    ("route: fold answered OQs into requirements", r"^Fold answered OQs into requirements artifacts$"),
]
PARTS_322 = [
    ("analyst draft", r"^S322 carry-over evaluation draft"), ("party dispatcher", r"^Round-dispatcher"),
    ("party cross (4 seats)", r"^(pm|architect|dev|tea) cross$"), ("party part (4 seats x 7)", r"^(pm|architect|dev|tea) \d/7$"),
    ("party repair, section shards + reruns", r"^(Party repair section|Repair re-run part|Second re-run of part)"),
    ("party repair, serial lane + fan-in", r"^(Serial lane 1 of party repair|Fan-in party repair remediator)"),
    ("adv p1 part (7 shards)", r"^coe p1 shard \d$"), ("adv p1 cross", r"^coe p1 cross shard$"),
    ("S7-cap edit", r"^Add S7 cap to Base config"), ("adv p1 repair, section shards + rerun", r"^coe repair p1 shard"),
    ("adv p1 repair, serial lane + fan-in", r"^coe serial (lane 1|fan-in)$"), ("adv p2 part (6 shards)", r"^coe p2 shard \d$"),
    ("adv p2 cross (3 runs)", r"^coe p2 cross"), ("adv p2 repair, section shards", r"^coe repair p2 shard"),
    ("adv p2 repair, serial lane", r"^coe serial lane p2$"), ("adv p3 part (6 shards)", r"^coe p3 shard"),
    ("adv p3 cross", r"^coe p3 cross shard$"), ("adv p3 deferral record", r"^Write coe deferral record"),
    ("route: s321 minors triage rows", r"^Route s321 minors"),
]
PARTS_319 = [
    ("analyst draft", r"^Carry-over evaluation draft"), ("party part", r"^(PM|Architect|Dev|TEA) part"),
    ("party cross", r"^(PM|Architect|Dev|TEA) cross"), ("party repair (serial party remediator)", r"^Serial cross-section party remediator"),
    ("elicitation part", r"^Elicitation part"), ("elicitation cross", r"^Elicitation cross"),
    ("elicitation repair (sections + serial)", r"^(Elicitation repair section|Serial cross-section elicitation remediator)"),
    ("adv p1 part", r"^Adversarial pass \d part"), ("adv p1 cross", r"^Adversarial pass \d cross"),
    ("adv p1 repair (sections + re-run)", r"^(Remediate section|Re-run section)"),
]


def cost_block(sp, step, parts, stories):
    s = [r for r in rows if int(r["sprint"]) == sp and r["step"] == step]
    acc = collections.OrderedDict((n, [0, 0.0, 0.0]) for n, _ in parts); acc["UNMATCHED"] = [0, 0.0, 0.0]
    multi = 0
    for r in s:
        d = r.get("description") or ""
        hit = [n for n, rx in parts if re.search(rx, d)]
        multi += len(hit) > 1
        a = acc[hit[0] if hit else "UNMATCHED"]; a[0] += 1; a[1] += r.get("usd") or 0; a[2] += r.get("minutes") or 0
    n, usd, mins, _ = B.agg(rows, sp, {step})
    print("\n== COST s%d %s (%d stories)" % (sp, step, stories))
    for k, (c, u, m) in acc.items():
        if c: print("  %-46s %3d spawns  $%7.2f  %7.1f agent-min" % (k, c, u, m))
    sc = sum(v[0] for v in acc.values()); su = sum(v[1] for v in acc.values()); sm = sum(v[2] for v in acc.values())
    tm = sum(r.get("minutes") or 0 for r in s)
    print("  %-46s %3d spawns  $%7.2f  %7.1f agent-min  ($%.2f per story)" % ("PARTITION SUM", sc, su, sm, su / stories))
    print("  label total (bl812_rederive.agg)               %3d spawns  $%7.2f  %7.1f agent-min" % (n, usd, tm))
    ok = sc == n and abs(su - usd) < 0.005 and abs(sm - tm) < 0.05 and acc["UNMATCHED"][0] == 0 and multi == 0
    print("  control partition sums to label totals, UNMATCHED bucket %d rows, rows matching 2+ rules %d: %s" % (acc["UNMATCHED"][0], multi, "MATCH" if ok else "DIFFERS"))
    return acc


def sub(acc, *names):
    return tuple(sum(acc[n][i] for n in names if n in acc) for i in range(3))


print("== CONTROLS (cost): impossible description token reads %d spawns; real token 'Adversarial p1 shard' reads %d (s323)" % (
    sum(1 for r in rows if r["step"] == LABEL and B.IMPOSSIBLE in (r.get("description") or "")),
    sum(1 for r in rows if r["step"] == LABEL and int(r["sprint"]) == 323 and "Adversarial p1 shard" in (r.get("description") or ""))))
A323 = cost_block(323, LABEL, PARTS_323, 18)
A322 = cost_block(322, LABEL, PARTS_322, 8)
A319 = cost_block(319, LABEL, PARTS_319, 20)

# ================================================================ 2 findings
HP2 = re.compile(r"^(#{2,4})\s+(F-\d+)\b.*?\b(CRITICAL|MAJOR|MINOR)\b", re.I)
HP3 = re.compile(r"^(#{2,4})\s+((CRITICAL|MAJOR|MINOR)\s+\d+)\b", re.I)
TOK = re.compile(r"`([^`\n]{6,80})`|(CO-S\d+[A-Z0-9-]*)|(\w+\.(?:py|md|sh|json):\d+)")
BT = re.compile(r"`([^`\n]{6,80})`|(CO-S\d+[A-Z0-9-]*)")
LINEREF = re.compile(r"^[:\d\s,.–-]+$|^\S+\.(?:py|md|sh|json|yaml|yml|txt):\d+")


def toks(body):
    s = set()
    for a, b, c in TOK.findall(body):
        t = a or b or c
        if t.startswith(("$ ", "grep", "sed ")): continue
        s.add(t.strip())
    return s


def ttoks(body):
    s = set()
    for a, b in BT.findall(body):
        t = (a or b).strip()
        if t.startswith(("$ ", "grep", "sed ")) or LINEREF.match(t): continue
        s.add(t)
    return s


def parse(text):
    lines = text.split("\n"); out = []; i = 0; hp3 = 0
    while i < len(lines):
        m = HP2.match(lines[i]); m3 = None if m else HP3.match(lines[i])
        if not m and not m3: i += 1; continue
        if m3:
            hp3 += 1; fid = re.sub(r"\s+", " ", m3.group(2).upper()); sev = m3.group(3).upper(); lvl = len(m3.group(1))
        else:
            fid = m.group(2); sev = m.group(3).upper(); lvl = len(m.group(1))
        j = i + 1
        while j < len(lines):
            mm = re.match(r"^(#{1,4})\s", lines[j])
            if mm and len(mm.group(1)) <= lvl: break
            j += 1
        body = "\n".join(lines[i:j])
        out.append(dict(fid=fid, sev=sev, toks=toks(body), ttoks=ttoks(body), head=lines[i][:150]))
        i = j
    return out, hp3


ELICD = "coe-elicitation"
ADV = (("elic", ELICD), ("p1", "coe-p1"), ("p2", "coe-p2"), ("p3", "coe-p3"))
REPAIR_NAMED = re.compile(r"\b(repair(?:ed|s|'s)?|rewritten|re-anchored|new negative|restored|renewed)\b", re.I)
ORDER = {"party": 0, "elic": 1, "p1": 2, "p2": 3, "p3": 4}
RN = ("party", "elic", "p1", "p2", "p3")


def collect(ref):
    R = []
    for f in ls(ref, "_bmad-output/party-mode/s323/"):
        b = os.path.basename(f)
        m = re.match(r"carry-over-evaluation-(pm|architect|dev|tea)-(\d+|cross)\.md$", b)
        if m: R.append(("party", "cross" if m.group(2) == "cross" else "part", m.group(1), b[:-3], show(ref, f)))
    for rn, d in ADV:
        for f in ls(ref, P + "/shards/" + d + "/"):
            if f.endswith(".md") and "/sections/" not in f:
                b = os.path.basename(f)[:-3]
                R.append((rn, "cross" if b == "cross" else "part", "adv", "%s/%s" % (d, b), show(ref, f)))
    return R


F = []; per = collections.defaultdict(lambda: [0, 0, 0, 0, 0])
for rn, kind, seat, key, text in collect(SHIP):
    fs, hp3 = parse(text)
    for x in fs: x.update(round=rn, kind=kind, seat=seat, key=key)
    cm = [x for x in fs if x["sev"] in ("CRITICAL", "MAJOR")]
    F += cm
    p = per[(rn, kind)]
    p[0] += len(cm)
    p[1] += gcount(r"^#{2,4}[[:space:]]+F-[0-9]+.*(critical|major)", text) if False else gcount(r"^#{2,4}[[:space:]]+(F-[0-9]+.*(critical|major)|(critical|major)[[:space:]]+[0-9]+)", text)
    p[2] += sum(int(v) for k, v in re.findall(r"^findings_(critical|major): (\d+)", text, re.M))
    p[3] += 1; p[4] += hp3
print("\n== FINDINGS s323 at %s: C/M by round x width (heading parse | independent grep -c | provenance findings_critical+major | HP3 'MAJOR n' headings)" % SHIP)
for rn in RN:
    for kind in ("part", "cross"):
        if (rn, kind) not in per: continue
        p = per[(rn, kind)]
        xs = [x for x in F if x["round"] == rn and x["kind"] == kind]
        prov = p[2] if rn not in ("party", "elic") else None
        agree = p[0] == p[1] and (prov is None or prov == p[0])
        print("  %-5s %-5s files %3d  C/M %3d (CRITICAL %d)  grep -c %3d  provenance %s  HP3 %d   control two counts agree: %s" % (
            rn, kind, p[3], p[0], sum(1 for x in xs if x["sev"] == "CRITICAL"), p[1], prov if prov is not None else "n/a", p[4], "MATCH" if agree else "DIFFERS"))
print("  control impossible finding F-9999 found in %d findings (must be 0); real F-1 in %d" % (sum(1 for x in F if x["fid"] == "F-9999"), sum(1 for x in F if x["fid"] == "F-1")))
print("  total C/M %d, CRITICAL %d" % (len(F), sum(1 for x in F if x["sev"] == "CRITICAL")))

# ---- control against width.py (committed output, same token-join rule)
def ov(a, b):
    s = a["toks"] & b["toks"]
    return len(s) >= 2 or any(t.startswith("CO-S") for t in s)


for x in F:
    x["same_part"] = sum(1 for y in F if y is not x and y["round"] == x["round"] and y["kind"] == "part" and ov(x, y))
    x["same_cross"] = sum(1 for y in F if y is not x and y["round"] == x["round"] and y["kind"] == "cross" and ov(x, y))
    x["other_rounds"] = sorted({y["round"] for y in F if y["round"] != x["round"] and ov(x, y)})
    x["later"] = sorted({y["round"] for y in F if ORDER[y["round"]] > ORDER[x["round"]] and ov(x, y)})
    x["earlier"] = sorted({y["round"] for y in F if ORDER[y["round"]] < ORDER[x["round"]] and ov(x, y)})
agg = collections.defaultdict(collections.Counter)
for x in F:
    a = agg[(x["round"], x["kind"])]; a["n"] += 1; a["crit"] += x["sev"] == "CRITICAL"
    a["refound_by_part"] += x["same_part"] > 0; a["refound_other_round"] += bool(x["other_rounds"])
    a["unique_in_cross"] += (x["kind"] == "cross" and x["same_part"] == 0 and not x["other_rounds"])
    a["unique_in_part"] += (x["kind"] == "part" and x["same_cross"] == 0 and not x["other_rounds"])
print("\n== CONTROL against width.py's committed output (%s): per round x width n, crit, refound_by_part, refound_other_round, unique_in_cross, unique_in_part" % os.path.basename(WIDTH_TXT))
WT = {}
if os.path.exists(WIDTH_TXT):
    for l in open(WIDTH_TXT):
        m = re.match(r"^\((323), '(\w+)', '([\w-]+)'\) (\{.*\})$", l.strip())
        if m: WT[(m.group(2), "part" if m.group(3) == "part" else "cross")] = eval(m.group(4), {"__builtins__": {}})
    allok = True
    for k in sorted(set(WT) | set(agg), key=lambda k: (ORDER[k[0]], k[1])):
        mine = dict(agg.get(k, {})); mine = {q: mine.get(q, 0) for q in ("n", "crit", "refound_by_part", "refound_other_round", "unique_in_cross", "unique_in_part")}
        theirs = WT.get(k)
        ok = theirs == mine; allok &= ok
        print("  %-5s %-5s mine %s | width.py %s : %s" % (k[0], k[1], list(mine.values()), list(theirs.values()) if theirs else None, "MATCH" if ok else "DIFFERS"))
    print("  control (rows read from width.py output: %d; impossible round key present: %s): ALL %s" % (len(WT), ("zz", "part") in WT, "MATCH" if allok and WT else "DIFFERS"))
else:
    print("  width.py output NOT FOUND at %s (control not run)" % WIDTH_TXT)

# ================================================================ 3 repair records and the join
RECS = [("party", "carry-over-evaluation-party-repair-p1.md", "party"), ("elic", "coe-elicitation-repair-p1.md", ELICD),
        ("p1", "coe-repair-p1.md", "coe-p1"), ("p1", "coe-serial-repair-p1.md", "coe-p1"), ("p1", "coe-serial-repair-p1-correction.md", None),
        ("p2", "coe-repair-p2.md", "coe-p2"), ("p2", "coe-serial-repair-p2.md", "coe-p2"),
        ("p3", "coe-repair-p3.md", "coe-p3"), ("p3", "coe-repair-p3-second.md", None)]
SRC = re.compile(r"(\S+?)\.md#(F-\d+)")
REPAIR = []; RECTEXT = {}
for rn, f, d in RECS:
    t = show(SHIP, "%s/%s" % (P, f)) or ""; RECTEXT[f] = t
    lines = t.split("\n"); ctx = None; i = 0
    while i < len(lines):
        l = lines[i]
        mc = re.match(r"^<!-- shard: (\S+?)(?:\.md)? -->", l)
        if mc: ctx = mc.group(1)
        if l.startswith("### "):
            j = i + 1
            while j < len(lines) and not re.match(r"^(#{1,3} |<!-- shard)", lines[j]): j += 1
            body = "\n".join(lines[i + 1:j]); head = l
            m = re.search(r"— (CRITICAL|MAJOR|MINOR|NOTE|NIT)", head); sev = m.group(1) if m else "?"
            disp = re.search(r"^- disposition: (\S+)", body, re.M)
            keys = set()
            for mm in SRC.finditer("\n".join(re.findall(r"^- source: (.*)$", body, re.M))):
                nm = mm.group(1)
                if rn == "party": keys.add((nm, mm.group(2)))
                elif nm == "cross": keys.add((d + "/cross", mm.group(2)))
                elif re.fullmatch(r"\d", nm) and d: keys.add((d + "/" + nm, mm.group(2)))
                elif d and "/" in nm: keys.add((nm, mm.group(2)))
            for mm in re.finditer(r"coe-adversarial-(p\d)\.md cross shard (F-\d+)", body):
                keys.add(("coe-%s/cross" % mm.group(1), mm.group(2)))
            claim = "\n".join(re.findall(r"^- claim now asserted:.*$", body, re.M))
            REPAIR.append(dict(rec=f, round=rn, dir=d, ctx=ctx, head=head[4:], sev=sev, disp=disp.group(1) if disp else "?", keys=keys, claim=claim, body=body))
            i = j
        else:
            i += 1

# head-based keys for blocks with no source key; escalated blocks of the p1 shard record hand their keys to the serial's "ESCALATED: k.md F-n"
esc = {}
for b in REPAIR:
    if b["rec"] == "coe-repair-p1.md" and b["disp"] == "escalated" and b["keys"]: esc[(b["ctx"], re.match(r"(?:M-|cross-)?F-\d+[a-z]?", b["head"]).group(0) if re.match(r"(?:M-|cross-)?F-\d+[a-z]?", b["head"]) else "")] = b["keys"]
HEADK = re.compile(r"^(?:ESCALATED: )?(?:(\d)\.md |(cross) )?(X-F-|M-F-|cross-F-|F-)(\d+)")
for b in REPAIR:
    if b["keys"] or not b["dir"] or b["round"] == "party": continue
    m = HEADK.match(b["head"])
    if b["head"].startswith("B") and re.match(r"B\d \(part (\d) (F-\d+)", b["head"]):
        mb = re.match(r"B\d \(part (\d) (F-\d+)", b["head"]); b["keys"].add((b["dir"] + "/" + mb.group(1), mb.group(2))); continue
    if not m: continue
    num = "F-" + m.group(4)
    if b["head"].startswith("ESCALATED: ") and b["rec"] == "coe-serial-repair-p1.md":
        hid = re.match(r"ESCALATED: (\d)\.md ((?:M-|cross-)?F-\d+[a-z]?)", b["head"])
        if hid and (hid.group(1), hid.group(2)) in esc: b["keys"] |= esc[(hid.group(1), hid.group(2))]; continue
    if m.group(2) or m.group(3) in ("X-F-", "M-F-", "cross-F-"): b["keys"].add((b["dir"] + "/cross", num))
    else: b["keys"].add((b["dir"] + "/" + (m.group(1) or b["ctx"] or ""), num))
by_key = collections.defaultdict(list)
for b in REPAIR:
    for k in b["keys"]: by_key[k].append(b)
print("\n== REPAIR RECORDS (s323) at %s: blocks, severity, disposition, blocks with no joinable finding key" % SHIP)
for rn, f, d in RECS:
    bs = [b for b in REPAIR if b["rec"] == f]
    print("  %-46s blocks %3d  C/M %3d  disp %s  no finding key %d" % (f, len(bs), sum(1 for b in bs if b["sev"] in ("CRITICAL", "MAJOR")),
          dict(sorted(collections.Counter(b["disp"] for b in bs).items())), sum(1 for b in bs if not b["keys"])))
    h = len(re.findall(r"^### .*\b(?:CRITICAL|MAJOR)\b", RECTEXT[f], re.M))
    print("      control C/M ### headings by independent regex %d vs parse %d: %s" % (h, sum(1 for b in bs if b["sev"] in ("CRITICAL", "MAJOR")), "MATCH" if h == sum(1 for b in bs if b["sev"] in ("CRITICAL", "MAJOR")) else "DIFFERS"))
print("  control impossible key cited by %d blocks (must be 0); real key ('carry-over-evaluation-pm-1','F-1') cited by %d" % (
    len(by_key.get(("carry-over-evaluation-zz-9", "F-1"), [])), len(by_key.get(("carry-over-evaluation-pm-1", "F-1"), []))))

for x in F:
    bl = by_key.get((x["key"], x["fid"]), [])
    x["status"] = "REPAIRED" if any(b["disp"] == "repaired" for b in bl) else ("ESCALATED-ONLY" if bl else "NO-BLOCK")
    x["blocks"] = [b for b in bl if b["disp"] == "repaired"]
print("\n== s323 C/M findings joined to repair blocks (REPAIRED = a citing block has disposition repaired)")
for rn in RN:
    for kind in ("part", "cross"):
        xs = [x for x in F if x["round"] == rn and x["kind"] == kind]
        if not xs: continue
        c = collections.Counter(x["status"] for x in xs)
        print("  %-5s %-5s C/M %3d: REPAIRED %3d  ESCALATED-ONLY %2d  NO-BLOCK %2d   control sum %s" % (rn, kind, len(xs), c["REPAIRED"], c["ESCALATED-ONLY"], c["NO-BLOCK"], "MATCH" if sum(c.values()) == len(xs) else "DIFFERS"))
nb = [x for x in F if x["status"] != "REPAIRED"]
print("  not REPAIRED (round key F-id status): %s" % "; ".join("%s %s %s %s" % (x["round"], x["key"].replace("carry-over-evaluation-", ""), x["fid"], x["status"]) for x in sorted(nb, key=lambda x: (ORDER[x["round"]], x["key"], x["fid"]))))

# ================================================================ 4 per-width marginal catch over defects
print("\n== s323 per-width marginal catch over DEFECTS (union-find: C/M findings of one round that share a repair block are one defect; a ceiling on the defect count)")
DEF = {}
for rn in RN:
    xs = [x for x in F if x["round"] == rn]
    par = {(x["key"], x["fid"]): (x["key"], x["fid"]) for x in xs}
    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for b in REPAIR:
        ks = sorted(k for k in b["keys"] if k in par)
        for k in ks[1:]: par[find(k)] = find(ks[0])
    comp = collections.defaultdict(list)
    for x in xs: comp[find((x["key"], x["fid"]))].append(x)
    cs = [comp[k] for k in sorted(comp)]; DEF[rn] = cs
    only_cross = sum(1 for c in cs if all(x["kind"] == "cross" for x in c)); only_part = sum(1 for c in cs if all(x["kind"] == "part" for x in c))
    print("  round %-5s C/M findings %3d -> defects %3d (control findings in components %d MATCH=%s); only cross %d, only part files %d, both %d" % (
        rn, len(xs), len(cs), sum(len(c) for c in cs), sum(len(c) for c in cs) == len(xs), only_cross, only_part, len(cs) - only_cross - only_part))
    print("    raised by exactly one review file: %d of %d; by 2+ files: %d" % (sum(1 for c in cs if len({x["key"] for x in c}) == 1), len(cs), sum(1 for c in cs if len({x["key"] for x in c}) > 1)))
    if rn == "party":
        print("    distinct seats per defect: %s" % dict(sorted(collections.Counter(len({x["seat"] for x in c}) for c in cs).items())))
        for seat in ("pm", "architect", "dev", "tea"):
            print("    seat %-9s is the ONLY seat on %2d defects; findings %d (part %d, cross %d)" % (seat, sum(1 for c in cs if {x["seat"] for x in c} == {seat}),
                  sum(1 for x in xs if x["seat"] == seat), sum(1 for x in xs if x["seat"] == seat and x["kind"] == "part"), sum(1 for x in xs if x["seat"] == seat and x["kind"] == "cross")))
        for sec in range(1, 7):
            print("    section %d: %2d defects touch it, %2d are raised by that section's part files alone" % (sec,
                  sum(1 for c in cs if any(x["key"].endswith("-%d" % sec) for x in c)),
                  sum(1 for c in cs if {x["key"].rsplit("-", 1)[1] for x in c} == {str(sec)} and all(x["kind"] == "part" for x in c))))
        print("    cross-only defects, per seat cross file: %s" % dict(sorted(collections.Counter(x["key"].replace("carry-over-evaluation-", "") for c in cs if all(y["kind"] == "cross" for y in c) for x in c).items())))
    else:
        sole = collections.Counter(); multi = 0
        for c in cs:
            ks = {x["key"].split("/")[1] for x in c}
            if len(ks) == 1: sole[next(iter(ks))] += 1
            else: multi += 1
        print("    defects with ONE shard as sole raiser, per shard: %s; raised by 2+ shards: %d" % (dict(sorted(sole.items())), multi))
for x in sorted([x for x in F if x["sev"] == "CRITICAL"], key=lambda x: (ORDER[x["round"]], x["key"], x["fid"])):
    comp = [c for c in DEF[x["round"]] if any(y is x for y in c)][0]
    print("  CRITICAL %s %s %s %s: defect of %d finding(s), files %s, repaired by %s" % (x["round"], x["kind"], x["key"].replace("carry-over-evaluation-", ""), x["fid"], len(comp),
          sorted({y["key"].replace("carry-over-evaluation-", "") + "#" + y["fid"] for y in comp}), sorted({b["rec"] for y in comp for b in y["blocks"]})))
print("  control: per-seat C/M counts sum to the party total: %s" % ("MATCH" if sum(1 for x in F if x["round"] == "party") == sum(1 for s_ in ("pm", "architect", "dev", "tea") for x in F if x["round"] == "party" and x["seat"] == s_) else "DIFFERS"))

# ================================================================ 5 texts each round read (from git) and the classification
TXT = {}
print("\n== TEXTS the rounds read, from the planning-branch commits (each verified against the round's own artifact_sha)")
for name, ref, shx in STATES:
    t = show(ref, DOC) or ""; TXT[name] = t
    print("  %-15s %s %6d B sha256 %s... expected %s: %s" % (name, ref, len(t), sha(t)[:8], shx, "MATCH" if sha(t).startswith(shx) else "DIFFERS"))
hd = collections.Counter()
for rn, d in ADV:
    for f in ls(SHIP, P + "/shards/" + d + "/"):
        if f.endswith(".md") and "/sections/" not in f:
            m = re.search(r"^artifact_sha: (\w{8})", show(SHIP, f) or "", re.M); hd[(rn, m.group(1) if m else None)] += 1
print("  artifact_sha read by each round's shard files: %s" % {"%s:%s" % k: v for k, v in sorted(hd.items(), key=lambda kv: (ORDER[kv[0][0]], str(kv[0][1])))})
print("  control impossible span in ship text: %s (must be False); real span '## Gaps' in ship text: %s" % (PT.IMPOSSIBLE in TXT["ship"], "## Gaps" in TXT["ship"]))
READ = {"elic": "elic read", "p1": "p1 read", "p2": "p2 read", "p3": "p3 read"}
PREV = {"p1": "elic read", "p2": "p1 read", "p3": "p2 read"}
norm = lambda s: re.sub(r"\s+", " ", s)
NT = {k: norm(v) for k, v in TXT.items()}
CLS = collections.OrderedDict()
for x in F:
    rn = x["round"]
    if rn == "party": x["tcls"] = "NOT-MEASURABLE (party-read text not in git)"
    elif rn == "elic": x["tcls"] = "NOT-MEASURABLE (no measurable previous round)"
    else:
        inR = [t for t in sorted(x["ttoks"]) if t in NT[READ[rn]]]
        new = [t for t in inR if t not in NT[PREV[rn]]]; old = [t for t in inR if t in NT[PREV[rn]]]
        x["tcls"] = "NO-TOKEN" if not inR else ("REPAIR-INTRODUCED" if new and not old else ("MIXED" if new else "MISSED-BY-PRIOR"))
        x["old_at_elic"] = bool(inR) and all(t in NT["elic read"] for t in inR)
    x["named"] = bool(REPAIR_NAMED.search(re.sub(r"^#+\s+F-\d+\s+\W+\s*(CRITICAL|MAJOR|MINOR)\s+\W+\s*", "", x["head"]))) if rn in ("p1", "p2", "p3") else None
    x["unique_survived"] = bool(x["status"] == "REPAIRED" and not x["later"] and x["tcls"] not in ("REPAIR-INTRODUCED", "MIXED") and not x["named"])
# survival of each repaired finding's block claim spans at ship
for b in REPAIR:
    sp = PT.claim_spans(b["claim"]); b["spans"] = sp
    b["ship"] = "NO-SPAN" if not sp else ("SHIPPED" if any(s in TXT["ship"] for s in sp) else "GONE")
for x in F:
    st = [b["ship"] for b in x["blocks"]]
    x["fixship"] = "n/a" if x["status"] != "REPAIRED" else ("SHIPPED" if "SHIPPED" in st else ("GONE" if "GONE" in st else "NO-SPAN"))
    x["unique_survived"] = x["unique_survived"] and x["fixship"] == "SHIPPED"

print("\n== s323 CLASSIFICATION of C/M findings, per round x width (population = C/M in that cell)")
print("   columns: C/M | REPAIRED | fix SHIPPED (claim span at ship) | NO-SPAN | GONE | REFOUND by a later round | REFOUND by an earlier round | REFOUND by other width, same round | text class: REPAIR-INTRODUCED / MIXED / MISSED-BY-PRIOR / NO-TOKEN | UNIQUE-SURVIVED")
for rn in RN:
    for kind in ("part", "cross"):
        xs = [x for x in F if x["round"] == rn and x["kind"] == kind]
        if not xs: continue
        tc = collections.Counter(x["tcls"].split(" ")[0] for x in xs)
        other = sum(1 for x in xs if (x["same_cross"] if kind == "part" else x["same_part"]) > 0)
        fs = collections.Counter(x["fixship"] for x in xs)
        print("  %-5s %-5s %3d | %3d | %3d | %2d | %2d | later %3d | earlier %3d | other-width %3d | RI %2d MIXED %2d MBP %2d NOTOK %2d NOTMEAS %2d | UNIQUE-SURVIVED %3d" % (
            rn, kind, len(xs), sum(1 for x in xs if x["status"] == "REPAIRED"), fs["SHIPPED"], fs["NO-SPAN"], fs["GONE"], sum(1 for x in xs if x["later"]), sum(1 for x in xs if x["earlier"]), other,
            tc["REPAIR-INTRODUCED"], tc["MIXED"], tc["MISSED-BY-PRIOR"], tc["NO-TOKEN"], tc["NOT-MEASURABLE"], sum(1 for x in xs if x["unique_survived"])))
print("  control: zero-token findings (width.py rule) %d of %d; zero text-token findings %d (neither can be REFOUND / classified by tokens)" % (
    sum(1 for x in F if not x["toks"]), len(F), sum(1 for x in F if not x["ttoks"])))
for rn in ("p1", "p2", "p3"):
    xs = [x for x in F if x["round"] == rn]
    print("  %s: findings whose in-text tokens were all already in the ELICITATION-read text (existed when elicitation ran): %d of %d" % (rn, sum(1 for x in xs if x["old_at_elic"]), len(xs)))
print("  must-differ control for the text classes: of the p2-read text vs the p1-read text, lines changed = %d (must be > 0 or REPAIR-INTRODUCED cannot occur)" % (
    len(set(TXT["p2 read"].split("\n")) ^ set(TXT["p1 read"].split("\n")))))

print("\n== s323 findings by (round, width), each with its class, fix at ship, and the repair block (head) that carries it: CRITICAL, REPAIR-INTRODUCED, MIXED, NO-BLOCK and GONE rows")
for x in sorted(F, key=lambda x: (ORDER[x["round"]], x["kind"], x["key"], x["fid"])):
    if x["sev"] == "CRITICAL" or x["tcls"].startswith(("REPAIR-INTRODUCED", "MIXED")) or x["status"] != "REPAIRED" or x["fixship"] == "GONE":
        print("  %-5s %-5s %-34s %-5s %-8s %-18s status %-14s fix %-8s later %s | %s" % (x["round"], x["kind"], x["key"].replace("carry-over-evaluation-", ""), x["fid"], x["sev"], x["tcls"].split(" ")[0],
              x["status"], x["fixship"], ",".join(x["later"]) or "-", x["head"][:110]))

# ================================================================ 6 survival floor per repair record
print("\n== SURVIVAL FLOOR per repair record (C/M blocks, disposition repaired): claim spans at the text after the round's repair / at p3-second-link / at ship")
print("   a span absent at the previous round's read text and present at ship is text the repair wrote that shipped; before-text of the party repair is not in git")
AFTER = {"carry-over-evaluation-party-repair-p1.md": "elic read", "coe-elicitation-repair-p1.md": "p1 read", "coe-repair-p1.md": "p1 repaired",
         "coe-serial-repair-p1.md": "p1 repaired", "coe-serial-repair-p1-correction.md": "p2 read", "coe-repair-p2.md": "p3 read",
         "coe-serial-repair-p2.md": "p3 read", "coe-repair-p3.md": "p3 repaired", "coe-repair-p3-second.md": "p3 second link"}
BEFORE = {"coe-elicitation-repair-p1.md": "elic read", "coe-repair-p1.md": "p1 read", "coe-serial-repair-p1.md": "p1 read", "coe-serial-repair-p1-correction.md": "p1 repaired",
          "coe-repair-p2.md": "p2 read", "coe-serial-repair-p2.md": "p2 read", "coe-repair-p3.md": "p3 read", "coe-repair-p3-second.md": "p3 repaired"}
for rn, f, d in RECS:
    bs = [b for b in REPAIR if b["rec"] == f and b["sev"] in ("CRITICAL", "MAJOR") and b["disp"] == "repaired"]
    c = collections.Counter(); new_ship = 0; after = 0
    for b in bs:
        c[b["ship"]] += 1
        if b["spans"] and any(s in TXT[AFTER[f]] for s in b["spans"]): after += 1
        if f in BEFORE and b["spans"] and any(s not in TXT[BEFORE[f]] and s in TXT["ship"] for s in b["spans"]): new_ship += 1
    print("  %-46s C/M repaired blocks %2d: SHIPPED %2d GONE %2d NO-SPAN %2d; a span present at '%s' text: %d%s" % (
        f, len(bs), c["SHIPPED"], c["GONE"], c["NO-SPAN"], AFTER[f], after, ("; absent at '%s' and at ship: %d" % (BEFORE[f], new_ship)) if f in BEFORE else ""))

# ---- REPAIR-INTRODUCED, by the record proxy s322 used, beside the text proxy
print("\n== REPAIR-INTRODUCED, record proxy (a finding token absent from the previous round's read text and present in the previous repair records), beside the text proxy above")
PREVREC = {"p1": ("coe-elicitation-repair-p1.md",), "p2": ("coe-repair-p1.md", "coe-serial-repair-p1.md", "coe-serial-repair-p1-correction.md"),
           "p3": ("coe-repair-p2.md", "coe-serial-repair-p2.md")}
for rn in ("p1", "p2", "p3"):
    xs = [x for x in F if x["round"] == rn]
    prev = "\n".join(RECTEXT[f] for f in PREVREC[rn])
    n = sum(1 for x in xs if any((t not in NT[PREV[rn]]) and t in prev for t in x["ttoks"]))
    print("  %-3s C/M %2d: record-proxy REPAIR-INTRODUCED %2d; text-proxy REPAIR-INTRODUCED %2d, MIXED %2d" % (rn, len(xs), n,
          sum(1 for x in xs if x["tcls"].startswith("REPAIR-INTRODUCED")), sum(1 for x in xs if x["tcls"].startswith("MIXED"))))

print("\n== p1/p2/p3 C/M findings read one by one: text class, whether the finding's own title names a repair (REPAIR-NAMED), status, fix at ship, later-round overlap")
for x in sorted([x for x in F if x["round"] in ("p1", "p2", "p3")], key=lambda x: (ORDER[x["round"]], x["kind"], x["key"], x["fid"])):
    print("  %-3s %-5s %-12s %-4s text %-17s named %-5s %-9s fix %-7s later %-4s | %s" % (x["round"], x["kind"], x["key"].split("/")[1], x["fid"], x["tcls"].split(" ")[0], x["named"], x["status"], x["fixship"], ",".join(x["later"]) or "-", x["head"][x["head"].find("MAJOR") + 8:][:112]))
for rn in ("p1", "p2", "p3"):
    xs = [x for x in F if x["round"] == rn]
    print("  %s: C/M %d, REPAIR-NAMED %d (control: a title naming a repair in p1 means the p1-read text already held an earlier repair; the elicitation repair is the only one before it)" % (rn, len(xs), sum(1 for x in xs if x["named"])))

print("\n== repair claims whose spans are NOT at ship (fix GONE): state where each span is present, in order elic read, p1 read, p1 repaired, p2 read, p3 read, p3 repaired, p3 second link, ship")
for x in sorted([x for x in F if x["fixship"] == "GONE"], key=lambda x: (ORDER[x["round"]], x["key"], x["fid"])):
    print("  %s %s %s %s: %s" % (x["round"], x["kind"], x["key"].replace("carry-over-evaluation-", ""), x["fid"], x["head"][:100]))
    for b in x["blocks"]:
        if b["ship"] != "GONE": continue
        print("     block %s %s (%s)" % (b["rec"], b["head"][:60], b["disp"]))
        for sp_ in b["spans"][:4]:
            print("       span %-70r in states %s" % (sp_[:70], "".join("1" if sp_ in TXT[n] else "0" for n, _, _ in STATES)))

print("\n== YIELD PER DOLLAR, s323 (spawn dollars of the part and cross rows of each round from the partition above; C/M from the heading parse)")
YM = [("party", "party part (4 seats x 6)", "party cross (4 seats)"), ("elic", "elicitation part (4 shards)", "elicitation cross (1 agent)"),
      ("p1", "adv p1 part (3 shards)", "adv p1 cross"), ("p2", "adv p2 part (4 shards)", "adv p2 cross"), ("p3", "adv p3 part (3 shards)", "adv p3 cross")]
for rn, pn, cn in YM:
    for kind, nm in (("part", pn), ("cross", cn)):
        c = A323[nm]; k = sum(1 for x in F if x["round"] == rn and x["kind"] == kind)
        print("  %-5s %-5s %2d spawns $%6.2f %6.1f agent-min   C/M %3d  $%s per C/M" % (rn, kind, c[0], c[1], c[2], k, ("%.2f" % (c[1] / k)) if k else "n/a (0 C/M)"))
for rn, names in (("party", ("party repair, section shards", "party repair, serial after assembly")), ("elic", ("elicitation repair, section shards", "elicitation repair, serial")),
                  ("p1", ("adv p1 repair, section shards", "adv p1 repair, adjudicator lanes + serial", "operator-decision closer correction")),
                  ("p2", ("adv p2 repair, section shards", "adv p2 repair, serial lane + record fixes")), ("p3", ("adv p3 repair + step 4a record",))):
    c = sub(A323, *names); k = sum(1 for x in F if x["round"] == rn)
    print("  %-5s repair %2d spawns $%6.2f %6.1f agent-min   repairs the round's %3d C/M findings" % (rn, c[0], c[1], c[2], k))
rt = sub(A323, "route: live reads and read-only checks", "route: adjudication and closure remediators", "route: fold answered OQs into requirements", "party dispatcher", "analyst draft")
print("  routing, dispatcher, draft and adjudication/closure rows: %d spawns $%.2f %.1f agent-min" % rt)

# ================================================================ 7 gate label
print("\n== GATE LABEL %s" % GLABEL)
for sp in (323, 322, 319):
    s = [x for x in rows if int(x["sprint"]) == sp and x["step"] == GLABEL]
    n, usd, mins, _ = B.agg(rows, sp, {GLABEL})
    print("  s%d: %d spawns $%.2f %.1f agent-min ($%.2f per story)" % (sp, n, usd, sum(x["minutes"] or 0 for x in s), usd / {323: 18, 322: 8, 319: 20}[sp]))
    kinds = collections.Counter(re.sub(r"\d+/\d+", "N/N", x["description"]) for x in s)
    for k, v in sorted(kinds.items()):
        print("      %-34s %2d spawns $%.2f" % (k, v, sum(x["usd"] for x in s if re.sub(r"\d+/\d+", "N/N", x["description"]) == k)))
s = sorted([x for x in rows if int(x["sprint"]) == 323 and x["step"] == GLABEL], key=lambda x: x["start"])
print("  s323 spawn windows: %s" % "; ".join("%s %s" % (x["start"][:19], x["description"]) for x in s))
verd = collections.Counter(("FAIL" if re.search(r"\bjudged (it )?FAIL\b", x.get("final_text") or "") else "no FAIL") for x in s)
print("  s323 final_text 'judged FAIL' reads: %s (control: 'judged' absent token reads %d)" % (dict(verd), sum(1 for x in s if "QZXV-NO-SUCH-TOKEN" in (x.get("final_text") or ""))))
VF = [f for f in ls(GLOG_REF, "_bmad-output/implementation-artifacts/s323/gate-adjudication/") if f.endswith(".verdict.json")]
lo = s[0]["start"][:19] if s else ""
print("  verdict files at %s: %d; the label's own gate is the one whose generated_at lies within an hour after its last spawn start" % (GLOG_REF, len(VF)))
own = []
for f in VF:
    V = json.loads(show(GLOG_REF, f))
    c = collections.Counter(v["verdict"] for v in V["verdicts"])
    mine = bool(s) and V["generated_at"] >= s[0]["start"][:19] + "Z" and V["generated_at"] <= (s[-1]["start"][:13] + ":59:59Z") and V["gate_type"] == "planning"
    if mine: own.append((f, V))
    print("    %-58s %-12s generated %s checks %d %s %s" % (os.path.basename(f), V["gate_type"], V["generated_at"], len(V["verdicts"]), dict(sorted(c.items())), "<- this label" if mine else ""))
print("  control: impossible verdict file in listing: %s (must be False); files for this label %d (must be 1)" % (any("QZXV" in f for f in VF), len(own)))
for f, V in own:
    nonpass = [v for v in V["verdicts"] if v["verdict"] != "PASS"]
    print("  %s: %d checks, non-PASS %d; adjudicators %s; check ids %s" % (os.path.basename(f), len(V["verdicts"]), len(nonpass), V["adjudicator_agent_id"], ",".join(v["check_id"] for v in V["verdicts"])))
GR = show(GLOG_REF, P + "/gate-planning-repair-p1.md") or ""
print("  FAIL record gate-planning-repair-p1.md: found %s; heading '### Check 2 — script arm': %s; disposition repaired: %s; seal repair-complete line: %s" % (
    bool(GR), "### Check 2 — script arm" in GR, "- disposition: repaired" in GR, bool(re.search(r"^repair-complete:", GR, re.M))))
m = re.search(r"^- source: (.*)$", GR, re.M); print("  what failed: %s" % (m.group(1)[:230] if m else "NOT FOUND"))
PEND = show(SHIP, "docs/escalations/pending.md") or ""
pl = PEND.split("\n")
print("  pending.md at ship: line 1051 reads %r; line 5490 reads %r; no 'Status:** CLOSED — RATIFIED' / 'Status:** DISPOSITIONED 2026-11-13' anywhere: %s (control: present token 'Status:** RESOLVED' count %d; impossible token count %d)" % (
    pl[1050][:48], pl[5489][:48], "Status:** CLOSED — RATIFIED" not in PEND and "Status:** DISPOSITIONED 2026-11-13" not in PEND, PEND.count("Status:** RESOLVED"), PEND.count("QZXV-NO-SUCH-STATUS")))
GL = show(GLOG_REF, "_bmad-output/implementation-artifacts/s323/gate-log-archive.md") or ""
i0 = GL.find("nonce: planning-20261117T025438Z"); seg = GL[i0:i0 + 40000]
print("  gate-log-archive planning entry for the label's gate: found %s; hard_block_fail false: %s; rows PASSED %d, NA %d, SKIPPED %d (rows read within the entry up to the next 'Gate Log' heading)" % (
    i0 >= 0, "hard_block_fail: false" in seg, *(len(re.findall(r"\| %s" % k, seg.split("## Gate Log")[0])) for k in ("PASSED", "NA", "SKIPPED"))))
hs = re.findall(r"^## Gate Log: Sprint 323 — (.*?)$\n(?:.*\n){0,3}?Gate: (\w[\w-]*) \| variant: [\w-]+ \| nonce: (\S+)", GL, re.M)
print("  s323 gate-log-archive entries (heading, gate, nonce): %s; the label's nonce appears in %d entry heading(s) (must be 1)" % ([(h[0][:48], h[1], h[2]) for h in hs], sum(1 for h in hs if h[2] == "planning-20261117T025438Z")))
print("  disclosure in the entry (a post-p3 edit no adversary read): %s" % ("DISCLOSURE: the §4a recurrence cross-check bullet" in seg))
