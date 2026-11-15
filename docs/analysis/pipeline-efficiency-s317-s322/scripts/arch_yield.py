"""Cost partition and a mechanical yield/survival reading of the `architecture` step, s321 against s319 (BL-812 item 1).

usage: python3 -I arch_yield.py <OUT dir holding spawns.jsonl> <graph repo clone> [--ref <graph ref the repair/shard records are read at>]

Read-only: <OUT>/spawns.jsonl and `git show` / `git log` / `git ls-tree` of the committed graph clone. Writes nothing. Stdlib only.
Exit 0 only when every control reads MATCH. --ref (default fb6f198e7) is the ref the shard and repair records of BOTH sprints
are read at; the ship refs are fixed in CFG (s321 fb6f198e7, s319 1da426ef9). From party_ts_yield.py (imported, not restated) it
uses CM, blocks(), git() and claim_spans().

1. Cost. Every `architecture` spawn of s321 and s319 is assigned by DESCRIPTION to one sub-part: party round + repair,
   elicitation + repair, adversarial pass N (review + its repair, printed apart and together), other. A repair carrying no pass
   number is assigned by start time (the latest pass whose reviews began before it); a numbered repair is checked against that
   rule (must agree). The partition must sum to the step total. Per story and absolute: spawns, $, agent-minutes. 1b localizes
   the s319 -> s321 per-story rise by sub-part.
2. Findings. C/M = `### ` headings carrying the whole word CRITICAL or MAJOR in a round's shards (the party round has no
   committed review shards; its stand-in is the C/M blocks of its repair record). Read sha per round. A span-overlap proxy for
   "refound by an earlier round" (>=2 shared backtick spans of 12+ chars; NOT a judgment). s321 p1 and p2 read one sha.
3. Survival (a FLOOR, counted in BLOCKS of a repair record, not findings). Per C/M repair block with disposition `repaired`:
   the backtick (8+) and double-quoted (12+) spans of its `- claim now asserted:` line, as party_ts_yield.claim_spans pairs
   them (PRE_FIX_SPAN, the single regex it replaced, mispairs a short span with the next one's backtick and is kept only as
   the seeded control's other side). NEW = absent from the text the
   round READ (BEFORE: the committed docs/architecture.md state or sections/.before file whose sha8 equals the round's read sha,
   plus the spine). Classes: NEW-SHIPPED (a NEW span is in docs/architecture.md or the spine at the sprint merge);
   NEW-SUPERSEDED (at the round's own output state, absent at ship: later rounds rewrote it); NEW-NOT-SEEN-AFTER (absent at
   the output state too: the arm cannot see where the fix landed); OLD-ONLY (every span already in BEFORE: cannot attribute);
   NO-SPAN; NO-TARGET (edit names no architecture file); NOT-REPAIRED. Where the read sha has no committed text, NEW is taken
   against the pre-sprint document and reads BASE-NEW-SHIPPED / BASE-NEW-GONE: that counts authoring as well as repair and is
   NOT a floor. 3b lists every CRITICAL finding with its repair blocks (by `- source:` incl. `carry:` sources, else span-linked).
Controls printed in the same run: step totals and per-story figures against the lead's; partition sums; numbered repairs against
the time rule; architecture-p1 / architecture-adversarial-p1 shard files byte-identical (counted once); BEFORE sha equals the
round's read sha; repair-record C/M heading count against a second count; every architecture-*repair*.md assigned to a
sub-part; seeded claim_spans / classify2 / overlap cases (both directions); an impossible description token and an impossible
finding token each count 0 beside a positive token present in the same corpus.
"""
import hashlib, importlib.util, json, os, re, subprocess, sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("party_ts_yield", os.path.join(HERE, "party_ts_yield.py"))
PTS = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(PTS)          # party_ts_yield guards main() with __name__; this binds names only
for _n in ("CM", "claim_spans", "blocks", "classify", "git"):
    assert hasattr(PTS, _n), "party_ts_yield.py does not bind " + _n
claim_spans = PTS.claim_spans
PRE_FIX_SPAN = re.compile(r"`([^`\n]{8,})`|\"([^\"\n]{12,})\"")   # the grammar claim_spans replaced; controls only

REF_DEFAULT = "fb6f198e7"
IMPOSSIBLE_DESC = "QZXV-ARCH-NEVER-8841"
IMPOSSIBLE_FIND = "QZXV-ARCH-FINDING-NEVER-8842"
ART = "_bmad-output/planning-artifacts/%s"
CFG = {
    321: dict(label="s321", stories=25, ctl=(118, 4.72, 10.41), ship="fb6f198e7", base="72e1cd749",
              win=("2026-11-02T00:00", "2026-11-08T12:00"), spine=True),
    319: dict(label="s319", stories=20, ctl=(135, 6.75, 9.48), ship="1da426ef9", base="28a15fce4",
              win=("2026-10-14T00:00", "2026-10-23T12:00"), spine=False),
}
# (kind, regex, pass-number group or None); first match wins. Party and elicitation precede the pass rules.
RULES = {
    321: [("elic", r"licit", None),
          ("party", r"^Party (architect|dev|tea|pm)\b|^Party repair|^Party serial", None),
          ("rev", r"^(?:Adversarial pass (\d)|Architecture review p(\d)|Pass (\d) |Adversary p(\d) )", "any"),
          ("rep", r"^(?:Repair p(\d)|Serial repair p(\d))", "any")],
    319: [("elic", r"licit", None),
          ("party", r"^(Architect|Dev|TEA|PM) (part|cross) .*review$|^Party repair|^Serial remediator party repair", None),
          ("rev", r"^(?:Adversarial|Adversary) p(\d) (?:part|cross)", "any"),
          ("rep", r"^(?:Remediator p(\d)|Serial remediator p(\d)|Adversarial serial remediator p(\d))", "any"),
          ("rep", r"^Adversarial repair section", None)],
}
REPAIR_FILES = [("party", r"^architecture-party-repair"), ("elic", r"^architecture-elicitation-(?:serial-)?repair"),
                ("pass", r"^architecture-(?:serial-)?repair-p(\d)\.md$")]


def gitb(g, *a):
    p = subprocess.run(["git", "-C", g] + list(a), capture_output=True)
    return p.stdout if p.returncode == 0 else None


def sha8(b):
    return hashlib.sha256(b).hexdigest()[:8]


# ---------------------------------------------------------------- cost
def assign(sp, desc, review_start, start):
    """-> (kind, pass) ; kind in party elic rev rep other."""
    for kind, rx, grp in RULES[sp]:
        m = re.search(rx, desc)
        if not m:
            continue
        n = None
        if grp == "any":
            n = int(next(x for x in m.groups() if x))
        if kind == "rep" and n is None:   # numberless repair: latest pass whose reviews began before it
            prior = [p for p, t in review_start.items() if t <= start]
            n = max(prior) if prior else None
        return kind, n
    return "other", None


def cost(rows, sp):
    s = [r for r in rows if int(r["sprint"]) == sp and r["step"] == "architecture"]
    review_start = {}
    for r in s:
        k, n = assign(sp, r.get("description") or "", {}, "")
        if k == "rev":
            review_start[n] = min(review_start.get(n, "9"), r["start"])
    acc = {}; disagree = []
    for r in s:
        d = r.get("description") or ""
        k, n = assign(sp, d, review_start, r["start"])
        if k == "rep" and re.search(r"p\d|pass \d", d):
            prior = [p for p, t in review_start.items() if t <= r["start"]]
            if prior and max(prior) != n:
                disagree.append((d, n, max(prior)))
        key = k if k in ("party", "elic", "other") else "p%d" % n
        sub = None if key in ("party", "elic", "other") else k
        a = acc.setdefault((key, sub), [0, 0.0, 0.0])
        a[0] += 1; a[1] += r.get("usd") or 0; a[2] += r.get("minutes") or 0
    return s, acc, disagree


def fold(acc):
    out = {}
    for (key, sub), a in acc.items():
        o = out.setdefault(key, [0, 0.0, 0.0])
        for i in range(3):
            o[i] += a[i]
    return out


def order(keys):
    return sorted(keys, key=lambda k: (0, 0) if k == "party" else (1, 0) if k == "elic" else (3, 0) if k == "other" else (2, int(k[1:])))


# ---------------------------------------------------------------- git corpus
def listdir(g, ref, d):
    return [n for n in (PTS.git(g, "ls-tree", "--name-only", ref, d + "/", ok=True) or "").split("\n") if n]


def shard_files(g, ref, sp, d):
    return [n for n in listdir(g, ref, "%s/shards/%s" % (ART % ("s%d" % sp), d)) if n.endswith(".md")]


def findings(text):
    """[(id, sev, title, body)] for each C/M `### ` block of a shard."""
    out = []
    for head, body, _ in PTS.blocks(text):
        if not PTS.CM.match(head):
            continue
        sev = "CRITICAL" if re.search(r"\bCRITICAL\b", head) else "MAJOR"
        m = re.match(r"^### (F-\d+)\s*[—-]?\s*(?:CRITICAL|MAJOR)?\s*[—-]?\s*(.*)$", head)
        out.append((m.group(1) if m else "?", sev, (m.group(2) if m else head)[:90], body))
    return out


def spans(body):
    return set(claim_spans(body, 12, len(body) + 1))   # code spans only: no double-quoted span is that long


class Corpus:
    def __init__(self, g, ref):
        self.g = g; self.ref = ref; self.text = {}   # name -> text, everything loaded, for the token controls
    def show(self, ref, path):
        b = gitb(self.g, "show", "%s:%s" % (ref, path))
        t = "" if b is None else b.decode("utf-8", "replace")
        if b is not None:
            self.text[(ref, path)] = t
        return None if b is None else t


def states(c, sp):
    """sha8 -> (label, doc, spine). Committed docs/architecture.md states of the sprint window plus every sections/.before."""
    cfg = CFG[sp]; P = ART % ("s%d" % sp); sp_path = P + "/architecture-spine/ARCHITECTURE-SPINE.md"
    st = {}; first_spine = ""
    order_ = []
    log = gitb(c.g, "log", "--all", "--reverse", "--format=%h", "--since=" + cfg["win"][0], "--until=" + cfg["win"][1],
               "--", "docs/architecture.md")
    commits = log.decode().split() if log else []
    for ch in commits:
        d = gitb(c.g, "show", "%s:docs/architecture.md" % ch)
        s = gitb(c.g, "show", "%s:%s" % (ch, sp_path)) if cfg["spine"] else None
        if d is None:
            continue
        if s and not first_spine:
            first_spine = s.decode("utf-8", "replace")
        order_.append(sha8(d))
        st.setdefault(sha8(d), ("commit " + ch, d.decode("utf-8", "replace"), (s or b"").decode("utf-8", "replace")))
    for n in listdir(c.g, c.ref, P + "/shards"):
        for b in listdir(c.g, c.ref, n):
            if b.endswith("/sections"):
                bf = gitb(c.g, "show", "%s:%s/.before" % (c.ref, b))
                if bf:
                    st.setdefault(sha8(bf), (".before of " + n.split("/")[-1], bf.decode("utf-8", "replace"), first_spine))
    return st, order_


# ---------------------------------------------------------------- survival
def repair_files(c, sp):
    P = ART % ("s%d" % sp); out = []
    for n in listdir(c.g, c.ref, P):
        b = n.split("/")[-1]
        if not b.endswith(".md"):
            continue
        for kind, rx in REPAIR_FILES:
            m = re.search(rx, b)
            if m:
                out.append(("party" if kind == "party" else "elic" if kind == "elic" else "p" + m.group(1), n))
                break
    return out


def classify2(body, before, texts):
    disp = re.search(r"^- disposition: (\S+)", body, re.M)
    if not disp or disp.group(1) != "repaired":
        return {k: "NOT-REPAIRED" for k in texts}
    sp = claim_spans("\n".join(re.findall(r"^- claim now asserted:.*$", body, re.M)))
    if not sp:
        return {k: "NO-SPAN" for k in texts}
    new = [x for x in sp if x not in before]
    if not new:
        return {k: "OLD-ONLY" for k in texts}
    return {k: ("NEW-SHIPPED" if any(x in t for x in new) else "NEW-GONE") for k, t in texts.items()}


def surv_target(body):
    ed = re.search(r"^- edit: (.*)$", body, re.M)
    if not ed:
        return False
    paths = [re.sub(r":[\w:,\-\s]*$", "", x.strip().split(" (")[0]) for x in ed.group(1).split(", ")]
    return any(("docs/architecture.md" in p) or ("/sections/" in p) or ("ARCHITECTURE-SPINE" in p) for p in paths)


def survival(c, sp, st, round_sha, ship_doc, ship_spine, base_doc, commit_order):
    cfg = CFG[sp]; res = []; recs = []
    for key, path in repair_files(c, sp):
        text = c.show(c.ref, path) or ""
        recs.append((key, path.split("/")[-1], text))
    for key, name, text in recs:
        want = round_sha.get(key)
        hit = st.get(want) if want else None
        seq = [k for k in ["party", "elic"] + ["p%d" % p for p in range(1, 6)] if round_sha.get(k)]
        nxt = [round_sha[k] for k in seq[seq.index(key) + 1:] if round_sha[k] != want] if key in seq else []
        after_sha = nxt[0] if nxt else (commit_order[commit_order.index(want) + 1] if want in commit_order and commit_order.index(want) + 1 < len(commit_order) else None)
        after = st.get(after_sha) if after_sha else None
        if hit:
            before = hit[1] + "\n" + hit[2]; fb = False; lab = hit[0]
        else:
            before = base_doc; fb = True; lab = "BASE %s (read sha %s has no committed text)" % (cfg["base"], want)
        for head, body, _ in PTS.blocks(text):
            if not PTS.CM.match(head):
                continue
            sev = "CRITICAL" if re.search(r"\bCRITICAL\b", head) else "MAJOR"
            if not re.search(r"^- disposition: repaired", body, re.M):
                k = "NOT-REPAIRED"
            elif not surv_target(body):
                k = "NO-TARGET"
            else:
                after_t = (after[1] + "\n" + after[2]) if after else None
                k = classify2(body, before, {"ship": ship_doc + "\n" + ship_spine, "after": after_t or ""})
                kk = k["ship"]
                if fb and kk in ("NEW-SHIPPED", "NEW-GONE"):
                    kk = "BASE-" + kk
                elif kk == "NEW-GONE" and after_t is not None:
                    kk = "NEW-SUPERSEDED" if k["after"] == "NEW-SHIPPED" else "NEW-NOT-SEEN-AFTER"
                k = kk
            res.append((key, name, sev, head, body, k, lab))
    return res, recs


# ---------------------------------------------------------------- main
def main():
    argv = list(sys.argv); ref = REF_DEFAULT
    if "--ref" in argv:
        i = argv.index("--ref"); ref = argv[i + 1]; del argv[i:i + 2]
    if len(argv) < 3:
        sys.exit(__doc__)
    out, g = argv[1], argv[2]
    rows = [json.loads(l) for l in open(os.path.join(out, "spawns.jsonl"))]
    ctl = []   # (label, ok)
    print("graph %s ref %s spawns %s" % (g, ref, out))
    costs = {}
    for sp in (321, 319):
        cfg = CFG[sp]; n = cfg["stories"]
        s, acc, dis = cost(rows, sp)
        f = fold(acc); tot = (len(s), sum(r.get("usd") or 0 for r in s), sum(r.get("minutes") or 0 for r in s))
        costs[sp] = (f, tot, acc)
        print("\n== 1. cost %s architecture: %d spawns $%.2f %.1f agent-min over %d stories = %.2f spawns $%.2f %.2f agent-h per story" % (
            cfg["label"], tot[0], tot[1], tot[2], n, tot[0] / n, tot[1] / n, tot[2] / 60 / n))
        print("   %-18s %6s %9s %9s | %6s %8s %8s" % ("sub-part", "spawns", "$", "agent-min", "sp/st", "$/st", "agent-h/st"))
        for k in order(f):
            a = f[k]
            print("   %-18s %6d %9.2f %9.1f | %6.2f %8.2f %8.2f" % (k, a[0], a[1], a[2], a[0] / n, a[1] / n, a[2] / 60 / n))
            if k.startswith("p"):
                for sub in ("rev", "rep"):
                    b = acc.get((k, sub))
                    if b:
                        print("     %-16s %6d %9.2f %9.1f | %6.2f %8.2f %8.2f" % ("  " + ("review" if sub == "rev" else "repair"), b[0], b[1], b[2], b[0] / n, b[1] / n, b[2] / 60 / n))
        sn = sum(a[0] for a in f.values()); su = sum(a[1] for a in f.values()); sm = sum(a[2] for a in f.values())
        ok = sn == tot[0] and round(su, 2) == round(tot[1], 2) and abs(sm - tot[2]) < 0.05
        ctl.append(("%s partition sums to step total (%d, $%.2f, %.1f min)" % (cfg["label"], sn, su, sm), ok))
        c0 = cfg["ctl"]
        ok2 = tot[0] == c0[0] and round(tot[0] / n, 2) == c0[1] and round(tot[1] / n, 2) == c0[2]
        ctl.append(("%s step reads %d spawns, %.2f spawns/story, $%.2f/story (lead's control %s)" % (cfg["label"], tot[0], tot[0] / n, tot[1] / n, c0), ok2))
        ctl.append(("%s numbered repairs agree with the start-time rule (%d disagree)" % (cfg["label"], len(dis)), not dis))
    print("\n== 1b. where the s319 -> s321 rise sits (per story; both sprints' stories counts as stated above)")
    n1, n9 = CFG[321]["stories"], CFG[319]["stories"]
    f1, f9 = costs[321][0], costs[319][0]
    print("   %-10s %9s %9s %8s | %9s %9s | %9s %9s" % ("sub-part", "$/st 319", "$/st 321", "delta", "sp/st 319", "sp/st 321", "ah/st 319", "ah/st 321"))
    d_sum = 0.0
    for k in order(set(f1) | set(f9)):
        a = f1.get(k, [0, 0.0, 0.0]); b = f9.get(k, [0, 0.0, 0.0]); d = a[1] / n1 - b[1] / n9; d_sum += d
        print("   %-10s %9.2f %9.2f %+8.2f | %9.2f %9.2f | %9.2f %9.2f" % (k, b[1] / n9, a[1] / n1, d, b[0] / n9, a[0] / n1, b[2] / 60 / n9, a[2] / 60 / n1))
    tot_d = costs[321][1][1] / n1 - costs[319][1][1] / n9
    print("   sum of deltas %+.2f against step delta %+.2f" % (d_sum, tot_d))
    ctl.append(("rise deltas sum to the step delta", abs(d_sum - tot_d) < 0.005))

    # ------------- corpus
    corpora = {}
    for sp in (321, 319):
        cfg = CFG[sp]; P = ART % ("s%d" % sp)
        c = Corpus(g, ref if sp == 321 else ref)     # records of both sprints are read at the same ref (s319 files persist)
        rounds = {}   # key -> list of (file, text)
        dirs = {"elic": "architecture-elicitation"}
        for p in range(1, 6):
            dirs["p%d" % p] = "architecture-p%d" % p
        for key, d in dirs.items():
            fl = shard_files(g, ref, sp, d)
            if fl:
                rounds[key] = [(f.split("/")[-1], c.show(ref, f) or "") for f in fl]
        corpora[sp] = (c, rounds)
        # duplicate adversarial-p1 directory
        dup = shard_files(g, ref, sp, "architecture-adversarial-p1")
        if dup:
            same = all(c.show(ref, f) == dict(rounds["p1"]).get(f.split("/")[-1]) for f in dup) and len(dup) == len(rounds["p1"])
            ctl.append(("%s architecture-adversarial-p1 shards byte-identical to architecture-p1 (%d files; counted once)" % (cfg["label"], len(dup)), same))

    print("\n== 2. findings (C/M `### ` headings) per round, from the shards; read sha per round")
    cmall = {}; round_sha = {}
    for sp in (321, 319):
        cfg = CFG[sp]; c, rounds = corpora[sp]; n = cfg["stories"]
        print("  %s" % cfg["label"])
        prev = None; round_sha[sp] = {}
        for key in ["elic"] + ["p%d" % p for p in range(1, 6)]:
            if key not in rounds:
                continue
            fl = rounds[key]
            sh = set(re.search(r"^artifact_sha: (\w{8})", t, re.M).group(1) for _, t in fl if re.search(r"^artifact_sha: (\w{8})", t, re.M))
            fs = [(f, x) for f, t in fl for x in findings(t)]
            cr = sum(1 for _, x in fs if x[1] == "CRITICAL")
            cmall[(sp, key)] = fs
            sha = sorted(sh)[0] if len(sh) == 1 else "/".join(sorted(sh))
            round_sha[sp][key] = sha
            print("    %-5s %2d shards  C/M %3d (CRITICAL %d, MAJOR %d)  %.2f C/M per story  read sha %s%s" % (
                key, len(fl), len(fs), cr, len(fs) - cr, len(fs) / n, sha, "   SAME SHA AS %s" % prev[0] if prev and prev[1] == sha else ""))
            prev = (key, sha)
    # party stand-in
    for sp in (321, 319):
        c, _ = corpora[sp]; P = ART % ("s%d" % sp)
        nonrep = [x for x in listdir(g, ref, P + "/shards") if "party" in x and "repair" not in x]
        txt = c.show(ref, "%s/architecture-party-repair-p1.md" % P) or ""
        blocks_ = [h for h, _, _ in PTS.blocks(txt) if PTS.CM.match(h)]
        srcs = set()
        for _, body, _ in PTS.blocks(txt):
            for m in re.finditer(r"^- source: (.+)$", body, re.M):
                srcs.update(re.findall(r"\S+\.md#F-\d+", m.group(1)))
        print("  %s party round: review shards committed under shards/: %d (party seats' own files are not in the clone); stand-in = %d C/M repair blocks naming %d distinct seat findings" % (
            CFG[sp]["label"], len(nonrep), len(blocks_), len(srcs)))
        ctl.append(("%s party review shard dirs found by the same ls-tree (must be 0, repair dirs excluded)" % CFG[sp]["label"], len(nonrep) == 0))

    print("\n   span-overlap proxy for refound (NOT a judgment): a C/M finding sharing >=2 backtick spans (12+ chars) with some C/M finding of an EARLIER round")
    for sp in (321, 319):
        seq = [k for k in ["elic"] + ["p%d" % p for p in range(1, 6)] if (sp, k) in cmall]
        for i, key in enumerate(seq):
            if i == 0:
                continue
            prior = [(k, x) for k in seq[:i] for _, x in cmall[(sp, k)]]
            hit = 0
            for _, x in cmall[(sp, key)]:
                sx = spans(x[3])
                if any(len(sx & spans(y[3])) >= 2 for _, y in prior):
                    hit += 1
            # control: the same test against a prior set that is the finding itself must hit (arm can fire)
            ex = ""
            if sp == 321 and key == "p2":
                p1o = sum(1 for _, x in cmall[(321, "p2")] if any(len(spans(x[3]) & spans(y[3])) >= 2 for _, y in cmall[(321, "p1")]))
                ex = "   (%d of them overlap p1 itself; p1 and p2 read the SAME sha)" % p1o
            print("    %s %-3s %2d of %2d C/M findings overlap an earlier round%s" % (CFG[sp]["label"], key, hit, len(cmall[(sp, key)]), ex))
    sa = "see `span-number-one-aaa` and `span-number-two-bbb`"; sb = "also `span-number-one-aaa` plus `span-number-two-bbb`"; sc = "only `span-number-one-aaa`"
    sd = "x `ENV` y `span-number-one-aaa` z `T` w `span-number-two-bbb`"   # short spans between long ones must not shift the pairing
    ctl.append(("overlap arm fires on a seeded 2-span pair (also with short spans interleaved) and stays quiet on a 1-span near-miss", len(spans(sa) & spans(sb)) >= 2 and len(spans(sa) & spans(sc)) < 2 and len(spans(sd) & spans(sb)) >= 2))

    # ------------- survival
    sv = {}
    for sp in (321, 319):
        cfg = CFG[sp]; c, rounds = corpora[sp]
        st, corder = states(c, sp)
        ship_doc = c.show(cfg["ship"], "docs/architecture.md") or ""
        ship_spine = (c.show(cfg["ship"], ART % ("s%d" % sp) + "/architecture-spine/ARCHITECTURE-SPINE.md") or "") if cfg["spine"] else ""
        base_doc = c.show(cfg["base"], "docs/architecture.md") or ""
        # round read sha by sub-part key: shards where they exist, else the record's own first artifact_sha_before
        rs = dict(round_sha[sp]); rs["party"] = None
        P = ART % ("s%d" % sp)
        pr = c.show(ref, P + "/architecture-party-repair-p1.md") or ""
        m = re.search(r"artifact_sha_before: (\w{8})", pr); rs["party"] = m.group(1) if m else None
        res, recs = survival(c, sp, st, rs, ship_doc, ship_spine, base_doc, corder)
        sv[sp] = (res, recs, rs)
        print("\n== 3. survival %s (ship = sprint merge %s; docs/architecture.md%s)" % (cfg["label"], cfg["ship"], " + spine" if cfg["spine"] else ""))
        print("   states resolvable by read sha: %d (committed doc states and sections/.before files)" % len(st))
        classes = ["NEW-SHIPPED", "NEW-SUPERSEDED", "NEW-NOT-SEEN-AFTER", "NEW-GONE", "OLD-ONLY", "NO-SPAN", "NO-TARGET", "NOT-REPAIRED", "BASE-NEW-SHIPPED", "BASE-NEW-GONE"]
        n = cfg["stories"]
        for key in order(set(r[0] for r in res)):
            sel = [r for r in res if r[0] == key]
            cnt = {k: sum(1 for r in sel if r[5] == k) for k in classes}
            crit = sum(1 for r in sel if r[2] == "CRITICAL")
            usd = costs[sp][0].get(key, [0, 0.0, 0.0])[1]
            usd_rep = costs[sp][2].get((key, "rep"), [0, 0.0, 0.0])[1] if key.startswith("p") else usd
            print("   %-5s BEFORE: %s" % (key, sel[0][6] if sel else "-"))
            if key == "p2" and sp == 321:
                cr = [r for r in sel if re.search(r"^- source: .*carry:", r[4], re.M)]
                ow = [r for r in sel if r not in cr]
                print("         record split: %d blocks carry an earlier pass's finding (`carry:architecture-adversarial-p1/...`), %d name a p2 shard finding; carry classes %s; own classes %s" % (
                    len(cr), len(ow), {k: sum(1 for r in cr if r[5] == k) for k in classes if any(r[5] == k for r in cr)},
                    {k: sum(1 for r in ow if r[5] == k) for k in classes if any(r[5] == k for r in ow)}))
            print("         %2d C/M repair blocks (%d CRITICAL): %s" % (len(sel), crit, "  ".join("%s %d" % (k, v) for k, v in cnt.items() if v)))
            ns = cnt["NEW-SHIPPED"]
            if ns:
                print("         floor: %d NEW-SHIPPED; sub-part $%.2f / %d = $%.2f per surviving block%s" % (ns, usd, ns, usd / ns,
                      ("; repair spawns alone $%.2f" % usd_rep) if key.startswith("p") else ""))
        # BEFORE sha verification
        for key, name, text in recs:
            m = re.search(r"artifact_sha_before: (\w{8})", text)
            rsha = rs.get(key); hit = st.get(rsha)
            if rsha and hit:
                ctl.append(("%s %s: BEFORE text sha %s equals the round's read sha %s (%s); record's own first before-sha %s" % (
                    cfg["label"], name, sha8((hit[1]).encode()), rsha, hit[0], m.group(1) if m else None), sha8(hit[1].encode()) == rsha))
        # every repair-ish record assigned
        allrep = [n for n in listdir(g, ref, ART % ("s%d" % sp)) if re.search(r"/architecture-[\w-]*repair[\w-]*\.md$", n)]
        ctl.append(("%s every architecture-*repair*.md file (%d) is assigned to a sub-part (%d)" % (cfg["label"], len(allrep), len(recs)), len(allrep) == len(recs)))
        # heading count control
        for key, name, text in recs:
            a = sum(1 for r in res if r[1] == name)
            b = len(re.findall(r"^### .*\b(?:CRITICAL|MAJOR)\b", text, re.M))
            ctl.append(("%s %s C/M repair blocks %d against a second count %d" % (cfg["label"], name, a, b), a == b))

    print("\n== 3b. CRITICAL findings (rare high-consequence): shard finding joined to its repair blocks by `- source: N.md#F-k`")
    for sp in (321, 319):
        res, recs, rs = sv[sp]
        for key in ["elic"] + ["p%d" % p for p in range(1, 6)]:
            for f, x in cmall.get((sp, key), []):
                if x[1] != "CRITICAL":
                    continue
                tag = "%s#%s" % (f, x[0])
                alias = re.sub(r"^cross-(\d+)\.md#", r"cross-group-\1-", tag)
                carry = "carry:architecture-adversarial-%s/%s" % (key, tag)   # a pass whose findings a LATER repair carried (s321 p1 -> repair p2)
                js = [r for r in res if (r[0] == key and re.search(r"^- source: .*(?:%s|%s)(?!\d)" % (re.escape(tag), re.escape(alias)), r[4], re.M))
                      or re.search(r"^- source: .*%s(?!\d)" % re.escape(carry), r[4], re.M)]
                lk = [r for r in res if not js and len(spans(x[3]) & spans(r[4])) >= 2]
                print("  %s %-4s %-12s %-70s -> %s" % (CFG[sp]["label"], key, tag, x[2][:70], ", ".join("%s/%s:%s" % (r[0], r[1].replace("architecture-", "").replace(".md", ""), r[5]) for r in js) or ("NO SOURCE-JOINED BLOCK; span-linked blocks (>=2 shared spans): " + (", ".join("%s:%s" % (r[1].replace("architecture-", "").replace(".md", ""), r[5]) for r in lk) or "none"))))

    # ------------- controls
    c, _ = corpora[321]
    ad = [r for r in rows if r["step"] == "architecture"]
    n0 = sum(1 for r in ad if IMPOSSIBLE_DESC in (r.get("description") or ""))
    npos = sum(1 for r in ad if "Elicitation" in (r.get("description") or ""))
    ctl.append(("impossible description token %s counts %d; positive token 'Elicitation' counts %d (same rows)" % (IMPOSSIBLE_DESC, n0, npos), n0 == 0 and npos > 0))
    texts = [t for cc, _ in corpora.values() for t in cc.text.values()]
    nf = sum(1 for t in texts if IMPOSSIBLE_FIND in t); npf = sum(1 for t in texts if "MAJOR" in t)
    ctl.append(("impossible finding token %s found in %d of %d loaded texts; positive token 'MAJOR' in %d" % (IMPOSSIBLE_FIND, nf, len(texts), npf), nf == 0 and npf > 0))
    seed_before = "the old text has `old-span-abcdefghij` only"
    seed = lambda claim: "- disposition: repaired\n- claim now asserted: " + claim
    k1 = classify2(seed("`new-span-zyxwvutsrq`"), seed_before, {"s": "x `new-span-zyxwvutsrq` y"})["s"]
    k2 = classify2(seed("`new-span-zyxwvutsrq`"), seed_before, {"s": "nothing here"})["s"]
    k3 = classify2(seed("`old-span-abcdefghij`"), seed_before, {"s": "x"})["s"]
    k4 = classify2(seed("`%s-xxxxxxxx`" % IMPOSSIBLE_FIND), seed_before, {"s": "none"})["s"]
    ctl.append(("classify seeds: NEW-SHIPPED=%s NEW-GONE=%s OLD-ONLY=%s impossible-span=%s" % (k1, k2, k3, k4),
                (k1, k2, k3, k4) == ("NEW-SHIPPED", "NEW-GONE", "OLD-ONLY", "NEW-GONE")))
    print("\n   s321 p2 re-reviewed the SAME sha as p1: each p2 C/M finding, and whether it shares >=2 spans with a p1 C/M finding")
    p1f = [x for _, x in cmall[(321, "p1")]]
    for f, x in cmall[(321, "p2")]:
        ov = any(len(spans(x[3]) & spans(y[3])) >= 2 for y in p1f)
        print("    p2 %-12s %-8s %-8s %s" % ("%s#%s" % (f, x[0]), x[1], "OVERLAPS-p1" if ov else "p2-ONLY", x[2][:80]))
    # the sibling grammar's mispairing: seeded (a short span between two long ones) and measured over every claim line loaded
    seed_claim = "`ENV` residual and `config.py:346` stated, plus `longer-span-xyz`"
    sib = [m.group(1) or m.group(2) for m in PRE_FIX_SPAN.finditer(seed_claim)]
    ctl.append(("seeded claim: this script's pairing reads %s; the pre-fix grammar reads %s (must differ, proving the mispairing is real)" % (claim_spans(seed_claim), sib), claim_spans(seed_claim) != sib and "config.py:346" in claim_spans(seed_claim)))
    seed_q = 'AC6 reads "the record prints `db=unknown` and never the raw value" and `grep -F "inside-a-code-span" f`'
    want_q = ["db=unknown", 'grep -F "inside-a-code-span" f', "the record prints `db=unknown` and never the raw value"]
    ctl.append(("seeded claim: a quoted sentence keeps its code span, a quote inside a code span is no delimiter: %s" % claim_spans(seed_q, 8, 12), claim_spans(seed_q, 8, 12) == want_q))
    seed_d = "the awk prints (`` `_execute_swap_same_pool` `` with padding) and `ENV`"
    ctl.append(("seeded claim: a double-backtick span is one span: %s" % claim_spans(seed_d), claim_spans(seed_d) == ["`_execute_swap_same_pool`"]))
    tot = dif = 0
    for sp in (321, 319):
        for r in sv[sp][0]:
            for cl in re.findall(r"^- claim now asserted:.*$", r[4], re.M):
                tot += 1
                if sorted(claim_spans(cl)) != sorted(m.group(1) or m.group(2) for m in PRE_FIX_SPAN.finditer(cl)):
                    dif += 1
    print("\n   span grammar: %d of %d claim lines (all C/M repair blocks, both sprints) read a different span set under the pre-fix grammar than under claim_spans" % (dif, tot))
    print("\n== 4. controls")
    bad = 0
    for lab, ok in ctl:
        print("  %-7s %s" % ("MATCH" if ok else "DIFFERS", lab))
        bad += 0 if ok else 1
    print("controls: %d, DIFFERS: %d" % (len(ctl), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
