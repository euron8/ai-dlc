"""BL-1004's second reading: the sprint-review pm seats on graph s322, by the method of
docs/analysis/step-value-sprint-review-deploy-validate-s321.md (the s321 reading).

usage: python3 -I pm_seats_s322.py <OUT dir holding spawns.jsonl> [<graph repo>]

Read-only: <OUT>/spawns.jsonl and `git show` / `git diff` / `git grep` of committed graph objects. Writes nothing.
Blocks, each with its controls in the same run:
  1. cost: the s321 control (the pm row and step total the s321 reading and BL-1004 record), then s322 over the
     labels `sprint-review` and `gate-validation[sprint-review]`, by phase and by (role, model ran);
  2. the C/M (CRITICAL or MAJOR) and minor headings in the s322 seat files, against the triage file's own
     "45 major, 112 minor";
  3. each pm C/M finding, the triage entry whose `sources:` cites it, and which other roles' seats raised that entry,
     with the severity each raised it at;
  4. survival: the share of each cited fix commit's added lines present at the pre-review tree and at the sprint
     squash, and the snapshot precondition line at the squash;
  5. earlier raises: tokens per pm candidate over the s322 records written before the round, excluding the round's
     own briefs, with the T-4 hit as the positive control and an impossible token;
  6. the decision rule's comparison: pm $ per pm-raised survivor against the step's $ per survivor, the step's
     survivor count bounded above by its distinct major entries.
It does NOT classify REFOUND or UNIQUE-SURVIVED: that reading is per finding, in
docs/analysis/step-value-sprint-review-pm-seats-s322.md.
"""
import collections, json, os, re, subprocess, sys

G_DEFAULT = os.path.expanduser("~/git/graph")
REF = "39aa9db6f"          # s322 sprint branch: sprint-review gate PASS record (seats, triage, fixes all committed)
PRE = "95d831207"          # s322 sprint-review party briefs: the tree the round read
SHIP = "e0ebaf019"         # Sprint 322 squash on main (#1317)
STORIES = {321: 25, 322: 8}
STEP = ("sprint-review", "gate-validation[sprint-review]")
S321 = {"pm": (26, 17.00, 0.75), "step": (169, 209.09)}
TRIAGE = "_bmad-output/implementation-artifacts/s322/sprint-review-party-triage.md"
SEAT = re.compile(r"^sprint-review-(architect|dev|pm|qa|tea)-(\d+|cross)\.md$")
HEAD = re.compile(r"^## F-(\d+)[a-z]? \((critical|major|minor)\)", re.I)
# pm candidate entry -> fix commits the commit bodies name, and earlier-raise tokens
FIXES = {"T-1": ["95a8f1ba2"], "T-2": ["95a8f1ba2", "b2f0cbc41"], "T-4": ["e946cb60b"],
         "T-13": ["28388fb70", "fcca51cad"]}
SNAP_LINE = "SPRINT-322 DEPLOY PRECONDITIONS (single ordered list, consolidated at sprint review T-14"
TOKENS = {"T-4": "DEPLOY_RANGE", "T-12": "AC8(a)", "T-2": "46aa113d2fa5", "T-1": "AC4-ORGANIC-READ",
          "T-14": "deploy precondition", "impossible": "ZQX-NEVER-TOKEN-77"}
SWEEP = ["docs/reviews/s322", "_bmad-output/implementation-artifacts/s322", "_bmad-output/planning-artifacts/s322"]


def git(g, *a):
    r = subprocess.run(["git", "-C", g] + list(a), capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def phase(r):
    d = (r.get("description") or "").strip()
    if r["role"] == "gate-adjudicator": return "gate adjudicator"
    if r["role"] == "adversary": return "adversary one-shot"
    m = re.match(r"^(?:SR party )?(pm|dev|qa|tea|architect)(?: |-)(?:story |cross ?)?(\d+|cross|g\d)(?: seat)?$", d)
    if m: return "party seat, cross" if ("cross" in d or re.search(r"g\d$", d)) else "party seat, per-story"
    if r["role"] in ("analyst", "general-purpose"): return "party consolidation, triage, dispatch"
    return "fix, review and QA of fixes"


def agg(rs):
    return len(rs), sum(r.get("usd") or 0 for r in rs), sum(r.get("minutes") or 0 for r in rs) / 60.0


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: pm_seats_s322.py <OUT dir> [<graph repo>]")
    out = sys.argv[1]; g = sys.argv[2] if len(sys.argv) > 2 else G_DEFAULT
    rows = [json.loads(l) for l in open(os.path.join(out, "spawns.jsonl"))]

    print("== 1. cost (spawns.jsonl, labels %s)" % " + ".join(STEP))
    for sp in (321, 322):
        st = [r for r in rows if int(r["sprint"]) == sp and r["step"] in STEP]
        pm = [r for r in st if r["role"] == "pm"]
        n, u, h = agg(st); pn, pu, ph = agg(pm)
        lab = agg([r for r in st if r["step"] == "sprint-review"])
        line = "s%d step %3d spawns $%7.2f %5.2f agent-h (label sprint-review alone %d $%.2f) | pm %d $%.2f %.2f agent-h" % (
            sp, n, u, h, lab[0], lab[1], pn, pu, ph)
        if sp == 321:
            ok = (pn, round(pu, 2), round(ph, 2)) == S321["pm"] and (n, round(u, 2)) == S321["step"]
            line += "   | s321 reading and BL-1004: pm 26 $17.00 0.75 h, step 169 $209.09 %s" % ("MATCH" if ok else "DIFFERS")
        print(line)
        ph_ = collections.defaultdict(list)
        for r in st: ph_[phase(r)].append(r)
        for k in sorted(ph_):
            a = agg(ph_[k]); print("   s%d %-40s %3d  $%7.2f  %5.2f agent-h" % (sp, k, a[0], a[1], a[2]))
        seats = collections.defaultdict(list)
        for r in st:
            if phase(r).startswith("party seat"): seats[(r["role"], r.get("model_ran"))].append(r)
        print("   s%d seats by (role, model ran): %s" % (sp, ", ".join("%s/%s %d $%.2f" % (k[0], k[1], len(v), agg(v)[1]) for k, v in sorted(seats.items()))))
    print("impossible step NEVER-STEP-ZZQ: %d spawns (must be 0)" % sum(1 for r in rows if r["step"] == "NEVER-STEP-ZZQ"))

    print("\n== 2. s322 seat findings (graph %s)" % REF)
    names = [f for f in (git(g, "ls-tree", "--name-only", REF, "_bmad-output/party-mode/s322/") or "").split("\n") if SEAT.match(os.path.basename(f))]
    if not names: sys.exit("no seat files at %s" % REF)
    sev = {}; cm = collections.Counter(); mi = 0
    for f in names:
        m = SEAT.match(os.path.basename(f)); seat = "%s-%s" % (m.group(1), m.group(2))
        for ln in git(g, "show", "%s:%s" % (REF, f)).split("\n"):
            h = HEAD.match(ln)
            if not h: continue
            s = h.group(2).lower(); sev["%s::F-%s" % (seat, h.group(1))] = s
            if s == "minor": mi += 1
            else: cm[m.group(1)] += 1
    tri = git(g, "show", "%s:%s" % (REF, TRIAGE)) or ""
    ok = len(names) == 45 and sum(cm.values()) == 45 and mi == 112 and "45 major, 112 minor, 0 critical" in tri
    print("seat files %d  C/M %d %s  minor %d   | triage: 45 files, 45 major, 112 minor %s" % (
        len(names), sum(cm.values()), dict(sorted(cm.items())), mi, "MATCH" if ok else "DIFFERS"))
    print("impossible role 'zzq' seat files: %d (must be 0)" % sum(1 for f in names if "-zzq-" in f))

    print("\n== 3. pm C/M findings and the triage entries that cite them")
    ents = {}
    for e in re.split(r"\n(?=## T-\d+ )", tri):
        m = re.match(r"## (T-\d+) \((\w+)\)", e); s = re.search(r"^sources: (.*)$", e, re.M)
        if m and s: ents[m.group(1)] = (m.group(2), [x.strip().split(" ")[0] for x in s.group(1).split(",")])
    print("triage entries %d (major %d)" % (len(ents), sum(1 for v in ents.values() if v[0] == "major")))
    pm_cm = sorted(k for k, v in sev.items() if k.startswith("pm-") and v != "minor")
    alone = 0
    for f in pm_cm:
        hit = [t for t, v in ents.items() if f in v[1]]
        for t in hit:
            others = ["%s(%s)" % (x, sev.get(x, "?")) for x in ents[t][1] if not x.startswith("pm-")]
            alone += int(not others)
            print("%-14s -> %-5s (%s)  other roles: %s" % (f, t, ents[t][0], ", ".join(others) or "NONE"))
        if not hit: print("%-14s -> no triage entry cites it" % f)
    print("pm C/M findings %d; entries with no other role's seat: %d" % (len(pm_cm), alone))
    print("control: an entry cited by no source spelling 'pm-zzq': %d (must be 0)" % sum(1 for v in ents.values() if "pm-zzq::F-1" in v[1]))

    print("\n== 4. fix survival: added lines (>= 12 chars) present at %s (pre) and %s (ship)" % (PRE, SHIP))
    cache = {}
    def blob(ref, p):
        if (ref, p) not in cache: cache[(ref, p)] = git(g, "show", "%s:%s" % (ref, p)) or ""
        return cache[(ref, p)]
    for t, cs in sorted(FIXES.items(), key=lambda x: int(x[0][2:])):
        for c in cs:
            files = {}; cur = None
            for ln in (git(g, "diff", "-U0", c + "^", c) or "").split("\n"):
                if ln.startswith("+++ "): cur = ln[6:] if ln.startswith("+++ b/") else None
                elif cur and ln.startswith("+") and len(ln[1:].strip()) >= 12: files.setdefault(cur, []).append(ln[1:].strip())
            tot = sum(len(v) for v in files.values())
            n = {ref: sum(1 for f, ls in files.items() for s in ls if s in blob(ref, f)) for ref in (PRE, SHIP)}
            print("%-5s %s  lines %4d  pre %4d  ship %4d (%5.1f%%)" % (t, c, tot, n[PRE], n[SHIP], 100.0 * n[SHIP] / max(tot, 1)))
    for ref in (PRE, REF, SHIP):
        print("T-12/T-14 snapshot precondition list at %s: %d" % (ref, int(SNAP_LINE in blob(ref, "_bmad-output/pipeline-snapshot.md"))))
    print("impossible line at ship: %d (must be 0)" % int("ZQX-NEVER-LINE-31337" in blob(SHIP, "_bmad-output/pipeline-snapshot.md")))

    print("\n== 5. earlier raises: token hits at %s over %s, the round's own briefs excluded" % (PRE, ", ".join(SWEEP)))
    for t, tok in TOKENS.items():
        hits = [l for l in (git(g, "grep", "-l", "-F", tok, PRE, "--", *SWEEP) or "").split("\n") if l and "/rounds/sprint-review-party/" not in l]
        tag = "  (impossible token, must be 0)" if t == "impossible" else "  (positive control: story 1.4 raised it before the round)" if t == "T-4" else ""
        print("%-10s %-22s %3d files%s" % (t, tok, len(hits), tag))
        for h in hits[:6]: print("            %s" % h.split(":", 1)[1])

    print("\n== 6. decision rule (BL-1004): pm $ per pm-raised survivor against the step's $ per survivor")
    st = [r for r in rows if int(r["sprint"]) == 322 and r["step"] in STEP]
    pm = [r for r in st if r["role"] == "pm"]
    majors = sum(1 for v in ents.values() if v[0] == "major")
    for label, pop in (("both labels", st), ("label sprint-review alone", [r for r in st if r["step"] == "sprint-review"])):
        u = agg(pop)[1]
        print("step %-26s $%.2f / at most %d survivors = at least $%.2f per survivor" % (label, u, majors, u / majors))
    print("pm $%.2f: survivors needed for pm $ per survivor <= the step's lower bound: %d" % (agg(pm)[1], -(-agg(pm)[1] * majors // agg(st)[1])))


main()
