"""Mechanical half of the s321 step-value reading for the three gate labels BL-812 records as risen with no value reading:
gate-validation[implementation], gate-validation[architecture], gate-validation[requirements].

usage: python3 -I gate_label_yield.py <OUT dir holding spawns.jsonl> [<graph repo>]

Read-only: <OUT>/spawns.jsonl and `git show` / `git ls-tree` of committed graph objects. Writes nothing.
It prints five blocks, each with its controls in the same run:
  1. per-label spawns, subagent dollars and agent-minutes, s319 and s321, against the figures BL-812 records (MATCH or
     DIFFERS), then the like-for-like pair (implementation + gate-validation[implementation]);
  2. the gate-validation[implementation] spawns partitioned by role class, both sprints, the class sum checked against the
     label total, and the per-class change localizing the rise;
  3. per class, what its deliverables found and whether a fix followed that is present in the s321 sprint merge, as a floor:
     (a) verdict tokens in the spawns' own final_text (the extractor keeps at most 1500 characters, so a token can be cut off);
     (b) the review files (docs/reviews/sNNN/<story>-code-review|qa-validation[-pN].md), whole sprint, ALL step labels
         (a review file cannot be attributed to one label here): NEEDS_REWORK files and series that ended APPROVED or PASS;
     (c) the gate-adjudication verdict files of the sprint's date window: FAIL checks and a later PASS of the same check;
     (d) each gate-labelled dev spawn against its story's review series;
  4. the small gate labels' spawns enumerated, each with what it produced read off the committed tree;
  5. controls: impossible step, impossible token (absent from the tree), positive tokens (present), duplicate units.
It does NOT judge whether a finding was valid or a fix correct: that reading is in the findings text, per item.
Verdict-file dates for s319 are not in the graph clone (printed as 0 against a positive control), so (c) is s321 only.
"""
import collections, json, os, re, subprocess, sys

G_DEFAULT = os.path.expanduser("~/git/graph")
SHIP = "fb6f198e7"          # Sprint 321 squash on main (#1303)
STORIES = {319: 20, 321: 25}
LAB = "gate-validation[implementation]"
RECORDED = {  # (sprint, label): (spawns per story, $ per story), from BL-812 and the lead's brief
    (319, LAB): (6.70, 4.61), (321, LAB): (5.04, 6.43),
    (321, "gate-validation[architecture]"): (0.16, 0.10), (321, "gate-validation[requirements]"): (0.16, 0.13),
    (319, "gate-validation[architecture]"): (None, 0.05), (319, "gate-validation[requirements]"): (None, 0.09),
    (319, "implementation"): (24.80, 26.08), (321, "implementation"): (6.16, 11.46)}
NEG_TOKEN = "ZQX-NEVER-TOKEN-77"


def git(g, *a):
    r = subprocess.run(["git", "-C", g] + list(a), capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def show(g, path):
    return git(g, "show", "%s:%s" % (SHIP, path))


def cls(r):
    ro = r["role"]
    if ro in ("code-reviewer", "code-reviewer-escalated"): return "code review"
    if ro == "qa": return "qa"
    if ro == "gate-adjudicator": return "gate adjudicator"
    if ro in ("dev", "dev-escalated"): return "dev build or rework"
    if ro == "remediator": return "remediator"
    if ro == "ops": return "ops reads"
    return "other:" + ro


def tot(rs):
    return len(rs), sum(r["usd"] or 0 for r in rs), sum(r["minutes"] or 0 for r in rs)


def match(a, b, tol=0.006):
    return "MATCH" if b is not None and abs(a - b) < tol else ("DIFFERS" if b is not None else "n/a")


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: gate_label_yield.py <OUT dir> [<graph repo>]")
    out = sys.argv[1]; g = sys.argv[2] if len(sys.argv) > 2 else G_DEFAULT
    rows = [json.loads(l) for l in open(os.path.join(out, "spawns.jsonl"))]
    if not rows: sys.exit("empty spawns.jsonl")
    for r in rows: r["sprint"] = int(r["sprint"])
    sel = lambda sp, step: [r for r in rows if r["sprint"] == sp and r["step"] == step]
    fs = (git(g, "ls-tree", "-r", "--name-only", SHIP) or "").splitlines()
    if not fs: sys.exit("graph ref %s not readable in %s" % (SHIP, g))

    print("== 1. per-label spawns, subagent $ and agent-minutes (spawns.jsonl); agent-minutes SUM parallel spawns")
    for step in (LAB, "gate-validation[architecture]", "gate-validation[requirements]", "implementation", "NEVER-STEP-ZZQ"):
        for sp in (319, 321):
            rs = sel(sp, step); n, u, m = tot(rs)
            line = "s%d %-31s spawns %3d  $%7.2f  %7.1f min (%5.2f h)  per story %.2f spawns $%.2f" % (sp, step, n, u, m, m / 60, n / STORIES[sp], u / STORIES[sp])
            rec = RECORDED.get((sp, step))
            if rec:
                line += "  | BL-812: %s $%.2f $ %s" % ("%.2f" % rec[0] if rec[0] is not None else "-", rec[1], match(u / STORIES[sp], rec[1]))
                if rec[0] is not None: line += ", spawns " + match(n / STORIES[sp], rec[0])
            if step == "NEVER-STEP-ZZQ": line += "  | impossible-step control, must be 0 spawns"
            print(line)
    print("like-for-like pair, implementation + gate-validation[implementation] (subagent $, spawns.jsonl):")
    pair = {}
    for sp in (319, 321):
        a = tot(sel(sp, "implementation")); b = tot(sel(sp, LAB))
        pair[sp] = (a[1] + b[1], a[0] + b[0], a[2] + b[2])
        print("   s%d impl $%.2f + gate $%.2f = $%.2f  $%.2f/story  spawns %d  %.1f h  | impl share of pair %.0f%%" % (
            sp, a[1], b[1], a[1] + b[1], (a[1] + b[1]) / STORIES[sp], a[0] + b[0], (a[2] + b[2]) / 60, 100 * a[1] / (a[1] + b[1])))
    print("   pair change s319 -> s321: $%.2f/story -> $%.2f/story (%+.2f); gate label alone %+.2f/story, implementation alone %+.2f/story" % (
        pair[319][0] / 20, pair[321][0] / 25, pair[321][0] / 25 - pair[319][0] / 20,
        tot(sel(321, LAB))[1] / 25 - tot(sel(319, LAB))[1] / 20, tot(sel(321, "implementation"))[1] / 25 - tot(sel(319, "implementation"))[1] / 20))
    print("   token-equivalent $ (roll.py --seats) is NOT derivable from spawns.jsonl; BL-812 records pair $41.3 -> $25.5. spawns.jsonl tok/story:")
    for sp in (319, 321):
        t = sum(r["tok"] or 0 for r in sel(sp, "implementation") + sel(sp, LAB))
        print("   s%d pair tokens %.1fM  %.2fM/story" % (sp, t / 1e6, t / 1e6 / STORIES[sp]))

    print("\n== 2. gate-validation[implementation] by role class (sum checked against the label)")
    classes = collections.OrderedDict()
    for sp in (319, 321):
        for r in sel(sp, LAB): classes.setdefault(cls(r), None)
    stat = {}
    for sp in (319, 321):
        rs = sel(sp, LAB); stat[sp] = {c: tot([r for r in rs if cls(r) == c]) for c in classes}
        ss = (sum(v[0] for v in stat[sp].values()), sum(v[1] for v in stat[sp].values()))
        lt = tot(rs)
        print("s%d class sum: %d spawns $%.2f vs label %d spawns $%.2f  %s" % (sp, ss[0], ss[1], lt[0], lt[1], "MATCH" if ss[0] == lt[0] and abs(ss[1] - lt[1]) < 0.005 else "DIFFERS"))
    print("%-22s %-22s %-22s %s" % ("class", "s319 n  $  min", "s321 n  $  min", "change $ (per story)"))
    tc = 0.0
    for c in classes:
        a, b = stat[319][c], stat[321][c]
        d = b[1] / 25 - a[1] / 20; tc += d
        print("%-22s %3d $%6.2f %6.1f   %3d $%6.2f %6.1f   %+.2f/story  (%+.2f total $)" % (c, a[0], a[1], a[2], b[0], b[1], b[2], d, b[1] - a[1]))
    print("per-story changes sum to %+.2f; label change %+.2f  %s" % (tc, tot(sel(321, LAB))[1] / 25 - tot(sel(319, LAB))[1] / 20,
          "MATCH" if abs(tc - (tot(sel(321, LAB))[1] / 25 - tot(sel(319, LAB))[1] / 20)) < 0.005 else "DIFFERS"))
    dev = [r for r in sel(321, LAB) if cls(r) == "dev build or rework"]
    print("dev build or rework spawns carry %.0f%% of the s321 label $ (%d spawns, %.1f agent-h); the same class in s319 was $%.2f" % (
        100 * sum(r["usd"] for r in dev) / tot(sel(321, LAB))[1], len(dev), sum(r["minutes"] for r in dev) / 60, stat[319]["dev build or rework"][1]))
    print("s321 'code review' class rows whose description is not a review: %s" % sorted(
        r["description"] for r in sel(321, LAB) if cls(r) == "code review" and not re.search(r"review", r["description"], re.I)))

    print("\n== 3a. verdict tokens in the spawns' own final_text (<=1500 chars kept, so a cut-off token reads absent)")
    for sp in (319, 321):
        for c in ("code review", "qa", "gate adjudicator", "dev build or rework", "remediator", "ops reads"):
            rs = [r for r in sel(sp, LAB) if cls(r) == c]
            k = collections.Counter()
            for r in rs:
                for t in ("NEEDS_REWORK", "FAIL", "APPROVED", "PASS", "CRITICAL", "MAJOR"):
                    if re.search(r"\b%s\b" % t, r["final_text"]): k[t] += 1
            print("s%d %-20s n=%-3d spawns naming: %s" % (sp, c, len(rs), dict(k) or "-"))

    print("\n== 3b. review-file series, whole sprint, ALL step labels (cannot attribute a file to one label)")
    FN = re.compile(r"^docs/reviews/s(\d+)/(\d+[.-]\d+)-(ff-)?(code-review|qa-validation)(?:-p(\d+))?\.md$")
    VER = re.compile(r"(?im)^\W*\**verdict\**\W*[:\-]?\s*\**\s*([A-Z_]{4,30})")
    series = {319: collections.defaultdict(list), 321: collections.defaultdict(list)}
    for f in fs:
        m = FN.match(f)
        if m and int(m.group(1)) in series:
            t = show(g, f) or ""
            v = VER.search(t)
            heads = sum(1 for l in t.splitlines() if re.match(r"#{2,4} ", l) and re.search(r"critical|major", l, re.I))
            series[int(m.group(1))][(m.group(2).replace("-", "."), m.group(4))].append((int(m.group(5) or 1), bool(m.group(3)), v.group(1) if v else None, heads))
    for sp in (319, 321):
        for kind in ("code-review", "qa-validation"):
            ks = [(k, sorted(v)) for k, v in series[sp].items() if k[1] == kind]
            files = sum(len(v) for _, v in ks); nr = sum(1 for _, v in ks for x in v if x[2] == "NEEDS_REWORK")
            rs_ = [(k, v) for k, v in ks if any(x[2] == "NEEDS_REWORK" for x in v)]
            ok = sum(1 for _, v in rs_ if v[-1][2] in ("APPROVED", "PASS"))
            print("s%d %-13s series %2d files %3d unverdicted %d  NEEDS_REWORK files %2d in %2d series; series last file APPROVED/PASS at ship: %d of %d; C/M headings %d (regex heading grammar)" % (
                sp, kind, len(ks), files, sum(1 for _, v in ks for x in v if x[2] is None), nr, len(rs_), ok, len(rs_), sum(x[3] for _, v in ks for x in v)))

    print("\n== 3c. gate-adjudication verdict files in the sprint's date window (verdict.json, not part files)")
    ga = [f for f in fs if f.startswith("_bmad-output/gate-adjudication/implementation-") and f.endswith(".verdict.json")]
    nonce = lambda f: (re.search(r"(\d{8}T\d{6})Z", f) or [None, ""])[1]
    for sp in (319, 321):
        ds = sorted(r["start"][:10].replace("-", "") for r in sel(sp, LAB) if r["role"] == "gate-adjudicator")
        lo, hi = ds[0], ds[-1]
        win = sorted([f for f in ga if lo <= nonce(f)[:8] <= hi], key=nonce)
        print("s%d window %s..%s (from adjudicator spawn dates): %d verdict files of %d implementation verdict files in the tree%s" % (
            sp, lo, hi, len(win), len(ga), "  | not in the clone, s319 not derivable at verdict level" if not win else ""))
        fails = []; allv = 0; runs_fail = 0
        docs = [(f, json.loads(show(g, f))) for f in win]
        for f, d in docs:
            vs = d.get("verdicts", []); allv += len(vs)
            if any(v.get("verdict") != "PASS" for v in vs): runs_fail += 1
            for v in vs:
                if v.get("verdict") != "PASS": fails.append((f, v))
        adj = tot([r for r in sel(sp, LAB) if r["role"] == "gate-adjudicator"])
        if win:
            print("   %d verdicts, %d non-PASS in %d of %d verdict files; adjudicator $%.2f = $%.2f per verdict file, $%.2f per file that returned a FAIL if only those counted" % (
                allv, len(fails), runs_fail, len(win), adj[1], adj[1] / len(win), adj[1] / max(runs_fail, 1)))
        for f, v in fails:
            later = [(f2, d2) for f2, d2 in docs if nonce(f2) > nonce(f)]
            nxt = next(((nonce(f2), x.get("verdict")) for f2, d2 in later for x in d2.get("verdicts", []) if x.get("check_id") == v.get("check_id")), None)
            print("   FAIL %s check %s -> next verdict on the same check: %s | %s" % (nonce(f), v.get("check_id"), nxt, (v.get("evidence") or "")[:130].replace("\n", " ")))

    print("\n== 3d. gate-labelled dev and ops spawns, s321, against the story's review series at ship")
    for r in sorted(sel(321, LAB), key=lambda r: r["start"]):
        if cls(r) not in ("dev build or rework", "ops reads"): continue
        m = re.search(r"(\d\.\d)", r["description"]); sid = m.group(1) if m else None
        info = ""
        if sid:
            parts = []
            for kind in ("code-review", "qa-validation"):
                v = sorted(series[321].get((sid, kind), []))
                parts.append("%s %s" % (kind, "/".join((x[2] or "?")[:5] for x in v) or "none"))
            info = "; ".join(parts)
        print("   %s %-15s %-45s $%6.2f %6.1f min | story %s: %s" % (r["start"][5:16], r["role"], r["description"][:45], r["usd"], r["minutes"], sid, info))

    print("\n== 4. the small gate labels, s321 (and s319 for comparison): every spawn and what it produced")
    for step in ("gate-validation[architecture]", "gate-validation[requirements]"):
        for sp in (319, 321):
            rs = sorted(sel(sp, step), key=lambda r: r["start"])
            n, u, m = tot(rs)
            print("s%d %s: %d spawns $%.2f %.1f min (%.2f h)" % (sp, step, n, u, m, m / 60))
            for r in rs:
                print("   %s %-22s %-42s $%5.2f %5.1f min  %s" % (r["start"][5:16], r["role"], r["description"][:42], r["usd"], r["minutes"], r["unit"]))
    # what each s321 small-gate spawn produced, from the committed tree
    for ts, label in (("20261104T044138Z", "architecture planning gate"), ("20261103T035443Z", "requirements planning gate")):
        t = show(g, "_bmad-output/gate-adjudication/planning-%s.verdict.json" % ts)
        d = json.loads(t) if t else {"verdicts": []}
        c = collections.Counter(v.get("verdict") for v in d["verdicts"])
        print("%s verdict file %s: %d checks %s (both shards' adjudication; the two adjudicator spawns of that label wrote it)" % (label, ts, len(d["verdicts"]), dict(c)))
    pend = show(g, "docs/escalations/pending.md") or ""
    i = pend.find("[S321-ARCHITECTURE-MTLS-ACTOR-GATE-APP-ENV-ABSENT]")
    print("architecture protected-path-editor: that entry's status line at ship: %r" % (pend[i:].split("\n")[1] if i >= 0 else None))
    ar = show(g, "_bmad-output/planning-artifacts/s321/architecture-repair-p5.md") or ""
    arch = show(g, "docs/architecture.md") or ""
    print("architecture remediator: repair-p5 record present %s, dispositions %s; fixed text in docs/architecture.md x%d; stale text 'yields 0 and keeps FAIL' x%d" % (
        bool(ar), dict(collections.Counter(re.findall(r"- disposition: (\w+)", ar))), arch.count("yields 0 and therefore passes under the exemption"), arch.count("yields 0 and keeps FAIL")))
    prd = show(g, "_bmad-output/planning-artifacts/prd.md") or ""
    pm = [r for r in sel(321, "gate-validation[requirements]") if r["role"] == "pm-escalated"]
    for r in pm:
        print("requirements pm-escalated final_text tally: %s" % re.findall(r"\*\*Findings:\*\*[^\n]*", r["final_text"]))
    nres = pend.count("**Status:** RESOLVED")
    print("requirements pm-escalated major (stale pending.md derivation): prd.md still says 'carries no RESOLVED or OVERRIDDEN entry' x%d while pending.md has %d RESOLVED status lines; prd.md still tallies '160 **Status:** DECIDED_AUTONOMOUSLY' x%d  -> unrepaired at ship if both >0" % (
        prd.count("carries no RESOLVED or OVERRIDDEN entry"), nres, prd.count(" 160 **Status:** DECIDED_AUTONOMOUSLY")))
    rp = show(g, "_bmad-output/planning-artifacts/s321/requirements-repair-p3.md") or ""
    brief = show(g, "_bmad-output/planning-artifacts/product-brief.md") or ""
    print("requirements adversary: repair-p3 dispositions %s; product-brief.md carries the repaired claim x%d, the false claim 'holds only \"Fix\" and \"Then,\"' x%d" % (
        dict(collections.Counter(re.findall(r"- disposition: (\w+)", rp))),
        brief.count('whose message body at line 1487 opens, operator: "Fix the create-position capital-sizing seam."'), brief.count('holds only "Fix" and "Then,"')))

    print("\n== 5. controls")
    print("impossible role in the label: %d (must be 0)" % sum(1 for r in sel(321, LAB) if r["role"] == "ZZQ-NO-ROLE"))
    tree_hit = git(g, "grep", "-c", "-F", NEG_TOKEN, SHIP)
    print("impossible token %s: in prd.md x%d, in tree grep: %s (must be 0 and empty)" % (NEG_TOKEN, prd.count(NEG_TOKEN), "empty" if not (tree_hit or "").strip() else tree_hit.strip()[:80]))
    print("positive token 'DEFERRAL_REQUEST' in pending.md x%d (must be >0); 'yields 0 and therefore passes' in architecture.md x%d (>0)" % (
        pend.count("DEFERRAL_REQUEST"), arch.count("yields 0 and therefore passes")))
    print("positive: s321 implementation verdict files read %d (>0); FILE-grammar review files s321 %d, s319 %d (>0)" % (
        len([f for f in ga if "20261106" <= nonce(f)[:8] <= "20261107"]), sum(len(v) for v in series[321].values()), sum(len(v) for v in series[319].values())))
    dup = collections.Counter((r["unit"]) for r in rows if r["sprint"] in (319, 321))
    d2 = [(u, sorted({(r["sprint"], r["step"]) for r in rows if r["unit"] == u})) for u, n in dup.items() if n > 1]
    print("units counted twice across s319/s321 (a unit in two lead transcripts): %s" % d2)


if __name__ == "__main__":
    main()
