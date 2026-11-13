"""Cost and a mechanical survival reading for two parts of stories-test-strategy, s321 against s319 (BL-812 item 1):
the stories party round with its repair, and test-strategy authoring with its adversarial passes and repairs.

usage: python3 -I party_ts_yield.py <OUT dir holding spawns.jsonl> [<graph repo>] [--ref <graph ref for records>]

Read-only: <OUT>/spawns.jsonl and `git show` of committed graph files. Writes nothing. Stdlib only.

Cost. s321 is partitioned by adversarial_yield.py's PARTS_321 (imported from the file beside this one, not restated),
so its party and test-strategy parts must reproduce that document's $187.19 and $125.88 ($7.49 and $5.04 per story
over 25 stories). s319 is partitioned by the description patterns PARTS_319 below (s319's descriptions differ); its
parts are printed with the s319 step total, which must equal adversarial_yield.py's S319_STEP (311 spawns, $441.19).

Survival arm, per repair block (a `### ` section of a repair record whose heading carries CRITICAL or MAJOR):
  evidence  the backtick spans (8+ characters) and double-quoted spans (12+) on the block's `- claim now asserted:` line;
  target    party: the story file the block's `- edit:` line names (else the shard's `- artifact:`);
            test strategy: the sprint's test-strategy.md;
  NEW       an evidence span absent from the target at BEFORE (the text the round read);
  class     NEW-SHIPPED   a NEW span is in the target at SHIP (the repair wrote text that reached the shipped artifact)
            NEW-GONE      NEW spans exist and none is at SHIP
            OLD-ONLY      every span was already at BEFORE (the arm cannot attribute the fix)
            NO-SPAN       the claim line carries no span
            NOT-REPAIRED  disposition is not `repaired`
Token presence is not correctness, and a NEW-SHIPPED fix may also have been caught by a later round had this round not
run; neither is measured here. Party is the first review round on the stories in both sprints.

Controls printed in the same run: the two s321 part totals against the adversarial document's figures; the s319 step
total; the C/M heading count of each repair file against a second independent count; an impossible span must not be
found in any target (it is searched in every target text the run loads).
"""
import importlib.util, json, os, re, subprocess, sys

sys.dont_write_bytecode = True   # importing adversarial_yield.py must leave no __pycache__ in the tree
HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("adversarial_yield", os.path.join(HERE, "adversarial_yield.py"))
AY = importlib.util.module_from_spec(_spec)
_argv = sys.argv; sys.argv = ["adversarial_yield.py"]
try:   # adversarial_yield.py calls main() unconditionally; with no arguments main() exits with its usage after every
    _spec.loader.exec_module(AY)   # definition above it has run, so the module's names are bound when SystemExit arrives
except SystemExit:
    pass
sys.argv = _argv
assert hasattr(AY, "PARTS_321") and hasattr(AY, "S319_STEP"), "adversarial_yield.py did not bind PARTS_321 / S319_STEP"

G_DEFAULT = os.path.expanduser("~/git/graph")
REF_DEFAULT = "f7e60625b"
IMPOSSIBLE = "QZXV-NO-SUCH-SPAN-90417"
PARTY_321 = "party round + repair"
TS_321 = "test strategy authoring, passes p1-p6 + repairs"
RECORDED_321 = {PARTY_321: 187.19, TS_321: 125.88}
PARTS_319 = [
    ("party round + repair", r"^((SM|Dev|Architect|TEA) seat (story|cross)|Party repair shard|Rerun party repair part|Serial remediator party repair)"),
    ("test strategy authoring, passes p1-p3 + repairs", r"^(Author sprint \d+ test strategy|TS p\d|TS repair|One-shot adversarial review of test strategy|Re-run test design and trace)"),
]
SPRINTS = {
    321: dict(stories=25, P="_bmad-output/planning-artifacts/s321",
              party_files=["stories-party-repair-p1.md", "stories-party-serial-repair-p1.md"],
              party_before="c3c00660f", party_ship=[("stories gate", "41484a513"), ("sprint merge", "fb6f198e7")],
              ts_files=["test-strategy-repair-p1.md", "test-strategy-repair-p2.md", "test-strategy-repair-p3.md", "test-strategy-repair-p6.md"],
              ts_before="c49d2ab9a", ts_ship=[("sprint merge", "fb6f198e7")], ts_passes=6),
    319: dict(stories=20, P="_bmad-output/planning-artifacts/s319",
              party_files=["stories-party-repair-p1.md"],
              party_before="ce821df7b", party_ship=[("sprint merge", "1da426ef9")],
              ts_files=["test-strategy-repair-p1.md", "test-strategy-repair-p2.md", "test-strategy-repair-p3.md", "test-strategy-repair-p4.md"],
              ts_before="e3fb1b442", ts_ship=[("sprint merge", "1da426ef9")], ts_passes=3),
}
CM = re.compile(r"^### .*\b(CRITICAL|MAJOR)\b")
SPAN = re.compile(r"`([^`\n]{8,})`|\"([^\"\n]{12,})\"")


def git(g, *a, ok=False):
    p = subprocess.run(["git", "-C", g] + list(a), capture_output=True)
    if p.returncode != 0:
        if ok:
            return None
        raise SystemExit("git %s failed: %s" % (" ".join(a), p.stderr.decode()))
    return p.stdout.decode("utf-8", "replace")


class Texts:
    def __init__(self, g):
        self.g = g; self.c = {}; self.missing = 0; self.loaded = 0
    def get(self, ref, path):
        k = (ref, path)
        if k not in self.c:
            t = git(self.g, "show", "%s:%s" % (ref, path), ok=True)
            if t is None:
                self.missing += 1; t = ""
            else:
                self.loaded += 1
            self.c[k] = t
        return self.c[k]


def blocks(text):
    """yield (heading, body, artifact) for every ### block; artifact is the latest `- artifact:` line above it."""
    lines = text.split("\n"); art = None; i = 0
    while i < len(lines):
        l = lines[i]
        m = re.match(r"^- artifact: (\S+)", l)
        if m:
            art = m.group(1)
        if l.startswith("### "):
            j = i + 1
            while j < len(lines) and not re.match(r"^(#{1,3} |<!-- shard)", lines[j]):
                j += 1
            yield l, "\n".join(lines[i + 1:j]), art
            i = j
        else:
            i += 1


def classify(body, target_texts):
    before, ships = target_texts
    disp = re.search(r"^- disposition: (\S+)", body, re.M)
    if not disp or disp.group(1) != "repaired":
        return {s: "NOT-REPAIRED" for s in ships}
    claim = "\n".join(re.findall(r"^- claim now asserted:.*$", body, re.M))
    spans = [m.group(1) or m.group(2) for m in SPAN.finditer(claim)]
    if not spans:
        return {s: "NO-SPAN" for s in ships}
    new = [s for s in spans if s not in before]
    if not new:
        return {s: "OLD-ONLY" for s in ships}
    return {s: ("NEW-SHIPPED" if any(x in t for x in new) else "NEW-GONE") for s, t in ships.items()}


def survival(tx, ref, sp, kind):
    cfg = SPRINTS[sp]; P = cfg["P"]
    files = cfg[kind + "_files"]; before_ref = cfg[kind + "_before"]; ship = cfg[kind + "_ship"]
    res = []; heads2 = 0
    for f in files:
        text = git(tx.g, "show", "%s:%s/%s" % (ref, P, f))
        heads2 += sum(1 for l in text.split("\n") if l.startswith("### ") and re.search(r"CRITICAL|MAJOR", l))
        for head, body, art in blocks(text):
            if not CM.match(head):
                continue
            sev = "CRITICAL" if "CRITICAL" in head else "MAJOR"
            if kind == "party":
                ed = re.search(r"^- edit: (\S+?\.md)", body, re.M)
                path = ed.group(1) if ed else art
                if not path or "/stories/" not in path:
                    m = re.search(r"(story-[\w.-]+\.md)", body)
                    path = "%s/stories/%s" % (P, m.group(1)) if m else None
                path = "%s/stories/%s" % (P, os.path.basename(path)) if path else None
            else:
                path = "%s/test-strategy.md" % P
            if path is None:
                c = {s: "NO-TARGET" for s, _ in ship}
            else:
                c = classify(body, (tx.get(before_ref, path), {s: tx.get(r, path) for s, r in ship}))
            res.append((f, sev, head, c))
    return res, heads2


def costs(rows, sp):
    s = [r for r in rows if int(r["sprint"]) == sp and r["step"] == "stories-test-strategy"]
    parts = AY.PARTS_321 if sp == 321 else PARTS_319
    acc = {}
    for r in s:
        d = r.get("description") or ""; name = "other"
        for n, rx in parts:
            if re.search(rx, d):
                name = n; break
        a = acc.setdefault(name, [0, 0.0, 0.0, 0])
        a[0] += 1; a[1] += r.get("usd") or 0; a[2] += r.get("minutes") or 0; a[3] += r.get("tok") or 0
    return len(s), sum(r.get("usd") or 0 for r in s), acc


def ts_pass_costs(rows):
    """s321 test-strategy part by pass: the pass number is `pass N` or `pN` in the description; authoring has none."""
    s = [r for r in rows if int(r["sprint"]) == 321 and r["step"] == "stories-test-strategy"
         and re.search(dict(AY.PARTS_321)[TS_321], r.get("description") or "")]
    acc = {}
    for r in s:
        d = r.get("description") or ""
        m = re.search(r"\bpass (\d)", d) or re.search(r"\bp(\d)\b", d)
        k = ("p" + m.group(1)) if m else "authoring"
        a = acc.setdefault(k, [0, 0.0]); a[0] += 1; a[1] += r.get("usd") or 0
    return acc


def shard_cm(tx, ref, sp, n):
    out = []
    for p in range(1, n + 1):
        d = "%s/shards/test-strategy-p%d" % (SPRINTS[sp]["P"], p)
        names = [x for x in (git(tx.g, "ls-tree", "--name-only", ref, d + "/") or "").split("\n") if x.endswith(".md")]
        c = sum(1 for nm in names for l in git(tx.g, "show", "%s:%s" % (ref, nm)).split("\n") if CM.match(l))
        out.append((p, len(names), c))
    return out


def main():
    argv = list(sys.argv); ref = REF_DEFAULT
    if "--ref" in argv:
        i = argv.index("--ref"); ref = argv[i + 1]; del argv[i:i + 2]
    if len(argv) < 2:
        sys.exit(__doc__)
    out = argv[1]; g = argv[2] if len(argv) > 2 else G_DEFAULT
    rows = [json.loads(l) for l in open(os.path.join(out, "spawns.jsonl"))]
    tx = Texts(g)
    print("records ref %s; graph %s; spawns %s" % (ref, g, out))
    part_usd = {}
    for sp in (321, 319):
        n = SPRINTS[sp]["stories"]; tot_n, tot_usd, acc = costs(rows, sp)
        print("== cost s%d stories-test-strategy: %d spawns $%.2f (%d stories)" % (sp, tot_n, tot_usd, n))
        for k in sorted(acc, key=lambda k: -acc[k][1]):
            a = acc[k]
            print("   %-50s %4d spawns $%8.2f  per story: %5.2f spawns $%6.2f %5.2f agent-h %6.2fM tok" % (
                k, a[0], a[1], a[0] / n, a[1] / n, a[2] / 60 / n, a[3] / 1e6 / n))
        sn = sum(a[0] for a in acc.values()); su = sum(a[1] for a in acc.values())
        print("   control partition sum %d $%.2f against the step %d $%.2f  %s" % (sn, su, tot_n, tot_usd,
              "MATCH" if (sn, round(su, 2)) == (tot_n, round(tot_usd, 2)) else "DIFFERS"))
        if sp == 321:
            for k, v in RECORDED_321.items():
                got = round(acc.get(k, [0, 0.0])[1], 2)
                print("   control %s $%.2f ($%.2f/story) against recorded $%.2f ($%.2f/story)  %s" % (
                    k, got, got / n, v, v / n, "MATCH" if got == v else "DIFFERS"))
            part_usd[(sp, "party")] = acc.get(PARTY_321, [0, 0.0])[1]; part_usd[(sp, "ts")] = acc.get(TS_321, [0, 0.0])[1]
            pc = ts_pass_costs(rows)
            print("   test-strategy part by pass (adversary + repair): " + ", ".join(
                "%s %d $%.2f" % (k, pc[k][0], pc[k][1]) for k in sorted(pc)))
            print("   control by-pass sum %d $%.2f against the part  %s" % (
                sum(v[0] for v in pc.values()), sum(v[1] for v in pc.values()),
                "MATCH" if round(sum(v[1] for v in pc.values()), 2) == round(acc[TS_321][1], 2) and
                sum(v[0] for v in pc.values()) == acc[TS_321][0] else "DIFFERS"))
        else:
            got = (tot_n, round(tot_usd, 2))
            print("   control s319 step total %s against adversarial_yield.S319_STEP %s  %s" % (
                got, AY.S319_STEP, "MATCH" if got == AY.S319_STEP else "DIFFERS"))
            part_usd[(sp, "party")] = acc.get(PARTS_319[0][0], [0, 0.0])[1]; part_usd[(sp, "ts")] = acc.get(PARTS_319[1][0], [0, 0.0])[1]
    for sp in (321, 319):
        cfg = SPRINTS[sp]
        print("== test-strategy adversarial shards s%d (C/M headings per pass): %s" % (
            sp, ", ".join("p%d %d shards %d C/M" % x for x in shard_cm(tx, ref, sp, cfg["ts_passes"]))))
        for kind in ("party", "ts"):
            res, heads2 = survival(tx, ref, sp, kind)
            print("== survival s%d %s (before %s; ship %s): %d C/M repair blocks (independent heading count %d %s)" % (
                sp, kind, cfg[kind + "_before"], ", ".join("%s %s" % x for x in cfg[kind + "_ship"]), len(res), heads2,
                "MATCH" if heads2 == len(res) else "DIFFERS"))
            for sname, _ in cfg[kind + "_ship"]:
                for f in cfg[kind + "_files"] + ["ALL"]:
                    sel = [r for r in res if f == "ALL" or r[0] == f]
                    cnt = {}
                    for r in sel:
                        k = (r[1], r[3][sname]); cnt[k] = cnt.get(k, 0) + 1
                    cls = ["NEW-SHIPPED", "NEW-GONE", "OLD-ONLY", "NO-SPAN", "NO-TARGET", "NOT-REPAIRED"]
                    line = "  ".join("%s %d (C %d)" % (c, sum(v for (s, k), v in cnt.items() if k == c),
                                                       cnt.get(("CRITICAL", c), 0)) for c in cls)
                    print("   [%s] %-36s %3d blocks: %s" % (sname, f, len(sel), line))
                ns = sum(1 for r in res if r[3][sname] == "NEW-SHIPPED")
                usd = part_usd[(sp, kind)]
                print("   [%s] part $%.2f / %d NEW-SHIPPED = $%s per surviving repaired C/M block" % (
                    sname, usd, ns, ("%.2f" % (usd / ns)) if ns else "n/a"))
    # Every CRITICAL block, with the grep -c -F token arm beside the span arm (the span arm is a floor: a claim line with no
    # backtick span reads NO-SPAN whatever happened to the fix).
    for sp in (321, 319):
        cfg = SPRINTS[sp]
        for kind in ("party", "ts"):
            text_files = [(f, git(g, "show", "%s:%s/%s" % (ref, cfg["P"], f))) for f in cfg[kind + "_files"]]
            res, _ = survival(tx, ref, sp, kind)
            crit = [r for r in res if r[1] == "CRITICAL"]
            i = 0
            for f, text in text_files:
                for head, body, art in blocks(text):
                    if not (CM.match(head) and "CRITICAL" in head):
                        continue
                    r = crit[i]; i += 1
                    ed = re.search(r"^- edit: (\S+?\.md)", body, re.M)
                    path = ("%s/stories/%s" % (cfg["P"], os.path.basename(ed.group(1)))) if (kind == "party" and ed) else (
                        "%s/test-strategy.md" % cfg["P"] if kind == "ts" else None)
                    tk = list(dict.fromkeys(t for t, p in AY.toks(body, AY.TOK_C)))
                    arm = []
                    for sname, sref in cfg[kind + "_ship"]:
                        if path:
                            b = tx.get(cfg[kind + "_before"], path); s = tx.get(sref, path)
                            arm.append("%s: %d tokens, %d at before, %d at ship" % (
                                sname, len(tk), sum(1 for t in tk if t in b), sum(1 for t in tk if t in s)))
                    print("CRITICAL s%d %s %s %s src=%s target=%s span-arm=%s token-arm=[%s]" % (
                        sp, kind, f, head[4:60], ",".join(re.findall(r"^- source: (.+)$", body, re.M))[:120],
                        os.path.basename(path) if path else None, "/".join(sorted(set(r[3].values()))), "; ".join(arm)))
            print("CRITICAL s%d %s blocks: %d" % (sp, kind, len(crit)))
    # Discriminating control for the GONE direction: the p4 CUT_SCOPE resolution (operator-adjudicated) records the
    # coverage rows whose p3-repair presence-control clause it deleted. p3 repair blocks are headed by ST321 row ids.
    res, _ = survival(tx, ref, 321, "ts")
    p3 = [r for r in res if r[0] == "test-strategy-repair-p3.md"]
    rd = git(g, "show", "%s:%s/test-strategy-resolution-p4.md" % (ref, SPRINTS[321]["P"]))
    m = re.search(r"from (\d+) coverage rows \(([^)]*)\)", rd)
    cut = set()
    for item in re.split(r",\s*", m.group(2).split(";")[0].replace("ST321-", "")):
        a = re.match(r"(\d+)(?: to (\d+))?$", item.strip())
        if a:
            cut.update(range(int(a.group(1)), int(a.group(2) or a.group(1)) + 1))
    print("control p4 CUT_SCOPE: the resolution names %s rows, %d parsed  %s" % (m.group(1), len(cut),
          "MATCH" if int(m.group(1)) == len(cut) else "DIFFERS"))
    for cls in ("NEW-GONE", "NEW-SHIPPED", "OLD-ONLY", "NO-SPAN", "NOT-REPAIRED"):
        sel = [r for r in p3 if r[3]["sprint merge"] == cls]
        ids = [int(x.group(1)) for x in (re.search(r"ST321-(\d+)", r[2]) for r in sel) if x]
        print("control p3 repair %-12s %2d blocks: %2d headed by a row the p4 cut names, %2d by another row, %2d by no row id" % (
            cls, len(sel), sum(1 for x in ids if x in cut), sum(1 for x in ids if x not in cut), len(sel) - len(ids)))
    hits = sum(1 for t in tx.c.values() if IMPOSSIBLE in t)
    print("control impossible span found in %d of %d loaded target texts (must be 0); %d target paths absent at their ref" % (
        hits, tx.loaded, tx.missing))


if __name__ == "__main__":
    main()
