"""s323 step-value reading for the review tail: sprint-review, gate-validation[sprint-review], deploy-validate, retro,
gate-validation[retro] (BL-812 item 1, sprint 323 against sprint 319 and sprint 322).  Port of tail_yield_s322.py.

usage: python3 -I tail_yield_s323.py <OUT dir holding spawns.jsonl> <graph repo or clone> [block ...]
  block: 0 refs and corpus controls, 1 cost, 2 partitions, 3 sprint-review seats and fixes, 4 fix survival,
         5 adversary passes and the sprint-review gate, 6 deploy-validate, 7 retro and gate-validation[retro].
  No block: all, in order.
Helpers (bl812_rederive, party_ts_yield) load from $SV_HELPERS or ../../pipeline-efficiency-s317-s322/scripts.

Read-only: <OUT>/spawns.jsonl and read-only git commands (GIT_OPTIONAL_LOCKS=0). Writes nothing. Stdlib only.
Hand readings (cluster table CL, REFOUND/REPAIR-INTRODUCED/MISSED-BY-PRIOR classes) are labelled as such; every
count is a regex or a git command with a control in the same run. Times in spawns.jsonl are UTC, git times -0500.
"""
import collections, importlib.util, json, os, re, subprocess, sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
HELP = os.environ.get("SV_HELPERS") or os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s322", "scripts")


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HELP, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)      # both modules guard main() behind __name__ == "__main__"
    return mod


B = load("bl812_rederive")            # spawns(), agg(), STORIES
PT = load("party_ts_yield")           # claim_spans()
STORIES = dict(B.STORIES); STORIES[323] = 18       # 18 stories: gate-log :1669 "all 18 stories done (18/18)"

SHIP = "eabdc576e"        # s323 sprint merge on main (#1337, squash)
FF1_PR = "6fcfd81a7"      # fix(s323-ff1) merge (#1338), the post-ship control commit
RETRO_PR = "6d606eaab"    # s323 retro merge (#1339); its parent is FF1_PR
CLOSE = "16fd227d9"       # s323 close snapshot
PARTY_TIP = "42f97d575"   # the tree the 95 party briefs were cut at (commit 893c0c128 message)
PARTY_DONE = "9f7a5256e"  # "party round complete - 95/95 seats, 165 findings"
S322_CLOSE = "f7e60625b"
G_LABELS = ["sprint-review", "gate-validation[sprint-review]", "deploy-validate", "retro", "gate-validation[retro]", "handoff"]
LEAD = {(323, "sprint-review"): 11.61, (319, "sprint-review"): 1.93, (322, "sprint-review"): 9.62,
        (323, "gate-validation[sprint-review]"): 0.92, (319, "gate-validation[sprint-review]"): 3.02,
        (323, "deploy-validate"): 1.14, (319, "deploy-validate"): 0.56, (322, "deploy-validate"): 0.65,
        (323, "retro"): 1.00, (319, "retro"): 0.40, (322, "retro"): 1.78,
        (323, "gate-validation[retro]"): 0.28, (319, "gate-validation[retro]"): 0.00, (322, "gate-validation[retro]"): 0.44}
IMPOSSIBLE_STEP, IMPOSSIBLE_TOK = "QZXV-NO-SUCH-STEP-5512", "ZQX-NEVER-TOKEN-77"
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
G = None


def git(*a):
    r = subprocess.run(["git", "-C", G] + list(a), capture_output=True, text=True, env=ENV)
    return r.stdout if r.returncode == 0 else None


def show(ref, path): return git("show", "%s:%s" % (ref, path))
def have(ref): return git("cat-file", "-e", ref + "^{commit}") is not None
def ls(ref, prefix): return [f for f in (git("ls-tree", "-r", "--name-only", ref, prefix) or "").split("\n") if f]
def usd(rs): return sum(r.get("usd") or 0 for r in rs)
def mins(rs): return sum(r.get("minutes") or 0 for r in rs)
def tot(rs): return "%3d  $%7.2f  %6.1f min" % (len(rs), usd(rs), mins(rs))
def p(s=""): print(s)
def pct(a, b): return "%5.1f%%" % (100.0 * a / b) if b else "  n/a "
def lrows(rows, sp, *steps): return [r for r in rows if int(r["sprint"]) == sp and r["step"] in steps]
def cdate(c): return (git("log", "-1", "--format=%cd", "--date=format:%m-%d %H:%M %z", c) or "?").strip()


def partition(rows, parts, label):
    """parts: [(name, regex)] on description; every row must match exactly one part and there is NO catch-all."""
    got = collections.OrderedDict((n, []) for n, _ in parts); un = []; multi = 0
    for r in rows:
        hit = [n for n, rx in parts if re.search(rx, r.get("description") or "")]
        if len(hit) > 1: multi += 1
        if hit: got[hit[0]].append(r)
        else: un.append(r)
    for n, rs in got.items(): print("  %-58s %s" % (n, tot(rs)))
    s = [x for rs in got.values() for x in rs]
    ok = len(s) == len(rows) and abs(usd(s) - usd(rows)) < 1e-9 and abs(mins(s) - mins(rows)) < 1e-9
    print("  %-58s %s" % ("PARTITION SUM", tot(s)))
    print("  label total %-46s %s   sum control: %s   unmatched (catch-all) %d  double-matched %d (both must be 0)" % (
        label, tot(rows), "MATCH" if ok else "DIFFERS", len(un), multi))
    for r in un[:5]: print("    UNMATCHED:", r.get("description"))
    return got


# ---------------------------------------------------------------- description partitions (anchored, no catch-all)
SEATRX = r"(pm|dev|qa|tea|architect) (\d+|cross)"
SR_323 = [("adversary one-shot passes (A 02:53Z, B 04:00Z, C 15:57Z)", r"^(Sprint 323 adversarial review|Sprint adversarial pass 2|Sprint-level adversarial pass)$"),
          ("pass A/B repair: merges, re-review, suites, fixes", r"^(Dev-escalated \d\.\d merge resolution|Re-review \d\.\d merge resolution|Full suites on merged HEAD|Fix 1\.4 bootstrap \+ SA-5 \+ SA-2|Re-review post-merge fixes|Fix p2 F-2 and F-6)$"),
          ("late story 2.1/2.3 build, review, QA (label by clock)", r"^(Close story 2\.1 record|Build story 2\.3 native pay-by-value|Pre-review story 2\.3 diff|Review 2\.3 pay-by-value diff|QA-validate 2\.3 pay-by-value)$"),
          ("pass C repair: F-1 wording, F-2/3/4 fixes, re-review, QA", r"^(F-1 procedure wording repair|F-2/F-3/F-4 code fixes|Re-review fix commits|Re-validate fix suite)$"),
          ("party dispatchers (p1, p2)", r"^Dispatch party round( p2)?$"),
          ("party seat rows named '<role> <n|cross>' (first dispatch)", r"^" + SEATRX + r"$"),
          ("party seat rows named '<role> <n|cross> seat' (second dispatch)", r"^" + SEATRX + r" seat$"),
          ("party fixes: devA devB devC, remediator p2", r"^(dev fixes A rebalancer|dev fixes B live-smoke|dev C small follow-ups|remediator artifact repair p2)$"),
          ("step-3 review loop: code re-review, QA, fix", r"^(Step-3 code re-review|Step-3 QA re-validation|Fix step-3 review findings)$")]
GS_323 = [("story 2.2/2.3 gate-3 adjudication and addendum (label by clock)", r"^(Adjudicate 2\.[23] gate-3 (rerun )?checks|Escalated addendum for 2\.3 review)$"),
          ("sprint-review gate adjudicators (pass 1 and pass 2, 4 shards each)", r"^Gate adjudicator shard \d/4$"),
          ("gate-failure remediator (pass-1 Check 1 FAIL)", r"^Gate-failure remediator sprint-review$")]
SR_319 = [("party seats, per-story", r"^SR party (pm|dev|qa|tea|architect) story \d+$"),
          ("party seats, cross", r"^SR party (pm|dev|qa|tea|architect) cross g\d$"),
          ("party consolidation", r"^Consolidate party round findings$"),
          ("adversary one-shot", r"^Sprint-review one-shot adversarial$"),
          ("fixes, with their review and QA", r"^(Step \d+ fix bundle|Fix C |Code review of fix|QA validation of fix|Re-QA of fix|Re-review of fix)"),
          ("gate adjudicators (4 shards)", r"^Gate adjudicator shard \d/4$")]
DV_323 = [("ops reads for the S323 roll (10: pre, post, AC reads)", r"^(Pre-roll reads for S323 deploy|Fresh active-lock reads pre-roll|Post-roll ops reads batch|Aggregator post-roll ops reads|Ui post-roll ops reads|Pre-fire allowlist GET read|AC7 after-read OPS seat|Post-smoke 4b window re-read|OPS: 5\.3 AC3 ground-truth read|OPS: 5\.1 values capture read)$"),
          ("ff1 fix-forward: dev fix and its review", r"^(Fix mTLS gate verify-mode header|Review ff1 fix diff)$"),
          ("ff1 ops reads (pre-roll, Base cert audit)", r"^(OPS pre-roll reads for ff1 roll|OPS Base cert-audit read)$")]
DV_319 = [("ops reads (Aurora, config, P&L, smoke cases)", r"^\d+b "),
          ("deferred-AC predicate extraction", r"^Extract deferred-AC predicates$"),
          ("diagnosis (smoke red, stale rewards)", r"^Diagnose "),
          ("fix-forward dev, code review and QA", r"^(Move rewards into|Review status-bar|QA status-bar)")]
RT_323 = [("party persona rounds (6)", r"^Party: (PM John|Dev Amelia|QA Tessa|SM Bob|TEA Quinn|Architect Winston)$"),
          ("analyst: classify findings (1)", r"^Classify party findings$"),
          ("analyst draft surfaces (7)", r"^Retro draft surface: "),
          ("analyst close-out (3)", r"^Closeout: "),
          ("dev fixes the retro applied (ecs-deploy poll, bright-line)", r"^(Fix ecs-deploy rollout poll|Bright-line reclass fixes)$"),
          ("7b next-sprint inputs (6)", r"^7b input \d: ")]
RT_319 = [("party persona seats (6)", r"^Retro party seat "),
          ("analyst gather, draft, close-out (5)", r"^(Gather Sprint \d+ handoff inputs|Re-read |Retro draft analyst|Close-out tables analyst)"),
          ("ops discharge reads (1)", r"^Read-only LR-S\d+-\d+ discharge reads$")]
RG_323 = [("retro gate shards (3)", r"^Retro gate shard \d/3$")]

# ---------------------------------------------------------------- seat files, fix records, hand cluster table
SEATF = re.compile(r"^sprint-review-(architect|dev|pm|qa|tea)-(\d+|cross)\.md$")
HEAD = re.compile(r"^## F-(\d+) \((\w+)\)")
CMSEV = ("critical", "major", "important")      # C/M-class vocabulary; 'medium' is reported apart, never folded in silently
FIXREC = ["sprint-review-fixes-devA", "sprint-review-fixes-devB", "sprint-review-fixes-devC", "sprint-review-fixes-devD", "sprint-review-repair-p2"]
CITE = re.compile(r"((?:(?:architect|dev|pm|qa|tea)-(?:\d+|cross)(?:\s*/\s*)?)+)\s*F-(\d+)")

# fix commits, by round: (sha, round). Base for survival = the commit's parent.
FIX_A = ["a2e89caca", "a11ffe82c", "6dab86c84", "208112c14"]            # adversary pass A (SA-4, SA-5/SA-2/AC3c) and pass B (F-2, F-6 guard + root)
FIX_C = ["ff164e5e5", "ca8c5f03f", "65ece9ec7", "ce1305dd3", "08403fc4e"]   # adversary pass C (F-2, F-1, F-4, re-review rework); F-3 has no own commit
FIX_P = ["491420c4f", "486b178e6", "c6d3dbb4b", "9700c48e9", "5c5d58ab4", "da79a7828", "e2454d806", "a60719349", "ab599a998"]  # party fixes
# (name, [seat F-ids], class (hand), disposition (hand), fix commits that carry it)
CL = [("4.1 gate-log entry dropped by merge b3a7de522", ["architect-10 F-1", "dev-10 F-1", "pm-10 F-1", "qa-10 F-1", "tea-10 F-1"], "MISSED-BY-PRIOR", "FIXED", ["a60719349"]),
      ("4.2 AC1/AC2 marker proofs already satisfied (vacuous)", ["architect-11 F-1", "pm-11 F-1", "qa-11 F-1", "tea-11 F-1"], "MISSED-BY-PRIOR", "FIXED", ["e2454d806"]),
      ("APP_ENV=prod fire merges armed (pass A SA-3, re-raised)", ["architect-12 F-1", "architect-cross F-1", "dev-12 F-1", "qa-12 F-1", "tea-12 F-2"], "REFOUND", "DOC-ONLY", ["e2454d806"]),
      ("5.1 AC8 / 5.3 AC4 live-smoke assertions unwritten after 3.2 merged", ["architect-14 F-1", "architect-16 F-1", "pm-16 F-1", "qa-14 F-1", "tea-14 F-1", "tea-16 F-1"], "MISSED-BY-PRIOR", "FIXED", ["486b178e6", "da79a7828"]),
      ("5.1 e2e capture cited but never committed", ["tea-14 F-2"], "MISSED-BY-PRIOR", "FIXED", ["e2454d806"]),
      ("layer byte pin re-baselined again by ce1305dd3, no sign-off", ["dev-1 F-1", "tea-1 F-1"], "REPAIR-INTRODUCED", "NOT-FIXED", []),
      ("batch fee-collect abort lost the sequential fallback (1.3)", ["architect-cross F-2", "dev-cross F-1"], "MISSED-BY-PRIOR", "NOT-FIXED", []),
      ("4.4 header-forwarding tests in no ci-local lane", ["tea-13 F-1"], "MISSED-BY-PRIOR", "FIXED", ["c6d3dbb4b", "5c5d58ab4"]),
      ("5.4/5.5 deferred-AC junit ids drifted", ["tea-17 F-1"], "MISSED-BY-PRIOR", "FIXED", ["e2454d806"]),
      ("1.4 unstubbed every-read-above arm missing", ["tea-4 F-1"], "MISSED-BY-PRIOR", "FIXED", ["491420c4f"]),
      ("1.4 ceiling refusal consumes the subscribe retry budget", ["qa-4 F-1"], "MISSED-BY-PRIOR", "FIXED", ["da79a7828"]),
      ("2.2 refusal execution_log row carries no reason", ["tea-6 F-1"], "MISSED-BY-PRIOR", "FIXED", ["491420c4f"]),
      ("2.3 by-value Leg 1 proven only on the default router kind", ["tea-7 F-1"], "MISSED-BY-PRIOR", "FIXED", ["491420c4f"]),
      ("3.1 _load_env ImportError tolerance untested", ["qa-8 F-1"], "MISSED-BY-PRIOR", "FIXED", ["491420c4f"]),
      ("4.3 header-less caller list incomplete (s317 runbook)", ["tea-12 F-1"], "MISSED-BY-PRIOR", "FIXED", ["e2454d806"]),
      ("1.2 EIP-1559 branch uncapped (story states unchanged)", ["dev-2 F-1"], "MISSED-BY-PRIOR", "NOT-FIXED", []),
      ("5.5 collect-label test lacks the 3.2 route guards", ["architect-18 F-1"], "MISSED-BY-PRIOR", "FIXED", ["486b178e6"]),
      ("2.1 wallet-checksum deploy precondition has no durable carrier", ["qa-5 F-1"], "MISSED-BY-PRIOR", "NOT-FIXED", [])]


EV = {"architect-10 F-1": r"restore story-4\.1 Item-4 adjudication entry", "architect-11 F-1": r"Story 4-2 vacuous proofs",
      "architect-12 F-1": r"any `cdk deploy ServicesStack` is the fire", "architect-14 F-1": r"5\.1 AC7/AC8 and 5\.3 AC4 live-smoke instruments",
      "tea-14 F-2": r"no `test-results/s323-5-1-e2e-cards\.txt", "tea-13 F-1": r"register story-4\.4 header-forwarding tests in ci-local",
      "tea-17 F-1": r"Test-id drift", "qa-4 F-1": r"ceiling-exhaust characterization", "tea-12 F-1": r"s317-base-enable\.md:85",
      "architect-18 F-1": r"5\.4/5\.5 through the 3\.2 page loader"}


def added_lines(c, base=None):
    files = {}; cur = None
    for ln in (git("diff", "-U0", "--no-renames", (base or c + "^"), c) or "").split("\n"):
        if ln.startswith("+++ "): cur = ln[6:] if ln.startswith("+++ b/") else None
        elif cur and ln.startswith("+") and len(ln[1:].strip()) >= 12: files.setdefault(cur, []).append(ln[1:].strip())
    return files


_blob = {}
def blob(ref, pth):
    if (ref, pth) not in _blob: _blob[(ref, pth)] = show(ref, pth) or ""
    return _blob[(ref, pth)]


def survival(files, refs):
    t = sum(len(v) for v in files.values())
    return t, {ref: sum(1 for f, ls_ in files.items() for s in ls_ if s in blob(ref, f)) for ref in refs}


def seats_at(ref):
    out = {}
    for f in ls(ref, "_bmad-output/party-mode/s323/"):
        m = SEATF.match(os.path.basename(f))
        if m: out[f] = (m.group(1), m.group(2))
    return out


def main():
    global G
    if len(sys.argv) < 3: sys.exit(__doc__)
    out, G = sys.argv[1], sys.argv[2]
    blocks = [int(x) for x in sys.argv[3:]] or list(range(8))
    rows = B.spawns(out)
    assert STORIES[323] == 18 and STORIES[322] == 8 and STORIES[319] == 20, "STORIES moved"
    REFS = collections.OrderedDict([("SHIP", SHIP), ("FF1_PR", FF1_PR), ("RETRO_PR", RETRO_PR), ("CLOSE", CLOSE), ("PARTY_TIP", PARTY_TIP), ("PARTY_DONE", PARTY_DONE), ("S322_CLOSE", S322_CLOSE)])
    for c in FIX_A + FIX_C + FIX_P: REFS["fix " + c] = c
    present = {k: have(v) for k, v in REFS.items()}
    sf = seats_at(CLOSE) if present["CLOSE"] else {}
    ghead = {}   # (seat, F-n) -> severity word
    for f in sorted(sf):
        t = blob(CLOSE, f)
        for ln in t.split("\n"):
            m = HEAD.match(ln)
            if m: ghead[(re.search(r"sprint-review-(.*)\.md", f).group(1), "F-" + m.group(1))] = m.group(2)

    if 0 in blocks:
        p("== 0. repo and refs (repo given: %s)" % G)
        for k, v in REFS.items(): p("  %-16s %-10s %-22s %s" % (k, v, cdate(v) if present[k] else "", "PRESENT" if present[k] else "ABSENT in this repo"))
        p("  impossible ref control: %s" % ("PRESENT (BAD)" if have("deadbeef0000") else "absent (as it must be)"))
        p("  s323 ship ref used: %s (sprint squash #1337 on main, 11-19 15:46 -0500); retro PR %s; close %s; the sprint-review gate entry sits at gate-log :1664" % (SHIP, RETRO_PR, CLOSE))
        p("  seat files at %s: %d (need 95 = 18 stories x 5 roles + 5 cross); .brief files under rounds/sprint-review-party: %d; impossible role seat count %d" % (
            CLOSE, len(sf), len([f for f in ls(CLOSE, "_bmad-output/planning-artifacts/s323/rounds/sprint-review-party/") if f.endswith(".brief")]), len([1 for f in sf if "sprint-review-zz-" in f])))
        p("  first-parent order: %s (sprint) -> %s (ff1) -> %s (retro) -> ... -> %s (close): parent of retro PR is ff1 PR: %s" % (SHIP, FF1_PR, RETRO_PR, CLOSE, "MATCH" if (git("rev-parse", RETRO_PR + "^") or "").startswith(FF1_PR) else "DIFFERS"))

    if 1 in blocks:
        p("\n== 1. cost per label, s323 against s319 and s322 (spawns.jsonl, every bucket; STORIES: s323 %d, s322 %d, s319 %d)" % (STORIES[323], STORIES[322], STORIES[319]))
        for sp in (323, 322, 319):
            for st in G_LABELS + [IMPOSSIBLE_STEP]:
                rs = lrows(rows, sp, st); n = STORIES[sp]; pu = usd(rs) / n
                line = "s%d %-31s spawns %3d  $%7.2f  %6.1f agent-min  per story %.2f spawns, $%.2f" % (sp, st, len(rs), usd(rs), mins(rs), len(rs) / n, pu)
                if (sp, st) in LEAD: line += "   | lead %.2f %s" % (LEAD[(sp, st)], "MATCH" if abs(pu - LEAD[(sp, st)]) < 0.006 else "DIFFERS")
                if st == IMPOSSIBLE_STEP: line += "   | impossible step, must be 0"
                p(line)
            both = lrows(rows, sp, "sprint-review", "gate-validation[sprint-review]")
            p("s%d like-for-like sprint-review + gate-validation[sprint-review] (the s321 document's population): %d spawns $%.2f %.1f min  per story $%.2f" % (sp, len(both), usd(both), mins(both), usd(both) / STORIES[sp]))
            n, u, m_, _t = B.agg(rows, sp, G_LABELS)
            p("s%d the six labels together: %d spawns $%.2f %.1f min (B.agg) vs summed above: %s" % (sp, n, u, m_, "MATCH" if n == sum(len(lrows(rows, sp, s)) for s in G_LABELS) and abs(u - sum(usd(lrows(rows, sp, s)) for s in G_LABELS)) < 1e-9 else "DIFFERS"))
        dup = collections.Counter((r["sprint"], r["step"], r["unit"]) for r in rows if r["step"] in G_LABELS and int(r["sprint"]) in (319, 322, 323))
        p("duplicate units across lead transcripts in these labels: %d (control: %d units counted)" % (sum(1 for v in dup.values() if v > 1), len(dup)))
        for sp in (319, 322, 323):
            c = collections.Counter(r["step"] for r in rows if int(r["sprint"]) == sp and r["role"] == "gate-adjudicator")
            p("s%d gate-adjudicator rows by label: %s" % (sp, dict(sorted(c.items()))))

    if 2 in blocks:
        p("\n== 2. partitions by description (each must SUM to the label total, 0 unmatched, 0 double-matched; no catch-all rule exists)")
        p("-- sprint-review, s323 (label sprint-review)")
        sr = partition(lrows(rows, 323, "sprint-review"), SR_323, "s323 sprint-review")
        p("-- gate-validation[sprint-review], s323")
        partition(lrows(rows, 323, "gate-validation[sprint-review]"), GS_323, "s323 gate-validation[sprint-review]")
        p("-- sprint-review + gate, s319 (both labels)")
        partition(lrows(rows, 319, "sprint-review", "gate-validation[sprint-review]"), SR_319, "s319 sprint-review + gate")
        seatrows = sr["party seat rows named '<role> <n|cross>' (first dispatch)"] + sr["party seat rows named '<role> <n|cross> seat' (second dispatch)"]
        tok = collections.Counter(); byrole = collections.defaultdict(lambda: [0, 0.0, 0, 0])
        for r in seatrows:
            m = re.match(r"^" + SEATRX, r["description"]); tok[(m.group(1), m.group(2))] += 1
            b = byrole[m.group(1)]; b[0] += 1; b[1] += r["usd"] or 0; b[2] += 1 if (r["usd"] or 0) == 0 else 0
        p("  seat rows by role (rows, $, $0-rows): " + ", ".join("%s %d $%.2f %d" % (k, v[0], v[1], v[2]) for k, v in sorted(byrole.items())))
        p("  distinct (role, ordinal) tokens with >= 1 row: %d of 95 deliverables (must be 95: MATCH/DIFFERS %s); tokens with 2 rows %d, with 3 rows %d ; extra rows beyond one per seat: %d, $%.2f" % (
            len(tok), "MATCH" if len(tok) == 95 else "DIFFERS", sum(1 for v in tok.values() if v == 2), sum(1 for v in tok.values() if v == 3), len(seatrows) - len(tok), 0.0))
        seen = set(); extra = []
        for r in sorted(seatrows, key=lambda r: r["start"]):
            m = re.match(r"^" + SEATRX, r["description"]); k = (m.group(1), m.group(2))
            (extra if k in seen else []).append(r); seen.add(k)
        p("  second-or-later rows of a seat token (re-runs): %d  $%.2f  %.1f min ; of the 95 seats, first rows that recorded $0 (model synthetic): %d" % (
            len(extra), usd(extra), mins(extra), sum(1 for r in seatrows if (r["usd"] or 0) == 0)))
        p("-- deploy-validate, s323 / s319")
        partition(lrows(rows, 323, "deploy-validate"), DV_323, "s323 deploy-validate")
        partition(lrows(rows, 319, "deploy-validate"), DV_319, "s319 deploy-validate")
        p("-- retro, s323 / s319")
        partition(lrows(rows, 323, "retro"), RT_323, "s323 retro")
        partition(lrows(rows, 319, "retro"), RT_319, "s319 retro")
        p("-- gate-validation[retro], s323 (s319: 0 rows)")
        partition(lrows(rows, 323, "gate-validation[retro]"), RG_323, "s323 gate-validation[retro]")
        p("  handoff rows s323: %d (control: retro rows %d)" % (len(lrows(rows, 323, "handoff")), len(lrows(rows, 323, "retro"))))

    if 3 in blocks:
        p("\n== 3. sprint-review party seats at %s (95 seat files), fix records, and the hand cluster table" % CLOSE)
        sev = collections.Counter(ghead.values())
        p("  seat files %d; finding headings (## F-n (sev)) %d ; severity words %s" % (len(sf), len(ghead), dict(sorted(sev.items()))))
        tot2 = sum(len(re.findall(r"(?m)^## F-\d+ ", blob(CLOSE, f))) for f in sf)
        msg = (git("log", "-1", "--format=%s", PARTY_DONE) or "").strip()
        mm = re.search(r"(\d+) findings", msg)
        p("  second count: all '## F-n ' lines %d ; commit %s message '%s' says %s : %s" % (tot2, PARTY_DONE, msg[:70], mm.group(1) if mm else None, "MATCH" if mm and tot2 == len(ghead) == int(mm.group(1)) else "DIFFERS"))
        p("  impossible seat token '%s' in the headings %d (must be 0); real heading ('architect-10','F-1') present: %d (must be 1)" % (IMPOSSIBLE_TOK, sum(1 for k in ghead if IMPOSSIBLE_TOK in k[0]), int(("architect-10", "F-1") in ghead)))
        cm = collections.Counter(); med = collections.Counter(); allr = collections.Counter(); kind = collections.Counter()
        for (seat, fid), sv in ghead.items():
            role = seat.split("-")[0]; allr[role] += 1
            if sv in CMSEV: cm[role] += 1; kind[(role, "cross" if seat.endswith("cross") else "story")] += 1
            if sv == "medium": med[role] += 1
        p("  C/M-class (critical %d, major %d, important %d) = %d ; 'medium' kept apart: %d ; CRITICAL headings %d" % (
            sum(1 for v in ghead.values() if v == "critical"), sum(1 for v in ghead.values() if v == "major"), sum(1 for v in ghead.values() if v == "important"), sum(cm.values()), sum(med.values()), sum(1 for v in ghead.values() if v == "critical")))
        p("  C/M-class by role: %s ; medium by role: %s ; all findings by role: %s" % (dict(sorted(cm.items())), dict(sorted(med.items())), dict(sorted(allr.items()))))
        p("  C/M-class by role and kind: %s" % dict(sorted(kind.items())))
        # fix-record citations
        rec = {n: blob(CLOSE, "_bmad-output/implementation-artifacts/s323/%s.md" % n) for n in FIXREC}
        p("  fix records read (bytes): %s ; impossible token in them %d (must be 0) ; seat-cite pattern hits %d (must be > 0)" % (
            {n: len(t) for n, t in rec.items()}, sum(t.count(IMPOSSIBLE_TOK) for t in rec.values()), sum(len(CITE.findall(t)) for t in rec.values())))
        cited = collections.defaultdict(set); phantom = []
        for n, t in rec.items():
            for seats, fid in CITE.findall(t):
                for s in re.findall(r"(?:architect|dev|pm|qa|tea)-(?:\d+|cross)", seats):
                    cited[(s, "F-" + fid)].add(n)
                    if (s, "F-" + fid) not in ghead: phantom.append((s, "F-" + fid, n))
        p("  seat findings cited in a fix record: %d ; cited but not a heading in any seat file (hand reading: record says 'does not exist'): %s" % (len(cited), sorted(set(phantom))))
        cmids = sorted(k for k, v in ghead.items() if v in CMSEV or v == "medium")
        flat = [(s, f) for _, members, _, _, _ in CL for s, f in [tuple(m.split(" ")) for m in members]]
        p("  cluster table covers C/M-class + medium ids exactly once: ids %d, cluster members %d, missing %s, extra %s, duplicates %d : %s" % (
            len(cmids), len(flat), sorted(set(cmids) - set(flat)), sorted(set(flat) - set(cmids)), len(flat) - len(set(flat)),
            "MATCH" if sorted(cmids) == sorted(flat) else "DIFFERS"))
        p("  clusters (hand reading): n  seats  roles  class  disposition  fix-record cites (derived)  survival of the named fix commits at ship")
        stat = collections.Counter(); solo = []; roles_of = {}
        for name, members, cls, disp, fixes in CL:
            seats_ = sorted({m.split(" ")[0] for m in members}); roles = sorted({s.split("-")[0] for s in seats_})
            sevs = sorted({ghead[tuple(m.split(" "))] for m in members})
            cites = sorted({x for m in members for x in cited.get(tuple(m.split(" ")), set())})
            n = l = 0
            for c in fixes:
                a, b = survival(added_lines(c), (SHIP,)); n += a; l += b[SHIP]
            corpus = "".join(git("log", "-1", "--format=%B", c) or "" for c in fixes) + "".join(rec.values())
            ev = len(re.findall(EV[members[0]], corpus)) if members[0] in EV else None
            join = "cite" if cites else ("evidence %d" % ev if ev is not None else "NO-JOIN")
            if disp == "FIXED" and not cites and not ev: join = "NO-JOIN(BAD)"
            cmx = any(s in CMSEV for s in sevs)
            stat[(cls, disp, cmx)] += 1
            if len(roles) == 1 and disp == "FIXED" and cmx: solo.append(name)
            p("   %-66s seats %d roles %d %-15s %-17s %-10s join %-14s %s fix lines %d at ship %d (%s)" % (
                name[:66], len(seats_), len(roles), ",".join(sevs), cls, disp, join, ",".join(fixes) or "-", n, l, pct(l, n)))
        p("  clusters %d ; with a C/M-class member %d ; by (class, disposition, C/M-class): %s" % (len(CL), sum(1 for _, m, _, _, _ in CL if any(ghead[tuple(x.split(' '))] in CMSEV for x in m)), dict(sorted(((str(k), v) for k, v in stat.items())))))
        p("  FIXED C/M-class clusters raised by ONE role only (sole-source fixed majors): %d %s" % (len(solo), solo))
        fixed_cm = [c for c in CL if c[3] == "FIXED" and any(ghead[tuple(x.split(' '))] in CMSEV for x in c[1])]
        p("  FIXED C/M-class clusters %d of %d C/M-class clusters; multi-seat clusters %d (5 seats: %d)" % (len(fixed_cm), sum(1 for c in CL if any(ghead[tuple(x.split(' '))] in CMSEV for x in c[1])), sum(1 for c in CL if len(c[1]) > 1), sum(1 for c in CL if len({m.split(' ')[0] for m in c[1]}) == 5)))
        sr323 = lrows(rows, 323, "sprint-review")
        seatrows = [r for r in sr323 if re.match(r"^" + SEATRX + r"( seat)?$", r["description"])]
        p("  per role: seat rows, $, C/M-class findings, $ per C/M-class finding, fixed C/M-class clusters the role raised, of which sole-source")
        for role in ("architect", "dev", "pm", "qa", "tea"):
            rr = [r for r in seatrows if r["description"].startswith(role + " ")]
            cmr = cm[role]
            fx = [c for c in fixed_cm if any(m.startswith(role + "-") for m in c[1])]
            so = [c for c in fx if len({m.split(" ")[0].split("-")[0] for m in c[1]}) == 1]
            p("   %-9s rows %3d  $%7.2f  C/M-class %2d  $/CM %6.2f  fixed clusters raised %2d  sole-source %d" % (role, len(rr), usd(rr), cmr, usd(rr) / cmr if cmr else 0.0, len(fx), len(so)))
        p1 = blob(CLOSE, "_bmad-output/planning-artifacts/s323/rounds/sprint-review-party-p2.dispatcher.brief")
        mem = len([l for l in p1.split("\n") if re.match(r"^(pm|dev|qa|tea|architect) /", l)])
        p("  second dispatch (round p2) members in its brief: %d (brief says 'Members (56)': %d) ; its own words: 'first round 42-wide wave hit the proxy account quota' present %d ; first-dispatch valid seats %d of 95 (commit cont147 '39 valid/56 missing')" % (
            mem, p1.count("Members (56)"), p1.count("42-wide wave hit the proxy account quota"), 95 - mem))
        rerun_first = []
        seen = collections.defaultdict(list)
        for r in sorted(seatrows, key=lambda r: r["start"]):
            m = re.match(r"^" + SEATRX, r["description"]); seen[(m.group(1), m.group(2))].append(r)
        for k, v in sorted(seen.items()):
            if len(v) > 1: rerun_first.append(v[0])
        p("  seats that ran twice: %d ; their FIRST rows (the 429-storm attempts): $%.2f, of which $0 rows %d ; their second rows: $%.2f" % (
            len(rerun_first), usd(rerun_first), sum(1 for r in rerun_first if not r["usd"]), usd([v[1] for v in seen.values() if len(v) > 1])))
        # triage: none exists
        tri = [f for f in ls(CLOSE, "_bmad-output") if "/s323/" in f and "triage" in f.lower()]
        t322 = [f for f in ls(S322_CLOSE, "_bmad-output/implementation-artifacts/s322/") if "triage" in f.lower()]
        p("  triage artifact: files under s323 with 'triage' in the path at %s: %d (UNAVAILABLE: the s323 round had no triage analyst row; dispositions are in gate-log :1668 and the fix records) ; control, s322 at %s: %d" % (CLOSE, len(tri), S322_CLOSE, len(t322)))
        gl = show(SHIP, "_bmad-output/implementation-artifacts/gate-log.md") or ""
        p("  gate-log :1668 'Step 3 dispositions (3 repair seats, 14 filed carry-overs, restored 4.1 record)': %d ; impossible %d" % (gl.count("3 repair seats, 14 filed carry-overs, restored 4.1 record"), gl.count(IMPOSSIBLE_TOK)))
        for n in FIXREC: p("   record %-28s lines %d  seat-complete markers %d" % (n, rec[n].count("\n"), rec[n].count("seat-complete:")))

    if 4 in blocks:
        p("\n== 4. fix survival (added lines >= 12 chars; base = the commit's parent; ship = %s)" % SHIP)
        if not (present["SHIP"] and all(present["fix " + c] for c in FIX_A + FIX_C + FIX_P)):
            p("  UNAVAILABLE: this repo lacks a ref (see block 0); rerun with the real graph repo")
        else:
            grp = collections.OrderedDict([("adversary pass A+B fixes (SA-4, SA-5/SA-2/AC3c, p2 F-2/F-6)", FIX_A), ("adversary pass C fixes (F-2, F-1, F-4, re-review)", FIX_C), ("party-round fixes (devA, devB, devC, devD, remediator p2, restore, rebind)", FIX_P)])
            alln = alls = 0
            for gname, cs in grp.items():
                n_ = s_ = 0
                for c in cs:
                    msg = (git("log", "-1", "--format=%s", c) or "").strip()[:62]
                    n, cc = survival(added_lines(c), (c + "^", SHIP)); n_ += n; s_ += cc[SHIP]
                    p("   %s %-10s lines %4d at parent %4d at ship %4d (%s)  %s" % (c, cdate(c)[:11], n, cc[c + "^"], cc[SHIP], pct(cc[SHIP], n), msg))
                p("  %s: commits %d, added lines %d, at ship %d (%s)" % (gname, len(cs), n_, s_, pct(s_, n_)))
                alln += n_; alls += s_
            p("  all %d fix commits: added lines %d, at ship %d (%s)" % (len(FIX_A + FIX_C + FIX_P), alln, alls, pct(alls, alln)))
            ctrl = added_lines(FF1_PR, SHIP); n, c = survival(ctrl, (SHIP,))
            p("  must-differ control: post-ship commit %s (ff1 PR #1338, base %s): added lines %d, at ship %d (%s) <- must read far below the fix commits" % (FF1_PR, SHIP, n, c[SHIP], pct(c[SHIP], n)))
            ctrl2 = added_lines(CLOSE, SHIP); n2, c2 = survival(ctrl2, (SHIP,))
            p("  second control: %s..%s (everything after ship): added lines %d, at ship %d (%s)" % (SHIP, CLOSE, n2, c2[SHIP], pct(c2[SHIP], n2)))
            # step-3 introduced critical: devB's repair 486b178e6 introduced the AC8 route-landing defect fixed by da79a7828
            cr = blob(SHIP, "docs/reviews/s323/sprint-review-step3-code-review.md")
            p("  REPAIR-INTRODUCED catch: step-3 code re-review (%d bytes) names the devB repair's defect: 'can never pass' present %d ; '### Critical' present %d ; 'APPROVED' present %d ; impossible %d" % (
                len(cr), cr.count("can never pass"), cr.count("### Critical"), cr.count("APPROVED"), cr.count(IMPOSSIBLE_TOK)))
            sr_ = blob(SHIP, "server/test_live_smoke.py")
            p("  fix da79a7828 (urlparse route landing) present at ship: 'urlparse(page.url).path.rstrip' count %d (must be >= 1); 'DID-NOT-RUN' in rewards-cards-live-verify.js at ship %d (>= 1)" % (
                sr_.count("urlparse(page.url).path.rstrip"), blob(SHIP, "scripts/lib/test-smoke/rewards-cards-live-verify.js").count("DID-NOT-RUN")))
            # fixers cost
            rs = lrows(rows, 323, "sprint-review")
            fx = [r for r in rs if re.search(r"^(dev fixes A rebalancer|dev fixes B live-smoke|dev C small follow-ups|remediator artifact repair p2)$", r["description"])]
            p("  fixer spawns of the party round (devA devB devC remediator p2): %s ; step-3 review loop: %s" % (tot(fx), tot([r for r in rs if re.search(r"^(Step-3 code re-review|Step-3 QA re-validation|Fix step-3 review findings)$", r["description"])])))

    if 5 in blocks:
        p("\n== 5. adversary one-shot passes and the sprint-review gate")
        adv = lrows(rows, 323, "sprint-review")
        advr = [r for r in adv if re.search(r"^(Sprint 323 adversarial review|Sprint adversarial pass 2|Sprint-level adversarial pass)$", r["description"])]
        for r in sorted(advr, key=lambda r: r["start"]): p("  %s Z $%5.2f %5.1f min %s %s" % (r["start"][5:16], r["usd"], r["minutes"], r["model_ran"], r["description"]))
        pa = show("0c9dcdd31", "_bmad-output/implementation-artifacts/s323/sprint-adversarial-p1.md") or ""
        pc = blob(SHIP, "_bmad-output/implementation-artifacts/s323/sprint-adversarial-p1.md")
        pb = blob(SHIP, "_bmad-output/implementation-artifacts/s323/sprint-adversarial-p2.md")
        ra = re.search(r"(?m)^- (\d+) Critical \(SA-1\), (\d+) Important \(SA-2\), (\d+) Minor \(SA-4\), (\d+) Suggestions", pa)
        p("  pass A record (sprint-adversarial-p1.md at 0c9dcdd31, overwritten later): '#### SA-n' headings %d ; result line (Critical, Important, Minor, Suggestion) %s ; SA-1 'never merged' present %d ; impossible %d" % (
            len(re.findall(r"(?m)^#### SA-\d+", pa)), ra.groups() if ra else None, pa.count("never merged"), pa.count(IMPOSSIBLE_TOK)))
        p("  pass B record (sprint-adversarial-p2.md at %s): '## F-n' headings %d ; MAJOR %d, MINOR %d ; its Disposition says the F-1 premise was superseded by the pair merge: %d" % (
            SHIP, len(re.findall(r"(?m)^## F-\d+ ", pb)), len(re.findall(r"(?m)^## F-\d+ \(MAJOR\)", pb)), len(re.findall(r"(?m)^## F-\d+ \(MINOR\)", pb)), pb.count("superseded") + pb.count("supersession")))
        p("  pass C record (sprint-adversarial-p1.md at %s): '### F-n' headings %d ; MAJOR %d, MINOR %d ; result line 0 CRITICAL, 1 MAJOR, 3 MINOR present %d ; impossible %d" % (
            SHIP, len(re.findall(r"(?m)^### F-\d+ ", pc)), len(re.findall(r"(?m)^### F-\d+ — MAJOR", pc)), len(re.findall(r"(?m)^### F-\d+ — MINOR", pc)), pc.count("0 CRITICAL, 1 MAJOR, 3 MINOR"), pc.count(IMPOSSIBLE_TOK)))
        p("  merge b3a7de522 (4.1 into the sprint branch, which dropped the gate-log entry): %s ; party-round finders' defect existed when pass A (spawn 02:53Z = 11-18 21:53 -0500) ran: merge predates it" % cdate("b3a7de522"))
        p("  pass A critical SA-1 repair: pair merges %s..%s (%s .. %s), spawns 'Dev-escalated 1.3/5.2 merge resolution' 03:19-03:20Z" % ("619a6f056", "59c9bcd81", cdate("619a6f056"), cdate("59c9bcd81")))
        p("  merge-introduced defects later found by the party round: 4.1 entry (merge b3a7de522) ; SA-4 root scratch fixed at a2e89caca (%s) and re-raised by pass C F-2 (ff164e5e5, '37 scratch files'): hand reading REFOUND; regex hits for 'scratch' in the pass A record %d, pass C record %d" % (
            cdate("a2e89caca"), len(re.findall(r"(?i)scratch", pa)), len(re.findall(r"(?i)scratch", pc))))
        P = "_bmad-output/implementation-artifacts/s323/gate-adjudication/"
        for nonce in ("20261119T193613Z", "20261119T195256Z"):
            v = show(CLOSE, P + "sprint-review-%s.verdict.json" % nonce)
            if not v: p("  verdict %s UNAVAILABLE" % nonce); continue
            d = json.loads(v)["verdicts"]
            p("  gate pass %s: %d checks, %s ; non-PASS: %s" % (nonce, len(d), dict(collections.Counter(x["verdict"] for x in d)), [(x["check_id"], x["verdict"]) for x in d if x["verdict"] != "PASS"]))
        glog = (show(SHIP, "_bmad-output/implementation-artifacts/gate-log.md") or "").split("\n")
        seg = "\n".join(glog[1663:1672]) if len(glog) > 1672 else ""
        p("  gate-log :1664-1672 (%d bytes): pass-1 Check 1 FAIL 'vocabulary restatement only' %d ; 'both verdicts were already pass-equivalent' %d ; 'superseded' p2 MAJOR disposition %d ; 'Verdict: 8/8 PASS' %d ; impossible %d" % (
            len(seg), seg.count("vocabulary restatement only"), seg.count("pass-equivalent"), seg.count("supersession"), seg.count("8/8 PASS"), seg.count(IMPOSSIBLE_TOK)))
        gs = lrows(rows, 323, "gate-validation[sprint-review]")
        real = [r for r in gs if re.search(r"^(Gate adjudicator shard \d/4|Gate-failure remediator sprint-review)$", r["description"])]
        p("  gate rows that are the sprint-review gate itself: %s ; rows that are story 2.2/2.3 gate work (label by clock): %s" % (tot(real), tot([r for r in gs if r not in real])))

    if 6 in blocks:
        p("\n== 6. deploy-validate")
        dv = sorted(lrows(rows, 323, "deploy-validate"), key=lambda r: r["start"])
        for r in dv: p("  s323 %-14s %-6s $%5.2f %5.1f min %s  %s" % (r["role"], (r["model_ran"] or "")[-6:], r["usd"], r["minutes"], r["start"][5:16], r["description"]))
        P = "_bmad-output/implementation-artifacts/s323/"
        reps = ["ops-preroll-reads", "ops-preroll-lockrows-2", "ops-postroll-reads", "ops-postroll-aggregator", "ops-postroll-ui", "ops-prefire-allowlist", "ops-ac7-afterread", "ops-4b-reread", "ops-ac3-groundtruth", "ops-51-values-read", "ff1-ops-preroll-reads", "ff1-base-cert-audit-read"]
        nrep = 0
        for f in reps:
            t = blob(CLOSE, P + f + ".md"); nrep += bool(t)
            cn = re.findall(r"(?i)findings that contradict an expectation: (\d+)", t)
            p("   %-26s %6d bytes  'contradict an expectation: N' lines %s ; 'deviation' lines %d" % (f, len(t), cn, len(re.findall(r"(?i)deviation", t))))
        for f in ("ops-preroll-reads", "ops-postroll-reads"):
            t = blob(CLOSE, P + f + ".md"); m = re.search(r"(?ms)^## Flags and deviations.*?(?=^## )", t)
            p("   %s '## Flags and deviations' section present %d, bullet lines %d (control: impossible heading %d)" % (f, int(bool(m)), len(re.findall(r"(?m)^- ", m.group(0))) if m else 0, int("## NO-SUCH-HEADING-77" in t)))
        p("  ops reports present %d of %d ; impossible token in them %d (must be 0)" % (nrep, len(reps), sum(blob(CLOSE, P + f + ".md").count(IMPOSSIBLE_TOK) for f in reps)))
        # fix-forward ff1 chain
        p("  ff1 fix-forward chain (found by smoke #1 at deploy-validate: the ALB VERIFY mode injects no X-Amzn-Mtls-Clientcert; operator's Collect Rewards blocked until PR #1338):")
        for c in ("8d6104bd6", "7c36f155f", "970238c2b", "d472856e0"):
            if not have(c): p("   %s UNAVAILABLE" % c); continue
            n, cc = survival(added_lines(c), (c + "^", FF1_PR, CLOSE))
            p("   %s %s lines %4d at parent %4d at ff1 merge %4d (%s) at close %4d (%s)  %s" % (c, cdate(c)[:11], n, cc[c + "^"], cc[FF1_PR], pct(cc[FF1_PR], n), cc[CLOSE], pct(cc[CLOSE], n), (git("log", "-1", "--format=%s", c) or "").strip()[:60]))
        rt = blob(CLOSE, "docs/retro/s323/retro.md")
        p("  retro names the ff1 gap as F-PARTY-1 critical gate-escape: %d ; 'built on bare client-cert header while listener is VERIFY' present %d ; impossible %d" % (rt.count("F-PARTY-1 | critical | gate-escape"), rt.count("built on bare client-cert header while listener is VERIFY"), rt.count(IMPOSSIBLE_TOK)))
        gold = blob(SHIP, "_bmad-output/implementation-artifacts/gate-log.md")
        p("  party-round seats for stories 4.3/4.4 (the mTLS gate and forwarder) naming 'VERIFY' as a finding: seat files 4.3/4.4 (architect-12,13 dev-12,13 pm-12,13 qa-12,13 tea-12,13, cross) containing 'VERIFY' %d of 11 ; 'clientcert' (case-insensitive) in %d of 11 ; control 'APP_ENV' %d" % (
            sum(1 for s in ("architect-12", "architect-13", "dev-12", "dev-13", "pm-12", "pm-13", "qa-12", "qa-13", "tea-12", "tea-13", "architect-cross") if "VERIFY" in blob(CLOSE, "_bmad-output/party-mode/s323/sprint-review-%s.md" % s)),
            sum(1 for s in ("architect-12", "architect-13", "dev-12", "dev-13", "pm-12", "pm-13", "qa-12", "qa-13", "tea-12", "tea-13", "architect-cross") if "clientcert" in blob(CLOSE, "_bmad-output/party-mode/s323/sprint-review-%s.md" % s).lower()),
            sum(1 for s in ("architect-12", "architect-13", "dev-12", "dev-13", "pm-12", "pm-13", "qa-12", "qa-13", "tea-12", "tea-13", "architect-cross") if "APP_ENV" in blob(CLOSE, "_bmad-output/party-mode/s323/sprint-review-%s.md" % s))))

    if 7 in blocks:
        p("\n== 7. retro (6 party persona seats + analysts + fixes + 7b inputs) and gate-validation[retro]")
        rt = blob(CLOSE, "docs/retro/s323/retro.md")
        prov = re.search(r"findings_critical: (\d+)\nfindings_major: (\d+)\nfindings_minor: (\d+)", rt)
        rowsf = re.findall(r"(?m)^\| PARTY \| F-PARTY-(\d+) \| (critical|major|minor) \|", rt)
        sv = collections.Counter(s for _, s in rowsf)
        p("  retro file %d bytes ; findings table rows %d ; by severity %s ; provenance (critical, major, minor) %s : %s" % (
            len(rt), len(rowsf), dict(sorted(sv.items())), prov.groups() if prov else None,
            "MATCH" if prov and tuple(map(int, prov.groups())) == (sv["critical"], sv["major"], sv["minor"]) else "DIFFERS"))
        p("  second count: 'F-PARTY-n' distinct ids %d (table rows %d) : %s ; impossible id %d" % (len(set(re.findall(r"F-PARTY-(\d+)", rt))), len(rowsf), "MATCH" if len(set(re.findall(r"F-PARTY-(\d+)", rt))) == len(rowsf) else "DIFFERS", rt.count("F-PARTY-9999")))
        p("  C/M-class rows (critical + major) %d" % (sv["critical"] + sv["major"]))
        classes = collections.Counter(re.findall(r"(?m)^\| PARTY \| F-PARTY-\d+ \| (?:critical|major|minor) \| ([a-z-]+) \|", rt))
        p("  finding classes: %s" % dict(sorted(classes.items())))
        # improvements applied
        i0 = rt.find("## Specific, Actionable Improvements"); i1 = rt.find("## Improvement Routing")
        seg = rt[i0:i1]
        items = re.findall(r"(?m)^(\d+)\. \*\*(.*?)(?:\*\*|\s—)", seg)
        p("  'Specific, Actionable Improvements' section %d bytes ; numbered items %d : %s" % (len(seg), len(items), [(a, b[:48]) for a, b in items]))
        pcs = sorted(set(re.findall(r"PC-S323-[A-Z0-9-]*[A-Z0-9]", seg)))
        p("  push candidates named in the section: %d %s" % (len(pcs), pcs))
        led = "_bmad-output/ai-dlc-update/push-candidate-ledger.md"
        for c in pcs:
            p("   %-52s ledger at %s: %d ; at close %s: %d" % (c, FF1_PR, blob(FF1_PR, led).count(c), CLOSE, blob(CLOSE, led).count(c)))
        p("   control: ledger bytes at %s %d (> 0) ; impossible PC id %d" % (CLOSE, len(blob(CLOSE, led)), blob(CLOSE, led).count("PC-S999-NEVER-XQ")))
        # landing of the applied improvements
        fl = added_lines(RETRO_PR)
        tg = {f: v for f, v in fl.items() if f in ("scripts/ecs-deploy.sh", ".gitignore", "docs/coding-conventions.md", "test-results/.gitignore")}
        n, c = survival(tg, (FF1_PR, CLOSE))
        p("  applied improvements in the retro PR (ecs-deploy.sh, .gitignore, coding-conventions.md): files %s ; added lines %d, at %s %d, at close %d (%s)" % (sorted(tg), n, FF1_PR, c[FF1_PR], c[CLOSE], pct(c[CLOSE], n)))
        for tag, path, tok in (("1 ecs-deploy poll", "scripts/ecs-deploy.sh", "rolloutState"), ("3 coding-conventions", "docs/coding-conventions.md", "mock")):
            p("   %s: token '%s' in %s at %s %d, at close %d" % (tag, tok, path, FF1_PR, blob(FF1_PR, path).count(tok), blob(CLOSE, path).count(tok)))
        ec = added_lines("73c537e3f"); n2, c2 = survival(ec, ("73c537e3f^", CLOSE)) if have("73c537e3f") else (0, {})
        p("  dev commit 73c537e3f (ecs-deploy poll): added lines %d, at parent %s, at close %s" % (n2, c2.get("73c537e3f^"), c2.get(CLOSE)))
        p("  must-differ control: the retro PR's added lines against its own base %s over ALL files: %s" % (FF1_PR, "%d lines, at base %d (must be far below)" % (lambda t: (t[0], t[1][FF1_PR]))(survival(fl, (FF1_PR,)))))
        v = show(CLOSE, "_bmad-output/implementation-artifacts/s323/gate-adjudication/retro-20261120T025001Z.verdict.json")
        if v:
            d = json.loads(v)["verdicts"]
            p("  retro gate verdict: %d checks %s ; non-PASS %d (gate-validation[retro]: 3 shards, 0 repairs; cost only, readings in BL-1141 / batch-262 D)" % (len(d), dict(collections.Counter(x["verdict"] for x in d)), sum(1 for x in d if x["verdict"] != "PASS")))
        else:
            p("  retro gate verdict UNAVAILABLE")
        # 7b inputs
        ni = ls("a9b015557", "_bmad-output/retro-artifacts/s323/")
        p("  7b next-input files at a9b015557 (the 7b/7d handoff commit; the retro PR deletes the previous sprint's): %d ; control, s322 files at %s: %d ; impossible dir %d" % (
            len(ni), FF1_PR, len(ls(FF1_PR, "_bmad-output/retro-artifacts/s322/")), len(ls("a9b015557", "_bmad-output/retro-artifacts/s999/"))))


main()
