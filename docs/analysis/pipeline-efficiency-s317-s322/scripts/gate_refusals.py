"""gate-run value evidence, BL-819 item 2(a) follow-up: WHAT did gate-transition.sh refuse, and do lead hand-runs of its
validators REPEAT it, with a story key that is derivable on most rows.  Records-only reader of the graph lead
transcripts; read-only, writes nothing (a mktemp copy of gate-transition.sh is read and removed).

usage: EXTRACT_WIN_END=2026-11-12T14:41:00Z python3 -I gate_refusals.py [--self-test]
  honours $EXTRACT_ROOT (transcripts), $GATE_TRANSITION (path to gate-transition.sh), $GT_CLONE / $GT_SHA (where the
  installed gate-transition.sh is read from when $GATE_TRANSITION is unset: `git show <sha>:scripts/ai-dlc/...`).

IMPORTED, NEVER RESTATED: gate_run_evidence.py (scan(), outcome(), b2(), compute(), parse_gt(), resolve_tuple(),
gt_parse(), invocations(), predicates GATE_RUN_RE / STEP_RE / EDGES) and gate_run_readings.py (classify(), verdict(): the
per-row exit-status resolution).  Both are loaded by importlib with $GATE_TRANSITION set before the load.

Q1 PREDICATES (refusals)
  call            a lead Bash tool_use whose invocations include gate-transition.sh (gate_run_evidence's `inv` count).
  refused call    gate_run_evidence.b2()'s reading: a column-0 `gate-transition: REFUSED` or `N refusal(s)` line.
  output text     the tool_result CONTENT only.  call["text"] is content + toolUseResult stdout + stderr, which repeats
                  every line; the stdout/stderr tail is cut off (content_text), and a count taken from the raw text is a
                  MUTANT in --self-test.
  refusal group   one invocation's refusal: its column-0 `gate-transition: REFUSED <check>: <detail>` lines (each with its
                  detail lines) closed by `gate-transition: N refusal(s); no plan written (<plan>)`.  The plan file name
                  `<story>-g<gate>-p<pass>.plan` (gate-transition.sh:126) keys the group: STORY, GATE, PASS.  A call may
                  run gate-transition.sh several times (`;`), so one call yields several groups; a group with no closing
                  line (output cut by `| tail`) is UNKEYED and counted so.
  reason          check name, plus the first inner token of the detail: `REFUSED <tok>` printed by a validator, or the
                  rule id of a `FINDING <path>:<line> <rule>` line.  Distinct unit = (story, gate, reason).
  class           VALIDATOR-FINDING iff the detail's first line is `<script>.sh ... exited N` and <script> is a
                  non-bookkeeping validator tuple of gate-transition.sh (parse_gt: its failure reaches `refuse`).
                  Everything else the script prints through refuse() is PROCEDURAL: its own preconditions (prior-review,
                  prior-validation, dar-fold, gate1-review, commit-presence, record-partition, open, close) and
                  bookkeeping scripts (merge-review-shards.sh, gate-checkpoint.sh).  COULD-NOT-RUN (die(), exit 2:
                  wrong argument, missing worktree or file) has no REFUSED line and is counted apart, never in the 34/19.
  invocation outcome  from the output markers, never the command's final status: refused = a closed group for its key;
                  passed = a line that is only `<dir>/gate-transition/<story>-g<gate>-p<pass>.plan` (write_plan prints
                  it, :294) whose key equals a LITERAL invocation key of the same call; otherwise NO-MARKER.  Background
                  calls and calls with no result in the window are UNRESOLVED, never 0.
  value reading   for each distinct VALIDATOR-FINDING unit: the first later PASS marker on the same (story, gate) in the
                  same sprint (same pass first, any pass second), and what the lead did between the refusal and that
                  pass: Edit/Write tool_use, a Bash command that commits/copies/moves/updates the snapshot, an
                  Agent/Task/SendMessage dispatch.  A pass with none of the three after a refusal is "retry, no visible
                  change".  LIMIT: a worker fixing the tree after a dispatch is visible only as the dispatch.

Q2 PREDICATES (hand-run repeat)
  row             one in-step hand-run row, exactly gate_run_evidence.compute's: a lead Bash call in `implementation` or
                  `gate-validation[implementation]` running a non-bookkeeping validator tuple with no gate-transition.sh
                  or gate-checkpoint.sh in the same command; one row per (call, tuple).  Control: rows per sprint equal
                  compute()'s hr_in.
  verdict         gate_run_readings.classify(): found/clean/recorded only where the exit is the validator's (resolvable or
                  echo-resolved); every other row is UNRESOLVED (piped, `&&`-masked, background...).  UNRESOLVED rows are
                  never same-verdict.
  scope           STORY-SCOPED tuple iff gate-transition.sh passes it a story/worktree/sha/base/index/function-argument
                  (statement mentions $STORY $WT $SHA $IDX $BASE or $1); SPRINT-WIDE otherwise (sprint-status.sh,
                  validate-spawn-ledger.sh --sprint, validate-h2-attestation.sh, escalation checks).  A sprint-wide
                  tuple has no story to key: it is joined on gate alone, and that join is exact for it.
  story key       T1 the validator's own arguments carry one story; T2 the whole command carries one story; T3 the
                  command carries none and the result text carries one; T4 none of those, and the latest lead tool_use
                  among the previous M=20 of the same transcript whose input is a gate-transition.sh call or an
                  Agent/Task/SendMessage dispatch names exactly one story.  A story is read from: `story-A-B-slug.md`,
                  `story-A.B`, `A.B-code-review|qa-validation|gN-pM`, `dev-report-A-B`, and the s322 bare worktree
                  `graph-s322-story-N` (alias to its story file through gate-transition calls that carry both).  A source
                  naming two or more stories is AMBIGUOUS and yields no key (a directory listing is not a story).
  repeat          the same tuple's gate set contains the gate of a later gate-transition.sh invocation (literal story
                  index and gate) in the same transcript within N lead tool_use blocks (idx), story-scoped tuples also
                  requiring that invocation's story to equal the row's key.  Same-verdict: row found and that
                  invocation refused the tuple's check, or row clean/recorded and that invocation not refused.
  bounds          LOWER = rows keyed by T1-T3 only; MID = T1-T4; UPPER = story-ignored gate match for rows with no key.
  THRESHOLD       MERGE-candidate iff same-verdict repeats >= 50% of in-step rows (fixed before the run).  Discriminates
                  iff UPPER < 50% (KEEP) or LOWER >= 50% (MERGE-candidate).
"""
import collections, datetime as dt, glob, importlib.util, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CLONE = os.environ.get("GT_CLONE") or "/private/tmp/claude-501/-Users-n8-git-ai-dlc/38f3a1ed-4ed6-4586-91e9-b7d254310c30/scratchpad/graph"
GT_SHA = os.environ.get("GT_SHA") or "f7e60625b"
GT_REL = "scripts/ai-dlc/gate-transition.sh"
WIN = os.environ.get("EXTRACT_WIN_END") or "2026-11-12T14:41:00Z"
_TMP = None


def stage_gate_transition():
    """Make $GATE_TRANSITION point at the installed script (read from the scratch clone, never from graph itself)."""
    global _TMP
    if os.environ.get("GATE_TRANSITION"):
        return
    _TMP = tempfile.mkdtemp(prefix="gate-refusals-")
    p = os.path.join(_TMP, "gate-transition.sh")
    out = subprocess.run(["git", "-C", CLONE, "show", GT_SHA + ":" + GT_REL], capture_output=True, check=True).stdout
    open(p, "wb").write(out)
    os.environ["GATE_TRANSITION"] = p


def load(name):
    sp = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
    m = importlib.util.module_from_spec(sp)
    keep = sys.argv
    sys.argv = [sp.origin]
    try:
        sp.loader.exec_module(m)
    finally:
        sys.argv = keep
    return m


stage_gate_transition()
os.environ["EXTRACT_WIN_END"] = WIN
g = load("gate_run_evidence")
rd = load("gate_run_readings")
SPR = (321, 322)
N_SMALL, N_LARGE = 5, 20
LOOKBACK = 20
THRESH = 0.5

# ------------------------------------------------------------------------------------------------ output parsing
CLOSE_RE = re.compile(r"^gate-transition: (\d+) refusal\(s\); no plan written \((.+)\)\s*$")
REFUSED_RE = re.compile(r"^gate-transition: REFUSED (\S+?): ?(.*)$")
DIE_LINE = re.compile(r"^gate-transition: (?!REFUSED |\d+ refusal\(s\)|Rule A answered )(.*)$")
PLANKEY_RE = re.compile(r"^(?:.*/)?gate-transition/(.+)-g(1|2|3|close)-p(\d+)\.plan\s*$")
PLANKEY_TAIL = re.compile(r"^(.+)-g(1|2|3|close)-p(\d+)\.plan$")
SCRIPT_EXIT = re.compile(r"^(\S+\.sh)\b.*\bexited (\d+)")
INNER_REFUSED = re.compile(r"(?:^|[:\s])REFUSED ([a-z][a-z0-9-]+)")
INNER_FINDING = re.compile(r"^FINDING \S+ ([a-z][a-z0-9-]+) ")


def content_text(call, mutant=False):
    """The tool_result CONTENT without the toolUseResult stdout/stderr tail evidence's text_of appends."""
    t, tur = call["text"], call["tur"]
    if mutant:
        return t
    if isinstance(tur, dict):
        tail = "\n" + str(tur.get("stdout") or "") + "\n" + str(tur.get("stderr") or "")
    elif isinstance(tur, str):
        tail = "\n" + tur
    else:
        return t
    return t[:-len(tail)] if t.endswith(tail) else t


def parse_groups(text):
    """[(plan key or None, [(check, detail lines)])]: reasons accumulate until a closing line names the plan."""
    groups, pend, cur = [], [], None
    for ln in text.split("\n"):
        m = REFUSED_RE.match(ln)
        if m:
            cur = [m.group(1), [m.group(2)]]
            pend.append(cur)
            continue
        m = CLOSE_RE.match(ln)
        if m:
            base = os.path.basename(m.group(2))
            k = PLANKEY_TAIL.match(base)
            groups.append((k.groups() if k else None, pend))
            pend, cur = [], None
            continue
        if DIE_LINE.match(ln):
            cur = None
            continue
        if cur is not None:
            cur[1].append(ln)
    if pend:
        groups.append((None, pend))
    return groups


def reason_of(check, detail):
    """check plus its first inner token."""
    for ln in detail[1:]:
        m = INNER_FINDING.match(ln.strip()) or INNER_REFUSED.search(ln)
        if m:
            return check + ":" + m.group(1)
    return check


def classify_reason(check, detail, validators, mode="script"):
    """VALIDATOR-FINDING or PROCEDURAL.  mode 'script' = the real rule; the others are --self-test mutants."""
    if mode == "all":
        return "VALIDATOR-FINDING"
    if mode == "prefix":
        return "VALIDATOR-FINDING" if check.startswith("check-") else "PROCEDURAL"
    m = SCRIPT_EXIT.match((detail[0] if detail else "").strip())
    if m and m.group(1) in validators:
        return "VALIDATOR-FINDING"
    return "PROCEDURAL"


def pass_keys(text, literal_keys, mode="literal"):
    """Plan keys printed as a bare path line AND equal to a literal invocation key of the call."""
    out = set()
    for ln in text.split("\n"):
        m = PLANKEY_RE.match(ln)
        if not m:
            continue
        k = (m.group(1), m.group(2), m.group(3))
        if mode == "any" or k in literal_keys:
            out.add(k)
    return out


def inv_args(a):
    """(story index, gate, pass, story-file) of a gate-transition.sh invocation's words."""
    ix, gt, sf = g.gt_parse(a)
    pa = 1
    toks = [x.strip("\"'") for x in a]
    for i, x in enumerate(toks):
        if x == "--pass" and i + 1 < len(toks) and toks[i + 1].isdigit():
            pa = int(toks[i + 1])
    return ix, gt, str(pa), sf


# ------------------------------------------------------------------------------------------------ story keys
S_FILE = re.compile(r"story-(\d{1,2})-(\d{1,2})-[A-Za-z]")
S_WT = re.compile(r"story-(\d{1,2})\.(\d{1,2})(?![\d])")
S_REV = re.compile(r"(?<![\d.\w-])(\d{1,2})[.-](\d{1,2})-(?:code-review|qa-validation|g[123]-p\d)")
S_DEV = re.compile(r"dev-report-(\d{1,2})-(\d{1,2})")
S_BARE = re.compile(r"graph-s(\d{3})-story-(\d{1,2})(?![\d.-])")


def stories_in(text, bare_map, mode="all"):
    """The set of canonical stories `A.B` a text names (bare worktree indices through bare_map)."""
    if not text:
        return set()
    out = set()
    for rx in (S_FILE, S_WT, S_REV, S_DEV):
        for m in rx.finditer(text):
            out.add(m.group(1) + "." + m.group(2))
    for m in S_BARE.finditer(text):
        k = (int(m.group(1)), m.group(2))
        if k in bare_map:
            out.add(bare_map[k])
    return out


def one(s, mode="single"):
    """The key when exactly one story is named.  mode 'first' is a --self-test mutant: take any."""
    if mode == "first":
        return sorted(s)[0] if s else None
    return next(iter(s)) if len(s) == 1 else None


def norm_story(ix, bare_map, sprint):
    k = ix.replace("-", ".")
    if re.fullmatch(r"\d{1,2}\.\d{1,2}", k):
        return k
    return bare_map.get((sprint, ix))


# ------------------------------------------------------------------------------------------------ all lead tool_use
CHG = re.compile(r"\bgit\b[^|;&\n]*\b(?:commit|merge|cherry-pick|add|apply|am)\b|(?:^|[\s;&|])(?:cp|mv)\s|sed\s+-i|snapshot-update\.sh")


def scan_all(root, wmax):
    """Every lead tool_use (any tool), in g.scan()'s idx numbering: [dict(unit, idx, t, name, id, side, kind, keys_text)]."""
    out = []
    for p in sorted(glob.glob(root + "/*.jsonl")):
        unit = os.path.basename(p)[:-6]
        idx = 0
        for line in open(p, errors="replace"):
            try:
                r = json.loads(line)
            except Exception:
                continue
            t = r.get("timestamp")
            if not t or t < g.STEP_WIN_START or t > wmax or r.get("type") != "assistant":
                continue
            for c in (r.get("message") or {}).get("content") or []:
                if not isinstance(c, dict) or c.get("type") != "tool_use":
                    continue
                idx += 1
                nm, inp = c.get("name"), c.get("input") or {}
                if nm == "Bash":
                    cmd = inp.get("command") or ""
                    kind = "gt" if re.search(r"gate-transition\.sh", cmd) else ("chg" if CHG.search(cmd) else "bash")
                    txt = cmd
                elif nm in ("Edit", "Write", "NotebookEdit", "MultiEdit"):
                    kind, txt = "edit", str(inp.get("file_path") or inp.get("notebook_path") or "")
                elif nm in ("Agent", "Task", "SendMessage"):
                    kind, txt = "dispatch", json.dumps(inp)
                else:
                    kind, txt = "other", ""
                out.append(dict(unit=unit, idx=idx, t=t, name=nm, id=c.get("id"), side=bool(r.get("isSidechain")), kind=kind, text=txt))
    return out


# ------------------------------------------------------------------------------------------------ repeat join
def repeat_match(row, gts, N, story_mode="strict", gate_mode="gate"):
    """First gate-transition invocation within N blocks after the row that runs the tuple's gate (and the row's story).
    gts: [dict(idx, story, gate, outcome, checks)].  story_mode 'ignore' = upper bound / --self-test mutant."""
    for x in gts:
        if not (row["idx"] < x["idx"] <= row["idx"] + N):
            continue
        if gate_mode == "gate" and x["gate"] not in row["gates"]:
            continue
        if story_mode == "strict" and row["scoped"] and (row["key"] is None or x["story"] != row["key"]):
            continue
        return x
    return None


def same_verdict(v, x, checks):
    if v not in ("found", "clean", "recorded") or x["outcome"] not in ("refused", "passed"):
        return None
    if v == "found":
        return x["outcome"] == "refused" and bool(set(x["checks"]) & checks)
    return x["outcome"] == "passed"


def pct(a, b):
    return f"{100.0 * a / b:5.1f}%" if b else "  n/a "


# ------------------------------------------------------------------------------------------------ main reading
def tuple_scope(tuples):
    """{(script, mode): 'story'|'sprint'} from the statements that call the tuple in gate-transition.sh."""
    L = open(g.GT_PATH).read().split("\n")
    out = {}
    for t in tuples:
        stmt = ""
        for ln in t["lines"]:
            j = ln - 1
            s = L[j]
            while s.rstrip().endswith("\\") and j + 1 < len(L):
                j += 1
                s += " " + L[j]
            stmt += " " + s
        out[(t["script"], t["mode"])] = "story" if re.search(r"\$\{?(?:STORY|WT|SHA|IDX|BASE)\b|\"\$1\"", stmt) else "sprint"
    return out


def build(W):
    tuples, sibs = g.parse_gt(g.GT_PATH)
    vals = {t["script"] for t in tuples if not t["bookkeeping"]}
    calls, st = g.scan(g.ROOT, W)
    allu = scan_all(g.ROOT, W)
    return tuples, vals, calls, st, allu


def gt_calls(calls, W, bare_map):
    """Per lead gate-transition.sh call (command-position invocation): outcome records, invocation-level."""
    recs = []
    for c in calls:
        if c["side"] or c["t"] > W or c["t"] < g.BBS_WIN_START:
            continue
        s = g.sprint_of(c["t"])
        if s not in SPR or "gate-transition.sh" not in [b for b, _ in c["invs"]]:
            continue
        kind, code, _ = g.outcome(c, W)
        text = content_text(c) if kind == "resolved" else ""
        invs = [inv_args(a) for b, a in c["invs"] if b == "gate-transition.sh"]
        lit = {(ix, gt, pa) for ix, gt, pa, sf in invs if ix and gt and not ix.startswith("$") and not gt.startswith("$")}
        groups = parse_groups(text) if kind == "resolved" else []
        passed = pass_keys(text, lit) if kind == "resolved" else set()
        recs.append(dict(c=c, s=s, kind=kind, code=code, text=text, invs=invs, lit=lit, groups=groups, passed=passed,
                         refused=bool(g.b2(c["text"])[0]) if kind == "resolved" else False,
                         die=[m.group(1) for m in map(DIE_LINE.match, text.split("\n")) if m]))
    return recs


def learn_bare(calls, W):
    """(sprint, bare index) -> `A.B` from gate-transition invocations carrying a bare index AND a literal story file."""
    m, bad = {}, 0
    for c in calls:
        if c["side"] or c["t"] > W or c["t"] < g.BBS_WIN_START:
            continue
        s = g.sprint_of(c["t"])
        for b, a in c["invs"]:
            if b != "gate-transition.sh":
                continue
            ix, gt, sf = g.gt_parse(a)
            fk = g.story_from_args([sf]) if sf else None
            if ix and fk and not re.fullmatch(r"\d{1,2}[.-]\d{1,2}", ix):
                if m.setdefault((s, ix), fk) != fk:
                    bad += 1
    return m, bad


def q1(recs, tuples, vals, allu, bare_map, W, out):
    P = out.append
    P("== Q1  what gate-transition.sh refused")
    for s in SPR:
        R = [r for r in recs if r["s"] == s]
        refc = [r for r in R if r["refused"]]
        o = collections.Counter(r["kind"] for r in R)
        P(f"s{s}: gate-transition.sh calls {len(R)} (resolved {o['resolved']}, UNRESOLVED bg {o['UNRESOLVED-bg']}, persisted {o['UNRESOLVED-persisted']}, "
          f"no-result {o['UNRESOLVED-noresult']}); refused calls (evidence b2) {len(refc)}; calls with a parsed REFUSED line "
          f"{sum(1 for r in R if r['groups'])}; calls with a die() line {sum(1 for r in R if r['die'])}")
    # invocation-level units
    units = []   # (sprint, story, gate, pass, reason, cls, t, unit, idx, keyed)
    unkeyed = collections.Counter()
    for r in recs:
        for key, reasons in r["groups"]:
            for check, detail in reasons:
                cls = classify_reason(check, detail, vals)
                rs = reason_of(check, detail)
                if key is None:
                    unkeyed[(r["s"], cls)] += 1
                    units.append((r["s"], None, None, None, rs, cls, r["c"]["t"], r["c"]["unit"], r["c"]["idx"]))
                else:
                    st_, gt_, pa_ = key
                    units.append((r["s"], st_, gt_, pa_, rs, cls, r["c"]["t"], r["c"]["unit"], r["c"]["idx"]))
    for s in SPR:
        U = [u for u in units if u[0] == s]
        P(f"s{s}: refusal reasons parsed {len(U)} (unkeyed, closing line cut off: {sum(1 for u in U if u[1] is None)})")
        for cls in ("VALIDATOR-FINDING", "PROCEDURAL"):
            Uc = [u for u in U if u[5] == cls]
            dist = {(u[1], u[2], u[4]) for u in Uc if u[1] is not None}
            dist_p = {(u[1], u[2], u[3], u[4]) for u in Uc if u[1] is not None}
            P(f"  {cls:18} occurrences {len(Uc):3d}  distinct (story,gate,reason) {len(dist):3d}  distinct incl. pass {len(dist_p):3d}  "
              f"retries (occurrences - distinct) {len(Uc) - len(dist) - sum(1 for u in Uc if u[1] is None)}")
            by = collections.Counter()
            byd = collections.defaultdict(set)
            for u in Uc:
                by[u[4]] += 1
                if u[1] is not None:
                    byd[u[4]].add((u[1], u[2]))
            for rs, n in by.most_common():
                P(f"      {rs:46} occurrences {n:3d}  distinct (story,gate) {len(byd[rs]):3d}")
    cnr = [r for r in recs if r["die"]]
    P("COULD-NOT-RUN (die(), exit 2; a wrong argument, missing path; no REFUSED line, so not in the refused counts):")
    dc = collections.Counter()
    for r in cnr:
        for d in set(r["die"]):
            dc[(r["s"], re.sub(r"/\S+|\b[0-9a-f]{7,40}\b", "<p>", d)[:90])] += 1
    for (s, d), n in sorted(dc.items()):
        P(f"  s{s} x{n}: {d}")
    if not dc:
        P("  none")
    # invocation outcomes
    P("invocation outcome (markers, per call output; never the command's final status):")
    for s in SPR:
        R = [r for r in recs if r["s"] == s]
        ref = sum(len([1 for k, _ in r["groups"] if k]) for r in R)
        pas = sum(len(r["passed"]) for r in R)
        lit = sum(len(r["lit"]) for r in R)
        P(f"  s{s}: literal-key invocations {lit}; closed refusal groups {ref}; pass markers {pas}; "
          f"resolved calls with neither marker {sum(1 for r in R if r['kind']=='resolved' and not r['groups'] and not r['passed'])}")
    # value reading
    gtl = []   # every pass marker, global, time-sorted
    for r in recs:
        for k in r["passed"]:
            gtl.append((r["c"]["t"], r["s"], k, r["c"]["unit"], r["c"]["idx"]))
    gtl.sort()
    byunit = collections.defaultdict(list)
    for a in allu:
        if not a["side"]:
            byunit[a["unit"]].append(a)
    P("value reading, one row per distinct VALIDATOR-FINDING (story,gate,reason) at its first occurrence "
      "[later PASS = same story+gate; same pass preferred; between = tool_use kinds after the refusal up to that pass]:")
    seen, rows = set(), []
    dmap = {}
    for r in recs:
        for key, reasons in r["groups"]:
            for check, detail in reasons:
                if key:
                    dmap.setdefault((r["s"], key[0], key[1], reason_of(check, detail)), detail[1:] if len(detail) > 1 else detail)
    for u in sorted(units, key=lambda u: u[6]):
        s, st_, gt_, pa_, rs, cls, t, unit, idx = u
        if cls != "VALIDATOR-FINDING" or st_ is None or (s, st_, gt_, rs) in seen:
            continue
        seen.add((s, st_, gt_, rs))
        later = [x for x in gtl if x[0] > t and x[1] == s and x[2][0] == st_ and x[2][1] == gt_]
        same = [x for x in later if x[2][2] == pa_]
        pick = (same or later or [None])[0]
        sk = norm_story(st_, bare_map, s) or st_
        det = ""
        for ln in dmap.get((s, st_, gt_, rs), []):
            if ln.strip() and not ln.strip().startswith("remedy"):
                i0 = ln.find("REFUSED ")
                det = re.sub(r"\s+", " ", ln[i0 + 8:] if i0 >= 0 else ln.strip())[:140]
                break
        if pick:
            win = [a for a in allu if not a["side"] and t < a["t"] <= pick[0] and a["kind"] in ("edit", "chg", "dispatch")]
            named = [a for a in win if sk in stories_in(a["text"], bare_map)]
            kn, ka = collections.Counter(a["kind"] for a in named), collections.Counter(a["kind"] for a in win)
            sig = (("named-story edit %d, commit/cp/mv %d, dispatch %d" % (kn["edit"], kn["chg"], kn["dispatch"])) if named else "no event naming the story") + \
                  (" | all lead events edit %d, commit/cp/mv %d, dispatch %d" % (ka["edit"], ka["chg"], ka["dispatch"]))
            mins = (dt.datetime.fromisoformat(pick[0].replace("Z", "+00:00")) - dt.datetime.fromisoformat(t.replace("Z", "+00:00"))).total_seconds() / 60
            rows.append((s, sk, gt_, rs, "PASS", "same-pass" if same else f"p{pick[2][2]}", mins, sig, bool(named), det))
        else:
            lateinv = sum(1 for r2 in recs if r2["s"] == s and r2["c"]["t"] > t and any(
                (norm_story(ix, bare_map, s) == sk and gt == gt_) for ix, gt, pa, sf in r2["invs"] if ix and gt))
            rows.append((s, sk, gt_, rs, "NO LATER PASS", f"later invocations {lateinv}", 0.0, "", False, det))
    for r in rows:
        P(f"  s{r[0]} story {r[1]} g{r[2]} {r[3]:40} {r[4]:13} {r[5]:9} {r[6]:5.1f} min  {r[7]}")
        P(f"        reason text: {r[9]}")
    P(f"  distinct validator-finding units {len(rows)}; later PASS {sum(1 for r in rows if r[4]=='PASS')} "
      f"(an event naming that story between {sum(1 for r in rows if r[4]=='PASS' and r[8])}, none naming it {sum(1 for r in rows if r[4]=='PASS' and not r[8])}); "
      f"no later PASS {sum(1 for r in rows if r[4] != 'PASS')}")
    # procedural rows: the same read, compactly
    seen2 = set()
    ppass = pn = 0
    for u in sorted(units, key=lambda u: u[6]):
        s, st_, gt_, pa_, rs, cls, t, unit, idx = u
        if cls != "PROCEDURAL" or st_ is None or (s, st_, gt_, rs) in seen2:
            continue
        seen2.add((s, st_, gt_, rs))
        pn += 1
        ppass += 1 if any(x[0] > t and x[1] == s and x[2][0] == st_ and x[2][1] == gt_ for x in gtl) else 0
    P(f"  distinct PROCEDURAL units {pn}; later PASS on the same story+gate {ppass}")
    return units


def q2(calls, tuples, vals, allu, recs, bare_map, W, out):
    P = out.append
    P("\n== Q2  hand-run repeat share with a derived story key")
    scope = tuple_scope(tuples)
    P("tuple scope (story-scoped = gate-transition.sh passes it $STORY/$WT/$SHA/$IDX/$BASE/$1):")
    for t in tuples:
        if not t["bookkeeping"]:
            P(f"   {scope[(t['script'], t['mode'])]:6} {t['script']:34} {t['mode']:26} gates {','.join(sorted(t['gates'])) or '-'}")
    # gate-transition invocation list (per unit), from output markers
    gtl = collections.defaultdict(list)
    for r in recs:
        c = r["c"]
        for key, reasons in r["groups"]:
            if key:
                st_ = norm_story(key[0], bare_map, r["s"])
                gtl[c["unit"]].append(dict(idx=c["idx"], story=st_, gate=key[1], outcome="refused", checks={x[0] for x in reasons}))
        for key in r["passed"]:
            gtl[c["unit"]].append(dict(idx=c["idx"], story=norm_story(key[0], bare_map, r["s"]), gate=key[1], outcome="passed", checks=set()))
        # invocations with a literal story and gate but neither marker: gate-known, outcome unknown
        mk = {k for k, _ in r["groups"] if k} | r["passed"]
        for ix, gt, pa, sf in r["invs"]:
            if ix and gt and not ix.startswith("$") and (ix, gt, pa) not in mk:
                gtl[c["unit"]].append(dict(idx=c["idx"], story=norm_story(ix, bare_map, r["s"]), gate=gt, outcome="unknown", checks=set()))
    for u in gtl:
        gtl[u].sort(key=lambda x: x["idx"])
    # recency context per unit: (idx, single story) of gt / dispatch tool_use inputs
    ctx = collections.defaultdict(list)
    for a in allu:
        if a["side"] or a["kind"] not in ("gt", "dispatch"):
            continue
        k = one(stories_in(a["text"], bare_map))
        if k:
            ctx[a["unit"]].append((a["idx"], k))
    known = {t["script"] for t in tuples}
    rows = []
    for c in calls:
        if c["side"] or c["t"] > W or c["t"] < g.BBS_WIN_START:
            continue
        s = g.sprint_of(c["t"])
        if s not in SPR:
            continue
        bases = [b for b, _ in c["invs"]]
        if any(b in g.GATE_SCRIPTS for b in bases):
            continue
        kind, code, text = g.outcome(c, W)
        seen = collections.Counter()
        for b, a in c["invs"]:
            occ = seen[b]
            seen[b] += 1
            if b in g.GATE_SCRIPTS or b not in known:
                continue
            tup = g.resolve_tuple(b, a, tuples)
            if tup is None or tup["bookkeeping"] or c["step"] not in g.STEPS_IN:
                continue
            v = "unresolved"
            if kind == "resolved":
                cl, ecode = rd.classify(c["cmd"], b, occ, text)
                if cl == "resolvable":
                    v = rd.verdict(code, tup)
                elif cl == "echo-resolved":
                    v = rd.verdict(ecode, tup)
            sc = scope[(tup["script"], tup["mode"])] == "story"
            k1 = one(stories_in(" ".join(a), bare_map))
            k2 = one(stories_in(c["cmd"], bare_map))
            k3 = one(stories_in(content_text(c) if kind == "resolved" else "", bare_map))
            key, tier = (k1, "T1") if k1 else ((k2, "T2") if k2 else ((k3, "T3") if k3 else (None, None)))
            k4 = None
            if key is None:
                prev = [x for x in ctx.get(c["unit"], []) if c["idx"] - LOOKBACK <= x[0] < c["idx"]]
                if prev:
                    k4 = max(prev)[1]
            rows.append(dict(s=s, idx=c["idx"], unit=c["unit"], tup=tup, gates=tup["gates"], checks=set(tup["checks"]), v=v, scoped=sc,
                             key=key, tier=tier, k4=k4, script=b))
    ev = g.compute(calls, W, tuples)
    for s in SPR:
        n = sum(1 for r in rows if r["s"] == s)
        P(f"control s{s}: in-step rows {n} vs gate_run_evidence.compute hr_in {ev[s]['hr_in']}  {'OK' if n == ev[s]['hr_in'] else 'DIFFERS'}")
    ctl_bad = sum(1 for s in SPR if sum(1 for r in rows if r["s"] == s) != ev[s]["hr_in"])
    # coverage
    P("story-key coverage (in-step rows):")
    for s in SPR + ("pooled",):
        R = [r for r in rows if s == "pooled" or r["s"] == s]
        sc = [r for r in R if r["scoped"]]
        sw = [r for r in R if not r["scoped"]]
        t1 = sum(1 for r in sc if r["tier"] == "T1"); t2 = sum(1 for r in sc if r["tier"] == "T2"); t3 = sum(1 for r in sc if r["tier"] == "T3")
        t4 = sum(1 for r in sc if r["tier"] is None and r["k4"])
        none = sum(1 for r in sc if r["tier"] is None and not r["k4"])
        P(f"  {str(s):6}: rows {len(R)}; sprint-wide (no story to key, joined on gate) {len(sw)}; story-scoped {len(sc)}: "
          f"T1 {t1}, T2 {t2}, T3 {t3} (strict key {t1+t2+t3} = {pct(t1+t2+t3, len(sc)).strip()}), T4 recency {t4}, no key {none}")
        vc = collections.Counter(r["v"] for r in R)
        P(f"          verdict resolved: found {vc['found']} clean {vc['clean']} recorded {vc['recorded']}; unresolved {vc['unresolved']}")
    P("  structurally excluded: a sprint-wide tuple has no story; a story named only in a file the validator READS (not in its "
      "arguments, command or result) is invisible; a bare s322 worktree index with no gate-transition call carrying both forms is "
      f"unmapped (bare map {dict(sorted((f's{a}:{b}', v) for (a, b), v in bare_map.items()))}); T4 inherits recency and can be wrong when the lead switches story.")
    # repeat shares
    P(f"threshold {int(THRESH*100)}% same-verdict repeats of in-step rows; LOWER = T1-T3 keys, MID = + T4, CEILING = story ignored (gate kept)")
    verdicts, ceil_bad = {}, 0
    bytup = collections.defaultdict(collections.Counter)
    for s in SPR:
        R = [r for r in rows if r["s"] == s]
        for N in (N_SMALL, N_LARGE):
            c = collections.Counter()
            for r in R:
                gts = gtl.get(r["unit"], [])
                x = repeat_match(r, gts, N) if (not r["scoped"] or r["key"]) else None
                xm = x
                if x is None and r["scoped"] and not r["key"] and r["k4"]:
                    xm = repeat_match(dict(r, key=r["k4"]), gts, N)
                xc = repeat_match(r, gts, N, story_mode="ignore")
                c["lo"] += 1 if x else 0
                c["mid"] += 1 if xm else 0
                c["ceil"] += 1 if xc else 0
                c["lo_same"] += 1 if x and same_verdict(r["v"], x, r["checks"]) else 0
                c["mid_same"] += 1 if xm and same_verdict(r["v"], xm, r["checks"]) else 0
                c["lo_wide"] += 1 if x and not r["scoped"] else 0
                if N == N_LARGE:
                    k = (r["tup"]["script"], r["tup"]["mode"])
                    bytup[(s, k)]["rows"] += 1
                    bytup[(s, k)]["strict"] += 1 if x else 0
                    bytup[(s, k)]["same"] += 1 if x and same_verdict(r["v"], x, r["checks"]) else 0
            n = len(R)
            ev_any = ev[s]["any"][N]
            ok = ev_any == c["ceil"]
            ceil_bad += 0 if ok else 1
            P(f"  s{s} N={N:2d}: rows {n}; repeats (any verdict) LOWER {c['lo']} ({pct(c['lo'], n).strip()}) MID {c['mid']} ({pct(c['mid'], n).strip()}) "
              f"CEILING {c['ceil']} ({pct(c['ceil'], n).strip()}) [control: gate_run_evidence story-ignored count {ev_any} {'OK' if ok else 'DIFFERS'}]; "
              f"same-verdict LOWER {c['lo_same']} ({pct(c['lo_same'], n).strip()}) MID {c['mid_same']} ({pct(c['mid_same'], n).strip()}); "
              f"of the LOWER repeats {c['lo_wide']} are sprint-wide rows")
            verdicts[(s, N)] = (n, c["lo"], c["mid"], c["ceil"], c["lo_same"], c["mid_same"])
    P("per tuple at N=20 (rows, strict repeats, same-verdict repeats):")
    for (s, k), c in sorted(bytup.items()):
        P(f"  s{s} {k[0]:34} {k[1]:26} rows {c['rows']:3d}  repeats {c['strict']:3d}  same-verdict {c['same']:3d}")
    P("verdict (threshold 50% same-verdict repeats; CEILING bounds every reading above it):")
    for (s, N), (n, lo, mid, up, lo_same, mid_same) in sorted(verdicts.items()):
        res = "KEEP" if n and up < THRESH * n else ("MERGE-candidate" if n and lo_same >= THRESH * n else "NOT DISCRIMINATED")
        P(f"  s{s} N={N:2d}: {res:18} (rows {n}, 50% = {THRESH*n:.1f}; CEILING {up}, MID repeats {mid}, same-verdict LOWER {lo_same})")
    ctl_bad += ceil_bad
    return ctl_bad, rows, gtl


def controls(recs, calls, tuples, W, out):
    P = out.append
    P("CONTROLS (same run):")
    bad = 0
    ev = g.compute(calls, W, tuples)
    for s, ci, cr in ((321, 160, 34), (322, 82, 19)):
        inv = ev[s]["inv"]
        ref = ev[s]["out"]["refused"]
        mine = sum(1 for r in recs if r["s"] == s)
        mref = sum(1 for r in recs if r["s"] == s and r["refused"])
        mgrp = sum(1 for r in recs if r["s"] == s and r["groups"])
        ok = (inv, ref, mine, mref) == (ci, cr, ci, cr)
        bad += 0 if ok else 1
        P(f"  s{s} gate-transition.sh calls: evidence {inv}, here {mine} (expected {ci}); refused: evidence {ref}, here b2 {mref}, here parsed groups {mgrp} (expected {cr})  "
          + ("OK" if ok else "DIFFERS"))
        P(f"      could-not-run: evidence {ev[s]['out']['could-not-run']} (die line or exit 2 of the command), here calls with a die() line "
          f"{sum(1 for r in recs if r['s'] == s and r['die'])}; passed: evidence {ev[s]['out']['passed']}")
        if mgrp != mref:
            P(f"      note: parsed-group calls {mgrp} vs b2 refused {mref}: b2 also counts a bare `N refusal(s)` line with no REFUSED line")
    tok = "validate-" + "zzimpossible" + "-q7x4kd.sh"
    absent = sum(open(p, errors="replace").read().count(tok) for p in glob.glob(g.ROOT + "/*.jsonl"))
    neg = sum(1 for c in calls if tok in [b for b, _ in c["invs"]])
    pos = sum(1 for c in calls if "gate-transition.sh" in [b for b, _ in c["invs"]])
    P(f"  negative control: impossible token raw-text count {absent} (must be 0), invoked {neg} (must be 0); positive control gate-transition.sh invoked {pos} (must be > 0)  "
      + ("OK" if absent == 0 and neg == 0 and pos > 0 else "BAD"))
    bad += 0 if absent == 0 and neg == 0 and pos > 0 else 1
    return bad


def main():
    W = WIN
    tuples, vals, calls, st, allu = build(W)
    out = [f"window {g.BBS_WIN_START} .. {W}  root {g.ROOT}  gate-transition.sh {GT_SHA}:{GT_REL}  (step state from {g.STEP_WIN_START})"]
    recs_all = None
    bare_map, badmap = learn_bare(calls, W)
    recs = gt_calls(calls, W, bare_map)
    # idx parity between this module's scan_all and g.scan for every Bash call
    byid = {(a["unit"], a["id"]): a["idx"] for a in allu}
    mism = sum(1 for c in calls if byid.get((c["unit"], c["id"])) != c["idx"])
    out.append(f"scan parity: Bash calls {len(calls)}, idx mismatches against scan_all {mism}; bare-index alias conflicts {badmap}")
    bad = controls(recs, calls, tuples, W, out) + (1 if mism else 0)
    out.append("")
    q1(recs, tuples, vals, allu, bare_map, W, out)
    cb, rows, gtl = q2(calls, tuples, vals, allu, recs, bare_map, W, out)
    print("\n".join(out))
    if bad or cb:
        print(f"CONTROL STATUS: DIFFERS ({bad} count control(s), {cb} row control(s))")
        sys.exit(2)
    print("CONTROL STATUS: OK")


# ------------------------------------------------------------------------------------------------ self-test
def selftest():
    fails = []
    def chk(name, cond, detail=""):
        print(f"  {'PASS' if cond else 'FAIL'}  {name} {detail}")
        if not cond:
            fails.append(name)
    vals = {"validate-stub-audit.sh", "validate-handoff-evidence.sh", "sprint-status.sh"}
    text = ("x\ngate-transition: REFUSED handoff-evidence: validate-handoff-evidence.sh a.md b c exited 1:\n"
            "/w/x.out:REFUSED dar-heads-stale a.md: block differs\n  remedy: r\n"
            "gate-transition: REFUSED check-16: validate-stub-audit.sh --changed-from b c exited 1:\n"
            "FINDING s.sh:1 element1-item-ref - cites none\n  remedy: r\n"
            "gate-transition: 2 refusal(s); no plan written (/r/gate-transition/3.1-g1-p1.plan)\n"
            "gate-transition: REFUSED prior-validation: no QA pass 1 file docs/x in /w or /r\n  remedy: merge\n"
            "gate-transition: 1 refusal(s); no plan written (/r/gate-transition/1-5-g2-p2.plan)\n"
            "/r/gate-transition/2.1-g1-p1.plan\n")
    G = parse_groups(text)
    chk("groups: two closed groups keyed by plan", [k for k, _ in G] == [("3.1", "1", "1"), ("1-5", "2", "2")], str([k for k, _ in G]))
    rs = [(reason_of(c, d), classify_reason(c, d, vals)) for _, rr in G for c, d in rr]
    want = [("handoff-evidence:dar-heads-stale", "VALIDATOR-FINDING"), ("check-16:element1-item-ref", "VALIDATOR-FINDING"), ("prior-validation", "PROCEDURAL")]
    chk("classifier: validator exits vs own precondition, with inner tokens", rs == want, str(rs))
    mp = [classify_reason(c, d, vals, "prefix") for _, rr in G for c, d in rr]
    chk("mutant FAILS: check-name-prefix classifier calls handoff-evidence PROCEDURAL", mp != [x[1] for x in rs], str(mp))
    ma = [classify_reason(c, d, vals, "all") for _, rr in G for c, d in rr]
    chk("mutant FAILS: everything-is-a-finding classifier calls prior-validation a finding", ma != [x[1] for x in rs], str(ma))
    chk("a bookkeeping script exit is PROCEDURAL (near-miss)", classify_reason("gate1-review", ["merge-review-shards.sh --read-verdict x exited 1: y"], vals) == "PROCEDURAL")
    # duplicate half of evidence's text
    call = dict(text="abc\ngate-transition: REFUSED x: d\n\nabc\ngate-transition: REFUSED x: d\n\n", tur=dict(stdout="abc\ngate-transition: REFUSED x: d\n", stderr=""))
    call["text"] = "abc\ngate-transition: REFUSED x: d" + "\n" + "abc\ngate-transition: REFUSED x: d\n" + "\n" + ""
    n1 = len(parse_groups(content_text(call))[0][1]) if parse_groups(content_text(call)) else 0
    n2 = len(parse_groups(content_text(call, mutant=True))[0][1]) if parse_groups(content_text(call, mutant=True)) else 0
    chk("content-only text counts a refusal once; mutant raw text counts it twice", n1 == 1 and n2 == 2, f"content {n1} raw {n2}")
    # pass detection
    lit = {("3.1", "1", "1")}
    t2 = "/r/gate-transition/3.1-g1-p1.plan\n/r/gate-transition/9.9-g1-p1.plan\n3.1-g1-p1.plan\n"
    chk("pass: bare plan path equal to a literal invocation key only", pass_keys(t2, lit) == {("3.1", "1", "1")}, str(pass_keys(t2, lit)))
    chk("mutant FAILS: accepting any plan path line adds the ls-listed story", pass_keys(t2, lit, "any") != pass_keys(t2, lit))
    chk("a refusal's closing line is not a pass marker", pass_keys("gate-transition: 1 refusal(s); no plan written (/r/gate-transition/3.1-g1-p1.plan)\n", lit) == set())
    # story keys
    bm = {(322, "4"): "1.4"}
    chk("story: filename", stories_in("x story-3-1-foo.md", bm) == {"3.1"})
    chk("story: worktree and review file agree on one story", stories_in("-C /w/graph-s321-story-3.1 docs/reviews/s321/3.1-code-review.md", bm) == {"3.1"})
    chk("story: bare s322 worktree maps through the learned alias", stories_in("-C /w/graph-s322-story-4", bm) == {"1.4"})
    chk("story: unmapped bare index names nothing", stories_in("-C /w/graph-s322-story-9", bm) == set())
    chk("story: two stories are ambiguous (no key)", one(stories_in("ls story-3-1-a.md story-4-2-b.md", bm)) is None)
    chk("mutant FAILS: first-match takes a key from the ambiguous text", one(stories_in("ls story-3-1-a.md story-4-2-b.md", bm), "first") is not None)
    chk("story: a version string 3.1 is not a story", stories_in("python 3.1 and v3.1-rc", bm) == set())
    # repeat join
    row = dict(idx=10, gates={"1"}, scoped=True, key="3.1", v="found", checks={"handoff-evidence"})
    gts = [dict(idx=12, story="3.1", gate="2", outcome="passed", checks=set()),
           dict(idx=14, story="4.2", gate="1", outcome="passed", checks=set()),
           dict(idx=30, story="3.1", gate="1", outcome="refused", checks={"handoff-evidence"})]
    chk("repeat: gate and story must both match; N bounds the window", repeat_match(row, gts, 5) is None and repeat_match(row, gts, 20)["idx"] == 30)
    chk("mutant FAILS: ignoring story matches the 4.2 call at N=5", repeat_match(row, gts, 5, story_mode="ignore") is not None)
    gts2 = [dict(idx=12, story="3.1", gate="2", outcome="passed", checks=set())]
    chk("mutant FAILS: ignoring gate matches the gate-2 call", repeat_match(row, gts2, 5) is None and repeat_match(row, gts2, 5, gate_mode="any") is not None)
    chk("sprint-wide row joins on gate alone", repeat_match(dict(idx=1, gates={"3"}, scoped=False, key=None), [dict(idx=3, story="9.9", gate="3", outcome="passed", checks=set())], 5) is not None)
    chk("unkeyed story-scoped row never joins strictly", repeat_match(dict(idx=1, gates={"3"}, scoped=True, key=None), [dict(idx=3, story="9.9", gate="3", outcome="passed", checks=set())], 5) is None)
    chk("same-verdict: found+refused-on-its-check yes, found+passed no, clean+passed yes, unresolved none",
        (same_verdict("found", gts[2], {"handoff-evidence"}), same_verdict("found", gts[0], {"handoff-evidence"}),
         same_verdict("clean", gts[0], set()), same_verdict("unresolved", gts[0], set())) == (True, False, True, None))
    # scope classifier on the real file
    real, _ = g.parse_gt(g.GT_PATH)
    sc = tuple_scope(real)
    chk("scope: stub-audit story-scoped, sprint-status sprint-wide (real file)",
        sc.get(("validate-stub-audit.sh", "--changed-from")) == "story" and sc.get(("sprint-status.sh", "derive-stories --check")) == "sprint", str({k: v for k, v in sc.items() if k[0] in ("validate-stub-audit.sh", "sprint-status.sh")}))
    print("SELF-TEST " + ("OK" if not fails else "FAILED: " + ", ".join(fails)))
    sys.exit(0 if not fails else 1)


if __name__ == "__main__":
    try:
        if "--self-test" in sys.argv:
            selftest()
        main()
    finally:
        if _TMP:
            import shutil
            shutil.rmtree(_TMP, ignore_errors=True)
