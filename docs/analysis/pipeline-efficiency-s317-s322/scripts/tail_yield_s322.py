"""s322 step-value reading for the review tail: sprint-review, deploy-validate, retro, gate-validation[retro], handoff
(BL-812 item 1, sprint 322 against sprint 319).

usage: python3 -I tail_yield_s322.py <OUT dir holding spawns.jsonl> <graph repo> [block ...]
  <graph repo> is a git repo (a clone or the real graph repo) read with `git -C ... show|log|diff|grep|cat-file`. The
  `file://` clone holds the s322 squash refs only; the per-fix commits and the round-start tree sit in the real graph
  repo. Block 0 prints, per ref, whether the repo given holds it; a figure that needs an absent ref prints UNAVAILABLE.
  block: 0 refs and the s322 corpus controls, 1 cost, 2 partitions, 3 sprint-review yield, 4 sprint-review fix
  survival, 5 sprint-review gate and the Check 3 catch, 6 deploy-validate, 7 retro, 8 handoff.  No block: all, in order.

Read-only: <OUT>/spawns.jsonl and read-only git commands (GIT_OPTIONAL_LOCKS=0). Writes nothing. Stdlib only.
It does NOT classify a finding as REFOUND by reading; the earlier-raise lines in blocks 3 and 5 are regex hit counts over
the earlier corpus with a positive control, and the readings that use them are hand readings (documented in the final
report). Round-start tree: PRE_SR is the tree the seats and the triage read (the triage names it as HEAD).
"""
import collections, importlib.util, json, os, re, subprocess, sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)      # both modules guard main() behind __name__ == "__main__"
    return mod


B = load("bl812_rederive")            # spawns(), agg(), STORIES
PT = load("party_ts_yield")           # claim_spans()

SHIP = "e0ebaf019"        # s322 sprint merge on main (#1317)
RETRO_PR = "78817f315"    # s322 retro merge (#1319)
RETRO_BASE = "6ee289617"  # its parent
CLOSE = "f7e60625b"       # s322 close
PRE_SR = "95d831207"      # sprint tip the seats and the triage read
ADV_BASE = "14bc28d2c"    # tree the sprint-level adversary reviewed
GATE_HEAD = "af307b314"   # sprint-review gate repair commit (last substantive sprint-review commit)
HANDOFF_COMMIT = "0140ef67d"
POST_CLOSE = "1449b5c72"  # #1320, the post-close push-candidate ledger backfill the retro names
LR_COMMIT = "28388fb70"   # sprint-review fix that set story 1.8 locked_requirements: [LR-S322-9]
G_LABELS = ["sprint-review", "gate-validation[sprint-review]", "deploy-validate", "retro", "gate-validation[retro]", "handoff"]
LEAD = {(322, "sprint-review"): 9.62, (319, "sprint-review"): 1.93, (322, "deploy-validate"): 0.65, (319, "deploy-validate"): 0.56,
        (322, "retro"): 1.78, (319, "retro"): 0.40, (322, "gate-validation[retro]"): 0.44, (319, "gate-validation[retro]"): 0.00,
        (322, "handoff"): 0.03, (319, "handoff"): 0.00}
IMPOSSIBLE_STEP, IMPOSSIBLE_TOK = "QZXV-NO-SUCH-STEP-5512", "ZQX-NEVER-TOKEN-77"
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
G = None


def git(*a):
    r = subprocess.run(["git", "-C", G] + list(a), capture_output=True, text=True, env=ENV)
    return r.stdout if r.returncode == 0 else None


def show(ref, path):
    return git("show", "%s:%s" % (ref, path))


def have(ref):
    return git("cat-file", "-e", ref + "^{commit}") is not None


def ls(ref, prefix):
    return [f for f in (git("ls-tree", "-r", "--name-only", ref, prefix) or "").split("\n") if f]


def usd(rs): return sum(r.get("usd") or 0 for r in rs)
def mins(rs): return sum(r.get("minutes") or 0 for r in rs)
def tot(rs): return "%3d  $%7.2f  %6.1f min" % (len(rs), usd(rs), mins(rs))


def partition(rows, parts, label):
    """parts: [(name, regex)] on description; every row must match exactly one part. Prints the sum control."""
    got = collections.OrderedDict((n, []) for n, _ in parts); un = []; multi = 0
    for r in rows:
        hit = [n for n, rx in parts if re.search(rx, r.get("description") or "")]
        if len(hit) > 1: multi += 1
        if hit: got[hit[0]].append(r)
        else: un.append(r)
    for n, rs in got.items(): print("  %-46s %s" % (n, tot(rs)))
    s = [x for rs in got.values() for x in rs]
    ok = len(s) == len(rows) and abs(usd(s) - usd(rows)) < 1e-9 and abs(mins(s) - mins(rows)) < 1e-9
    print("  %-46s %s" % ("PARTITION SUM", tot(s)))
    print("  label total %-34s %s   sum control: %s   unmatched %d  double-matched %d (both must be 0)" % (
        label, tot(rows), "MATCH" if ok else "DIFFERS", len(un), multi))
    return got


# ---------------------------------------------------------------- description partitions
SR_322 = [("party seats, per-story (pm dev qa tea architect x 1-8)", r"^(pm|dev|qa|tea|architect)-[1-8] seat$"),
          ("party seats, cross (x5)", r"^(pm|dev|qa|tea|architect)-cross seat$"),
          ("party-round dispatcher", r"^Run sprint-review party round$"),
          ("party triage (analyst)", r"^Triage sprint-review party findings$"),
          ("adversary one-shot", r"^Sprint-level adversarial review$"),
          ("adversary comment fixes (S-1, S-2)", r"^Apply adversarial comment fixes$"),
          ("fixes, dev (batch A, B, T-22/23, ci-local lane)", r"^(Dev fixes batch [AB]|Follow-up fixes T-\d+/T-\d+|Add admission verifier lane)$"),
          ("fixes, protected-path editor", r"^Protected-file review fixes$"),
          ("fixes, artifact remediator", r"^Remediate artifact findings$"),
          ("bug root-cause, instance-selector pollution", r"^Root-cause instance-selector pollution$"),
          ("gate repair, Check 3 story 1.8", r"^Gate repair: Check 3 story 1\.8$"),
          ("gate adjudicators, pass 1 (4 shards)", r"^Gate adjudication shard \d/4$"),
          ("gate adjudicators, pass 2 (4 shards)", r"^Gate adjudication pass2 shard \d/4$")]
SR_319 = [("party seats, per-story", r"^SR party (pm|dev|qa|tea|architect) story \d+$"),
          ("party seats, cross", r"^SR party (pm|dev|qa|tea|architect) cross g\d$"),
          ("party consolidation", r"^Consolidate party round findings$"),
          ("adversary one-shot", r"^Sprint-review one-shot adversarial$"),
          ("fixes, with their review and QA", r"^(Step \d+ fix bundle|Fix C |Code review of fix|QA validation of fix|Re-QA of fix|Re-review of fix)"),
          ("gate adjudicators (4 shards)", r"^Gate adjudicator shard \d/4$")]
DV_322 = [("ops pre-roll live reads (4b: AC1, AC4, AC8, 1.3 AC5)", r"^Ops seat: s322 pre-roll live reads$"),
          ("ops execution_lock re-reads (x2)", r"^Ops( lock recheck pre-roll|: fresh lock re-read pre-roll)$")]
DV_319 = [("ops reads (Aurora, config, P&L, smoke cases)", r"^\d+b "),
          ("deferred-AC predicate extraction", r"^Extract deferred-AC predicates$"),
          ("diagnosis (smoke red, stale rewards)", r"^Diagnose "),
          ("fix-forward dev, code review and QA", r"^(Move rewards into|Review status-bar|QA status-bar)")]
RT_322 = [("party persona rounds (6)", r"^Party (PM|Dev|QA|SM|TEA|Architect) persona retro round$"),
          ("analyst draft shards (6)", r"^Retro draft shard: "),
          ("analyst close-out gather (4)", r"^Closeout gather: "),
          ("Dispatch C next-sprint inputs (6, after the 12:32Z close)", r"^Dispatch C input \d: ")]
RT_319 = [("party persona seats (6)", r"^Retro party seat "),
          ("analyst gather, draft, close-out (5)", r"^(Gather Sprint \d+ handoff inputs|Re-read |Retro draft analyst|Close-out tables analyst)"),
          ("ops discharge reads (1)", r"^Read-only LR-S\d+-\d+ discharge reads$")]
RG_322 = [("retro gate shards (9)", r"^Retro gate shard \d/9$")]
HO_322 = [("fix-forward dev commit 0140ef67d (label attribution)", r"^Fix check-31 fixture interpreter$")]


def lrows(rows, sp, *steps): return [r for r in rows if int(r["sprint"]) == sp and r["step"] in steps]


# ---------------------------------------------------------------- seat files and triage
SEAT = re.compile(r"^sprint-review-(architect|dev|pm|qa|tea)-([1-8]|cross)\.md$")
CM = re.compile(r"^## F-(\d+) \((critical|major)\)", re.I)
MI = re.compile(r"^## F-(\d+) \(minor\)", re.I)


def seats_at(ref):
    out = {}
    for f in ls(ref, "_bmad-output/party-mode/s322/"):
        m = SEAT.match(os.path.basename(f))
        if m: out[f] = (m.group(1), m.group(2))
    return out


def triage_entries(t):
    ents = re.split(r"(?m)^## (?=T-\d+ )", t)[1:]; out = []
    for e in ents:
        m = re.match(r"T-(\d+) \((major|minor)\) (.*)", e)
        rec = re.search(r"(?m)^recommend: ([A-Z-]+)", e); ver = re.search(r"(?m)^verdict: ([A-Z-]+)", e)
        src = re.search(r"(?m)^sources: (.*)$", e)
        out.append(dict(n=int(m.group(1)), sev=m.group(2), title=m.group(3), rec=rec.group(1), ver=ver.group(1),
                        src=[re.sub(r"\s*\(.*\)$", "", s.strip()) for s in src.group(1).split(",")]))
    return out


def dispositions(t):
    """final class per T-n from the lead's Disposition section; unnamed ids take the triage recommend."""
    sec = t.split("## Disposition (lead", 1)[1]; d = {}
    for ln in sec.split("\n"):
        if not ln.startswith("- T-"): continue
        head = re.split(r" (ACCEPTED|REJECTED|DECLINED|DECIDED)\b", ln, maxsplit=1)
        ids = []
        for a, b in re.findall(r"T-(\d+)(?:\.\.T-(\d+))?", head[0]):
            ids += list(range(int(a), int(b or a) + 1))
        kw = head[1] if len(head) > 2 else ""
        mm = re.search(r"as (CODE-FIX|ARTIFACT-FIX|CARRY-OVER)", ln)
        for i in ids:
            d[i] = (kw, mm.group(1) if mm else ("record-only" if kw == "DECIDED" else None))
    return d


def final_class(e, d):
    kw, cls = d.get(e["n"], ("ACCEPTED", None))
    if kw in ("REJECTED", "DECLINED"): return kw
    if kw == "DECIDED": return "DECIDED record-only"
    return cls or e["rec"]


def added_lines(c, base=None):
    files = {}; cur = None
    for ln in (git("diff", "-U0", "--no-renames", (base or c + "^"), c) or "").split("\n"):
        if ln.startswith("+++ "): cur = ln[6:] if ln.startswith("+++ b/") else None
        elif cur and ln.startswith("+") and len(ln[1:].strip()) >= 12: files.setdefault(cur, []).append(ln[1:].strip())
    return files


_blob = {}
def blob(ref, p):
    if (ref, p) not in _blob: _blob[(ref, p)] = show(ref, p) or ""
    return _blob[(ref, p)]


def survival(files, refs):
    tot_ = sum(len(v) for v in files.values())
    return tot_, {ref: sum(1 for f, ls_ in files.items() for s in ls_ if s in blob(ref, f)) for ref in refs}


def pct(a, b): return "%5.1f%%" % (100.0 * a / b) if b else "  n/a "


def p(s=""): print(s)


def main():
    global G
    if len(sys.argv) < 3: sys.exit(__doc__)
    out, G = sys.argv[1], sys.argv[2]
    blocks = [int(x) for x in sys.argv[3:]] or list(range(9))
    rows = B.spawns(out); ST = B.STORIES
    assert ST[322] == 8 and ST[319] == 20, "STORIES moved"
    refs = {k: have(v) for k, v in dict(SHIP=SHIP, CLOSE=CLOSE, RETRO_BASE=RETRO_BASE, PRE_SR=PRE_SR, ADV_BASE=ADV_BASE,
                                        GATE_HEAD=GATE_HEAD, HANDOFF=HANDOFF_COMMIT, LR=LR_COMMIT).items()}

    if 0 in blocks:
        p("== 0. repo and refs (repo given: %s)" % G)
        for k, v in refs.items(): p("  %-10s %-10s %s" % (k, dict(SHIP=SHIP, CLOSE=CLOSE, RETRO_BASE=RETRO_BASE, PRE_SR=PRE_SR, ADV_BASE=ADV_BASE, GATE_HEAD=GATE_HEAD, HANDOFF=HANDOFF_COMMIT, LR=LR_COMMIT)[k], "PRESENT" if v else "ABSENT in this repo"))
        p("  impossible ref control: %s" % ("PRESENT (BAD)" if have("deadbeef0000") else "absent (as it must be)"))
        sf = seats_at(CLOSE) if refs["CLOSE"] else {}
        p("  s322 seat files at %s: %d (need 45); rounds/sprint-review-party holds .brief files: %d (briefs) and %d non-brief" % (
            CLOSE, len(sf), len([f for f in ls(CLOSE, "_bmad-output/planning-artifacts/s322/rounds/sprint-review-party/") if f.endswith(".brief")]),
            len([f for f in ls(CLOSE, "_bmad-output/planning-artifacts/s322/rounds/sprint-review-party/") if not f.endswith(".brief")])))
        p("  impossible role seat count (must be 0): %d" % len([1 for f in sf if "sprint-review-zz-" in f]))

    if 1 in blocks:
        p("\n== 1. cost per label, s322 against s319 (spawns.jsonl, every bucket; STORIES from bl812_rederive: s322 %d, s319 %d)" % (ST[322], ST[319]))
        for sp in (322, 319):
            for st in G_LABELS + [IMPOSSIBLE_STEP]:
                rs = lrows(rows, sp, st); n = ST[sp]; pu = usd(rs) / n
                line = "s%d %-31s spawns %3d  $%7.2f  %6.1f agent-min  per story %.2f spawns, $%.2f" % (sp, st, len(rs), usd(rs), mins(rs), len(rs) / n, pu)
                if (sp, st) in LEAD: line += "   | lead %.2f %s" % (LEAD[(sp, st)], "MATCH" if abs(pu - LEAD[(sp, st)]) < 0.006 else "DIFFERS")
                if st == IMPOSSIBLE_STEP: line += "   | impossible step, must be 0"
                p(line)
            n, u, m_, _t = B.agg(rows, sp, G_LABELS)
            p("s%d the six labels together: %d spawns $%.2f %.1f min (B.agg)  vs summed above: %s" % (sp, n, u, m_, "MATCH" if n == sum(len(lrows(rows, sp, s)) for s in G_LABELS) and abs(u - sum(usd(lrows(rows, sp, s)) for s in G_LABELS)) < 1e-9 else "DIFFERS"))
            both = lrows(rows, sp, "sprint-review", "gate-validation[sprint-review]")
            p("s%d sprint-review + gate-validation[sprint-review] (the s321 document's population): %d spawns $%.2f  per story $%.2f" % (sp, len(both), usd(both), usd(both) / ST[sp]))
        dup = collections.Counter((r["sprint"], r["step"], r["unit"]) for r in rows if r["step"] in G_LABELS and int(r["sprint"]) in (319, 322))
        p("duplicate units across lead transcripts in these labels: %d (control: %d units counted)" % (sum(1 for v in dup.values() if v > 1), len(dup)))
        for sp in (319, 322):
            c = collections.Counter(r["step"] for r in rows if int(r["sprint"]) == sp and r["role"] == "gate-adjudicator")
            p("s%d gate-adjudicator rows by label: %s" % (sp, dict(sorted(c.items()))))
        p("s319 retro-gate: no verdict file under s319 gate-adjudication at the clone HEAD (a retro gate did not run, not a mislabel): retro verdicts %d, sprint-review verdicts %d (control)" % (
            len([f for f in ls("HEAD", "_bmad-output/implementation-artifacts/s319/gate-adjudication/") if "/retro-" in f]),
            len([f for f in ls("HEAD", "_bmad-output/implementation-artifacts/s319/gate-adjudication/") if "/sprint-review-" in f])))

    if 2 in blocks:
        p("\n== 2. partitions by description (each must SUM to the label total, 0 unmatched, 0 double-matched)")
        p("-- sprint-review, s322 (label sprint-review + gate-validation[sprint-review])")
        both = lrows(rows, 322, "sprint-review", "gate-validation[sprint-review]")
        part = partition(both, SR_322, "s322 sprint-review + gate")
        sr_only = lrows(rows, 322, "sprint-review"); p("  of which label sprint-review alone: %s ; gate label alone: %s" % (tot(sr_only), tot(lrows(rows, 322, "gate-validation[sprint-review]"))))
        p("-- sprint-review, s319 (both labels)")
        partition(lrows(rows, 319, "sprint-review", "gate-validation[sprint-review]"), SR_319, "s319 sprint-review + gate")
        seats = collections.defaultdict(lambda: [0, 0.0])
        for r in both:
            if re.search(r"-(\d|cross) seat$", r.get("description") or ""): s = seats[(r["role"], r["model_ran"])]; s[0] += 1; s[1] += r["usd"] or 0
        p("  s322 seats by (role, model ran): " + ", ".join("%s/%s %d $%.2f" % (k[0], k[1], v[0], v[1]) for k, v in sorted(seats.items())))
        p("-- deploy-validate, s322 / s319")
        partition(lrows(rows, 322, "deploy-validate"), DV_322, "s322 deploy-validate")
        partition(lrows(rows, 319, "deploy-validate"), DV_319, "s319 deploy-validate")
        p("-- retro, s322 / s319")
        partition(lrows(rows, 322, "retro"), RT_322, "s322 retro")
        partition(lrows(rows, 319, "retro"), RT_319, "s319 retro")
        p("-- gate-validation[retro], s322 (s319: 0 rows)")
        partition(lrows(rows, 322, "gate-validation[retro]"), RG_322, "s322 gate-validation[retro]")
        p("-- handoff, s322 (s319: 0 rows)")
        partition(lrows(rows, 322, "handoff"), HO_322, "s322 handoff")
        late = [r for r in lrows(rows, 322, "retro") if (r.get("start") or "") >= "2026-11-12T12:32"]
        p("  retro spawns that start after the close commit (12:32Z): %d  $%.2f  (the Dispatch C inputs; their records sit at the clone HEAD, not at %s)" % (len(late), usd(late), CLOSE))

    sf = seats_at(SHIP) if refs["SHIP"] else {}
    tri = show(CLOSE, "_bmad-output/implementation-artifacts/s322/sprint-review-party-triage.md") or ""
    ents = triage_entries(tri) if tri else []
    disp = dispositions(tri) if tri else {}

    if 3 in blocks:
        p("\n== 3. sprint-review yield (seat files at %s; triage and its lead disposition at %s)" % (SHIP, CLOSE))
        cm = collections.Counter(); mi = collections.Counter(); heads = {}
        for f, (role, n) in sf.items():
            for ln in (show(SHIP, f) or "").split("\n"):
                m = CM.match(ln)
                if m: cm[(role, "cross" if n == "cross" else "story")] += 1; heads[(os.path.basename(f)[14:-3], "F-" + m.group(1))] = "major"
                m = MI.match(ln)
                if m: mi[role] += 1; heads[(os.path.basename(f)[14:-3], "F-" + m.group(1))] = "minor"
        crit = sum(1 for f in sf for ln in (show(SHIP, f) or "").split("\n") if re.match(r"^## F-\d+ \(critical\)", ln, re.I))
        p("  seat files %d; C/M headings %d (critical %d); minor headings %d; total %d" % (len(sf), sum(cm.values()), crit, sum(mi.values()), len(heads)))
        p("  C/M by role and kind: %s" % dict(sorted(cm.items())))
        by_role = collections.Counter(); [by_role.update({k[0]: v}) for k, v in cm.items()]
        p("  C/M by role: %s" % dict(sorted(by_role.items())))
        m = re.search(r"input counts: (\d+) major, (\d+) minor, (\d+) critical \((\d+) findings", tri)
        p("  triage file's own input counts (45 major, 112 minor, 0 critical, 157): %s ; headings give %d / %d / %d / %d : %s" % (
            m.groups() if m else None, sum(cm.values()) - crit, sum(mi.values()), crit, len(heads),
            "MATCH" if m and tuple(map(int, m.groups())) == (sum(cm.values()) - crit, sum(mi.values()), crit, len(heads)) else "DIFFERS"))
        pairs = [(s.split("::")[0], s.split("::")[1]) for e in ents for s in e["src"]]
        p("  second count, triage `sources:` pairs: %d entries, %d pairs, %d distinct, %d not in the seat headings (0 expected), %d seat headings not in any entry (0 expected)" % (
            len(ents), len(pairs), len(set(pairs)), len([x for x in set(pairs) if x not in heads]), len([x for x in heads if x not in set(pairs)])))
        p("  merged major entries %d (their major-labelled source pairs: %d), minor entries %d" % (
            sum(1 for e in ents if e["sev"] == "major"), len({x for e in ents if e["sev"] == "major" for x in map(lambda s: (s.split("::")[0], s.split("::")[1]), e["src"]) if heads.get(x) == "major"}), sum(1 for e in ents if e["sev"] == "minor")))
        p("  impossible seat token '%s' in the triage: %d (must be 0); a real one 'architect-1::F-1': %d (must be > 0)" % (IMPOSSIBLE_TOK, tri.count(IMPOSSIBLE_TOK), tri.count("architect-1::F-1")))
        c = collections.Counter((e["sev"], final_class(e, disp)) for e in ents)
        p("  triage recommend vs the lead's final class, by severity: %s" % dict(sorted(c.items())))
        p("  triage verdicts: %s" % dict(collections.Counter((e["sev"], e["ver"]) for e in ents)))
        fixed = [e for e in ents if final_class(e, disp) in ("CODE-FIX", "ARTIFACT-FIX")]
        p("  entries the lead fixed (CODE-FIX or ARTIFACT-FIX): %d (major %d)" % (len(fixed), sum(1 for e in fixed if e["sev"] == "major")))
        for label, pool in (("major fixed entries", [e for e in fixed if e["sev"] == "major"]), ("major CODE-FIX entries", [e for e in fixed if e["sev"] == "major" and final_class(e, disp) == "CODE-FIX"])):
            solo_role = collections.Counter(); solo_seat = collections.Counter(); onlycross = 0; onlystory = 0
            for e in pool:
                roles = {s.split("::")[0].rsplit("-", 1)[0] for s in e["src"]}; seatset = {s.split("::")[0] for s in e["src"]}
                if len(roles) == 1: solo_role[next(iter(roles))] += 1
                if len(seatset) == 1: solo_seat[next(iter(seatset)).rsplit("-", 1)[0]] += 1
                kinds = {s.split("::")[0].endswith("-cross") for s in e["src"]}
                onlycross += kinds == {True}; onlystory += kinds == {False}
            p("  %s (%d): raised by one role only %s; by one seat only %s; by cross seats only %d, by per-story seats only %d" % (
                label, len(pool), dict(sorted(solo_role.items())), dict(sorted(solo_seat.items())), onlycross, onlystory))
        p("  multiplicity: major entries' distinct-seat counts %s" % sorted(collections.Counter(len({s.split('::')[0] for s in e['src']}) for e in ents if e["sev"] == "major").items()))
        # sprint-level adversary
        adv = show(CLOSE, "_bmad-output/implementation-artifacts/s322/sprint-adversarial-p1.md") or ""
        p("  adversary one-shot: finding headings (### S-) %d, graded Suggestion %d, 'no Critical or Important' line present %d; C/M raised 0" % (
            len(re.findall(r"(?m)^### S-\d+", adv)), len(re.findall(r"(?m)^- Severity: Suggestion", adv)), int("no Critical or Important" in adv)))

    if 4 in blocks:
        p("\n== 4. sprint-review fix survival (added lines >= 12 chars; base = round-start tree %s; ship = %s)" % (PRE_SR, SHIP))
        if not (refs["PRE_SR"] and refs["SHIP"] and refs["GATE_HEAD"]):
            p("  UNAVAILABLE: this repo lacks %s%s%s; rerun with the real graph repo" % ("" if refs["PRE_SR"] else PRE_SR + " ", "" if refs["SHIP"] else SHIP + " ", "" if refs["GATE_HEAD"] else GATE_HEAD))
        else:
            raw = (git("log", "--reverse", "--format=%x00%h|%B", "%s..%s" % (PRE_SR, GATE_HEAD)) or "").split("\x00")[1:]
            log = [(x.split("|", 1)[0], x.split("|", 1)[1]) for x in raw]   # (sha, full message: subject plus body)
            per_t = collections.defaultdict(lambda: [0, 0, 0]); unmapped = []; records = []
            p("  commits in %s..%s: %d ; T-ids are read from the full commit message, subject plus body" % (PRE_SR, GATE_HEAD, len(log)))
            for h, msg in log:
                s = msg.split("\n", 1)[0]; ts = sorted({int(x) for x in re.findall(r"\bT-(\d+)\b", msg)})
                files = added_lines(h); n, c = survival(files, (PRE_SR, SHIP))
                if not s.startswith("fix("):
                    records.append(h); p("  %s [not a fix: round record] lines %4d at ship %4d  %s" % (h, n, c[SHIP], s[:70])); continue
                if not ts: unmapped.append((h, s[:70], n, c[SHIP]))
                for t in ts: per_t[t][0] += n; per_t[t][1] += c[PRE_SR]; per_t[t][2] += c[SHIP]
                p("  %s lines %4d  at base %4d  at ship %4d (%s)  T:%s  %s" % (h, n, c[PRE_SR], c[SHIP], pct(c[SHIP], n), ",".join(map(str, ts)) or "--", s[8:62]))
            fixc = [h for h, m_ in log if m_.startswith("fix(")]; fl = [survival(added_lines(h), (PRE_SR, SHIP)) for h in fixc]
            p("  all %d fix commits: added lines %d, at ship %d (%s)" % (len(fixc), sum(x[0] for x in fl), sum(x[1][SHIP] for x in fl), pct(sum(x[1][SHIP] for x in fl), sum(x[0] for x in fl))))
            ctrl = added_lines(RETRO_BASE); n, c = survival(ctrl, (PRE_SR, SHIP))
            p("  must-differ control: post-merge commit %s (follow-up after the merge): lines %d, at ship %d (%s)  <- must read far below the fix commits" % (RETRO_BASE, n, c[SHIP], pct(c[SHIP], n)))
            ent = {e["n"]: e for e in ents}
            fixed_ids = [e["n"] for e in ents if final_class(e, disp) in ("CODE-FIX", "ARTIFACT-FIX")]
            p("  per entry (commits naming it; a commit naming several entries counts in each): entries with a commit %d of %d fixed entries" % (len([i for i in fixed_ids if i in per_t]), len(fixed_ids)))
            for sev in ("major", "minor"):
                have_c = [i for i in fixed_ids if ent[i]["sev"] == sev and i in per_t]
                lines_ = sum(per_t[i][0] for i in have_c); ship_ = sum(per_t[i][2] for i in have_c)
                p("   %s entries with a commit %d: added lines %d, at ship %d (%s)" % (sev, len(have_c), lines_, ship_, pct(ship_, lines_)))
            both_ = lrows(rows, 322, "sprint-review", "gate-validation[sprint-review]")
            mj = [i for i in fixed_ids if ent[i]["sev"] == "major" and i in per_t and per_t[i][2] * 100 >= per_t[i][0] * 80]
            p("  fixed major entries whose commits keep >= 80%% of their lines at ship: %d ; both-label cost $%.2f -> $%.2f per such entry (per entry, not per distinct defect; seats double-raise)" % (len(mj), usd(both_), usd(both_) / max(len(mj), 1)))
            p("  accepted-fix entries with NO commit naming them: major %s ; minor count %d" % (
                [i for i in fixed_ids if ent[i]["sev"] == "major" and i not in per_t], len([i for i in fixed_ids if ent[i]["sev"] == "minor" and i not in per_t])))
            p("  commits in the range with no T-id: %d  %s" % (len(unmapped), [(a, d) for a, d, _, _ in unmapped][:6]))
            ac = added_lines("b6b5d8df9"); n, c = survival(ac, (ADV_BASE, SHIP)) if refs["ADV_BASE"] else (0, {})
            p("  adversary S-1/S-2 fix b6b5d8df9 (base %s): lines %d at ship %s" % (ADV_BASE, n, c.get(SHIP)))
        # earlier-raise candidates (hand reading follows in the report)
        p("\n  earlier-raise candidates: regex hit counts at %s over docs/reviews/s322 + planning/implementation artifacts of s322, EXCLUDING the round's own briefs (hand-read; positive control = the same regex over the triage)" % PRE_SR)
        if refs["PRE_SR"]:
            pats = [("T-4 DEPLOY_RANGE producer/contract", r"DEPLOY_RANGE.*(producer|never defined|nothing defines|assign|export)|(producer|assign|export).*DEPLOY_RANGE"),
                    ("T-9 admission verifier wired into no lane (narrow)", r"(test-pytest-admission|admission verifier).*(wired|unwired|no lane|not run by|never run|runs in no)|(wired|unwired|no lane|never run).*(test-pytest-admission|admission verifier)"),
                    ("T-9 same file named at all (broad; file listings)", r"test-pytest-admission"),
                    ("T-25 watchdog exit status (narrow)", r"footprint-watchdog.*(always exit|exits? 0|exit status|returncode|propagat|return code)"),
                    ("T-25 watchdog named at all (broad; usage lines)", r"footprint-watchdog"),
                    ("gate Check 3: story 1.8 LOCKED_REQUIREMENTS block absent", r"1\.8.*LOCKED_REQUIREMENTS|LOCKED_REQUIREMENTS.*1\.8|locked_requirements: \[\].*1\.8"),
                    ("impossible", IMPOSSIBLE_TOK)]
            for name, rx in pats:
                hits = (git("grep", "-n", "-E", rx, PRE_SR, "--", "docs/reviews/s322", "_bmad-output/planning-artifacts/s322", "_bmad-output/implementation-artifacts/s322",
                            ":(exclude)_bmad-output/planning-artifacts/s322/rounds/sprint-review-party") or "").strip().split("\n")
                hits = [h.split(":", 1)[1] for h in hits if h]
                files = sorted({h.split(":")[0] for h in hits})
                ctl = len(re.findall(rx, tri))
                p("   %-58s earlier hits %2d in %d files %s | triage hits %d (positive control)" % (name, len(hits), len(files), [os.path.basename(f) for f in files][:4], ctl))

    if 5 in blocks:
        p("\n== 5. sprint-review gate (gate-validation[sprint-review] + repair) and the Check 3 catch")
        P = "_bmad-output/implementation-artifacts/s322/gate-adjudication/"
        for nonce in ("20261112T051649Z", "20261112T053127Z"):
            v = show(CLOSE, P + "sprint-review-%s.verdict.json" % nonce)
            if not v: p("  verdict %s UNAVAILABLE" % nonce); continue
            d = json.loads(v)["verdicts"]
            p("  pass %s: %d checks, %s ; non-PASS: %s" % (nonce, len(d), dict(collections.Counter(x["verdict"] for x in d)), [(x["check_id"], x["verdict"]) for x in d if x["verdict"] != "PASS"]))
        rep = show(CLOSE, P + "sprint-review-20261112T051649Z.repair.md") or ""
        p("  repair record: repaired_checks line %r ; names story 1.8 and LR-S322-9: %s ; impossible token: %d" % (
            (re.search(r"repaired_checks: (\d+)", rep) or [None, None])[1], "LR-S322-9" in rep and "story 1.8" in rep, rep.count(IMPOSSIBLE_TOK)))
        if refs["LR"] and refs["PRE_SR"] and refs["GATE_HEAD"]:
            sp = "_bmad-output/planning-artifacts/s322/stories/story-1-8-xdist-crash-admission-controls.md"
            fm = lambda ref: (re.search(r"(?m)^locked_requirements: (.*)$", blob(ref, sp)) or [None, None])[1]
            p("  story 1.8 frontmatter locked_requirements: at %s %s ; at %s^ %s ; at %s^ %s ; at ship %s" % (PRE_SR, fm(PRE_SR), LR_COMMIT, fm(LR_COMMIT + "^"), GATE_HEAD, fm(GATE_HEAD + "^"), fm(SHIP)))
            has_block = lambda ref: len(re.findall(r"(?m)^## LOCKED_REQUIREMENTS\s*$", blob(ref, sp)))
            p("  `## LOCKED_REQUIREMENTS` block count in story 1.8: at %s %d ; at %s^ %d ; at %s %d ; at ship %d (absent before the gate repair, present at ship)" % (
                PRE_SR, has_block(PRE_SR), GATE_HEAD, has_block(GATE_HEAD + "^"), GATE_HEAD, has_block(GATE_HEAD), has_block(SHIP)))
            files = added_lines(GATE_HEAD); n, c = survival(files, (GATE_HEAD + "^", SHIP))
            p("  repair commit %s: added lines %d, at its parent %d, at ship %d (%s)" % (GATE_HEAD, n, c[GATE_HEAD + "^"], c[SHIP], pct(c[SHIP], n)))
            p("  the commit that set the frontmatter to [LR-S322-9], %s, names T-ids %s (a sprint-review fix; the gate caught what the step's own fix introduced)" % (
                LR_COMMIT, sorted({int(x) for x in re.findall(r"\bT-(\d+)\b", git("log", "-1", "--format=%s", LR_COMMIT) or "")})))
            p("  implementation gate at story 1.8 had read `locked_requirements: []` and PASSED with a disclosed exemption: verdict 102922Z check 3 mentions 'locked_requirements: []': %d" % (
                (show(PRE_SR, P + "implementation-20261111T102922Z.verdict.json") or "").count("locked_requirements: []")))
        else:
            p("  frontmatter and block survival UNAVAILABLE in this repo (needs %s, %s, %s)" % (PRE_SR, LR_COMMIT, GATE_HEAD))
        seat_corpus = "".join(show(SHIP, f) or "" for f in sf) + tri
        both_ = [l for l in seat_corpus.split("\n") if "LOCKED_REQUIREMENTS" in l and re.search(r"\b1\.8\b|story-1-8|\b1-8\b", l)]
        p("  lines in the seat files or triage naming LOCKED_REQUIREMENTS together with story 1.8: %d (the Check 3 defect is not raised by any seat; the one LOCKED_REQUIREMENTS line is a clean-bill line for another story)" % len(both_))
        p("  does any seat file or the triage name the Check 3 defect? 'LOCKED_REQUIREMENTS' %d, 'LR-S322-9' %d, impossible %d, positive control 'DEPLOY_RANGE' %d" % (
            seat_corpus.count("LOCKED_REQUIREMENTS"), seat_corpus.count("LR-S322-9"), seat_corpus.count(IMPOSSIBLE_TOK), seat_corpus.count("DEPLOY_RANGE")))

    if 6 in blocks:
        p("\n== 6. deploy-validate (labels: deploy-validate only; no gate label in either sprint)")
        dv = lrows(rows, 322, "deploy-validate")
        for r in dv: p("  s322 %-6s %-6s $%5.2f %5.1f min %s  %s" % (r["role"], r["model_ran"], r["usd"], r["minutes"], r["start"][5:16], r["description"]))
        P = "_bmad-output/implementation-artifacts/s322/"
        tot_f = 0
        for f in ("ops-4b-preroll-report", "ops-lock-reread-report", "ops-lock-reread-2-report"):
            t = show(CLOSE, P + f + ".md") or ""
            fh = re.findall(r"(?m)^#+ Finding ", t); disp_ = re.findall(r"(?m)^- disposition: (.*)$", t); tasks = re.findall(r"(?m)^## Task \d", t)
            tot_f += len(fh)
            p("  %-26s %5d bytes, `## Task` headings %d, Finding headings %d, dispositions %s" % (f, len(t), len(tasks), len(fh), [d[:30] for d in disp_]))
        t4 = show(CLOSE, P + "ops-4b-preroll-report.md") or ""
        t1 = show(CLOSE, P + "ops-lock-reread-report.md") or ""; t2 = show(CLOSE, P + "ops-lock-reread-2-report.md") or ""
        p("  active execution_lock rows `(0 rows)` per report: 4b %d, re-read 1 %d, re-read 2 %d ; re-read 1 line 'LOCK-RECHECK: IDLE' %d ; verdicts '3/3 PASSED, 0 skipped' in 4b %d" % (
            t4.count("(0 rows)"), t1.count("(0 rows)"), t2.count("(0 rows)"), t1.count("LOCK-RECHECK: IDLE"), t4.count("3/3 PASSED, 0 skipped")))
        p("  hygiene finding in re-read 2: the 08:03Z seat's SSM session still Active server-side ('stale, from the 08:03Z re-read seat') %d, terminated %d ; impossible %d" % (
            t2.count("stale, from the 08:03Z re-read seat"), t2.count("terminated before this read"), t2.count(IMPOSSIBLE_TOK)))
        retro = show(CLOSE, "docs/retro/s322/retro.md") or ""
        p("  retro's ledger line: '7 discharged, 3 re-deferred' present %d ; 'rb_all_idle plus compensating lock reads' present %d ; impossible %d" % (
            retro.count("7 discharged, 3 re-deferred"), retro.count("compensating lock reads"), retro.count(IMPOSSIBLE_TOK)))
        sevs = [l for f in ("ops-4b-preroll-report", "ops-lock-reread-report", "ops-lock-reread-2-report") for l in (show(CLOSE, P + f + ".md") or "").split("\n") if re.match(r"(?i)^(#+ .*\((critical|major)\)|- severity: (critical|major))", l)]
        sev_rx = r"(?i)^(#+ .*\((critical|major)\)|- severity: (critical|major))"
        ctl_ = sum(1 for f in sf for l in (show(SHIP, f) or "").split("\n") if re.match(sev_rx, l))
        p("  same severity grammar over the 45 sprint-review seat files (positive control, must be > 0): %d" % ctl_)
        p("  severity lines of critical or major in the three reports: %d (headings carry no severity grade; the 4b report has Tasks, the two re-reads one `state read only` Finding each, disposition n/a)" % len(sevs))

    if 7 in blocks:
        p("\n== 7. retro (party persona rounds + analyst shards + Dispatch C) and gate-validation[retro]")
        rt = show(CLOSE, "docs/retro/s322/retro.md") or ""; L = rt.split("\n")
        rowsf = [l for l in L if re.match(r"\| (PM|AR|DV|SM|TEA|QA) \| F-", l)]
        sev = collections.Counter(l.split("|")[3].strip() for l in rowsf); ps = collections.Counter(l.split("|")[1].strip() for l in rowsf)
        prov = re.search(r"findings_critical: (\d+)\nfindings_major: (\d+)\nfindings_minor: (\d+)", rt)
        p("  findings table rows %d: %s ; by pass %s" % (len(rowsf), dict(sev), dict(ps)))
        p("  provenance block counts (critical, major, minor): %s ; table (CRITICAL, IMPORTANT, MODERATE): %s : %s" % (
            prov.groups() if prov else None, (sev["CRITICAL"], sev["IMPORTANT"], sev["MODERATE"]),
            "MATCH" if prov and tuple(map(int, prov.groups())) == (sev["CRITICAL"], sev["IMPORTANT"], sev["MODERATE"]) else "DIFFERS"))
        p("  C/M-class rows (CRITICAL+IMPORTANT) %d" % (sev["CRITICAL"] + sev["IMPORTANT"]))
        impr = [l for l in L if re.match(r"- \*\*I-\d+ ", l)]
        route = {m.group(1): m.group(2).split("|") for l in L for m in [re.match(r"\| (I-\d+) \| (.*) \|$", l)] if m}
        cited = set()
        for l in impr:
            cited |= set(re.findall(r"F-(?:PM|AR|DV|SM|TEA|QA)-\d+", l))
        allf = {l.split("|")[2].strip() for l in rowsf}
        p("  improvements I-n in the retro: %d ; F-ids cited by them: %d of %d table rows ; F-ids cited but not in the table (0 expected): %d" % (len(impr), len(cited & allf), len(allf), len(cited - allf)))
        for l in impr:
            iid = re.match(r"- \*\*(I-\d+)", l).group(1); ids = sorted(set(re.findall(r"F-(?:PM|AR|DV|SM|TEA|QA)-\d+", l)))
            crit = [i for i in ids if any(i in r and "CRITICAL" in r for r in rowsf)]
            r_ = route.get(iid, ["?", "?", "?", "?", "?"])
            p("   %s cites %2d finding ids (CRITICAL among them: %s) ; lands as: %s" % (iid, len(ids), crit, " ".join(r_[-1:]).strip()[:70]))
        # landing by id or claim span, absent at base and present at close
        p("  landing (absent at %s, present at %s):" % (RETRO_BASE, CLOSE))
        if refs["RETRO_BASE"] and refs["CLOSE"]:
            LED = "_bmad-output/ai-dlc-update/push-candidate-ledger.md"
            post = POST_CLOSE if have(POST_CLOSE) else None
            for tag, files, ids in (("I-2 push candidate", [LED], ["PC-S322-RETRO-CARRY-DERIVATION-REPOINT-BLINDS-TREE-MATCH"]),
                                    ("I-5 CO item", ["_bmad-output/planning-artifacts/carry-over-backlog.md"], ["CO-S322-DOTENV-IMPORT-INJECTION-RESIDUAL"])):
                corpus = lambda ref: "".join(blob(ref, f) for f in files)
                a, b = corpus(RETRO_BASE), corpus(CLOSE)
                for i in ids: p("   %s id %-62s at base %d, at close %d, at %s (the #1320 ledger backfill) %s" % (tag, i, a.count(i), b.count(i), POST_CLOSE, corpus(post).count(i) if post else "UNAVAILABLE"))
            for tag, iid, path in (("I-3 extension edit", "I-3", ".claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md"), ("I-4 conventions edit", "I-4", "docs/coding-conventions.md")):
                para = next((l for l in impr if l.startswith("- **%s " % iid)), "")
                spans = PT.claim_spans(para)
                before, after = blob(RETRO_BASE, path), blob(CLOSE, path)
                p("   %s %s: %d claim spans from the improvement text; in target at base %d, at close %d, new (absent at base, present at close) %d ; target changed by the retro PR: %s" % (
                    tag, path.split("/")[-1], len(spans), sum(1 for s in spans if s in before), sum(1 for s in spans if s in after), sum(1 for s in spans if s not in before and s in after), before != after))
            for tag, path, tok in (("I-3 emitted paragraph", ".claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md", "**Re-open obligation naming.**"),
                                   ("I-4 emitted heading", "docs/coding-conventions.md", "## Validator Tests Against the Live Config Shape")):
                p("   %s `%s` in %s: at base %d, at close %d" % (tag, tok, path.split("/")[-1], blob(RETRO_BASE, path).count(tok), blob(CLOSE, path).count(tok)))
            fl = added_lines(RETRO_PR); n, c = survival({f: v for f, v in fl.items() if f in ("docs/coding-conventions.md", ".claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md", "_bmad-output/planning-artifacts/carry-over-backlog.md")}, (RETRO_BASE, CLOSE))
            p("   added lines of the retro PR in those three targets: %d, at base %d, at close %d (%s)" % (n, c[RETRO_BASE], c[CLOSE], pct(c[CLOSE], n)))
            i8 = next((l for l in impr if l.startswith("- **I-8 ")), "")
            cos = sorted(set(re.findall(r"CO-S\d+-[A-Z0-9-]*[A-Z0-9]", i8)))
            bk = "_bmad-output/planning-artifacts/carry-over-backlog.md"
            p("   I-8 (CRITICAL product findings 'existing COs'): ids named %d ; present in the carry-over backlog at base %d, at close %d  (a present-at-base id means an earlier record already carried the finding: REFOUND by id)" % (
                len(cos), sum(1 for c_ in cos if c_ in blob(RETRO_BASE, bk)), sum(1 for c_ in cos if c_ in blob(CLOSE, bk))))
            p("   control: impossible CO id at base %d (must be 0); the backlog file length at base %d bytes (must be > 0)" % (blob(RETRO_BASE, bk).count("CO-S999-NEVER-XQ"), len(blob(RETRO_BASE, bk))))
        else:
            p("   UNAVAILABLE in this repo (needs %s and %s)" % (RETRO_BASE, CLOSE))
        # retro gate
        v = show(CLOSE, "_bmad-output/implementation-artifacts/s322/gate-adjudication/retro-20261112T111510Z.verdict.json")
        if v:
            d = json.loads(v)["verdicts"]; p("  retro gate verdict: %d checks %s ; non-PASS %d (gate-validation[retro]: 9 shards, 0 repairs)" % (len(d), dict(collections.Counter(x["verdict"] for x in d)), sum(1 for x in d if x["verdict"] != "PASS")))
        # Dispatch C at the clone HEAD
        p("  Dispatch C next-sprint inputs (records at the repo HEAD, not at %s):" % CLOSE)
        ni = show("HEAD", "_bmad-output/retro-artifacts/s322/next-inputs.md")
        if ni:
            ids = sorted(set(re.findall(r"CO-S\d+-[A-Z0-9-]*[A-Z0-9]", ni)))
            s323 = [f for f in ls("HEAD", "_bmad-output") if "/s323/" in f and f.endswith(".md")]
            corp = "".join(show("HEAD", f) or "" for f in s323)
            bk = show("HEAD", "_bmad-output/planning-artifacts/carry-over-backlog.md") or ""
            others = [c_ for c_ in sorted(set(re.findall(r"CO-S\d+-[A-Z0-9-]*[A-Z0-9]", bk))) if c_ not in ids][:200]
            p("   next-inputs.md: %d bytes, %d CO ids; cited in s323 planning files (%d files): %d of %d ; confound control, %d other backlog ids cited in s323: %d ; impossible id %d" % (
                len(ni), len(ids), len(s323), sum(1 for i in ids if i in corp), len(ids), len(others), sum(1 for i in others if i in corp), corp.count("CO-S999-NEVER-XQ")))
        else:
            p("   next-inputs.md UNAVAILABLE at HEAD of this repo")

    if 8 in blocks:
        p("\n== 8. handoff (1 spawn, label attribution)")
        h = lrows(rows, 322, "handoff")
        for r in h: p("  start %s end %s role %s $%.2f %.1f min: %s" % (r["start"], r["end"], r["role"], r["usd"], r["minutes"], r["description"]))
        p("  s319 handoff rows: %d (control: s322 %d)" % (len(lrows(rows, 319, "handoff")), len(h)))
        if refs["HANDOFF"]:
            files = added_lines(HANDOFF_COMMIT); n, c = survival(files, (HANDOFF_COMMIT + "^", SHIP, CLOSE))
            p("  commit %s (%s): files %s ; added lines %d, at parent %d, at ship %d (%s)" % (HANDOFF_COMMIT, (git("log", "-1", "--format=%s", HANDOFF_COMMIT) or "")[:80], sorted(files), n, c[HANDOFF_COMMIT + "^"], c[SHIP], pct(c[SHIP], n)))
        else:
            p("  commit %s UNAVAILABLE in this repo" % HANDOFF_COMMIT)


main()
