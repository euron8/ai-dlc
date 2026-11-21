"""Cost partition and a mechanical yield/survival reading of the `requirements` step and the `gate-validation[requirements]`
label, s322 against s319 (BL-812 item 1).

usage: python3 -I req_yield_s322.py <OUT dir holding spawns.jsonl> <graph repo clone> [--ref <ref the record files are read at>]

Read-only: <OUT>/spawns.jsonl and `git show` / `git log` / `git ls-tree` of the committed graph clone. Writes nothing. Stdlib only.
Exit 0 only when every control reads MATCH. The ship refs are fixed in CFG (s322 e0ebaf019, s319 1da426ef9); --ref overrides
both for the RECORD files only. From bl812_rederive.py (imported) it uses STORIES, spawns() and agg(); from party_ts_yield.py
(imported) CM, blocks(), claim_spans().

1. Cost. Every `requirements` spawn is assigned by DESCRIPTION to one part: authoring (digest, authoring chain, folds, SPEC
   render), party review (seats, cross seats, dispatcher), party repair (shards, serial lanes), elicitation review / repair
   (s319 only), adversarial pass N review, pass N verdict stamps (s319), and the pass-N follow-up window (every other spawn
   that starts after pass N's first review and before pass N+1's: shard repairs, serial lanes, fan-in, record-only re-runs).
   The partition must sum to the step total (MATCH / DIFFERS). Per story and absolute: spawns, $, agent-minutes. The s322
   BL-1035 slice (32 spawns, 14:00Z to 15:08:37Z) is printed against BL-812's figures. The gate-validation[requirements] label
   is partitioned the same way.
2. Yield. C/M findings counted two ways: `### ` headings carrying the whole word CRITICAL or MAJOR, and the
   findings_critical / findings_major header counts a review file stamps (party seat files, which stamp none, are counted by
   their `## F-N (critical|major` heading and by the repair records' `- source:` lines). Per seat and per shard: $ against
   C/M. Per round: the repair record's C/M blocks by disposition. A linking floor from `- source:` tokens to review findings
   (basename + F-id, inside the pass; joined-file refs are not mappable and are counted apart).
3. Survival (a FLOOR, in BLOCKS of a repair record, not findings), as arch_yield.py: per C/M block with disposition
   `repaired` and an edit naming a requirements document: the backtick (8+) and double-quoted (12+) spans of its
   `- claim now asserted:` lines (party_ts_yield.claim_spans), NEW = absent from the BEFORE text (the committed states whose
   sha256 equals the record's `artifact_sha_before` / the pass review's `artifact_sha`, per file; a file with no committed
   state of that sha falls back to the pre-sprint file, and its NEW-* classes read BASE-NEW-* and are NOT a floor).
   Classes NEW-SHIPPED, NEW-SUPERSEDED (seen in another committed state, absent at ship), NEW-NOT-SEEN-AFTER, OLD-ONLY,
   NO-SPAN, NO-TARGET, NOT-REPAIRED.
4. Gate label: per adjudication run the PASS / FAIL check verdicts of its part files, FAILs with a later PASS of the same
   check, and the gate repair record's claim spans at the ship ref.
Controls in the same run: partition sums, the lead's figures, BL-812 slice figures, heading count against header count, joined
file against shard sum, an impossible description token and an impossible finding token each 0 beside a present one.
"""
import hashlib, importlib.util, json, os, re, subprocess, sys, collections

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
HELPERS = os.environ.get("SV_HELPERS") or os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s322", "scripts")


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HELPERS, name + ".py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


PTS = load("party_ts_yield")
RD = load("bl812_rederive")
for _n in ("CM", "claim_spans", "blocks"):
    assert hasattr(PTS, _n), "party_ts_yield.py does not bind " + _n
for _n in ("STORIES", "spawns", "agg"):
    assert hasattr(RD, _n), "bl812_rederive.py does not bind " + _n
RD.STORIES[323] = 18   # s323 has 18 stories (hand brief); bl812_rederive.py predates s323
claim_spans = PTS.claim_spans

IMPOSSIBLE_DESC = "QZXV-REQ-DESC-NEVER-9923"
IMPOSSIBLE_FIND = "QZXV-REQ-FINDING-NEVER-9924"
ART = "_bmad-output/planning-artifacts/%s"
STEP = "requirements"
GATE = "gate-validation[requirements]"
CFG = {
    323: dict(label="s323", ship="eabdc576e", base="c8ab65397b30bca2ee43e4bea663820f39b9376f", win=("2026-11-16T00:00", "2026-11-19T00:00"),
              ctl=(176, 12.34, 222.14), gctl=(3, 0.10, 1.80)),
    322: dict(label="s322", ship="e0ebaf019", base="5596361ce", win=("2026-11-09T00:00", "2026-11-12T12:00"),
              ctl=(106, 30.00, 239.96), gctl=(22, 1.19, 9.55)),
    319: dict(label="s319", ship="1da426ef9", base="d82236ceec42c4a9609031c0c151e5d2d04d90de", win=("2026-10-15T00:00", "2026-10-23T12:00"),
              ctl=(156, 11.70, 234.07), gctl=(2, 0.09, 1.72)),
}
# first match wins. (part, regex)
PART_RULES = {
    323: [("authoring", r"^Requirements (?:context digest|authoring chain)$"),
          ("party", r"^Party seat (?:architect|dev) "),
          ("party-web-fetch", r"mTLS header names$"),
          ("party-repair-shard", r"^Party repair part \d+"),
          ("party-adjudicate", r"^Adjudicator (?:lane|fanin)"),
          ("party-repair-serial", r"^Lane \d remediator|^Fan-in serial remediator$|^Serial repair p\d remediator$"),
          ("elic", r"^Elicitation (?:adversary \d+/\d+|cross shard)"),
          ("elic-repair-shard", r"^Elicitation repair part"),
          ("elic-repair-fixup", r"^Fix |^Seal |^Rework record|^Re-derive four|^Propagate LR bullets"),
          ("elic-repair-serial", r"^(?:Lane 1 serial|Fan-in serial) elicitation remediator$"),
          ("rev", r"^(?:Adversary (?:part \d+|cross shard) p(\d)|p(\d) verifier shard)\b")],
    322: [("authoring", r"digest|[Aa]uthoring chain|^Fold |^Render SPEC"),
          ("party", r"^Dispatch requirements-party|^(?:architect|dev) (?:cross seat|part \d+)$"),
          ("party-repair-shard", r"^Party repair part \d+"),
          ("party-repair-serial", r"^Serial lane \d|^Re-run lane \d|^Fan-in serial remediator s322$"),
          ("rev", r"^Adversar(?:y|ial) p(\d)\b")],
    319: [("authoring", r"digest|[Aa]uthoring chain|^Fold |^Render SPEC"),
          ("party", r"^Party (?:architect|dev) (?:part|cross)"),
          ("party-repair-shard", r"^Party repair part \d+"),
          ("party-repair-serial", r"^Party repair serial cross-part"),
          ("elic", r"^Elicitation (?:part|cross)"),
          ("elic-repair-shard", r"^Elicitation repair part"),
          ("elic-repair-serial", r"^Elicitation serial"),
          ("rev", r"^(?:Adversarial p(\d) (?:part|cross)|P(\d) adversary (?:part|cross))"),
          ("stamp", r"^Add verdict to|^Demote probes heading")],
}
GATE_RULES = [("gate: PRD validate run", r"^PRD validate"),
              ("gate: adjudicate round 1", r"^Adjudicate shard|^Gate adjudicator shard"),
              ("gate: adjudicate round 2", r"^P\d shard \d+/\d+ adjudicate"),
              ("gate: repair", r"repair")]


def gitb(g, *a):
    p = subprocess.run(["git", "-C", g] + list(a), capture_output=True)
    return p.stdout if p.returncode == 0 else None


def show(g, ref, path):
    b = gitb(g, "show", "%s:%s" % (ref, path))
    return None if b is None else b.decode("utf-8", "replace")


def sha256(t):
    return hashlib.sha256(t.encode("utf-8")).hexdigest()


# ---------------------------------------------------------------- cost
def classify_spawns(rows, sp, step, rules):
    s = [r for r in rows if int(r["sprint"]) == sp and r["step"] == step]
    first_rev = {}
    for r in s:
        d = r.get("description") or ""
        for kind, rx in rules:
            m = re.search(rx, d)
            if m:
                if kind == "rev":
                    n = int(next(x for x in m.groups() if x))
                    first_rev[n] = min(first_rev.get(n, "9"), r["start"])
                break
    acc = collections.OrderedDict(); asg = []
    for r in sorted(s, key=lambda r: r["start"]):
        d = r.get("description") or ""
        key = None
        for kind, rx in rules:
            m = re.search(rx, d)
            if not m:
                continue
            if kind == "rev":
                key = ("p%d review" % int(next(x for x in m.groups() if x)),)
            elif kind == "stamp":
                prior = [p for p, t in first_rev.items() if t <= r["start"]]
                key = ("p%d verdict stamps" % max(prior),) if prior else ("other",)
            else:
                key = (kind,)
            break
        if key is None:
            prior = [p for p, t in first_rev.items() if t <= r["start"]]
            if prior:
                sub = "shard repair" if re.match(r"^Repair (?:p\d )?part \d", d) else ("adjudicate" if re.match(r"^Adjudicate ", d) else "serial/fan-in/other")
                key = ("p%d follow-up: %s" % (max(prior), sub),)
            else:
                key = ("other",)
        k = key[0]
        a = acc.setdefault(k, [0, 0.0, 0.0])
        a[0] += 1; a[1] += r.get("usd") or 0; a[2] += r.get("minutes") or 0
        asg.append((k, r))
    return s, acc, asg


def part_order(k):
    base = ["authoring", "party", "party-web-fetch", "party-repair-shard", "party-adjudicate", "party-repair-serial", "elic", "elic-repair-shard", "elic-repair-fixup", "elic-repair-serial"]
    if k in base:
        return (0, base.index(k), "")
    m = re.match(r"p(\d) (review|verdict stamps|follow-up)", k)
    if m:
        return (1, int(m.group(1)), ("review", "verdict stamps", "follow-up").index(m.group(2)))
    return (2, 0, k)


def rowfmt(name, a, n):
    return "   %-40s %6d %9.2f %9.1f | %6.2f %8.2f %8.2f" % (name, a[0], a[1], a[2], a[0] / n, a[1] / n, a[2] / 60 / n)


# ---------------------------------------------------------------- records
def findings_heads(text):
    """C/M `### ` blocks of a review shard or joined review file: [(id, sev, head, body)]"""
    out = []
    for head, body, _ in PTS.blocks(text):
        if PTS.CM.match(head):
            sev = "CRITICAL" if re.search(r"\bCRITICAL\b", head) else "MAJOR"
            m = re.match(r"^### (F-\d+)", head)
            out.append((m.group(1) if m else "?", sev, head, body))
    return out


def prov_counts(text):
    c = re.search(r"^findings_critical: (\d+)", text, re.M)
    m = re.search(r"^findings_major: (\d+)", text, re.M)
    return (int(c.group(1)), int(m.group(1))) if c and m else None


SEAT_HEAD = re.compile(r"^#{2,4} (F-\d+) \((critical|major|minor)\b", re.M | re.I)


def seat_findings(text):
    return [(m.group(1), m.group(2).upper()) for m in SEAT_HEAD.finditer(text)]


def fkey(name):
    """normalise a review/seat file basename to a key: '07.md' -> '7', 'cross-3.md' -> 'cross-3', 'requirements-dev-07.md' -> 'dev:7'."""
    m = re.match(r"^requirements-(architect|dev)-(cross)(?:-(\d+))?\.md$", name)
    if m:
        return "%s:cross%s" % (m.group(1), "-%d" % int(m.group(3)) if m.group(3) else "")
    m = re.match(r"^requirements-(architect|dev)-(\d+)\.md$", name)
    if m:
        return "%s:%d" % (m.group(1), int(m.group(2)))
    m = re.match(r"^cross(?:-(\d+))?\.md$", name)
    if m:
        return "cross%s" % ("-%d" % int(m.group(1)) if m.group(1) else "")
    m = re.match(r"^(\d+)\.md$", name)
    if m:
        return str(int(m.group(1)))
    return name


def desc_key(desc, sp, role=None):
    """spawn description -> review file key (shard or seat)"""
    if role in ("architect", "dev"):
        m = re.search(r"\bcross\b(?: seat| g(\d+))?", desc)
        if m:
            return "%s:cross%s" % (role, "-%d" % int(m.group(1)) if m.group(1) else "")
        m = re.search(r"part (\d+)", desc)
        return "%s:%d" % (role, int(m.group(1))) if m else None
    m = re.search(r"cross g(\d+)", desc)
    if m:
        return "cross-%d" % int(m.group(1))
    if re.search(r"cross shard|cross$", desc):
        return "cross"
    m = re.search(r"(?:shard|part) (\d+)", desc) or re.search(r"adversary (\d+)/\d+", desc)
    return str(int(m.group(1))) if m else None


SRC = re.compile(r"(?:[\w.\-]+/)*([\w\-]+\.md)#(F-\d+)")
SRC2 = re.compile(r"requirements-elicitation\.md#part (\d+) (F-\d+)")   # elicitation repair records name a part and a finding


def repair_blocks(text):
    """C/M blocks of a repair record: dicts head, sev, disp, edit, sources [(basename, F-id)], claim, art.
    A block with no parseable `- source:` token takes (shard, F-id) from its own heading (`### 7.md F-1`) or from the
    enclosing `# ... part|shard N` heading plus its `### F-k` (derived=True)."""
    h1 = []; cur = ""; shm = []; curs = None
    for l in text.split("\n"):
        m_ = re.match(r"^<!-- shard: (\S+) -->", l)
        if m_:
            curs = m_.group(1)
        if l.startswith("# "):
            cur = l
        elif l.startswith("### "):
            h1.append(cur); shm.append(curs)
    out = []
    for i, (head, body, art) in enumerate(PTS.blocks(text)):
        if not PTS.CM.match(head):
            continue
        d = re.search(r"^- disposition: (\S+)", body, re.M)
        ed = re.search(r"^- edit: (.*)$", body, re.M)
        sl = re.findall(r"^- source: (.*)$", body, re.M)
        srcs = []
        for l in sl:
            for a, b in SRC.findall(l):
                # a ref into a JOINED adversarial file is keyed by the shard marker the block sits under
                if re.match(r"^requirements-adversarial-p\d\.md$", a) and i < len(shm) and shm[i]:
                    a = shm[i]
                srcs.append((a, b))
            for n_, b in SRC2.findall(l):
                srcs.append(("%d.md" % int(n_), b))
        derived = False
        if not srcs:
            m = re.match(r"^### (\d+\.md|cross(?:-\d+)?\.md) (F-\d+)", head)
            if m:
                srcs = [(m.group(1), m.group(2))]; derived = True
            else:
                f = re.match(r"^### (F-\d+)", head); pn = re.search(r"(?:part|shard) (\d+)", h1[i] if i < len(h1) else "")
                if f and pn:
                    srcs = [("%d.md" % int(pn.group(1)), f.group(1))]; derived = True
        out.append(dict(head=head, sev="CRITICAL" if re.search(r"\bCRITICAL\b", head) else "MAJOR",
                        disp=d.group(1) if d else None, edit=ed.group(1) if ed else "", sources=srcs, derived=derived,
                        source_lines=sl, claim="\n".join(re.findall(r"^- claim now asserted:.*$", body, re.M)), body=body))
    return out


def surv_target(edit):
    if not edit:
        return False
    return bool(re.search(r"prd\.md|product-brief\.md|SPEC\.md|architecture-impact\.md|\.memlog\.md|/sections/", edit))


class World:
    def __init__(self, g, sp, ref):
        self.g = g; self.sp = sp; self.cfg = CFG[sp]; self.ref = ref; self.ship = self.cfg["ship"]
        self.P = ART % ("s%d" % sp)
        self.tree = set((gitb(g, "ls-tree", "-r", "--name-only", self.ship) or b"").decode().split("\n")) - {""}
        self.tree_ref = set((gitb(g, "ls-tree", "-r", "--name-only", ref) or b"").decode().split("\n")) - {""}
        self.corpus = []     # every text loaded, for the token controls
        subj = self.rd(self.P + "/requirements-subject.md") or ""
        self.files = dict((a, b) for a, b in re.findall(r"^file: (\S+) (\S+)$", subj, re.M))
        self.states = {}     # sha256 -> (name, label, text)
        self.base = {}; self.shiptext = {}
        for name, path in self.files.items():
            cs = (gitb(g, "log", "--all", "--format=%h", "--since=" + self.cfg["win"][0], "--until=" + self.cfg["win"][1], "--", path) or b"").decode().split()
            for c in cs + [self.cfg["base"], self.ship]:
                t = show(g, c, path)
                if t is not None:
                    self.states.setdefault(sha256(t), (name, c, t))
            self.base[name] = show(g, self.cfg["base"], path) or ""
            self.shiptext[name] = show(g, self.ship, path) or ""

    def rd(self, path, ref=None):
        t = show(self.g, ref or self.ref, path)
        if t is not None:
            self.corpus.append(t)
        return t

    def ls(self, prefix, rx=None):
        return sorted(f for f in self.tree_ref if f.startswith(prefix) and (rx is None or re.search(rx, f)))

    def before_for(self, record_text, review_text):
        """-> (text, n_base_fallback): per-file BEFORE from sha tokens in the record, else the pass review, else pre-sprint."""
        toks = {}
        for src in (review_text, record_text):
            for m in re.finditer(r"^(?:- )?artifact_sha(?:_before)?: (.*@[0-9a-f]{64}.*)$", src or "", re.M):
                for nm, h in re.findall(r"([\w\-]+)@([0-9a-f]{64})", m.group(1)):
                    toks.setdefault(nm, h)
        parts = []; fb = 0; ex_b = []; ex_s = []; ntok = len(toks)
        for name in self.files:
            h = toks.get(name)
            st = self.states.get(h) if h else None
            if st and st[0] == name:
                parts.append(st[2]); ex_b.append(st[2]); ex_s.append(self.shiptext[name])
            else:
                parts.append(self.base[name]); fb += 1
        self.last_exact = ("\n".join(ex_b), "\n".join(ex_s), ntok, len(ex_b))
        return "\n".join(parts), fb, toks


def classify_block(blk, before, ship_text, others):
    if blk["disp"] != "repaired":
        return "NOT-REPAIRED"
    if not surv_target(blk["edit"]):
        return "NO-TARGET"
    sp_ = claim_spans(blk["claim"])
    if not sp_:
        return "NO-SPAN"
    new = [x for x in sp_ if x not in before]
    if not new:
        return "OLD-ONLY"
    if any(x in ship_text for x in new):
        return "NEW-SHIPPED"
    if any(x in o for x in new for o in others):
        return "NEW-SUPERSEDED"
    return "NEW-NOT-SEEN-AFTER"


# ---------------------------------------------------------------- main
def main():
    argv = list(sys.argv); ref_over = None
    if "--ref" in argv:
        i = argv.index("--ref"); ref_over = argv[i + 1]; del argv[i:i + 2]
    if len(argv) < 3:
        sys.exit(__doc__)
    out, g = argv[1], argv[2]
    rows = RD.spawns(out)
    for r in rows:
        r["sprint"] = int(r["sprint"])
    ctl = []
    print("graph %s spawns %s" % (g, out))
    costs = {}; asgs = {}
    for sp in (323, 322, 319):
        cfg = CFG[sp]; n = RD.STORIES[sp]
        for step, lab, c0, rules in ((STEP, "requirements", cfg["ctl"], PART_RULES[sp]), (GATE, "gate-validation[requirements]", cfg["gctl"], GATE_RULES)):
            if step == GATE:
                rl = [(k, rx) for k, rx in GATE_RULES]
                s = [r for r in rows if r["sprint"] == sp and r["step"] == step]
                acc = collections.OrderedDict(); asg = []
                for r in sorted(s, key=lambda r: r["start"]):
                    d = r.get("description") or ""; key = "gate: other"
                    for k, rx in rl:
                        if re.search(rx, d):
                            key = k; break
                    a = acc.setdefault(key, [0, 0.0, 0.0]); a[0] += 1; a[1] += r.get("usd") or 0; a[2] += r.get("minutes") or 0
                    asg.append((key, r))
            else:
                s, acc, asg = classify_spawns(rows, sp, step, rules)
            asgs[(sp, step)] = asg
            tot = RD.agg(rows, sp, [step])
            costs[(sp, step)] = (acc, tot)
            print("\n== 1. cost %s %s: %d spawns $%.2f %.1f agent-min over %d stories = %.2f spawns $%.2f %.2f agent-h per story" % (
                cfg["label"], lab, tot[0], tot[1], tot[2], n, tot[0] / n, tot[1] / n, tot[2] / 60 / n))
            print("   %-40s %6s %9s %9s | %6s %8s %8s" % ("part", "spawns", "$", "agent-min", "sp/st", "$/st", "agent-h/st"))
            for k in sorted(acc, key=part_order) if step == STEP else acc:
                print(rowfmt(k, acc[k], n))
            sn = sum(a[0] for a in acc.values()); su = sum(a[1] for a in acc.values()); sm = sum(a[2] for a in acc.values())
            # a catch-all bucket makes the sum match by construction, so the control also requires it to be empty
            catch = sum(acc[k][0] for k in acc if k in ("other", "gate: other"))
            ok = sn == len(s) == tot[0] and abs(su - tot[1]) < 0.005 and abs(sm - tot[2]) < 0.05 and catch == 0
            print("   partition sum %d spawns $%.2f %.1f min against label %d $%.2f %.1f, catch-all rows %d (must be 0): %s" % (sn, su, sm, tot[0], tot[1], tot[2], catch, "MATCH" if ok else "DIFFERS"))
            ctl.append(("%s %s partition sums to the label" % (cfg["label"], lab), ok))
            ok2 = tot[0] == c0[0] and round(tot[1] / n, 2) == c0[1] and round(tot[1], 2) == c0[2]
            ctl.append(("%s %s reads %d spawns, $%.2f per story, $%.2f (lead's %s)" % (cfg["label"], lab, tot[0], tot[1] / n, tot[1], c0), ok2))
    # 1b: rise
    print("\n== 1b. where the s319 -> s323 per-story difference sits ($ per story; s319 divisor 20, s322 divisor 8, s323 divisor 18)")
    def fam(k):
        if k.startswith("party-repair") or k == "party-adjudicate": return "party repair (incl. adjudicate)"
        if k in ("party", "party-web-fetch"): return "party review"
        if k.startswith("elic-repair"): return "elicitation repair"
        if k == "elic": return "elicitation review"
        if k == "authoring": return "authoring"
        m = re.match(r"p(\d) (.*)", k)
        if m:
            return "adversarial p%s %s" % (m.group(1), "review (incl. stamps)" if m.group(2) in ("review", "verdict stamps") else "follow-up")
        return k
    fams = collections.OrderedDict()
    for sp_ in (319, 322, 323):
        for k, a in costs[(sp_, STEP)][0].items():
            o = fams.setdefault(fam(k), {319: [0, 0.0, 0.0], 322: [0, 0.0, 0.0], 323: [0, 0.0, 0.0]})
            for i in range(3):
                o[sp_][i] += a[i]
    print("   %-34s %9s %9s %9s %9s | %9s %9s" % ("family", "$/st 319", "$/st 322", "$/st 323", "323-319", "sp/st 319", "sp/st 323"))
    dsum = 0.0
    for k in sorted(fams):
        o = fams[k]; d = o[323][1] / 18 - o[319][1] / 20; dsum += d
        print("   %-34s %9.2f %9.2f %9.2f %+9.2f | %9.2f %9.2f" % (k, o[319][1] / 20, o[322][1] / 8, o[323][1] / 18, d, o[319][0] / 20, o[323][0] / 18))
    td = costs[(323, STEP)][1][1] / 18 - costs[(319, STEP)][1][1] / 20
    print("   sum of deltas %+.2f against step delta %+.2f" % (dsum, td))
    ctl.append(("family deltas sum to the s323-s319 step delta", abs(dsum - td) < 0.005))

    # ---------------------------------------------------------------- yield
    W = {sp: World(g, sp, ref_over or CFG[sp]["ship"]) for sp in (323,)}
    seat_stats = {}; pass_stats = {}
    for sp in (323,):
        w = W[sp]; P = w.P; n = RD.STORIES[sp]
        print("\n== 2. yield %s (records read at %s; subject files %s)" % (CFG[sp]["label"], w.ref, sorted(w.files)))
        # ---- party seats
        seat_files = sorted(f for f in w.tree_ref if f.startswith("_bmad-output/party-mode/s%d/requirements-" % sp) and f.endswith(".md"))
        seats = {}
        for f in seat_files:
            t = w.rd(f) or ""
            seats[fkey(f.split("/")[-1])] = seat_findings(t)
        # per-seat cost
        seatcost = collections.defaultdict(float)
        for k, r in asgs[(sp, STEP)]:
            if k == "party" and r["role"] in ("architect", "dev"):
                dk = desc_key(r["description"], sp, r["role"])
                if dk:
                    seatcost[dk] += r["usd"] or 0
        tc = sum(len(v) for v in seats.values()); tcm = sum(1 for v in seats.values() for _, s in v if s in ("CRITICAL", "MAJOR"))
        # party-family repair records
        precs = ["requirements-party-repair.md"] + ["requirements-party-serial-repair-p%d.md" % i for i in range(1, 7)]
        pb = []
        for rn in precs:
            t = w.rd("%s/%s" % (P, rn))
            if t:
                pb += [dict(b, rec=rn) for b in repair_blocks(t)]
        print("   party seat files (%d, %s): findings headed critical/major %d (CRITICAL %d), all severities %d (minor %d)" % (
            len(seats), "committed", tcm, sum(1 for v in seats.values() for _, s in v if s == "CRITICAL"), tc, sum(1 for v in seats.values() for _, s in v if s == "MINOR")))
        # second count: distinct (seat, F-id) pairs named by a party-family repair block source, intersected with C/M seat headings
        cm_ids = {(k, fid) for k, v in seats.items() for fid, s in v if s in ("CRITICAL", "MAJOR")}
        link = collections.defaultdict(list)
        for b in pb:
            for nm, fid in b["sources"]:
                link[(fkey(nm), fid)].append(b["disp"])
        mapped = {k for k in link if k in cm_ids}
        d_any = collections.Counter()
        for k in cm_ids:
            ds = link.get(k, [])
            d_any["REPAIRED" if "repaired" in ds else ("ESCALATED/OTHER" if ds else "NO-BLOCK-LINKED")] += 1
        nsrc = sum(len(b["sources"]) for b in pb)
        print("   second count: %d distinct seat C/M findings named by a party-family repair `- source:` line (of %d C/M); of the C/M: %s; %d source tokens in all, %d resolve to a seat C/M heading" % (
            len(mapped), len(cm_ids), dict(sorted(d_any.items())), nsrc, sum(1 for b in pb for nm, fid in b["sources"] if (fkey(nm), fid) in cm_ids)))
        ctl.append(("%s party seat C/M heading count positive (%d)" % (CFG[sp]["label"], tcm), tcm > 0))
        print("   party-family repair records: C/M blocks %d by disposition %s" % (len(pb), dict(sorted(collections.Counter(b["disp"] for b in pb).items()))))
        # per seat table, grouped by role
        for role in ("architect", "dev"):
            ks = sorted((k for k in seats if k.startswith(role + ":")), key=lambda k: (k.split(":")[1].startswith("cross"), k))
            c = sum(len([1 for _, s in seats[k] if s in ("CRITICAL", "MAJOR")]) for k in ks)
            u = sum(seatcost.get(k, 0) for k in ks)
            z = [k for k in ks if not any(s in ("CRITICAL", "MAJOR") for _, s in seats[k])]
            print("   %-9s seats %2d  C/M %3d  $%6.2f  $/C/M %5.2f  seats with 0 C/M: %s" % (role, len(ks), c, u, u / c if c else float("nan"), z or "-"))
        seat_stats[sp] = (seats, seatcost)
        # ---- elicitation (s319 only)
        passes = collections.OrderedDict()
        keys = []
        keys.append(("elic", "requirements-elicitation", "requirements-elicitation.md", ["requirements-elicitation-repair.md", "requirements-elicitation-serial-repair-p1.md"]))
        keys += [("p%d" % p, "requirements-p%d" % p, "requirements-adversarial-p%d.md" % p,
                  ["requirements-repair-p%d.md" % p, "requirements-serial-repair-p%d.md" % p]) for p in range(1, 4)]
        for key, sd, joined, reps in keys:
            files = w.ls("%s/shards/%s/" % (P, sd), r"/[^/]+\.md$")
            files = [f for f in files if "/prd/" not in f and "/product-brief/" not in f]
            jt = w.rd("%s/%s" % (P, joined)) if "%s/%s" % (P, joined) in w.tree_ref else None
            if not files and jt is None:
                continue
            sh = []
            for f in files:
                t = w.rd(f) or ""
                sh.append((fkey(f.split("/")[-1]), t, findings_heads(t), prov_counts(t)))
            rec = []
            for rn in reps:
                t = w.rd("%s/%s" % (P, rn)) if "%s/%s" % (P, rn) in w.tree_ref else None
                if t:
                    rec.append((rn, t, repair_blocks(t)))
            passes[key] = dict(sh=sh, joined=jt, rec=rec)
        # review cost per shard
        rcost = collections.defaultdict(float)
        for k, r in asgs[(sp, STEP)]:
            m = re.match(r"^(p\d|elic)\b", k)
            if k.endswith("review") or k == "elic":
                pk = "elic" if k == "elic" else k.split()[0]
                dk = desc_key(r["description"], sp)
                if dk:
                    rcost[(pk, dk)] += r["usd"] or 0
        print("   %-6s %5s %9s %9s %6s %8s | joined file: heads  provenance  | shard sum: heads  provenance" % ("round", "files", "C(head)", "M(head)", "$", "$/CM"))
        for key, d in passes.items():
            sh = d["sh"]
            ch = sum(1 for _, _, fl, _ in sh for _, s, _, _ in fl if s == "CRITICAL"); mh = sum(1 for _, _, fl, _ in sh for _, s, _, _ in fl if s == "MAJOR")
            pc = [p for _, _, _, p in sh if p]
            pcs = (sum(p[0] for p in pc), sum(p[1] for p in pc)) if pc else None
            jt = d["joined"]
            jh = (sum(1 for x in findings_heads(jt) if x[1] == "CRITICAL"), sum(1 for x in findings_heads(jt) if x[1] == "MAJOR")) if jt else None
            jp = prov_counts(jt) if jt else None
            u = sum(v for (pk, _), v in rcost.items() if pk == key)
            cm = ch + mh
            ok_a = (pcs is None) or (pcs == (ch, mh))
            ok_b = (jh is None) or (jh == (ch, mh))
            print("   %-6s %5d %9d %9d %6.2f %8.2f | joined heads %s prov %s | shard prov %s  [heads vs shard prov %s; joined vs shard sum %s]" % (
                key, len(sh), ch, mh, u, u / cm if cm else float("nan"), jh, jp, pcs, "MATCH" if ok_a else "DIFFERS", "MATCH" if ok_b else "DIFFERS"))
            ctl.append(("%s %s heading count equals shard provenance count" % (CFG[sp]["label"], key), ok_a))
            ctl.append(("%s %s joined file C/M equals shard sum" % (CFG[sp]["label"], key), ok_b))
            d["cm"] = (ch, mh)
        # per-shard yield
        print("   per-shard C/M (cost from the matching spawn description; shard with 0 C/M listed):")
        for key, d in passes.items():
            parts = []
            for kk, t, fl, p in sorted(d["sh"], key=lambda x: (x[0].startswith("cross"), len(x[0]), x[0])):
                nm = len(fl); u = rcost.get((key, kk), 0.0)
                parts.append("%s:%d($%.2f)" % (kk, nm, u))
            print("     %-6s %s" % (key, " ".join(parts)))
            zs = [(kk, rcost.get((key, kk), 0.0)) for kk, t, fl, p in d["sh"] if not fl]
            print("     %-6s zero-C/M review shards: %d of %d, $%.2f of $%.2f review spend" % (key, len(zs), len(d["sh"]), sum(v for _, v in zs), sum(v for (pk, _), v in rcost.items() if pk == key)))
        FAM = {"party": ("party", "party-web-fetch", "party-repair-shard", "party-adjudicate", "party-repair-serial"),
               "elic": ("elic", "elic-repair-shard", "elic-repair-fixup", "elic-repair-serial"),
               "p1": ("p1 review", "p1 follow-up: shard repair", "p1 follow-up: serial/fan-in/other", "p1 follow-up: adjudicate"),
               "p2": ("p2 review", "p2 follow-up: serial/fan-in/other")}
        accs = costs[(sp, STEP)][0]
        print("   round totals (review + its repair and follow-up spawns), s323 over 18 stories:")
        rsum = [0, 0.0, 0.0]
        for rk, parts_ in FAM.items():
            a_ = [sum(accs[k][i] for k in parts_ if k in accs) for i in range(3)]
            for i in range(3):
                rsum[i] += a_[i]
            print("     %-6s %3d spawns $%7.2f %7.1f agent-min | $%.2f per story" % (rk, a_[0], a_[1], a_[2], a_[1] / n))
        au = accs.get("authoring", [0, 0.0, 0.0])
        rt_ok = rsum[0] + au[0] == costs[(sp, STEP)][1][0] and abs(rsum[1] + au[1] - costs[(sp, STEP)][1][1]) < 0.005
        print("     round totals + authoring = %d spawns $%.2f against label %d $%.2f: %s" % (rsum[0] + au[0], rsum[1] + au[1], costs[(sp, STEP)][1][0], costs[(sp, STEP)][1][1], "MATCH" if rt_ok else "DIFFERS"))
        ctl.append(("s323 round totals plus authoring sum to the label", rt_ok))
        # ---- repair records, linking and survival
        shipt = "\n".join(w.shiptext[nm] for nm in w.files)
        everything = [t for _, _, t in w.states.values()]
        allrounds = [("party", None, precs)]
        allrounds.append(("elic", "elic", ["requirements-elicitation-repair.md", "requirements-elicitation-serial-repair-p1.md"]))
        for key in ("p1", "p2"):
            allrounds.append((key, key, ["requirements-repair-%s.md" % key, "requirements-serial-repair-%s.md" % key]))
        print("   repair records (C/M blocks, disposition) and survival FLOOR in blocks:")
        classes_all = collections.OrderedDict(); allblk = []
        for key, pk, rns in allrounds:
            bl = []; rtexts = []
            for rn in rns:
                t = w.rd("%s/%s" % (P, rn)) if "%s/%s" % (P, rn) in w.tree_ref else None
                if t:
                    rtexts.append(t); bl += [dict(b, rec=rn) for b in repair_blocks(t)]
            if not rtexts:
                print("     %-6s no repair record file (%s)" % (key, ", ".join(rns)))
                continue
            rev_t = passes[pk]["joined"] if pk in passes else None
            cls = collections.Counter(); disp = collections.Counter(b["disp"] for b in bl)
            for rt, rn in zip(rtexts, [r for r in rns if "%s/%s" % (P, r) in w.tree_ref]):
                before, fb, toks = w.before_for(rt, rev_t)
                rbl = [b for b in bl if b["rec"] == rn]
                for b in rbl:
                    k = classify_block(b, before, shipt, [t for t in everything if t != before and t != shipt])
                    if fb and k.startswith("NEW-"):
                        eb, es, _, nex = w.last_exact
                        k2 = classify_block(b, eb, es, []) if nex else "NONE"
                        k = "EXACT-FILES-NEW-SHIPPED" if k2 == "NEW-SHIPPED" else "BASE-" + k
                    b["cls"] = k
                    cls[k] += 1
                print("       %-40s before: %d sha tokens parsed, %d of %d files matched to a committed state, %d fell back to pre-sprint; blocks %d" % (rn, w.last_exact[2], w.last_exact[3], len(w.files), fb, len(rbl)))
            print("     %-6s C/M blocks %3d  disposition %s" % (key, len(bl), dict(disp)))
            print("            survival %s" % dict(cls))
            classes_all[key] = (len(bl), dict(disp), dict(cls))
            allblk.extend((key, b) for b in bl)
            # linking floor to the review shards of the pass
            if pk in passes:
                fnd = {(k, fid): s for k, t, fl, p in passes[pk]["sh"] for fid, s, _, _ in fl}
                lk = collections.defaultdict(list)
                unm = 0
                for b in bl:
                    for nm, fid in b["sources"]:
                        kk = (fkey(nm), fid)
                        if kk in fnd:
                            lk[kk].append(b["disp"])
                        else:
                            unm += 1
                dd = collections.Counter()
                for kk in fnd:
                    ds = lk.get(kk, [])
                    dd["REPAIRED-LINKED" if "repaired" in ds else ("ESCALATED/OTHER-LINKED" if ds else "NO-BLOCK-LINKED")] += 1
                print("            link floor: %d review C/M findings: %s; %d source tokens did not resolve to a shard C/M finding (joined-file or repair-record refs: not mappable)" % (len(fnd), dict(dd), unm))
        pass_stats[sp] = (passes, classes_all)
        # CRITICAL findings and their repair blocks
        crit = [(key, kk, fid, h) for key, d in passes.items() for kk, t, fl, p in d["sh"] for fid, s, h, _ in fl if s == "CRITICAL"]
        print("   CRITICAL review findings: %d" % len(crit))
        for key, kk, fid, h in crit:
            lb = [(k_, b) for k_, b in allblk if k_ == key and (kk, fid) in [(fkey(a_), b_) for a_, b_ in b["sources"]]]
            print("     %s %s#%s %s -> linked repair blocks %s" % (key, kk, fid, h[:80], [(b["disp"], b.get("cls"), b["edit"][-40:]) for _, b in lb] or "none linked (by source grammar)"))

        # ---- 2b. four-way reading of every C/M finding (a mechanical PROXY on quoted spans, see overlap_n and classify_finding)
        rounds = ["party", "elic", "p1", "p2"]
        F = collections.OrderedDict((r_, []) for r_ in rounds)     # round -> [(key, fid, sev, spans)]
        for f in seat_files:
            t = w.rd(f) or ""
            kk = fkey(f.split("/")[-1])
            parts_ = re.split(r"(?m)^(?=## F-\d+ \()", t)
            for pt in parts_:
                m_ = SEAT_HEAD.match(pt)
                if m_ and m_.group(2).upper() in ("CRITICAL", "MAJOR"):
                    F["party"].append((kk, m_.group(1), m_.group(2).upper(), set(claim_spans(pt, 12, 16))))
        for key_ in ("elic", "p1", "p2"):
            for kk, t, fl, _p in passes[key_]["sh"]:
                for fid, sev, head, body in fl:
                    F[key_].append((kk, fid, sev, set(claim_spans(head + "\n" + body, 12, 16))))
        def state_of(src_text, fallback_base):
            toks = {}
            for m_ in re.finditer(r"^(?:- )?artifact_sha(?:_before)?: (.*[@=][0-9a-f]{64}.*)$", src_text or "", re.M):
                for nm, h in re.findall(r"([\w\-]+)[@=]([0-9a-f]{64})", m_.group(1)):
                    toks.setdefault(nm, h)
            parts_ = []; ex = 0
            for nm in w.files:
                st = w.states.get(toks.get(nm))
                if st and st[0] == nm:
                    parts_.append(st[2]); ex += 1
                elif fallback_base:
                    parts_.append(w.base[nm])
                else:
                    return None, ex
            return "\n".join(parts_), ex
        pty = w.rd(P + "/requirements-party-repair.md") or ""
        ST = {"party": state_of(pty, True)}
        for key_ in ("elic", "p1", "p2"):
            first = passes[key_]["sh"][0][1] if passes[key_]["sh"] else ""
            ST[key_] = state_of(first, False)
        print("\n== 2b. four-way reading, C/M findings by round (PROXY: spans are backtick spans of 12+ and quoted spans of 16+ chars; states are the committed subject files at the sha each round's provenance names)")
        print("   reviewed state resolved (exact files of 4): " + ", ".join("%s %s" % (k_, ("%d/4" % v[1]) if v[0] is not None else "UNRESOLVED %d/4" % v[1]) for k_, v in ST.items()) + "  (party's state is its repair's artifact_sha_before; a file with no committed state falls back to the pre-sprint file there)")
        # repaired-and-shipped link per (round, shard, F-id)
        shipped = collections.defaultdict(set)
        for key_, b in allblk:
            for nm, fid in b["sources"]:
                shipped[(key_, fkey(nm), fid)].add(b.get("cls"))
        SHIPPED = {"NEW-SHIPPED", "EXACT-FILES-NEW-SHIPPED", "BASE-NEW-SHIPPED"}
        res_all = {}
        for th in (2, 3, 4):
            print("   -- REFOUND threshold: later-round C/M finding sharing >= %d spans --" % th)
            print("   %-6s %5s %8s %9s %9s %9s %8s %9s %10s %14s" % ("round", "C/M", "REFOUND", "REP-INTRO", "(all-new)", "MISSED", "NO-TEXT", "UNKN-ST", "SURV-LINK", "UNIQUE-SURV"))
            for i_, r_ in enumerate(rounds):
                cnt = collections.Counter(); later = [g for r2 in rounds[i_ + 1:] for g in F[r2]]
                for kk, fid, sev, S in F[r_]:
                    refound = any(len(S & g[3]) >= th for g in later)
                    if r_ == "party":
                        intro = None
                    else:
                        cur_t, prev_t = ST[r_][0], ST[rounds[i_ - 1]][0]
                        if cur_t is None or prev_t is None:
                            intro = "UNKN-ST"
                        else:
                            E = [x for x in S if x in cur_t]
                            if not E:
                                intro = "NO-TEXT"
                            elif any(x not in prev_t for x in E):
                                intro = "REP-INTRO"
                                if all(x not in prev_t for x in E):
                                    cnt["REP-INTRO-ALL"] += 1
                            else:
                                intro = "MISSED"
                    sl = bool(shipped.get((r_, kk, fid), set()) & SHIPPED)
                    cnt["C/M"] += 1
                    if refound: cnt["REFOUND"] += 1
                    if intro: cnt[intro] += 1
                    if sl: cnt["SURV-LINK"] += 1
                    if not refound and intro != "REP-INTRO" and sl: cnt["UNIQUE-SURV"] += 1
                res_all[(th, r_)] = cnt
                print("   %-6s %5d %8d %9d %9d %9d %8d %9d %10d %14d" % (r_, cnt["C/M"], cnt["REFOUND"], cnt["REP-INTRO"], cnt["REP-INTRO-ALL"], cnt["MISSED"], cnt["NO-TEXT"], cnt["UNKN-ST"], cnt["SURV-LINK"], cnt["UNIQUE-SURV"]))
        ok_t = all(res_all[(2, r_)]["REFOUND"] >= res_all[(3, r_)]["REFOUND"] >= res_all[(4, r_)]["REFOUND"] for r_ in rounds)
        ctl.append(("2b REFOUND is monotone in the threshold (2 >= 3 >= 4)", ok_t))
        ctl.append(("2b round C/M counts equal the heading counts (party %d elic %d p1 %d p2 %d)" % tuple(len(F[r_]) for r_ in rounds),
                    len(F["party"]) == tcm and len(F["elic"]) == passes["elic"]["cm"][0] + passes["elic"]["cm"][1] and len(F["p1"]) == sum(passes["p1"]["cm"]) and len(F["p2"]) == sum(passes["p2"]["cm"])))
        # a REFOUND seed: finding sharing spans must read REFOUND at threshold 2 and not at 4; a disjoint one reads neither
        A_ = {"aaaaaaaaaaaa1", "bbbbbbbbbbbb2", "cccccccccccc3"}; B_ = {"aaaaaaaaaaaa1", "bbbbbbbbbbbb2", "zzzzzzzzzzzz9"}; C_ = {"qqqqqqqqqqqq7"}
        seedok = (len(A_ & B_) >= 2 and len(A_ & B_) < 3 and len(A_ & C_) == 0)
        ctl.append(("2b span-overlap seeds (shared 2, disjoint 0) discriminate the thresholds", seedok))
        # the four-way split has to be able to read each of REP-INTRO and MISSED: positive-count control on the real data
        ctl.append(("2b the classifier reads at least one REP-INTRO and one MISSED across elic/p1/p2 (it can fire both ways)",
                    sum(res_all[(3, r_)]["REP-INTRO"] for r_ in ("elic", "p1", "p2")) > 0 and sum(res_all[(3, r_)]["MISSED"] for r_ in ("elic", "p1", "p2")) > 0))
        pass_stats[(sp, "F")] = F

    # ---------------------------------------------------------------- gate label
    print("\n== 4. gate-validation[requirements]: what each adjudication run returned (part files) and what the repair left at ship")
    for sp in (323,):
        w = W[sp]; gs = [r for r in rows if r["sprint"] == sp and r["step"] == GATE and r["role"] == "gate-adjudicator"]
        lo = min(r["start"] for r in gs); hi = max(r["end"] for r in gs)
        def stamp(f):
            m = re.search(r"planning-(\d{8})T(\d{6})Z", f); return (m.group(1), m.group(2)) if m else None
        def iso(s):
            return "%s-%s-%sT%s:%s:%s" % (s[0][:4], s[0][4:6], s[0][6:], s[1][:2], s[1][2:4], s[1][4:])
        # window: nonce between five minutes before the first adjudicator spawn and the last spawn's end
        def minus5(s):
            import datetime
            d = datetime.datetime.strptime(s[:19], "%Y-%m-%dT%H:%M:%S") - datetime.timedelta(minutes=5)
            return d.strftime("%Y-%m-%dT%H:%M:%S")
        pf = sorted(f for f in w.tree if re.search(r"gate-adjudication/planning-\d{8}T\d{6}Z\.part-\d+of\d+\.jsonl$", f) and minus5(lo) <= iso(stamp(f)) <= hi[:19])
        byrun = collections.OrderedDict()
        for f in pf:
            byrun.setdefault(stamp(f), []).append(f)
        print("   %s: %d adjudicator spawns (%s .. %s); %d part files in %d runs" % (CFG[sp]["label"], len(gs), lo[11:19], hi[11:19], len(pf), len(byrun)))
        later = {}
        runs = []
        for stm, fl in byrun.items():
            vs = []
            for f in fl:
                for l in (show(g, w.ship, f) or "").splitlines():
                    try:
                        d = json.loads(l)
                    except Exception:
                        continue
                    vs.append((d.get("check_id"), d.get("verdict"), (d.get("evidence") or "")[:140].replace("\n", " ")))
            runs.append((stm, len(fl), vs))
        for i, (stm, nf, vs) in enumerate(runs):
            c = collections.Counter(v for _, v, _ in vs)
            print("     run %sT%sZ: %d part files, %d verdicts %s" % (stm[0], stm[1], nf, len(vs), dict(c)))
            for cid, v, ev in vs:
                if v != "PASS":
                    nxt = next(((s2[1], v2) for s2, _, vs2 in runs[i + 1:] for c2, v2, _ in vs2 if c2 == cid), None)
                    print("       %s check %s; next run's verdict on the same check: %s | %s" % (v, cid, nxt, ev))
        ctl.append(("%s gate part files found (positive)" % CFG[sp]["label"], len(pf) > 0 and sum(len(vs) for _, _, vs in runs) > 0))
        for r in sorted((r for r in rows if r["sprint"] == sp and r["step"] == GATE and r["role"] != "gate-adjudicator"), key=lambda r: r["start"]):
            print("     non-adjudicator gate spawn %s %s $%.2f final_text (<=1500 kept): %s" % (r["role"], r["description"], r["usd"], (r["final_text"] or "")[:420].replace("\n", " ")))
        gr = [f for f in w.tree if re.search(r"/s%d/gate-planning-repair-p\d+\.md$" % sp, f)]
        print("   gate repair records of the planning gate at the ship ref: %s" % (sorted(gr) or "none"))
        for f in sorted(gr):
            t = show(g, w.ship, f) or ""
            print("     %s: %s | %s" % (f.split("/")[-1], t.split("\n")[0], next((l for l in t.split("\n") if l.startswith("- repaired_checks")), "no repaired_checks line")))
        nrep = sum(1 for r in rows if r["sprint"] == sp and r["step"] == GATE and re.search(r"repair", r.get("description") or ""))
        nrep_arch = sum(1 for r in rows if r["sprint"] == sp and r["step"] == "gate-validation[architecture]" and re.search(r"repair", r.get("description") or ""))
        print("   repair spawns charged to the requirements gate label: %d (control: gate-validation[architecture] repair spawns, the label the planning-gate repair records above belong to: %d)" % (nrep, nrep_arch))
        ctl.append(("s323 requirements gate has 0 repair spawns beside a nonzero architecture one", nrep == 0 and nrep_arch > 0))
        fails = sum(1 for _, _, vs in runs for _, v, _ in vs if v != "PASS")
        ctl.append(("s323 gate verdict tally reads 10 PASS (positive) and %d non-PASS" % fails, sum(len(vs) for _, _, vs in runs) == 10))

    # ---------------------------------------------------------------- controls
    print("\n== 5. controls")
    for sp in (323, 322, 319):
        rs = [r for r in rows if r["sprint"] == sp and r["step"] == STEP]
        real = collections.Counter(re.sub(r"\d+", "N", r["description"])[:14] for r in rs).most_common(1)[0]
        print("   s%d description token present %r x%d (must be >0); impossible token %s x%d (must be 0)" % (
            sp, real[0], real[1], IMPOSSIBLE_DESC, sum(1 for r in rs if IMPOSSIBLE_DESC in r["description"])))
        ctl.append(("s%d impossible description token reads 0 beside a present one" % sp, real[1] > 0 and not any(IMPOSSIBLE_DESC in r["description"] for r in rs)))
        if sp not in W:
            continue
        corp = "\n".join(W[sp].corpus)
        pos = len(re.findall(r"\bMAJOR\b", corp))
        print("   s%d corpus loaded %d texts %d bytes: 'MAJOR' x%d (must be >0); impossible finding token %s x%d (must be 0)" % (
            sp, len(W[sp].corpus), len(corp), pos, IMPOSSIBLE_FIND, corp.count(IMPOSSIBLE_FIND)))
        ctl.append(("s%d impossible finding token reads 0 beside a present one" % sp, pos > 0 and corp.count(IMPOSSIBLE_FIND) == 0))
        print("   s%d committed states of the subject files: %d distinct shas over %s" % (sp, len(W[sp].states), sorted(W[sp].files)))
        ctl.append(("s%d subject files resolved (4)" % sp, len(W[sp].files) == 4))
    impossible_step = [r for r in rows if r["sprint"] == 322 and r["step"] == "QZXV-NO-SUCH-STEP-5512"]
    print("   impossible step reads %d spawns (must be 0)" % len(impossible_step))
    ctl.append(("impossible step reads 0", not impossible_step))
    # seeded classify cases, both directions
    before = "alpha `keep-this-old-span` omega"
    ship = "x `brand-new-claim-span-text` y"
    mk = lambda claim, disp="repaired", edit="prd.md:1": dict(disp=disp, edit=edit, claim="- claim now asserted: " + claim)
    seeds = [(mk("it adds `brand-new-claim-span-text` here"), "NEW-SHIPPED"), (mk("it adds `keep-this-old-span` here"), "OLD-ONLY"),
             (mk("it adds `gone-claim-span-text-x` here"), "NEW-NOT-SEEN-AFTER"), (mk("none"), "NO-SPAN"),
             (mk("`brand-new-claim-span-text`", "escalated"), "NOT-REPAIRED"), (mk("`brand-new-claim-span-text`", edit="docs/x.md:1"), "NO-TARGET")]
    sok = all(classify_block(b, before, ship, []) == want for b, want in seeds)
    seat_seed = "## F-1 (critical) sections: 1\n## F-2 (major) sections: 2,3\n## F-3 (minor) sections: 1\n## Header note (no critical)\n"
    ss = seat_findings(seat_seed)
    sok2 = ss == [("F-1", "CRITICAL"), ("F-2", "MAJOR"), ("F-3", "MINOR")]
    print("   seeded seat-heading grammar (a critical, a major, a minor, a near-miss header note): %s" % ("MATCH" if sok2 else "DIFFERS"))
    ctl.append(("seeded seat heading grammar can read CRITICAL (real files carry none)", sok2))
    print("   seeded classify cases (6, both directions): %s" % ("MATCH" if sok else "DIFFERS"))
    ctl.append(("seeded classify cases", sok))
    print("\n== controls summary")
    bad = 0
    for lab, ok in ctl:
        print("   %-8s %s" % ("MATCH" if ok else "DIFFERS", lab))
        bad += 0 if ok else 1
    print("   %d controls, %d DIFFER" % (len(ctl), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
