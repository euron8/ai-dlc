"""Per-pass cost and the mechanical arms of the step-value classification for s321 stories adversarial passes p1 to p3 (BL-812).

usage: python3 adversarial_yield.py <OUT dir holding spawns.jsonl> [<graph repo>] [--ref <graph ref>] [--elicitation-doc <path>]

Read-only: `git show` of committed graph files at pinned refs, and <OUT>/spawns.jsonl. Writes nothing.

This is the MECHANICAL half of docs/analysis/step-value-stories-adversarial-s321.md, built on the method of
docs/analysis/step-value-stories-elicitation-s321.md:
  cost       every stories-test-strategy spawn of s321 whose description names a stories adversarial pass shard ("Pass N
             [cross ]shard") or its repair ("Repair pN", "Serial lane", "Fan-in serial remediator pass N", "Serial
             remediator pass N"), assigned to a pass by description AND by the round epochs in rounds/*.return; the two
             assignments must agree.
  findings   every `### ` heading carrying the whole word CRITICAL or MAJOR in shards/stories-pN/*.md.
  join       every repair block (a `### ` section of a repair record) whose `- source:` names the finding.
  token arm  the `grep -c -F` tokens of the joined blocks: in the story at the stories gate (41484a513), and how many were
             already in the text the pass read.
  deletion   (sensitivity only) the `grep -rn -F` sibling tokens of the joined blocks: present in the read text, absent at
             the gate.
  span arm   every backtick or double-quoted span of 12+ characters in the finding body that occurs in the read text, and
             the earliest text state that carries each; origin = the repair that wrote every such span.
REFOUND and the attribution reading are manual and live in the document, not here.

Controls printed in the same run (each must read MATCH or the run says DIFFERS):
  - the step's s321 total (428 spawns, $589.64: BL-812's 17.12 spawns and $23.59 per story over 25 stories);
  - the s321 elicitation cells the committed elicitation document records ($111.55 per-story, $11.33 cross);
  - C/M per pass against the counts the lead wrote into rounds/stories-repair-pN.return;
  - the token and span arms re-run on the ELICITATION population, compared row by row with the committed evidence column
    of step-value-stories-elicitation-s321.md;
  - an impossible description token and an impossible finding token, each must count 0.
"""
import hashlib, json, os, re, subprocess, sys

G_DEFAULT = os.path.expanduser("~/git/graph")
REF_DEFAULT = "da6cadadd"
P = "_bmad-output/planning-artifacts/s321"
SD = P + "/stories"
SHIP = "41484a513"            # "gate story passed": the stories gate
STATES = [                    # text states, oldest first: (ref, the event that wrote it)
    ("01f3925ec", "authored"),
    ("c3c00660f", "readiness fold"),
    ("e6f964de8", "party repair"),
    ("6509c26b2", "elicitation repair"),
    ("9671dbb93", "p1+p2 repair"),
]
READ = {"stories-elicitation": "e6f964de8", "stories-p1": "6509c26b2", "stories-p2": "9671dbb93", "stories-p3": "9671dbb93"}
NOTE_P2 = "p2 read the p1-repair output, which no commit carries; 9671dbb93 (post-p2 repair) is its proxy"
HEAD = re.compile(r"^### .*\b(CRITICAL|MAJOR)\b")
STORIES = 25
IMPOSSIBLE = "QZXV-NO-SUCH-TOKEN-7731"

def git(g, *a):
    return subprocess.run(["git", "-C", g] + list(a), capture_output=True, check=True).stdout.decode("utf-8", "replace")

class Tree:
    def __init__(self, g):
        self.g = g; self.cache = {}
    def stories(self, ref):
        if ref not in self.cache:
            names = [n for n in git(self.g, "ls-tree", "--name-only", ref, SD + "/").split("\n") if n.endswith(".md")]
            self.cache[ref] = {os.path.basename(n): git(self.g, "show", "%s:%s" % (ref, n)) for n in names}
        return self.cache[ref]
    def files(self, ref, d):
        names = [n for n in git(self.g, "ls-tree", "--name-only", ref, d + "/").split("\n") if n.endswith(".md")]
        return {os.path.basename(n): git(self.g, "show", "%s:%s" % (ref, n)) for n in names}
    def show(self, ref, path):
        return git(self.g, "show", "%s:%s" % (ref, path))

# ---------- cost ----------
PASS_RE = re.compile(r"^Pass (\d) (cross )?shard(?: (\d+))?")
REPAIR_RE = [re.compile(r"^Repair p(\d) "), re.compile(r"^Fan-in serial remediator pass (\d)"), re.compile(r"^Serial remediator pass (\d)")]
LANE_RE = re.compile(r"^Serial lane \d+ \(story")

def epochs(tree, ref):
    e = {}
    for k in ("stories-p1", "stories-p2", "stories-p3"):
        t = tree.show(ref, "%s/rounds/%s.return" % (P, k))
        e[k] = re.search(r"epoch: (\S+?)Z", t).group(1)
    return e

def cost(rows, ep):
    s = [r for r in rows if int(r["sprint"]) == 321 and r["step"] == "stories-test-strategy"]
    tot = (len(s), sum(r.get("usd") or 0 for r in s))
    licit = {"per-story": 0.0, "cross": 0.0}
    for r in s:
        d = r.get("description") or ""
        if r["role"] == "adversary" and "licit" in d:
            licit["cross" if "cross" in d.lower() else "per-story"] += r.get("usd") or 0
    w = [ep["stories-p1"], ep["stories-p2"], ep["stories-p3"], "2026-11-04T19:54:00"]  # p3 window ends at the TEA test-strategy spawn
    def by_window(t):
        for i in range(3):
            if w[i] <= t < w[i + 1]: return i + 1
        return None
    out = {}; disagree = []; shard_usd = {}; shard_min = {}; iv = {}
    for r in s:
        d = r.get("description") or ""; t = r["start"][:19]
        m = PASS_RE.match(d); kind = None; pd = None
        if m:
            kind = "adversary"; pd = int(m.group(1))
            key = "cross.md" if m.group(2) else "%02d.md" % int(m.group(3))
            shard_usd.setdefault(pd, {}).setdefault(key, 0.0)
            shard_usd[pd][key] += r.get("usd") or 0
            shard_min.setdefault(pd, {}).setdefault(key, 0.0)
            shard_min[pd][key] += r.get("minutes") or 0
        else:
            for rx in REPAIR_RE:
                mm = rx.match(d)
                if mm: kind = "repair"; pd = int(mm.group(1)); break
            if kind is None and LANE_RE.match(d):
                kind = "repair"; pd = by_window(t)       # lane rows carry no pass number
        if kind is None: continue
        pw = by_window(t)
        if pw != pd: disagree.append((d, pd, pw))
        iv.setdefault(pd, []).append((r["start"][:19], r["end"][:19]))
        o = out.setdefault((pd, kind), [0, 0.0, set()])
        o[0] += 1; o[1] += r.get("usd") or 0; o[2].add(r.get("model_ran"))
    imp = sum(1 for r in rows if IMPOSSIBLE in (r.get("description") or ""))
    return tot, licit, out, disagree, shard_usd, imp, shard_min, iv

# The step's s321 spawns, partitioned by description; first matching part wins. The parts must sum to the step total.
PARTS_321 = [
    ("stories adversarial p1-p3 + repairs", r"^(Pass \d (cross )?shard|Repair p\d |Serial lane \d+ \(story|Fan-in serial remediator pass \d|Serial remediator pass \d)"),
    ("elicitation + repair", r"licit"),
    ("party round + repair", r"^(Run stories party|(sm|dev|architect|tea) (cross|\d+)$|Story party repair|Lane \d+ serial remediator|Fan-in serial remediator$)"),
    ("test strategy authoring, passes p1-p6 + repairs", r"^(TEA|TS |Adversary p\d|Serial lane repair p|Serial remediator, test-strategy)"),
    ("authoring, readiness, amendments", r"^(Readiness|PM |Architect |Author story|Test framework|Architecture amendment)"),
]
# s319's stories adversarial passes, in the same step (sprint-specific descriptions; s319 ran p1 and p2 only)
S319_ADV = (r"^(Adversary p\d (shard|cross)|Pass \d (adversary|cross) shard)", r"^(Repair p\d part|Serial remediator pass \d repair)")

S319_STEP = (311, 441.19)     # the step total the author read for s319 (spawns, dollars); re-derived by the control below

def s319_step(rows):
    s = [r for r in rows if int(r["sprint"]) == 319 and r["step"] == "stories-test-strategy"]
    models = {}
    for r in s:
        d = r.get("description") or ""
        k = "adversary" if re.search(S319_ADV[0], d) else ("repair" if re.search(S319_ADV[1], d) else None)
        if k: models.setdefault(k, set()).add(r.get("model_ran"))
    return (len(s), sum(r.get("usd") or 0 for r in s)), models

def idle(ivs):
    """first start, last end (minutes between) and the longest stretch with no spawn running, over [(start, end)] ISO strings."""
    import datetime as dt
    f = lambda x: dt.datetime.strptime(x, "%Y-%m-%dT%H:%M:%S")
    ivs = sorted((f(a), f(b)) for a, b in ivs)
    cur = ivs[0][1]; gap = 0.0
    for a, b in ivs:
        if a > cur: gap = max(gap, (a - cur).total_seconds() / 60)
        cur = max(cur, b)
    return ivs[0][0], cur, (cur - ivs[0][0]).total_seconds() / 60, gap

def partition(rows):
    s = [r for r in rows if int(r["sprint"]) == 321 and r["step"] == "stories-test-strategy"]
    acc = {}
    for r in s:
        d = r.get("description") or ""; name = "other"
        for n, rx in PARTS_321:
            if re.search(rx, d): name = n; break
        a = acc.setdefault(name, [0, 0.0]); a[0] += 1; a[1] += r.get("usd") or 0
    return acc

def s319_adv(rows):
    s = [r for r in rows if int(r["sprint"]) == 319 and r["step"] == "stories-test-strategy"]
    a = [0, 0.0]; rp = [0, 0.0]
    for r in s:
        d = r.get("description") or ""
        if re.search(S319_ADV[0], d): a[0] += 1; a[1] += r.get("usd") or 0
        elif re.search(S319_ADV[1], d): rp[0] += 1; rp[1] += r.get("usd") or 0
    return a, rp

# ---------- findings and repair blocks ----------
def sections(text):
    """yield (heading line, body) for every ### section; a body ends at the next #, ## or ### heading."""
    lines = text.split("\n"); i = 0
    while i < len(lines):
        if lines[i].startswith("### "):
            j = i + 1
            while j < len(lines) and not re.match(r"^#{1,3} ", lines[j]): j += 1
            yield lines[i], "\n".join(lines[i + 1:j]); i = j
        else:
            i += 1

def fid(head):
    m = re.search(r"\b([EF]-\d+[a-z]?)\b", head)
    return m.group(1) if m else "(no id) " + re.sub(r"^### .*?(CRITICAL|MAJOR)\S*\s*[—:-]*\s*", "", head)[:22]

def norm_src(s):
    m = re.match(r"([\w-]+)/0*(\d+|cross)\.md#(\S+)", s)
    return (m.group(1), m.group(2), m.group(3)) if m else None

def repair_blocks(tree, ref, files):
    blocks = []
    for path in files:
        try:
            t = tree.show(ref, path)
        except subprocess.CalledProcessError:
            continue
        for head, body in sections(t):
            src = re.findall(r"^- source: (.+)$", body, re.M)
            keys = [k for line in src for k in (norm_src(x) for x in line.split()) if k]
            keys += [("raw", line) for line in src]
            blocks.append((path, head, body, keys))
    return blocks

TOK_C = re.compile(r"grep -c -F (?:-e )?(?:'([^']*)'|\"([^\"]*)\")\s+(\S+)")
TOK_RN = re.compile(r"grep -rn -F (?:-e )?(?:'([^']*)'|\"([^\"]*)\")\s+(\S+)")

def toks(body, rx):
    return [((m.group(1) if m.group(1) is not None else m.group(2)), m.group(3)) for m in rx.finditer(body)]

def present(tree, ref, tok, path, story_of_finding):
    st = tree.stories(ref)
    b = os.path.basename(path)
    if b.startswith("story-") and b.endswith(".md"):
        return tok in st.get(b, "")
    return any(tok in v for v in st.values())

def joins(b, key, head):
    if key in b[3]:
        return True
    if not key[2].startswith("(no id)"):
        return False
    pre = "%s/%s.md#" % (key[0], key[1].zfill(2) if key[1] != "cross" else key[1])
    return any(k[0] == "raw" and k[1].startswith(pre) and head[4:].startswith(k[1][len(pre):].strip()) for k in b[3])

def token_arm(tree, blocks, key, read_ref, story, head=""):
    jb = [b for b in blocks if joins(b, key, head)]
    ct = [(t, p) for b in jb for (t, p) in toks(b[2], TOK_C)]
    story_t = [(t, p) for (t, p) in ct if "/stories/story-" in p and p.endswith(".md")]
    use = story_t or ct
    use = list(dict.fromkeys(use))
    shipped = sum(1 for t, p in use if present(tree, SHIP, t, p, story))
    already = sum(1 for t, p in use if present(tree, read_ref, t, p, story))
    rn = list(dict.fromkeys((t, p) for b in jb for (t, p) in toks(b[2], TOK_RN)))
    dels = [(t, p) for (t, p) in rn if present(tree, read_ref, t, p, story)]
    dels_gone = sum(1 for t, p in dels if not present(tree, SHIP, t, p, story))
    return len(jb), len(use), shipped, already, len(dels), dels_gone

SPAN = re.compile(r"`([^`\n]{12,})`|\"([^\"\n]{12,})\"")

def span_arm(tree, body, story, read_ref, prior_states):
    spans = [m.group(1) or m.group(2) for m in SPAN.finditer(body)]
    rd = tree.stories(read_ref).get(story, "")
    inread = [s for s in spans if s in rd]
    first = []
    for s in inread:
        f = None
        for ref, ev in prior_states:
            if s in tree.stories(ref).get(story, ""):
                f = ev; break
        first.append(f)
    return inread, first

def story_of(shard_text):
    m = re.search(r"^artifact: (\S+)", shard_text, re.M)
    return os.path.basename(m.group(1)) if m else None

def main():
    argv = list(sys.argv); ref = REF_DEFAULT
    edoc = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "step-value-stories-elicitation-s321.md")
    if "--ref" in argv:
        i = argv.index("--ref"); ref = argv[i + 1]; del argv[i:i + 2]
    if "--elicitation-doc" in argv:
        i = argv.index("--elicitation-doc"); edoc = argv[i + 1]; del argv[i:i + 2]
    if len(argv) < 2:
        sys.exit(__doc__)
    out = argv[1]; g = argv[2] if len(argv) > 2 else G_DEFAULT
    tree = Tree(g)
    rows = [json.loads(l) for l in open(os.path.join(out, "spawns.jsonl"))]
    ep = epochs(tree, ref)

    # ---- cost
    tot, licit, cst, disagree, shard_usd, imp, shard_min, iv = cost(rows, ep)
    print("== cost (s321, step stories-test-strategy, spawns.jsonl)")
    print("control step total: %d spawns $%.2f (%.2f and $%.2f per story)  | BL-812: 17.12 and $23.59  %s" % (
        tot[0], tot[1], tot[0] / STORIES, tot[1] / STORIES,
        "MATCH" if abs(tot[0] / STORIES - 17.12) < 0.005 and abs(tot[1] / STORIES - 23.59) < 0.005 else "DIFFERS"))
    for t, want in (("per-story", 111.55), ("cross", 11.33)):
        print("control elicitation %s adversary $%.2f  | elicitation doc $%.2f  %s" % (t, licit[t], want, "MATCH" if abs(licit[t] - want) < 0.005 else "DIFFERS"))
    print("control impossible description token %r: %d rows (must be 0)" % (IMPOSSIBLE, imp))
    print("control description-vs-epoch pass assignment: %d disagreements (must be 0) %s" % (len(disagree), disagree[:3]))
    print("epochs:", ep)
    for p in (1, 2, 3):
        a = cst.get((p, "adversary"), [0, 0, set()]); r = cst.get((p, "repair"), [0, 0, set()])
        print("p%d adversary %2d spawns $%6.2f %s | repair %2d spawns $%6.2f %s | pass+repair %2d $%6.2f" % (
            p, a[0], a[1], sorted(map(str, a[2])), r[0], r[1], sorted(map(str, r[2])), a[0] + r[0], a[1] + r[1]))
    allp = [sum(cst.get((p, k), [0, 0])[i] for p in (1, 2, 3) for k in ("adversary", "repair")) for i in (0, 1)]
    print("p1-p3 with repairs: %d spawns $%.2f, %.2f spawns and $%.2f per story (25)" % (allp[0], allp[1], allp[0] / STORIES, allp[1] / STORIES))
    a, rp = s319_adv(rows)
    print("s319 stories adversarial p1-p2 with repairs (same step): adversary %d $%.2f, repair %d $%.2f; %d spawns $%.2f, %.2f and $%.2f per story (20)" % (
        a[0], a[1], rp[0], rp[1], a[0] + rp[0], a[1] + rp[1], (a[0] + rp[0]) / 20, (a[1] + rp[1]) / 20))
    (n319, u319), m319 = s319_step(rows)
    print("control s319 step total: %d spawns $%.2f | author read %d spawns $%.2f  %s" % (
        n319, u319, S319_STEP[0], S319_STEP[1], "MATCH" if n319 == S319_STEP[0] and abs(u319 - S319_STEP[1]) < 0.005 else "DIFFERS"))
    print("s319 adversarial/repair spawns model_ran: %s (s321 pass spawns: %s)" % (
        {k: sorted(map(str, v)) for k, v in m319.items()}, sorted(set(str(m) for v in cst.values() for m in v[2]))))
    wend = {1: ep["stories-p2"], 2: ep["stories-p3"], 3: "2026-11-04T19:54:00"}
    for p in (1, 2, 3):
        a0, a1, span, gap = idle(iv[p])
        wall = (__import__("datetime").datetime.strptime(wend[p], "%Y-%m-%dT%H:%M:%S") - __import__("datetime").datetime.strptime(ep["stories-p%d" % p], "%Y-%m-%dT%H:%M:%S")).total_seconds() / 60
        print("p%d wall clock %.1f min (round epoch to the next); spawn activity %s..%s = %.1f min, longest stretch with no spawn running %.2f min" % (p, wall, a0.time(), a1.time(), span, gap))
    acc = partition(rows); sn = sum(v[0] for v in acc.values()); su = sum(v[1] for v in acc.values())
    print("partition of the s321 step (first match wins):")
    for n, v in sorted(acc.items(), key=lambda x: -x[1][1]):
        print("   %-48s %3d spawns $%7.2f  $%.2f per story" % (n, v[0], v[1], v[1] / STORIES))
    print("control partition sum: %d spawns $%.2f against the step total %d $%.2f  %s" % (
        sn, su, tot[0], tot[1], "MATCH" if sn == tot[0] and abs(su - tot[1]) < 0.005 else "DIFFERS"))
    sa = acc.get("stories adversarial p1-p3 + repairs", [0, 0])
    print("control partition adversarial part against the per-pass sum: %d $%.2f vs %d $%.2f  %s" % (
        sa[0], sa[1], allp[0], allp[1], "MATCH" if sa[0] == allp[0] and abs(sa[1] - allp[1]) < 0.005 else "DIFFERS"))

    # ---- findings
    rec = {}
    for k in ("stories-repair-p1", "stories-repair-p2", "stories-repair-p3"):
        t = tree.show(ref, "%s/rounds/%s.return" % (P, k))
        m = re.search(r"repairing pass \d: (?:EXIT_CONDITION_MET with )?(\d+) CRITICAL, (\d+) (?:blocking )?MAJOR", t)
        m2 = re.search(r"repairing pass \d: (?:EXIT_CONDITION_MET with )?(\d+) blocking MAJOR, (\d+) CRITICAL", t)
        rec[k[-2:]] = (int(m.group(1)) + int(m.group(2))) if m else ((int(m2.group(1)) + int(m2.group(2))) if m2 else None)
    blocks = repair_blocks(tree, ref, [
        P + "/stories-repair-p1.md", P + "/stories-repair-p2.md", P + "/stories-repair-p3.md", P + "/stories-serial-repair-p1.md"]
        + [P + "/shards/stories-serial-repair-p1/" + f for f in tree.files(ref, P + "/shards/stories-serial-repair-p1")])
    eblocks = repair_blocks(tree, ref, [P + "/stories-elicitation-serial-repair-p1.md"]
        + [P + "/shards/stories-elicitation-repair-p1/" + f for f in tree.files(ref, P + "/shards/stories-elicitation-repair-p1")])

    prev_sha = None; total = 0; joined = 0; reread = [0, 0.0, 0.0]
    print("\n== findings (C/M) per pass; read text, unchanged shards")
    allrows = []
    for p in (1, 2, 3):
        d = "stories-p%d" % p
        sh = tree.files(ref, P + "/shards/" + d)
        shas = {f: (re.search(r"^artifact_sha: (\S+)", t, re.M) or [None, None])[1] for f, t in sh.items()}
        cm = 0; crit = 0
        for f in sorted(sh):
            for head, body in sections(sh[f]):
                if HEAD.match(head):
                    cm += 1; crit += bool(re.search(r"\bCRITICAL\b", head))
                    allrows.append((p, f, head, body, story_of(sh[f])))
        imp_f = sum(t.count(IMPOSSIBLE) for t in sh.values())
        rd = tree.stories(READ[d]); hits = sum(1 for f, t in sh.items() if story_of(t) and hashlib.sha256(rd.get(story_of(t), "").encode()).hexdigest() == shas[f])
        line = "p%d shards %d C/M %d (CRITICAL %d) | rounds/stories-repair-p%d.return %s %s | impossible token %d | artifact_sha == story at %s: %d of %d" % (
            p, len(sh), cm, crit, p, rec.get("p%d" % p), "MATCH" if rec.get("p%d" % p) == cm else "DIFFERS", imp_f, READ[d], hits, len(sh) - 1)
        print(line)
        if prev_sha:
            same = [f for f in sh if f != "cross.md" and shas.get(f) and shas.get(f) == prev_sha.get(f)]
            u = sum(shard_usd.get(p, {}).get(f, 0) for f in same)
            cmu = sum(1 for r in allrows if r[0] == p and r[1] in same)
            um = sum(shard_min.get(p, {}).get(f, 0) for f in same)
            reread[0] += len(same); reread[1] += u; reread[2] += um
            print("   p%d shards reading the same story bytes as p%d did: %d of 25, $%.2f, %.2f spawn-hours (sum of spawn minutes), C/M %d" % (p, p - 1, len(same), u, um / 60, cmu))
        prev_sha = shas
    print("   " + NOTE_P2)
    print("   re-read total, p2 + p3: %d shard reads, $%.2f, %.2f spawn-hours (sum of the spawns' own minutes, not wall clock)" % (reread[0], reread[1], reread[2] / 60))
    # p2 and p3 C/M on the native-spend bound = stories 2.3 and 2.4 = shards 09.md and 10.md
    pq = [r for r in allrows if r[0] in (2, 3)]
    ns = [r for r in pq if r[1] in ("09.md", "10.md")]
    print("p2+p3 C/M: %d; in shards 09.md and 10.md (stories 2.3 and 2.4, the native-spend bound): %d; the rest: %s" % (
        len(pq), len(ns), [(r[0], r[1], fid(r[2]), r[4]) for r in pq if r not in ns]))
    # hash chain: p1 repair part `artifact_sha_after` against the p2 shard's `artifact_sha`, per story file
    rp1 = tree.show(ref, P + "/stories-repair-p1.md")
    after = {}
    for blk in re.split(r"<!-- shard: \S+ -->", rp1)[1:]:
        ma = re.search(r"^- artifact: (\S+)", blk, re.M); mb = re.search(r"^- artifact_sha_after: (\S+)", blk, re.M)
        if ma and mb: after[os.path.basename(ma.group(1))] = mb.group(1)
    # the serial remainder (stories-serial-repair-p1.md and its lane records) re-edits some stories after their part
    ser = {}
    for sp in [P + "/stories-serial-repair-p1.md"] + [P + "/shards/stories-serial-repair-p1/" + f for f in tree.files(ref, P + "/shards/stories-serial-repair-p1")]:
        for m in re.finditer(r"^- artifact: (\S+)\n- artifact_sha_before: (\S+)\n- artifact_sha_after: (\S+)", tree.show(ref, sp), re.M):
            ser.setdefault(os.path.basename(m.group(1)), set()).add((m.group(2), m.group(3)))
    p2sh = tree.files(ref, P + "/shards/stories-p2")
    chain = 0; via = 0
    for f, t in p2sh.items():
        st = story_of(t); sha = (re.search(r"^artifact_sha: (\S+)", t, re.M) or [None, None])[1]
        if st not in after: continue
        if after[st] == sha: chain += 1
        elif any(b0 == after[st] and a0 == sha for b0, a0 in ser.get(st, ())): via += 1
    print("hash chain: p1 repair parts %d; p2 shards whose artifact_sha equals the part's artifact_sha_after: %d; equals the serial remainder's artifact_sha_after, whose before is the part's after: %d; total %d" % (len(after), chain, via, chain + via))
    for c in ("0b8f86e0b", "a92c1be3d", "04cf4a2f8"):
        ns_ = git(g, "show", "--numstat", "--format=", c, "--", SD).split("\n"); ns_ = [x.split("\t") for x in ns_ if x.strip()]
        print("commit %s on stories/: %d files, %d insertions, %d deletions" % (c, len(ns_), sum(int(x[0]) for x in ns_), sum(int(x[1]) for x in ns_)))
    after_p3 = [x for x in git(g, "log", "--format=%h", "169208e5b..%s" % SHIP, "--", SD).split() if x]
    print("commits editing stories/ after the p3 repair (169208e5b) up to %s: %d %s" % (SHIP, len(after_p3), after_p3))

    print("\n== per finding: join, token arm (at %s; already = in the read text), deletion arm, span arm (first state carrying each read-text span)" % SHIP)
    for p, f, head, body, story in allrows:
        key = ("stories-p%d" % p, re.sub(r"^0+", "", f[:-3]) or f[:-3], fid(head))
        nb, n, shipped, already, nd, dg = token_arm(tree, blocks, key, READ["stories-p%d" % p], story, head)
        total += 1; joined += nb > 0
        prior = [s for s in STATES if s[0] != READ["stories-p%d" % p]][: [s[0] for s in STATES].index(READ["stories-p%d" % p])]
        inread, first = span_arm(tree, body, story, READ["stories-p%d" % p], prior + [(READ["stories-p%d" % p], "read text")])
        print("p%d %-8s %-6s blocks %d | tokens %d/%d shipped, %d in read | del %d/%d gone | spans %d first: %s | %s" % (
            p, f, key[2], nb, shipped, n, already, dg, nd, len(inread), ",".join(str(x) for x in first), head[4:110]))
    s1 = 9; a1 = cst.get((1, "adversary"), [0, 0])[1]
    print("p1 $ per survivor by survivor count: %s" % ", ".join("%d: $%.2f" % (k, a1 / k) for k in (8, 9, 10, 11)))
    print("control join: %d of %d findings join at least one repair block (must be all)" % (joined, total))

    # ---- arm control on the elicitation population
    print("\n== arm control: elicitation population vs the committed evidence column of %s" % os.path.basename(edoc))
    doc = open(edoc).read()
    esh = tree.files(ref, P + "/shards/stories-elicitation")
    agree = 0; n = 0; diff = []
    for f in sorted(esh):
        if f == "cross.md": continue
        story = story_of(esh[f])
        for head, body in sections(esh[f]):
            if not HEAD.match(head): continue
            i = fid(head)
            m = re.search(r"^\| [^|]+ \| `%s` \| %s \|[^\n]*\| (\S+) \| ([^\n]*) \|$" % (re.escape(f), re.escape(i)), doc, re.M)
            if not m: continue
            cls, ev = m.group(1), m.group(2)
            mt = re.search(r": (\d+)/(\d+) tokens in `stories/` at 41484a513(?:, (\d+) at e6f964de8)?", ev)
            ms = re.search(r"span arm: (\d+)/(\d+) quoted spans", ev)
            if mt:
                _, nn, sh_, al, _, _ = token_arm(tree, eblocks, ("stories-elicitation", re.sub(r"^0+", "", f[:-3]), i), "e6f964de8", story, head)
                n += 1; ok = (sh_, nn) == (int(mt.group(1)), int(mt.group(2))) and (mt.group(3) is None or al == int(mt.group(3)))
                agree += ok
                if not ok: diff.append((f, i, "tokens", (sh_, nn, al), mt.groups()))
            elif ms:
                inread, first = span_arm(tree, body, story, "e6f964de8", [("01f3925ec", "authored")])
                absent = sum(1 for x in first if x is None)
                n += 1; ok = (absent, len(inread)) == (int(ms.group(1)), int(ms.group(2)))
                agree += ok
                if not ok: diff.append((f, i, "spans", (absent, len(inread)), ms.groups()))
    print("elicitation rows with a token or span evidence cell: %d; reproduced exactly: %d %s" % (n, agree, "MATCH" if n and agree == n else "DIFFERS"))
    for x in diff: print("   differs:", x)
    # the elicitation document's `later:` REFOUND rows against p1 C/M headings (the document's claim: 4 findings naming 5 p1 findings)
    p1cm = set((r[1], fid(r[2])) for r in allrows if r[0] == 1)
    named = []; erows = 0
    for line in doc.split("\n"):
        mm = re.search(r"\| REFOUND \| later: (.*)$", line)
        if not mm: continue
        erows += 1
        named += re.findall(r"`shards/stories-p1/(\w+\.md)` (F-\d+)", mm.group(1))
    ok = [x for x in named if x in p1cm]
    print("elicitation doc `later:` REFOUND rows: %d findings naming %d p1 findings, %d of them a p1 C/M heading  %s" % (
        erows, len(named), len(ok), "MATCH" if (erows, len(named), len(ok)) == (4, 5, 5) else "DIFFERS"))

main()
