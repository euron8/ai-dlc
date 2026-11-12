"""Mechanical half of the s321 step-value reading for sprint-review and deploy-validate (BL-812 item 1).

usage: python3 -I sr_dv_yield.py <OUT dir holding spawns.jsonl> [<graph repo>]

Read-only: <OUT>/spawns.jsonl and `git show` / `git diff` of committed graph objects. Writes nothing.
It prints five blocks, each with its controls in the same run:
  1. per-step spawns and subagent dollars, s319 and s321, against the figures BL-812 records (MATCH or DIFFERS),
     plus the same-step gate (gate-validation[sprint-review]) that s319 charged part of its party round to;
  2. the sprint-review and deploy-validate spawns split by phase (description and role classes below);
  3. the C/M (CRITICAL or MAJOR) headings in the sprint-review seat files, against the s321 minors-triage file's own
     "34 major rows" and "186 minor rows" and the gate verdict's "130 seat files";
  4. survival: the share of each fix commit's added lines present in the shipped tree and at the measured ref, with
     the deploy-validate fix-forwards as the discriminating control (absent from the sprint squash, present after);
  5. whether any sprint-review seat or adversary record names a deploy-validate defect (tokens), with a positive
     token control and an impossible token.
It does NOT classify REFOUND, REPAIR-INTRODUCED or UNIQUE-SURVIVED: that reading is in
docs/analysis/step-value-sprint-review-deploy-validate-s321.md, per finding.
"""
import collections, json, os, re, subprocess, sys

G_DEFAULT = os.path.expanduser("~/git/graph")
REF = "da6cadadd"          # graph HEAD the b255 extraction pinned
SHIP = "fb6f198e7"         # Sprint 321 squash on main (#1303)
PRE_SR = "dfca19e76"       # sprint-review Step 0 merge, the tree sprint-review read
STORIES = {319: 20, 321: 25}
RECORDED = {(319, "sprint-review"): (3.65, 1.93), (321, "sprint-review"): (6.60, 8.25),
            (319, "deploy-validate"): (0.45, 0.56), (321, "deploy-validate"): (1.80, 4.01)}
SEAT = re.compile(r"^sprint-review-(architect|dev|pm|qa|tea)-(\d\d|cross(?:-\d+)?)\.md$")
CM = re.compile(r"^## F-\d+[a-z]? \((critical|major)", re.I)
MINOR = re.compile(r"^## F-\d+[a-z]? \(minor", re.I)
# label, commit, pre-fix base: sprint-review Step 1 and Step 3 fixes, then the four deploy-validate fix-forwards
FIXES = [("SR adversary F-1 golden", "36bf72950", PRE_SR), ("SR pool", "4b1fd2a65", PRE_SR),
         ("SR pool rework", "6df2ae912", PRE_SR), ("SR probe", "323c7b18e", PRE_SR), ("SR docs", "a723c175a", PRE_SR),
         ("SR docs rework", "1c6433d94", PRE_SR), ("SR web", "4a58923c0", PRE_SR), ("SR tests", "0d83871e3", PRE_SR),
         ("SR leftovers", "d1482f34b", PRE_SR), ("SR envleak", "09d1ebbf8", PRE_SR), ("SR claude", "484c7aeb5", PRE_SR),
         ("DV #1304 smoke nav", "01dde7133", SHIP), ("DV #1305 Base first save", "2625acc45", "01dde7133"),
         ("DV #1306 refunding router", "c5ddf2d4d", "2625acc45"), ("DV #1307 zero gas field", "4840808e7", "c5ddf2d4d")]
DV_TOKENS = ["shell-nav-btn", "first save", "first-save", "refund", "estimateGas", "gas allowance", "swap_router_kind", "PoolSwapTest"]
POS_TOKEN, NEG_TOKEN = "_resolve_request_pool", "ZQX-NEVER-TOKEN-77"


def git(g, *a):
    r = subprocess.run(["git", "-C", g] + list(a), capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def sr_phase(r):
    d = (r.get("description") or "").strip()
    if r["role"] == "gate-adjudicator": return "gate adjudicator"
    if r["role"] == "adversary": return "adversary one-shot"
    m = re.match(r"^(?:SR party )?(pm|dev|qa|tea|architect) (?:story |cross ?)?(\d+|cross|g\d)$", d)
    if m: return "party seat, cross" if ("cross" in d or re.search(r"g\d$", d)) else "party seat, per-story"
    if r["role"] in ("analyst", "general-purpose"): return "party consolidation, triage, dispatch"
    return "fix, review and QA of fixes"


def dv_phase(r):
    d = r.get("description") or ""
    if r["role"] != "ops": return "fix-forward dev, review and QA"
    if re.search(r"triage|Diagnose|estimateGas|[Dd]erive|watch|Watch|Verify Base L2 create", d): return "ops diagnosis and watch"
    if re.search(r"Create Base DB|Write Base config|PUT|restart|Deploy PoolSwapTest", d): return "ops rollout action"
    return "ops verification (smoke, 3b, Step 4, reads)"


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: sr_dv_yield.py <OUT dir> [<graph repo>]")
    out = sys.argv[1]; g = sys.argv[2] if len(sys.argv) > 2 else G_DEFAULT
    rows = [json.loads(l) for l in open(os.path.join(out, "spawns.jsonl"))]

    print("== 1. per-step spawns and subagent $ (spawns.jsonl, all buckets)")
    for sp in (319, 321):
        for step in ("sprint-review", "gate-validation[sprint-review]", "deploy-validate", "NEVER-STEP-ZZQ"):
            rs = [r for r in rows if int(r["sprint"]) == sp and r["step"] == step]
            usd = sum(r.get("usd") or 0 for r in rs); ps, pu = len(rs) / STORIES[sp], usd / STORIES[sp]
            line = "s%d %-31s spawns %3d  $%7.2f  per story %.2f  $%.2f" % (sp, step, len(rs), usd, ps, pu)
            rec = RECORDED.get((sp, step))
            if rec: line += "   | BL-812: %.2f $%.2f %s" % (rec[0], rec[1], "MATCH" if abs(ps - rec[0]) < 0.006 and abs(pu - rec[1]) < 0.006 else "DIFFERS")
            if step == "NEVER-STEP-ZZQ": line += "   | impossible-step control, must be 0"
            print(line)
        both = [r for r in rows if int(r["sprint"]) == sp and r["step"] in ("sprint-review", "gate-validation[sprint-review]")]
        u = sum(r.get("usd") or 0 for r in both)
        print("s%d sprint-review + its gate         spawns %3d  $%7.2f  per story %.2f  $%.2f" % (sp, len(both), u, len(both) / STORIES[sp], u / STORIES[sp]))
    labs = collections.defaultdict(lambda: [0, 0.0])
    for r in rows:
        if int(r["sprint"]) in (319, 321) and ("sprint-review" in r["step"] or "deploy-validate" in r["step"]):
            l = labs[(int(r["sprint"]), r["step"])]; l[0] += 1; l[1] += r.get("usd") or 0
    print("step labels containing sprint-review or deploy-validate (the label set behind each figure above):")
    for k, v in sorted(labs.items()): print("   s%d %-31s %3d spawns $%7.2f" % (k[0], k[1], v[0], v[1]))
    print("s319 recorded label alone vs both labels: $%.2f vs $%.2f per story  (BL-812 records the first)" % (
        labs[(319, "sprint-review")][1] / STORIES[319], (labs[(319, "sprint-review")][1] + labs[(319, "gate-validation[sprint-review]")][1]) / STORIES[319]))
    print("deploy-validate has no gate-validation[...] label in s319 or s321: %d labels  %s" % (
        sum(1 for k in labs if "deploy-validate" in k[1] and k[1] != "deploy-validate"), "(must be 0)"))
    dup = collections.Counter((r["sprint"], r["step"], r["unit"]) for r in rows if r["step"] in ("sprint-review", "gate-validation[sprint-review]", "deploy-validate"))
    for k, v in sorted(dup.items()):
        if v > 1:
            usd = [r["usd"] for r in rows if (r["sprint"], r["step"], r["unit"]) == k]
            print("duplicate unit (one agent in %d lead transcripts): s%s %s %s, $%.2f counted %d times" % (v, k[0], k[1], k[2], usd[0], v))

    print("\n== 2. phase split")
    for sp in (319, 321):
        for name, steps, fn in (("sprint-review + gate", ("sprint-review", "gate-validation[sprint-review]"), sr_phase), ("deploy-validate", ("deploy-validate",), dv_phase)):
            agg = collections.defaultdict(lambda: [0, 0.0, 0.0])
            for r in rows:
                if int(r["sprint"]) == sp and r["step"] in steps:
                    a = agg[fn(r)]; a[0] += 1; a[1] += r.get("usd") or 0; a[2] += r.get("minutes") or 0
            for k, v in sorted(agg.items()):
                print("s%d %-21s %-44s %3d  $%7.2f  %6.1f agent-min" % (sp, name, k, v[0], v[1], v[2]))
        seats = collections.defaultdict(lambda: [0, 0.0])
        for r in rows:
            if int(r["sprint"]) == sp and r["step"] in ("sprint-review", "gate-validation[sprint-review]") and sr_phase(r).startswith("party seat"):
                s = seats[(r["role"], r["model_ran"])]; s[0] += 1; s[1] += r.get("usd") or 0
        print("s%d party seats by (role, model ran): %s" % (sp, ", ".join("%s/%s %d $%.2f" % (k[0], k[1], v[0], v[1]) for k, v in sorted(seats.items()))))

    print("\n== 3. sprint-review seat findings (graph %s)" % REF)
    for sp in ("s319", "s321"):
        d = "_bmad-output/party-mode/%s/" % sp
        names = [f for f in (git(g, "ls-tree", "--name-only", REF, d) or "").split("\n") if SEAT.match(os.path.basename(f))]
        if not names: sys.exit("no seat files for %s at %s" % (sp, REF))
        cm = collections.Counter(); mi = 0
        for f in names:
            role = SEAT.match(os.path.basename(f)).group(1)
            for ln in git(g, "show", "%s:%s" % (REF, f)).split("\n"):
                if CM.match(ln): cm[role] += 1
                elif MINOR.match(ln): mi += 1
        line = "%s seat files %d  C/M %d %s  minor %d" % (sp, len(names), sum(cm.values()), dict(sorted(cm.items())), mi)
        if sp == "s321":
            ok = len(names) == 130 and sum(cm.values()) == 34 and mi == 186
            line += "   | triage file: 34 major, 186 minor; verdict: 130 files %s" % ("MATCH" if ok else "DIFFERS")
        print(line)
    adv = git(g, "show", "%s:_bmad-output/implementation-artifacts/s321/sprint-review-adversarial.md" % REF) or ""
    print("s321 adversary one-shot: finding headings (### F-) %d; its own grading line 'Counted below as one MAJOR' present: %d" % (
        sum(1 for l in adv.split("\n") if re.match(r"^### F-\d+", l)), int("Counted below as one MAJOR" in adv)))

    print("\n== 4. fix survival: added lines (>= 12 chars) present at the pre-fix base, at %s (ship) and at %s" % (SHIP, REF))
    cache = {}
    def blob(ref, p):
        if (ref, p) not in cache: cache[(ref, p)] = git(g, "show", "%s:%s" % (ref, p)) or ""
        return cache[(ref, p)]
    for label, c, base in FIXES:
        files = {}; cur = None
        for ln in (git(g, "diff", "-U0", c + "^", c) or "").split("\n"):
            if ln.startswith("+++ "): cur = ln[6:] if ln.startswith("+++ b/") else None
            elif cur and ln.startswith("+") and len(ln[1:].strip()) >= 12: files.setdefault(cur, []).append(ln[1:].strip())
        tot = sum(len(v) for v in files.values())
        n = {ref: sum(1 for f, ls in files.items() for s in ls if s in blob(ref, f)) for ref in (base, SHIP, REF)}
        print("%-27s %s  lines %4d  pre %4d  ship %4d (%5.1f%%)  %s %4d (%5.1f%%)" % (label, c, tot, n[base], n[SHIP], 100.0 * n[SHIP] / max(tot, 1), REF, n[REF], 100.0 * n[REF] / max(tot, 1)))
    print("impossible line at ship: %d (must be 0)" % int("ZQX-NEVER-LINE-31337" in blob(SHIP, "rebalancer/api.py")))

    print("\n== 5. do sprint-review records name a deploy-validate defect? (s321 seat files + adversary + minors triage)")
    corpus = adv + (git(g, "show", "%s:_bmad-output/implementation-artifacts/s321/sprint-review-minors-triage.md" % REF) or "")
    for f in (git(g, "ls-tree", "--name-only", REF, "_bmad-output/party-mode/s321/") or "").split("\n"):
        if SEAT.match(os.path.basename(f)): corpus += git(g, "show", "%s:%s" % (REF, f))
    low = corpus.lower()
    for t in DV_TOKENS + [POS_TOKEN, NEG_TOKEN]:
        tag = "  (positive control, must be > 0)" if t == POS_TOKEN else "  (impossible token, must be 0)" if t == NEG_TOKEN else ""
        print("%-24s %3d%s" % (t, low.count(t.lower()), tag))


main()
