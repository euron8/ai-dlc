"""Mechanical half of the s322 step-value reading for four labels BL-812 records as risen with no value reading:
gate-validation[implementation], gate-validation[architecture], gate-validation[bug-investigation], bug-investigation.

usage: python3 -I gate_yield_s322.py <OUT dir holding spawns.jsonl> <graph clone>

Read-only: <OUT>/spawns.jsonl and `git show` / `git ls-tree` of committed graph objects. Writes nothing. Modelled on
gate_label_yield.py (s321). Five blocks, controls in the same run:
  1. per-label spawns, subagent $ and agent-minutes, s322 against s319, against the per-story figures the lead's brief
     records (MATCH or DIFFERS); the like-for-like pair (implementation + gate-validation[implementation]);
  2. each label partitioned (class or description part), the partition summed against the label total (MATCH/DIFFERS);
  3. yield: (a) gate-adjudication verdict files joined to adjudicator spawns, FAIL checks and the next verdict on the same
     check; (b) review files docs/reviews/sNNN, blob-deduplicated, C/M findings by two counts; (c) gate-transition plan
     files; (d) gate-labelled dev, ops and re-review spawns against the story's review series at ship; (e) architecture
     party round and J2 repair; (f) bug-investigation records, provenance counts, dispositions, shipped-fix presence;
  4. what is NOT measurable;
  5. controls: impossible description token and impossible finding token at 0 beside present ones.
Review severity mapping: a review file's "### Critical" section is CRITICAL, its "### Important" section is MAJOR.
It does NOT judge whether a finding was valid: that reading is in the findings text, per item.
"""
import collections, importlib.util, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("bl812_rederive", os.path.join(HERE, "bl812_rederive.py"))
bl = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(bl)
STORIES = bl.STORIES
REF = {319: "1da426ef9", 321: "fb6f198e7", 322: "e0ebaf019"}   # sprint merges; 322 = PR #1317
CLOSE = "f7e60625b"                                              # s322 close
GI, GA, GB, BI = ("gate-validation[implementation]", "gate-validation[architecture]",
                  "gate-validation[bug-investigation]", "bug-investigation")
RECORDED = {(322, GI): 8.90, (319, GI): 4.61, (322, GA): 5.04, (319, GA): 0.05, (322, GB): 0.33, (319, GB): 0.00,
            (322, BI): 3.13, (319, BI): 0.00}
NEG_DESC = "ZQX-NO-SUCH-DESC-4417"
NEG_FIND = "ZQX-NO-SUCH-FINDING-6602"
G = None


def git(*a):
    r = subprocess.run(["git", "-C", G] + list(a), capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def show(ref, p):
    return git("show", "%s:%s" % (ref, p))


def tree(ref):
    return (git("ls-tree", "-r", "--name-only", ref) or "").splitlines()


def tot(rs):
    return len(rs), sum(r["usd"] or 0 for r in rs), sum(r["minutes"] or 0 for r in rs)


def match(a, b, tol=0.006):
    return "MATCH" if abs(a - b) < tol else "DIFFERS"


def cls(r):
    ro, d = r["role"], r["description"]
    if ro in ("code-reviewer", "code-reviewer-escalated"): return "code review"
    if ro == "qa": return "qa"
    if ro == "gate-adjudicator": return "gate adjudicator"
    if ro in ("dev", "dev-escalated"): return "dev build or rework"
    if ro == "protected-path-editor":
        return "closing writer" if re.search("closing writer", d, re.I) else "dev build or rework"
    if ro == "remediator": return "remediator"
    if ro == "ops": return "ops live reads"
    if ro == "adversary": return "adversary"
    return "other:" + ro


def story_of(d):
    m = re.search(r"\b1\.([1-8])\b", d) or re.search(r"story\s+([1-8])\b", d, re.I)
    return int(m.group(1)) if m else None


# ---- review files -------------------------------------------------------------------------------------------------
VER = re.compile(r"(?im)^\W*\**verdict\**\W*[:\-]?\s*\**\s*([A-Z_]{4,30})")
FN = re.compile(r"^docs/reviews/s(\d+)/((?:\d+[.-])?\d+)-(ff-)?(code-review|qa-validation)(?:-p(\d+))?\.md$")


def cm_counts(t):
    """(critical headed, important headed, critical Class-lines, important Class-lines) inside Critical / Important
    sections: count A = '#### ' headings, count B = 'Class:' lines (independent grammars)."""
    sec = None; a = {"C": 0, "I": 0}; b = {"C": 0, "I": 0}
    for l in t.splitlines():
        if re.match(r"#{2,3} ", l):
            if re.match(r"###\s+Critical", l): sec = "C"
            elif re.match(r"###\s+Important", l): sec = "I"
            else: sec = None
            continue
        if sec and re.match(r"#### ", l): a[sec] += 1
        if sec and re.match(r"Class:\s*\S", l): b[sec] += 1
    return a["C"], a["I"], b["C"], b["I"]


def review_series(sp):
    """{(story, kind): [(pass, verdict, cm-tuple, blob)]} over docs/reviews/sNNN at the sprint's merge ref, blob-deduped
    per (story, kind, pass) key and also across keys (an identical blob under two names counts once)."""
    ref = REF[sp]
    out = git("ls-tree", "-r", ref, "--", "docs/reviews/s%d" % sp) or ""
    ser = collections.defaultdict(list); seen = {}; dups = []; shard = [0, 0, 0, 0, 0]
    for l in out.splitlines():
        meta, path = l.split("\t", 1); blob = meta.split()[2]
        m = FN.match(path)
        if m:
            t = show(ref, path) or ""
            if blob in seen: dups.append((path, seen[blob])); continue
            seen[blob] = path
            v = VER.search(t); key = (re.split(r"[.-]", m.group(2))[-1] if sp == 322 else m.group(2), m.group(4))
            ser[key].append((int(m.group(5) or 1), v.group(1) if v else None, cm_counts(t), path))
        elif re.search(r"/shards/[^/]+/(\d+|cross)\.md$", path):
            c = cm_counts(show(ref, path) or ""); shard[0] += 1
            for i in range(4): shard[i + 1] += c[i]
    return ser, dups, shard


def main():
    global G
    if len(sys.argv) < 3: sys.exit("usage: gate_yield_s322.py <OUT dir> <graph clone>")
    out, G = sys.argv[1], sys.argv[2]
    rows = bl.spawns(out)
    if not rows: sys.exit("empty spawns.jsonl")
    for r in rows: r["sprint"] = int(r["sprint"])
    sel = lambda sp, step: [r for r in rows if r["sprint"] == sp and r["step"] == step]
    ts = {sp: tree(REF[sp]) for sp in REF}
    tcl = tree(CLOSE)
    if not ts[322] or not tcl: sys.exit("graph refs not readable in %s" % G)

    print("== 1. per-label spawns, subagent $ and agent-minutes (spawns.jsonl; agent-minutes SUM parallel spawns)")
    for step in (GI, GA, GB, BI, "implementation", "NEVER-STEP-ZZQ"):
        for sp in (319, 322):
            n, u, m = tot(sel(sp, step)); per = u / STORIES[sp]
            line = "s%d %-34s spawns %3d  $%7.2f  %7.1f min (%5.2f h)  per story (%d) $%.2f" % (sp, step, n, u, m, m / 60, STORIES[sp], per)
            if (sp, step) in RECORDED: line += "  | brief: $%.2f %s" % (RECORDED[(sp, step)], match(per, RECORDED[(sp, step)]))
            if step == "NEVER-STEP-ZZQ": line += "  | impossible-step control, must be 0"
            print(line)
    print("like-for-like pair, implementation + gate-validation[implementation] (subagent $):")
    pair = {}
    for sp in (319, 321, 322):
        a = tot(sel(sp, "implementation")); b = tot(sel(sp, GI)); pair[sp] = (a[1] + b[1]) / STORIES[sp]
        print("   s%d impl $%.2f + gate $%.2f = $%.2f = $%.2f/story  spawns %d  %.1f agent-h  | impl share %.0f%%" % (
            sp, a[1], b[1], a[1] + b[1], pair[sp], a[0] + b[0], (a[2] + b[2]) / 60, 100 * a[1] / (a[1] + b[1])))
    print("   s319 -> s322 per story: pair %+.2f; gate label alone %+.2f; implementation alone %+.2f" % (
        pair[322] - pair[319], tot(sel(322, GI))[1] / 8 - tot(sel(319, GI))[1] / 20,
        tot(sel(322, "implementation"))[1] / 8 - tot(sel(319, "implementation"))[1] / 20))

    print("\n== 2. partitions (each must SUM to the label total)")
    def part_print(name, sps, fn, step):
        parts = collections.OrderedDict()
        for sp in sps:
            for r in sel(sp, step): parts.setdefault(fn(r), None)
        for sp in sps:
            rs = sel(sp, step); lt = tot(rs); acc = [0, 0.0, 0.0]
            print("%s s%d: label %d spawns $%.2f %.1f min" % (name, sp, *lt))
            for p in parts:
                x = tot([r for r in rs if fn(r) == p]); acc = [acc[0] + x[0], acc[1] + x[1], acc[2] + x[2]]
                print("     %-44s %3d spawns $%7.2f %7.1f min  ($%.2f/story)" % (p, x[0], x[1], x[2], x[1] / STORIES[sp]))
            # a catch-all bucket makes the sum match by construction, so the control also requires it to be empty
            catch = sum(1 for r in rs if fn(r) == "other" or fn(r).startswith("other:"))
            print("     partition sum %d / $%.2f / %.1f min vs label, catch-all rows %d (must be 0)  %s" % (acc[0], acc[1], acc[2], catch,
                  "MATCH" if acc[0] == lt[0] and abs(acc[1] - lt[1]) < 0.005 and abs(acc[2] - lt[2]) < 0.05 and catch == 0 else "DIFFERS"))
    part_print(GI, (319, 322), cls, GI)
    def arch_part(r):
        d, ro = r["description"], r["role"]
        if ro == "gate-adjudicator": return "gate adjudicator shards"
        if ro == "remediator" and re.search(r"J2", d): return "remediator J2 amendment (Check 24 repair)"
        if ro == "remediator": return "remediator repair of the party round"
        if ro in ("architect", "dev", "tea", "pm") or re.search(r"(?i)dispatch|party", d):
            return "architecture-party round (4 seats x 4 shards + dispatch)"
        return "other"
    part_print(GA, (319, 322), arch_part, GA)
    part_print(GB, (319, 322), cls, GB)
    def bug_part(r):
        d, ro = r["description"], r["role"]
        if ro == "analyst": return "bug analysis (analyst)"
        if re.search(r"root-cause review", d): return "root-cause adversary (2c)"
        if re.search(r"Remediate crash analysis", d): return "remediator of the analysis findings"
        if re.search(r"story 1\.4", d, re.I): return "story 1.4 gate rework (dev, review, QA, closing writer)"
        if re.search(r"Dev story 1\.8", d): return "story 1.8 dev build"
        if re.search(r"1\.8|CAP-7|Protected edits", d): return "story 1.8 spec repair/fold/amendments/role files"
        return "other"
    part_print(BI, (322,), bug_part, BI)

    print("\n== 3a. gate-adjudication verdict files (implementation gate), joined to adjudicator spawns")
    d322 = "_bmad-output/implementation-artifacts/s322/gate-adjudication/"
    n78 = sum(1 for f in tcl if f.startswith(d322)); n85 = sum(1 for f in tcl if f.startswith("_bmad-output/implementation-artifacts/s322/gate-transition/"))
    print("files at close ref %s: gate-adjudication %d (brief 78 %s), gate-transition %d (brief 85 %s)" % (
        CLOSE, n78, "MATCH" if n78 == 78 else "DIFFERS", n85, "MATCH" if n85 == 85 else "DIFFERS"))
    kinds = collections.Counter(re.sub(r"\d{8}T\d{6}Z", "TS", re.sub(r"-\d+of\d+", "", f[len(d322):])).rsplit(".", 1)[0] + "." + f.rsplit(".", 1)[1] for f in tcl if f.startswith(d322))
    print("   by kind: %s" % dict(kinds))
    adj = [r for r in rows if r["sprint"] == 322 and r["role"] == "gate-adjudicator" and r["step"] in (GI, GB)]
    vf = sorted(f for f in ts[322] if f.startswith(d322 + "implementation-") and f.endswith(".verdict.json"))
    docs = []
    for f in vf:
        d = json.loads(show(REF[322], f)); docs.append((f, d))
    docs.sort(key=lambda x: x[1]["generated_at"])
    joined = []
    for f, d in docs:
        m = re.search(r"story(?:1x)?(\d)", d["gate_series_id"]); sid = int(m.group(1)) if m else None
        cand = [r for r in adj if story_of(r["description"]) in (sid, None) and r["start"] <= d["generated_at"].replace("Z", "") + ".999Z"]
        sp_ = max(cand, key=lambda r: r["start"]) if cand else None
        joined.append((f, d, sid, sp_))
    print("verdict files %d; adjudicator spawns in %s and %s: %d; every file joined to a spawn: %s; every spawn has a file: %s" % (
        len(vf), GI, GB, len(adj), all(j[3] for j in joined), all(any(j[3] is r for j in joined) for r in adj)))
    print("%-17s %-6s %-33s %-26s %5s  %s" % ("generated_at", "story", "spawn (label)", "series", "FAIL", "failed checks"))
    for f, d, sid, sp_ in joined:
        fl = [v["check_id"] for v in d["verdicts"] if v["verdict"] != "PASS"]
        print("%-17s %-6s %-33s %-26s %5d  %s" % (d["generated_at"][5:16], sid, ("%s (%s)" % (sp_["description"][:20], sp_["step"][16:20])) if sp_ else None, d["gate_series_id"].split("-")[1] + "-" + d["gate_series_id"][-7:], len(fl), fl))
    for lab in (GI, GB):
        js = [j for j in joined if j[3] and j[3]["step"] == lab]; sps = [r for r in adj if r["step"] == lab]
        nf = sum(1 for j in js if any(v["verdict"] != "PASS" for v in j[1]["verdicts"]))
        nfc = sum(sum(1 for v in j[1]["verdicts"] if v["verdict"] != "PASS") for j in js)
        u = sum(r["usd"] for r in sps)
        print("%s: %d adjudicator spawns $%.2f, %d verdict files, %d with a FAIL, %d FAIL checks (%d checks read); $%.2f per file, $%.2f per FAIL file if only those counted" % (
            lab, len(sps), u, len(js), nf, nfc, sum(len(j[1]["verdicts"]) for j in js), u / max(len(js), 1), u / max(nf, 1)))
    print("FAIL checks, and the next verdict on the same check in a later file of the same story:")
    for i, (f, d, sid, sp_) in enumerate(joined):
        for v in d["verdicts"]:
            if v["verdict"] == "PASS": continue
            nxt = next((x["verdict"] for f2, d2, s2, _ in joined[i + 1:] if s2 == sid for x in d2["verdicts"] if x["check_id"] == v["check_id"]), None)
            print("   %s story %s check %-3s -> next %s | %s" % (d["generated_at"][5:16], sid, v["check_id"], nxt, v["evidence"][:110].replace("\n", " ")))
    print("check-19 share of FAIL checks: %d of %d" % (sum(1 for _, d, _, _ in joined for v in d["verdicts"] if v["verdict"] != "PASS" and v["check_id"] == "19"),
                                                       sum(1 for _, d, _, _ in joined for v in d["verdicts"] if v["verdict"] != "PASS")))
    dd = "_bmad-output/implementation-artifacts/s319/gate-adjudication/implementation-"
    fl = sorted(f for f in ts[321] if f.startswith(dd) and f.endswith(".verdict.json")); nv = nf = nfc = 0
    for f in fl:
        d = json.loads(show(REF[321], f)); nv += len(d["verdicts"]); bad = [v for v in d["verdicts"] if v["verdict"] != "PASS"]
        nf += 1 if bad else 0; nfc += len(bad)
    print("s319 implementation verdict files (per-sprint dir, read at ref %s): %d files, %d checks, %d with a FAIL, %d FAIL checks, over 20 stories (s322: 15 files over 8 stories); check ids failing: %s" % (
        REF[321], len(fl), nv, nf, nfc, dict(collections.Counter(v["check_id"] for f in fl for v in json.loads(show(REF[321], f))["verdicts"] if v["verdict"] != "PASS"))))
    print("s321 verdict files sit in the undated root _bmad-output/gate-adjudication/ and are joined by date window in gate_label_yield.py 3c; not repeated here")
    first = {}
    for f, d, sid, _ in joined: first.setdefault(sid, d)
    last = {}
    for f, d, sid, _ in joined: last[sid] = d
    print("stories with an implementation verdict file %d of 8; first file had a FAIL: %s; last file all PASS: %d" % (
        len(first), sorted(k for k, d in first.items() if any(v["verdict"] != "PASS" for v in d["verdicts"])),
        sum(1 for d in last.values() if all(v["verdict"] == "PASS" for v in d["verdicts"]))))

    print("\n== 3b. review files docs/reviews/sNNN (whole sprint, ALL step labels; blob-deduplicated; no per-label attribution possible)")
    allser = {}
    for sp in (319, 321, 322):
        ser, dups, shard = review_series(sp); allser[sp] = ser
        for kind in ("code-review", "qa-validation"):
            ks = [(k, sorted(v)) for k, v in ser.items() if k[1] == kind]
            files = [x for _, v in ks for x in v]; nr = [x for x in files if x[1] == "NEEDS_REWORK"]
            ca = sum(x[2][0] for x in files); ia = sum(x[2][1] for x in files); cb = sum(x[2][2] for x in files); ib = sum(x[2][3] for x in files)
            rs_ = [(k, v) for k, v in ks if any(x[1] == "NEEDS_REWORK" for x in v)]
            ok = sum(1 for _, v in rs_ if v[-1][1] in ("APPROVED", "PASS"))
            print("s%d %-13s series %2d files %3d unverdicted %d NEEDS_REWORK files %2d in %2d series, last file APPROVED/PASS: %d of %d | C/M by #### headings: C %d M %d; by Class: lines: C %d M %d" % (
                sp, kind, len(ks), len(files), sum(1 for x in files if x[1] is None), len(nr), len(rs_), ok, len(rs_), ca, ia, cb, ib))
        print("   s%d shard files (%d, the parts the merged files above already contain, not added): C/M headings C %d M %d, Class: lines C %d M %d" % (sp, shard[0], shard[1], shard[2], shard[3], shard[4]))
        print("   s%d identical blobs counted once across names: %d%s" % (sp, len(dups), (" %s" % dups) if dups else ""))
    print("s322 series at ship (story, kind): pass:verdict[C/M by headings]")
    ser = allser[322]
    for k in sorted(ser, key=lambda k: (int(k[0]), k[1])):
        print("   story %s %-13s %s" % (k[0], k[1], "  ".join("p%d:%s[%d/%d]" % (p, (v or "?")[:5], c[0], c[1]) for p, v, c, _ in sorted(ser[k]))))
    nr = sorted((k, sorted(v)) for k, v in ser.items() if any(x[1] == "NEEDS_REWORK" for x in v))
    print("s322 NEEDS_REWORK series: %s" % [(k, "->".join((x[1] or "?")[:5] for x in v)) for k, v in nr])
    print("review spawns by label, s322 (code-review + qa roles): %s" % {st: n for st, n in collections.Counter(r["step"] for r in rows if r["sprint"] == 322 and r["role"] in ("code-reviewer", "code-reviewer-escalated", "qa")).items()})

    print("\n== 3c. gate-transition plan files (s322): one plan per story x gate x pass")
    pl = sorted(f for f in tcl if "s322/gate-transition/" in f and f.endswith(".plan"))
    gp = collections.defaultdict(list); lvl = collections.Counter(); route = collections.Counter(); steer = 0
    for f in pl:
        t = show(CLOSE, f) or ""; m = re.match(r".*/(\d+)-(g\w+)-p(\d+)\.plan$", f); gp[(m.group(1), m.group(2))].append(int(m.group(3)))
        for l in t.splitlines():
            if l.startswith("gate-log:"):
                mm = re.match(r"gate-log: (\w+) ", l); lvl[mm.group(1) if mm else "other"] += 1
            if l.startswith("route:"): route[l.split()[1]] += 1
            if l.startswith("steering-count:") and l.split()[1] != "0": steer += 1
    print("plan files %d (+ %d capture lists); passes per gate: %s" % (len(pl), sum(1 for f in tcl if "s322/gate-transition/" in f and f.endswith(".captures")),
          {g: sum(len(v) for (s, gg), v in gp.items() if gg == g) for g in ("g1", "g2", "g3", "gclose")}))
    print("   stories with a gate-1 pass 2 or later (rework): %s of 8; gate-3 pass 2 or later: %s" % (
        sorted(s for (s, g), v in gp.items() if g == "g1" and max(v) > 1), sorted(s for (s, g), v in gp.items() if g == "g3" and max(v) > 1)))
    print("   gate-log lines by level: %s (FAIL/REFUSED lines: %d; WARN lines are the positive control); routes %s; nonzero steering-count lines %d" % (
        dict(lvl), sum(n for k, n in lvl.items() if k in ("FAIL", "REFUSED")), dict(route), steer))

    print("\n== 3d. gate-labelled dev, ops and re-review spawns against the story's review series at ship (s322)")
    for r in sorted(sel(322, GI), key=lambda r: r["start"]):
        c = cls(r)
        if c not in ("dev build or rework", "ops live reads", "closing writer") and not re.search(r"re-review|pass 2 review|pass-3|p4", r["description"], re.I): continue
        sid = story_of(r["description"]); info = ""
        if sid:
            info = "; ".join("%s %s" % (kind[:2], "/".join((x[1] or "?")[:5] for x in sorted(ser.get((str(sid), kind), []))) or "none") for kind in ("code-review", "qa-validation"))
        print("   %s %-22s %-40s $%5.2f %5.1f min | story %s: %s" % (r["start"][5:16], c, r["description"][:40], r["usd"], r["minutes"], sid, info))
    fc = [r for r in sel(322, GI) if (r["role"] == "gate-adjudicator" and re.search(r"pass 2|p2|p3|re-run", r["description"], re.I)) or
          (r["role"].startswith("code-reviewer") and re.search(r"re-review|pass 2 review|pass-3|pass 2", r["description"], re.I))]
    print("FAIL-chain spawns (pass-2+ adjudicators and re-reviews, by description): %d spawns $%.2f of label $%.2f" % (len(fc), sum(r["usd"] for r in fc), tot(sel(322, GI))[1]))
    nn = {f: (show(REF[322], f) or "") for f in ts[322] if f.startswith("docs/reviews/s322/3-") and f.endswith(".md")}
    print("story 1.3 named catch (gate-3 Check 11a FAIL -> live attempt -> fix): 'networkidle' mentions in the pass-1 review files %d (3-code-review %d, 3-qa-validation %d), in later p2+ files %d; the dev fix text 'domcontentloaded' in story-3 review files after the fix %d" % (
        sum(t.count("networkidle") for f, t in nn.items() if re.search(r"3-(code-review|qa-validation)\.md$", f)),
        nn.get("docs/reviews/s322/3-code-review.md", "").count("networkidle"), nn.get("docs/reviews/s322/3-qa-validation.md", "").count("networkidle"),
        sum(t.count("networkidle") for f, t in nn.items() if re.search(r"-p\d\.md$", f)), sum(t.count("domcontentloaded") for f, t in nn.items() if re.search(r"-p\d\.md$", f))))
    ops = [r for r in sel(322, GI) if r["description"].startswith("11a live attempt")]
    print("   11a live-attempt ops seat final_text: %s" % [re.findall(r"all 4 tests failed[^.]*\.", r["final_text"]) for r in ops])

    print("\n== 3e. gate-validation[architecture]: the party round and the J2 repair")
    pm = sorted(f for f in ts[322] if f.startswith("_bmad-output/party-mode/s322/architecture-"))
    sevA = collections.Counter(); sevB = collections.Counter(); pfind = 0
    for f in pm:
        t = show(REF[322], f) or ""
        for l in t.splitlines():
            m = re.match(r"## F-\d+ \((critical|major|minor)\)", l, re.I)
            if m: sevA[m.group(1).lower()] += 1
            if re.match(r"#{2,3} ", l) and re.search(r"\b(critical|major)\b", l, re.I): sevB["cm-heading"] += 1
    print("party files %d (spine shards: 16 expected = 4 seats x (3 shards + cross): %s); '## F-n (sev)' headings: %s; second count, headings naming critical/major: %d" % (
        len(pm), "MATCH" if len(pm) == 16 else "DIFFERS", dict(sevA), sevB["cm-heading"]))
    print("   per seat C/M headed findings: %s" % {s: sum(1 for f in pm if "-%s-" % s in f for l in (show(REF[322], f) or "").splitlines() if re.match(r"## F-\d+ \((critical|major)\)", l, re.I)) for s in ("architect", "dev", "tea", "pm")})
    pv = sorted(f for f in tcl if f.startswith(d322 + "planning-") and f.endswith(".verdict.json"))
    for f in pv:
        d = json.loads(show(CLOSE, f))
        if d["generated_at"].startswith("2026-11-10T08"):
            print("   architecture planning verdict %s: %d checks, FAIL %d (series %s)" % (d["generated_at"], len(d["verdicts"]), sum(1 for v in d["verdicts"] if v["verdict"] != "PASS"), d["gate_series_id"]))
    jr = show(REF[322], "_bmad-output/planning-artifacts/s322/gate-planning-arch-repair-p1.md") or ""
    print("   J2 repair record: disposition %s, 'failed check: Check 24 arm J2' x%d, edit hunks named: %s" % (re.findall(r"- disposition: (\w+)", jr), jr.count("Check 24 arm J2"), re.findall(r"- edit: (\S+)", jr)))
    rr = [f for f in ts[322] if re.match(r"_bmad-output/planning-artifacts/s322/[^/]*repair[^/]*\.md$", f)]
    print("   repair records (planning-artifacts/s322/*repair*.md) %d; those whose text names the architecture party round: %d (control: naming 'adversarial': %d)" % (
        len(rr), sum(1 for f in rr if re.search(r"party", show(REF[322], f) or "", re.I)), sum(1 for f in rr if re.search(r"adversar", show(REF[322], f) or "", re.I))))
    for sp in (319, 321, 322):
        pr = [r for r in rows if r["sprint"] == sp and r["role"] in ("architect", "dev", "tea", "pm") and re.search(r"^(architect|dev|tea|pm)-(\d|cross)$|architecture-party", r["description"]) and r["step"] in ("architecture", GA)]
        print("   s%d architecture-party-round spawns by step label: %s" % (sp, {k: (n, round(sum(r["usd"] for r in pr if r["step"] == k), 2)) for k, n in collections.Counter(r["step"] for r in pr).items()} or "none"))
    ar = [r for r in sel(322, "architecture")]
    print("   the architecture label ran 36 spawns $%.2f: %d spawns $%.2f of them are adversary shards; the party round (03:14) is in %s, so party cost is booked to the gate label" % (
        tot(ar)[1], sum(1 for r in ar if r["role"] == "adversary"), sum(r["usd"] for r in ar if r["role"] == "adversary"), GA))

    print("\n== 3f. bug-investigation: records, provenance counts, dispositions, shipped fix (s322)")
    P = "_bmad-output/planning-artifacts/"
    recs = [(P + "s322/bug-analysis-xdist-worker-cap.md", "analyst 1 (spawns 22:34 and redirect 22:39)"),
            (P + "s322/bug-analysis-adversarial-xdist-worker-cap.md", "2c adversary of analysis 1"),
            (P + "bug-analysis-xdist-runtime-footprint-crash-guard.md", "analyst 2 (06:17)"),
            (P + "bug-analysis-adversarial.md", "2c adversary of analysis 2 (07:41)"),
            (P + "s322/bug-fix-oneshot-xdist-crash-admission-controls.md", "one-shot adversary, story 1.8 (07:55, label %s)" % GB),
            (P + "s322/bug-fix-oneshot-xdist-collection-footprint-bisect-and-pin.md", "one-shot adversary, story 1.7"),
            (P + "s322/bug-fix-oneshot-test-harness-repair-measure-and-cap.md", "one-shot adversary, story 1.6")]
    PV = re.compile(r"invoked_at: (\S+).*?findings_critical: (\d+).*?findings_major: (\d+).*?findings_minor: (\d+)", re.S)
    for p, what in recs:
        t = show(REF[322], p) or ""; m = PV.search(t[:1500]); fh = collections.Counter(x.lower() for x in re.findall(r"^### F-\d+ - (CRITICAL|MAJOR|MINOR)", t, re.M))
        print("   %-70s %s | provenance at %s C %s M %s m %s | F- headings %s" % (p.replace(P, ""), "present" if t else "ABSENT", m.group(1)[5:16] if m else "-", *(m.groups()[1:] if m else ("-",) * 3), dict(fh) or "-"))
    cg = show(REF[322], P + "bug-analysis-xdist-runtime-footprint-crash-guard.md") or ""
    disp = collections.Counter(re.findall(r"^\| F-\d+ (?:MAJOR|MINOR)[^|]*\| (\w+)", cg, re.M))
    print("   analysis 2 disposition table rows by disposition: %s; ladder-layer tokens at ship: 'L12' x%d, 'L4a' x%d (both from the 2c repair); control impossible token x%d" % (dict(disp), cg.count("L12"), cg.count("L4a"), cg.count(NEG_FIND)))
    wc = show(REF[322], P + "s322/bug-analysis-xdist-worker-cap.md") or ""
    print("   analysis 1 lead disposition section present x%d; the two analysis files are single-commit records (git log counts: analysis 2 %s, story 1.8 %s), so no pre-repair blob exists in the clone: before-absence of repaired text is NOT measurable" % (
        wc.count("## Disposition (lead"), len((git("log", "--format=%h", REF[322], "--", P + "bug-analysis-xdist-runtime-footprint-crash-guard.md") or "").split()),
        len((git("log", "--format=%h", REF[322], "--", P + "s322/stories/story-1-8-xdist-crash-admission-controls.md") or "").split())))
    st = show(REF[322], P + "s322/stories/story-1-8-xdist-crash-admission-controls.md") or ""
    print("   story 1.8 at ship carries repair text: 'single-home' x%d, 'PYTEST_PIN' x%d, one-shot F-1 premise 'collect-only -n 8' x%d, '### F-' headings in the story x%d" % (st.count("single-home"), st.count("PYTEST_PIN"), st.count("collect-only"), len(re.findall(r"^### F-", st, re.M))))
    for p in ("scripts/pytest_admission.py", "scripts/pytest-footprint-watchdog.py", "scripts/pytest-admission.conf"):
        print("   shipped at %s: %-40s %s" % (REF[322], p, "present, %d bytes" % len(show(REF[322], p)) if show(REF[322], p) else "ABSENT"))
    print("   PYTEST_PIN line at ship: %s" % re.findall(r"^PYTEST_PIN=.*$", show(REF[322], "scripts/pytest-admission.conf") or "", re.M))
    fl = sum((show(REF[322], x) or "").count('"pytest>=8.0"') for x in ("rebalancer/pyproject.toml", "server/pyproject.toml"))
    print("   floating specifier '\"pytest>=8.0\"' (the analysis's L12 producer) still at ship: rebalancer+server pyproject x%d (positive control: 'pytest-xdist' x%d in rebalancer/pyproject.toml)" % (fl, (show(REF[322], "rebalancer/pyproject.toml") or "").count("pytest-xdist")))
    for s in ("6", "7", "8"):
        print("   story 1.%s review series at ship: %s" % (s, {k[1]: "->".join((x[1] or "?")[:5] for x in sorted(v)) for k, v in ser.items() if k[0] == s}))
    print("   admission-controls story 1.8 ACs proof: 8-qa-validation shard text 'collected total' / '2 failed, 9234 passed' x%d (the run is a full execution, not collect-only)" % (show(REF[322], "docs/reviews/s322/8-qa-validation-p2.md") or "").count("9234 passed"))
    print("   instance-selector bug analysis (_bmad-output/implementation-artifacts/s322/bug-analysis-instance-selector-pollution.md) present %s; spawns in %s naming it: %d; in sprint-review label: %d" % (
        bool(show(REF[322], "_bmad-output/implementation-artifacts/s322/bug-analysis-instance-selector-pollution.md")), BI,
        sum(1 for r in sel(322, BI) if re.search("pollution|selector", r["description"], re.I)), sum(1 for r in sel(322, "sprint-review") if re.search("pollution|selector", r["description"], re.I))))

    sp_ = show(REF[322], "_bmad-output/planning-artifacts/s322/architecture-spine/ARCHITECTURE-SPINE.md") or ""
    pmx = show(REF[322], "_bmad-output/party-mode/s322/architecture-pm-cross.md") or ""
    fal = "the CAP-6 Day-0 GET uses `/api/rebalancer-base/config`"
    print("survival floor, party finding pm-cross F-1 (AD-5 row rewrote the CAP-6 Day-0 route): false text quoted in the finding file x%d (control, >0); false text in the spine at ship x%d (0 = repaired); repaired text 'GET /api/rebalancer/config` on the Base instance' in spine x%d (>0); absent-before needs the pre-repair spine blob, which was not read: NOT measured" % (
        pmx.count(fal), sp_.count(fal), sp_.count("GET /api/rebalancer/config` on the Base instance")))
    os_ = show(REF[322], P + "s322/bug-fix-oneshot-xdist-crash-admission-controls.md") or ""
    print("survival floor, one-shot F-1 on story 1.8 (AC6 proved by collect-only -n 8): finding file names the premise x%d (control, >0); story at ship carries the repaired AC6 text 'a FULL `-n 8` run (not `--collect-only`' x%d (>0); admission proof run in the QA record: '2 failed, 9234 passed' x%d" % (
        os_.count("collect-only"), st.count("a FULL `-n 8` run (not `--collect-only`"), (show(REF[322], "docs/reviews/s322/8-qa-validation-p2.md") or "").count("9234 passed")))

    print("\n== 4. NOT measured")
    print("   - review files carry no label: C/M above are whole-sprint, not per label. Available: attribution by commit time is unreliable (files land at the sprint merge).")
    print("   - the claim texts of dev rework (what a gate finding changed in code) are in product repo commits not in this clone's file tree reads; survival floor here is series-ended-APPROVED/PASS, not span survival.")
    print("   - s319 gate-3 FAIL checks come from verdict files under s319/gate-adjudication read at the s321 merge; no per-spawn join for s319 (adjudicator_agent_id mostly a placeholder, joined by story+time for s322 only).")

    print("\n== 5. controls")
    for lab in (GI, GA, GB, BI):
        rs = sel(322, lab)
        print("%-34s description token 'adjudicat|review|analys|dev|party|architect' present in %d spawns (>0 expected); impossible token %s in %d (must be 0)" % (
            lab, sum(1 for r in rs if re.search(r"adjudicat|review|analys|dev|party|architect|QA", r["description"], re.I)), NEG_DESC, sum(1 for r in rs if NEG_DESC in r["description"])))
    revtxt = "".join(show(REF[322], f) or "" for f in ts[322] if f.startswith("docs/reviews/s322/") and f.endswith(".md") and "/shards/" not in f)
    print("impossible finding token %s in s322 review corpus x%d (must be 0); positive 'Critical' x%d, 'Class:' x%d (>0)" % (NEG_FIND, revtxt.count(NEG_FIND), revtxt.count("Critical"), revtxt.count("Class:")))
    dup = collections.Counter(r["unit"] for r in rows if r["sprint"] in (319, 322))
    print("units counted twice across s319/s322: %s" % [u for u, n in dup.items() if n > 1])
    allm = sum(sum(1 for x in v for y in [x]) for v in allser[322].values())
    print("s322 review series entries %d; spawns.jsonl s322 rows %d" % (allm, sum(1 for r in rows if r["sprint"] == 322)))


if __name__ == "__main__":
    main()
