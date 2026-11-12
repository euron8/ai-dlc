"""gate-run value evidence (BL-819 item 2): do lead hand-runs of the validators gate-transition.sh runs REPEAT what
gate-transition.sh answers, and do lead gate-run calls refuse?  Records-only reader of the graph lead transcripts.

usage: python3 -I gate_run_evidence.py [--control | --self-test]      (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
  (no flag)     control first (exit 2, no reading printed, on any mismatch), then the readings for s317..s322.
  --control     only the control: D5 rows PARSED from out/bash_by_sprint.txt, recounted with bash_by_sprint.py's
                keying at that file's own window; both values printed; exit 2 on any mismatch.
  --self-test   seeded mktemp transcript dir + seeded mini gate-transition.sh: each case and its verdict, each
                mutant (a deliberately broken predicate) shown to FAIL the same assertions; negative control.

WHAT IS LOADED, NEVER RESTATED (ast, as roll.py:146-147 loads definitions; extract.py is never imported or run):
  extract.py   EDGES (45-47), STEP_RE (30), SUBPROC (31), GATE_RUN_RE (162), strip_heredocs (57), invoked (165),
               gate_event (68).   bash_by_sprint.py   FAM (20), WIN_START (17).
  gate-transition.sh (read at run time from $GATE_TRANSITION, default /Users/n8/git/graph/scripts/ai-dlc/):
  the validator (script, mode) tuples, the gate each runs at, the check name it refuses under and the exit codes it
  records without refusing.  Sites parsed: `run <script>` (:159 def; calls :236 captures, :248 handoff, :279 carried),
  `arm <id> <script>` (:445 def; :451-455, :467-473), and `bash "$SELF/<script>"` (:264 map, :317, :326, :365,
  :393, :424, :436, :456, :480, :488, :490, :498, :532).  A tuple is a VALIDATOR iff its failure reaches `refuse`
  (:147-150, which prints `gate-transition: REFUSED <check>: ...`; :151-155 prints `gate-transition: N refusal(s)`):
  an `arm` site (arm() body refuses, :448), a `run` site whose enclosing function refuses, or a bash site whose
  statement or following lines (to a blank line, the next site, or 8 lines) carry `refuse`.  Tuples of
  gate-checkpoint.sh and merge-review-shards.sh are BOOKKEEPING even where they refuse (:365, :436, :498, :532),
  as are non-refusing tuples (partition-review-diff.sh :264-:393, validate-steering-budget.sh :488 which records
  `Check 25 SKIP`).  A hand-run of a bookkeeping script, or of a mode no tuple names, is its own bucket.
  Exit meaning is parsed from the `N) input gate-log` case arms: handoff/captures exit 2 (:251, :239), stub-audit 4
  (:459), spawn-ledger Check 22 exit 3 (:484) are RECORDED not refused, so a hand-run exiting there found nothing.

PREDICATES (stated once; the output header repeats them):
  gate-run call     tool_use Bash block with any(GATE_RUN_RE.match(x) for x in invoked(cmd))  (extract.py:227).
                    Also given per distinct message.id.  Refused = resolved result with non-zero exit (is_error or
                    leading `Exit code N`) or B2 text.  A chained `a; b` reports the last status: an UNDERcount.
  gate-transition   an INVOCATION = gate-transition.sh in command position of an invoked() segment (cat/grep/sed of
                    it are excluded).  "keyed as bash_by_sprint" = first FAM match basename (control, no sidechain
                    filter); "any command containing" = substring.  Sprint = tool_use timestamp.
  B2 refusal        a column-0 line `gate-transition: REFUSED ` or `gate-transition: N refusal(s)` in the
                    tool_result content or toolUseResult stdout/stderr.  could-not-run = a column-0
                    `gate-transition: ` line that is neither (die(), :102, exit 2).  UNRESOLVED (never 0):
                    run_in_background, persisted output (toolUseResult.persistedOutputPath or a
                    <persisted-output> marker), no result inside the window.  A line preceded by other text on
                    the same line is not column 0 and is missed (limit).
  hand-run          a lead Bash call whose invoked() segments run a validator tuple of gate-transition.sh with
                    neither gate-transition.sh nor gate-checkpoint.sh in the same command.  One ROW per
                    (call, tuple).  Counted only in steps `implementation` and `gate-validation[implementation]`
                    (the brief's "gate[implementation]").
  step attribution  RE-DERIVED, not loaded: extract.py's scan() is one function over module globals and cannot be
                    loaded without running extract.py's body.  This script replays scan()'s step state machine
                    (extract.py:340-375 incl. gate_event open/close and the SUBPROC / whole-vs-slice rules) over the
                    lead records, with STEP_RE, SUBPROC and gate_event loaded by ast.  LIMIT: a replay, not the
                    extractor; drift in scan() is not detected.  The step is the one in force BEFORE the tool_use's
                    own record updates it (extract.py:353).
  story key (D7)    gate-transition's first positional (`3.1`; `-` read as `.`), plus, when its --story-file is a
                    literal path, the key that file name gives (a bare index `4` names story-1-4-*.md; `$S` is
                    unresolvable).  A hand-run's story is derived ONLY for
                    validate-handoff-evidence.sh from an argument `.../story-<a>-<b>-<slug>.md` -> `<a>.<b>`; the
                    join is itself checked against every gate-transition call that carries both an index and a
                    --story-file.  Every other hand-run is "story not derivable".
  REPEAT (FOLD)     the same tuple, later followed within N lead tool_use blocks (same transcript) by a
                    gate-transition.sh call for the same story AT A GATE THAT RUNS THAT TUPLE.  Counted at N=5 and
                    N=20.  SAME-VERDICT: hand-run found (non-zero, not a recorded code) and that call's output
                    REFUSED the tuple's check name; or hand-run clean/recorded and that call output carries no
                    refusal at all.  Check names are shared between tuples (check-2, check-5, check-17): coarse.
  THRESHOLD         MERGE-candidate if same-verdict repeats >= 50% of in-step hand-run rows (denominator includes
                    story-not-derivable and unresolved rows); otherwise KEEP.  Decided before the run; recorded as
                    a finding, not shipped.
"""
import ast, collections, datetime as dt, glob, json, os, re, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
EX = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")
BBS = os.path.join(HERE, "bash_by_sprint.py")
BBS_OUT = os.path.join(HERE, "..", "out", "bash_by_sprint.txt")
GT_PATH = os.environ.get("GATE_TRANSITION") or "/Users/n8/git/graph/scripts/ai-dlc/gate-transition.sh"
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
STEP_WIN_START = os.environ.get("EXTRACT_WIN_START") or "2026-09-26T00:35:00Z"
SPRINTS = range(317, 323)
POOL_SPRINTS = (321, 322)   # gate-transition.sh did not exist before s321; s317..s320 rows cannot repeat
N_SMALL, N_LARGE = 5, 20
THRESHOLD = 0.5
STEPS_IN = ("implementation", "gate-validation[implementation]")
BOOK_SCRIPTS = ("gate-checkpoint.sh", "merge-review-shards.sh")
GATE_SCRIPTS = ("gate-transition.sh", "gate-checkpoint.sh")
SCOPE_FLAGS = ("-C", "--root", "--ledger", "--sprint", "--probe", "--settings", "--escalations", "--transcript-dir",
               "--nonce", "--gate", "--shard-dir")


def load_defs(path, assigns, funcs, ns):
    tree = ast.parse(open(path).read())
    for n in tree.body:
        if (isinstance(n, ast.Assign) and getattr(n.targets[0], "id", None) in assigns) or \
           (isinstance(n, ast.FunctionDef) and n.name in funcs):
            exec(compile(ast.Module([n], []), path, "exec"), ns)
    for a in assigns + funcs:
        if a not in ns:
            sys.exit(f"gate_run_evidence: {a} not found in {path}")
    return ns


NS = load_defs(EX, ("EDGES", "STEP_RE", "SUBPROC", "GATE_RUN_RE"), ("strip_heredocs", "invoked", "gate_event"),
               {"re": re, "os": os})
load_defs(BBS, ("WIN_START", "FAM"), (), NS)
EDGES, STEP_RE, SUBPROC, GATE_RUN_RE = NS["EDGES"], NS["STEP_RE"], NS["SUBPROC"], NS["GATE_RUN_RE"]
strip_heredocs, invoked, gate_event = NS["strip_heredocs"], NS["invoked"], NS["gate_event"]
BBS_WIN_START, FAM = NS["WIN_START"], NS["FAM"]


def sprint_of(t):
    for e, n in EDGES:
        if t < e:
            return n


def invocations(cmd):
    """invoked()'s segmentation, keeping the argument words: [(basename, args)]."""
    out = []
    for seg_ in re.split(r"\|\||&&|[|;&\n]", strip_heredocs(cmd)):
        w = [x.strip("\"'()") for x in seg_.split()]
        while w and (w[0] in ("bash", "sh", "env", "python", "python3") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w[0])):
            w = w[1:]
        if w:
            out.append((os.path.basename(w[0]), w[1:]))
    return out


def bbs_key(cmd):
    m = FAM.findall(cmd)
    key = m[0] if m else (cmd.split()[0] if cmd.split() else "?")
    return re.sub(r"^.*/", "", key)


# ----------------------------------------------------------------------------------------------- gate-transition.sh
def mode_of(tokens):
    """First non-scope flag, or the first bare word (subcommand) plus the next non-scope flag; (default) if none."""
    toks = [t.strip("\"'") for t in tokens]
    i, word, flag = 0, None, None
    while i < len(toks):
        t = toks[i]
        if t in SCOPE_FLAGS:
            i += 2
            continue
        if t.startswith("$") or t == "":
            i += 1
            continue
        if t.startswith("-"):
            flag = t
            break
        if word is None:
            word = t
        i += 1
    if word is None and flag is None:
        return "(default)"
    if word is None:
        return flag
    # a subcommand word: take the next non-scope flag after it, if any
    j = toks.index(word) + 1
    nxt = None
    while j < len(toks):
        if toks[j] in SCOPE_FLAGS:
            j += 2
            continue
        if toks[j].startswith("-"):
            nxt = toks[j]
            break
        j += 1
    return word + (" " + nxt if nxt else "")


CUT_RE = re.compile(r"\s\)|\s>|\s<|\s\|\||\s&&|;|\s\\$")
CP = r"(?:^\s*|[;&|{(]\s*)"


def parse_gt(path):
    text = open(path).read()
    L = text.split("\n")
    isc = lambda i: L[i].lstrip().startswith("#")
    funcs = {}
    for i, l in enumerate(L):
        m = re.match(r"^(\s*)([A-Za-z_]\w*)\(\) \{(.*)$", l)
        if not m:
            continue
        ind, name, rest = m.groups()
        if rest.rstrip().endswith("}"):
            funcs[name] = (i, i)
            continue
        for j in range(i + 1, len(L)):
            if L[j] == ind + "}":
                funcs[name] = (i, j)
                break
    gates, start = {}, None
    for i, l in enumerate(L):
        if re.match(r'^case "\$GATE" in\s*$', l):
            start = i
            continue
        if start is None:
            continue
        m = re.match(r"^(1|2|3|close)\)\s*$", l)
        if m:
            gates[m.group(1)] = [i, None]
            last = m.group(1)
        elif l.startswith("esac"):
            gates[last][1] = i
            break
    for g, v in gates.items():
        if v[1] is None:
            v[1] = len(L)
    # a gate's end is the next label: close each span at the following label
    order = sorted(gates, key=lambda g: gates[g][0])
    for a, b in zip(order, order[1:]):
        gates[a][1] = gates[b][0]

    def gate_of(i):
        for g, (a, b) in gates.items():
            if a <= i < b:
                return g

    def func_of(i):
        best = None
        for n, (a, b) in funcs.items():
            if a <= i <= b and (best is None or funcs[best][0] < a):
                best = n
        return best

    body = lambda n: "\n".join(L[funcs[n][0]:funcs[n][1] + 1])
    REF = re.compile(r"\brefuse\b")

    def args_of(rest):
        m = CUT_RE.search(rest)
        return (rest[:m.start()] if m else rest).split()

    # sites
    sites = []  # dict(kind, script, args, line, fn, check_id)
    for i, l in enumerate(L):
        if isc(i):
            continue
        m = re.search(CP + r"run\s+([\w-]+\.sh)\b(.*)$", l)
        if m:
            sites.append(dict(kind="run", script=m.group(1), args=args_of(m.group(2)), line=i))
        m = re.search(CP + r"arm\s+(\S+)\s+([\w-]+\.sh)\b(.*)$", l)
        if m:
            sites.append(dict(kind="arm", script=m.group(2), args=args_of(m.group(3)), line=i, cid=m.group(1)))
        for m in re.finditer(r'bash\s+"\$SELF/([\w-]+\.sh)"(.*)$', l):
            sites.append(dict(kind="bash", script=m.group(1), args=args_of(m.group(2)), line=i))
    site_lines = {s["line"] for s in sites}
    arm_refuses = "arm" in funcs and bool(REF.search(body("arm")))

    def callers(fname):
        out = []
        for i, l in enumerate(L):
            if isc(i):
                continue
            m = re.search(CP + re.escape(fname) + r"\s+(.*)$", l)
            if m and func_of(i) != fname:
                out.append((i, args_of(m.group(1))))
        return out

    tuples = {}  # (script, mode) -> dict

    def add(script, mode, line, gate_set, refuses, check, noop, kind):
        t = tuples.setdefault((script, mode), dict(script=script, mode=mode, lines=set(), gates=set(), refuses=False,
                                                   checks=set(), noop=set(), kinds=set()))
        t["lines"].add(line + 1)
        t["gates"] |= gate_set
        t["refuses"] = t["refuses"] or refuses
        if check:
            t["checks"].add(check)
        t["noop"] |= noop
        t["kinds"].add(kind)

    def noop_codes(lines_):
        out = set()
        for l in lines_:
            m = re.match(r"^\s*(\d+)\)\s*(.*)$", l)
            if m and m.group(1) != "0" and "input gate-log" in m.group(2) and not REF.search(m.group(2)):
                out.add(int(m.group(1)))
        return out

    for s in sites:
        i, kind = s["line"], s["kind"]
        if kind == "arm":
            add(s["script"], mode_of(s["args"]), i, {gate_of(i)} - {None}, arm_refuses, "check-" + s["cid"], set(), "arm")
            continue
        fn = func_of(i)
        if kind == "run" and fn:
            b = body(fn)
            refuses = bool(REF.search(b))
            noop = noop_codes(b.split("\n"))
            m = re.search(r"\brefuse\s+([\w-]+)", b)
            if '"$@"' in " ".join(s["args"]) or "$@" in " ".join(s["args"]):
                for ci, cargs in callers(fn):
                    name = cargs[0] if cargs else ""
                    margs = cargs[1:]
                    add(s["script"], mode_of(margs), i, {gate_of(ci)} - {None}, refuses, name.strip("\"'"), noop, "run")
            else:
                gs = {gate_of(ci) for ci, _ in callers(fn)} - {None}
                add(s["script"], mode_of(s["args"]), i, gs, refuses, m.group(1) if m else "", noop, "run")
            continue
        # bash / top-level run: statement + following lines
        j = i
        while L[j].rstrip().endswith("\\") and j + 1 < len(L):
            j += 1
        win = list(range(i, j + 1))
        k = j + 1
        while k < len(L) and k <= j + 8 and L[k].strip() != "" and k not in site_lines \
                and not re.match(r"^(1|2|3|close)\)\s*$", L[k]) and not re.match(r"^\s*;;\s*$", L[k]):
            win.append(k)
            k += 1
        wl = [L[x] for x in win if not isc(x)]
        wt = "\n".join(wl)
        m = re.search(r"\brefuse\s+([\w-]+)", wt)
        add(s["script"], mode_of(s["args"]), i, {gate_of(i)} - {None}, bool(REF.search(wt)), m.group(1) if m else "",
            noop_codes(wl), "bash")
    # cross-derivation: every parsed script is in the :136 sibling list
    m = re.search(r"for s in ([^;]+); do", text)
    sibs = set(m.group(1).split()) if m else set()
    out = []
    for (script, mode), t in sorted(tuples.items()):
        t["bookkeeping"] = (not t["refuses"]) or script in BOOK_SCRIPTS
        t["why"] = ("non-refusing" if not t["refuses"] else "bookkeeping script") if t["bookkeeping"] else "validator"
        t["in_siblings"] = script in sibs
        out.append(t)
    return out, sibs


def resolve_tuple(script, args, tuples):
    """The parsed tuple a real invocation runs: non-default modes by token membership (longest first), else (default)."""
    toks = [a.strip("\"'") for a in args]
    cand = [t for t in tuples if t["script"] == script]
    if not cand:
        return None
    hit = []
    for t in cand:
        if t["mode"] == "(default)":
            continue
        if all(w in toks for w in t["mode"].split()):
            hit.append(t)
    if hit:
        return max(hit, key=lambda t: len(t["mode"]))
    for t in cand:
        if t["mode"] == "(default)":
            return t
    return None


# ----------------------------------------------------------------------------------------------- transcript scan
def text_of(x, tur):
    parts = []
    c = x.get("content")
    if isinstance(c, str):
        parts.append(c)
    elif isinstance(c, list):
        parts += [y.get("text") or "" for y in c if isinstance(y, dict)]
    if isinstance(tur, dict):
        parts += [str(tur.get("stdout") or ""), str(tur.get("stderr") or "")]
    elif isinstance(tur, str):
        parts.append(tur)
    return "\n".join(parts)


def scan(root, wmax):
    """One pass over ROOT/*.jsonl lead transcripts up to wmax.  Returns (calls, stats).  Bash calls from
    BBS_WIN_START on are kept; the step state machine runs from STEP_WIN_START (extract.py's rule)."""
    calls, st = [], collections.Counter()
    for p in sorted(glob.glob(root + "/*.jsonl")):
        st["files"] += 1
        unit = os.path.basename(p)[:-6]
        pend, seen_ids = {}, set()
        step = main = "pre-step"; gate = None; whole = set(); idx = 0
        for line in open(p, errors="replace"):
            try:
                r = json.loads(line)
            except Exception:
                continue
            t = r.get("timestamp")
            if not t or t < STEP_WIN_START or t > wmax:
                continue
            side = bool(r.get("isSidechain"))
            if side:
                st["sidechain_records"] += 1
            typ = r.get("type")
            if typ == "assistant":
                for c in (r.get("message") or {}).get("content") or []:
                    if not isinstance(c, dict) or c.get("type") != "tool_use":
                        continue
                    idx += 1
                    inp = c.get("input") or {}
                    if c.get("name") == "Bash" and t >= BBS_WIN_START:
                        cmd = inp.get("command", "") or ""
                        if c["id"] in seen_ids:
                            st["dup_tool_use_ids"] += 1
                        seen_ids.add(c["id"])
                        call = dict(id=c["id"], unit=unit, idx=idx, t=t, mid=(r.get("message") or {}).get("id"),
                                    cmd=cmd, step=step, side=side, bg=bool(inp.get("run_in_background")),
                                    res_t=None, text="", tur=None, is_error=False, invs=invocations(cmd))
                        if [b for b, _ in call["invs"]] != invoked(cmd):
                            st["invoked_parity_mismatch"] += 1
                        calls.append(call)
                        pend[c["id"]] = call
                    if c.get("name") == "Bash":
                        ev = gate_event(str(inp.get("command") or ""))
                        if ev == "open":
                            gate = "gate-validation[" + main + "]"; step = gate
                        elif ev == "close":
                            gate = None; step = main
                    mm = STEP_RE.search(json.dumps(c.get("input", {})))
                    if mm and c.get("name") == "Read":
                        name = mm.group(1)
                        isslice = "offset" in c.get("input", {}) or "limit" in c.get("input", {})
                        sliced = isslice and name in whole
                        if not isslice:
                            whole.add(name)
                        if name not in SUBPROC and not sliced:
                            if name == "gate-validation":
                                step = gate or "gate-validation[" + main + "]"
                            else:
                                main = name
                                if gate is None:
                                    step = name
            elif typ == "user":
                c = (r.get("message") or {}).get("content")
                if isinstance(c, list):
                    for x in c:
                        if isinstance(x, dict) and x.get("type") == "tool_result" and x.get("tool_use_id") in pend:
                            call = pend.pop(x["tool_use_id"])
                            call["res_t"] = t
                            call["tur"] = r.get("toolUseResult")
                            call["is_error"] = x.get("is_error") is True
                            call["text"] = text_of(x, call["tur"])
    return calls, st


# ----------------------------------------------------------------------------------------------- reading
REF_RE = re.compile(r"^gate-transition: REFUSED (\S+?):", re.M)
CNT_RE = re.compile(r"^gate-transition: \d+ refusal\(s\)", re.M)
DIE_RE = re.compile(r"^gate-transition: (?!REFUSED |\d+ refusal\(s\))", re.M)
EXIT_RE = re.compile(r"^\s*Exit code (\d+)")
STORY_RE = re.compile(r"story-(\d+)-(\d+)-[^/\s]*\.md$")
OPT0 = dict(inv="command", anchored=True, excl_gate=True, story=True, gatematch=True)


def norm_story(s):
    return s.replace("-", ".").lower()


def story_from_args(args):
    for a in args:
        m = STORY_RE.search(os.path.basename(a.strip("\"'")))
        if m:
            return m.group(1) + "." + m.group(2)
    return None


def gt_parse(args):
    """(story index, gate, story-file) from a gate-transition.sh invocation's argument words."""
    pos, i, sf = [], 0, None
    while i < len(args):
        a = args[i].strip("\"'")
        if a in ("--pass", "-C", "--base", "--sprint", "--story-file", "--transcript-dir"):
            if a == "--story-file" and i + 1 < len(args):
                sf = args[i + 1].strip("\"'")
            i += 2
            continue
        if a.startswith("-"):
            i += 1
            continue
        pos.append(a)
        i += 1
    return (pos[0] if pos else None, pos[1] if len(pos) > 1 else None, sf)


def outcome(call, W):
    """(kind, exit code or None, text).  kind: resolved | UNRESOLVED-bg | UNRESOLVED-persisted | UNRESOLVED-noresult."""
    if call["bg"]:
        return "UNRESOLVED-bg", None, ""
    if call["res_t"] is None or call["res_t"] > W:
        return "UNRESOLVED-noresult", None, ""
    tur = call["tur"]
    if (isinstance(tur, dict) and tur.get("persistedOutputPath")) or "<persisted-output>" in call["text"]:
        return "UNRESOLVED-persisted", None, ""
    m = EXIT_RE.match(call["text"])
    code = int(m.group(1)) if m else (1 if call["is_error"] else 0)
    return "resolved", code, call["text"]


def b2(text, anchored=True):
    if not anchored:
        return ("REFUSED" in text), sorted(set(re.findall(r"REFUSED (\S+?):", text))), False
    names = sorted(set(REF_RE.findall(text)))
    return bool(names or CNT_RE.search(text)), names, bool(DIE_RE.search(text))


def compute(calls, W, tuples, opts=OPT0, inv_script="gate-transition.sh"):
    R = {s: dict(
        gr_calls=0, gr_mids=set(), gr_prog=collections.Counter(), gr_ref_prog=collections.Counter(), gr_ref=0, gr_unres=0,
        bbs=0, inv=0, contain=0, out=collections.Counter(), reflines=0, join_ok=0, join_n=0,
        hr_rows=0, hr_calls=set(), hr_steps=collections.Counter(), hr_book=collections.Counter(), hr_notuple=0,
        hr_in=0, hr_tuple=collections.Counter(), hr_verdict=collections.Counter(), hr_nostory=0,
        rep=collections.Counter(), rep_same=collections.Counter(), rep_diff=collections.Counter(),
        rep_unres=collections.Counter(), any=collections.Counter(), hr_found_in=0) for s in SPRINTS}
    gtl = collections.defaultdict(list)   # unit -> [(idx, story, gate, call)]
    cand = []
    tmap = [t for t in tuples if not t["bookkeeping"]]
    allmap = tuples
    for c in calls:
        if c["side"] or c["t"] > W or c["t"] < BBS_WIN_START:
            continue
        s = sprint_of(c["t"])
        if s not in R:
            continue
        r = R[s]
        bases = [b for b, _ in c["invs"]]
        kind, code, text = outcome(c, W)
        res_in = c["res_t"] is not None and c["res_t"] <= W
        # (0) gate-run
        progs = sorted({b for b in invoked(c["cmd"]) if GATE_RUN_RE.match(b)})
        if progs:
            r["gr_calls"] += 1
            r["gr_mids"].add(c["mid"] or c["id"])
            if kind != "resolved":
                r["gr_unres"] += 1
            refused = kind == "resolved" and (code != 0 or b2(text, opts["anchored"])[0])
            r["gr_ref"] += 1 if refused else 0
            for b in progs:
                r["gr_prog"][b] += 1
                r["gr_ref_prog"][b] += 1 if refused else 0
        # (1) gate-transition
        if res_in and bbs_key(c["cmd"]) == inv_script:
            r["bbs"] += 1
        if inv_script in c["cmd"]:
            r["contain"] += 1
        is_inv = (inv_script in bases) if opts["inv"] == "command" else (inv_script in c["cmd"])
        if is_inv:
            r["inv"] += 1
            if kind != "resolved":
                r["out"][kind] += 1
                refd, names, die = False, [], False
            else:
                refd, names, die = b2(text, opts["anchored"])
                r["reflines"] += len(re.findall(r"^gate-transition: REFUSED ", text, re.M)) if opts["anchored"] else text.count("REFUSED")
                r["out"]["refused" if refd else ("could-not-run" if die or code == 2 else "passed")] += 1
            for b, a in c["invs"]:
                if b == inv_script:
                    ix, gt, sf = gt_parse(a)
                    fkey = story_from_args([sf]) if sf else None
                    if ix is not None and fkey:
                        r["join_n"] += 1
                        r["join_ok"] += 1 if fkey == norm_story(ix) else 0
                    if ix is not None and gt is not None:
                        # the call's story keys: its index AND, when --story-file is a literal path, the key that
                        # file name gives (a bare index such as `4` names story-1-4-*.md; `$S` is not resolvable)
                        gtl[c["unit"]].append((c["idx"], {norm_story(ix)} | ({fkey} if fkey else set()), gt, kind, refd, names))
        # (3) hand-run
        if opts["excl_gate"] and any(b in GATE_SCRIPTS for b in bases):
            continue
        for b, a in c["invs"]:
            if b in GATE_SCRIPTS:
                continue
            tup = resolve_tuple(b, a, allmap)
            known = {x["script"] for x in allmap}
            if b not in known:
                continue
            if tup is None:
                r["hr_notuple"] += 1
                continue
            if tup["bookkeeping"]:
                r["hr_book"][(tup["script"], tup["mode"])] += 1
                continue
            r["hr_rows"] += 1
            r["hr_calls"].add(c["id"])
            r["hr_steps"][c["step"]] += 1
            if c["step"] in STEPS_IN:
                r["hr_in"] += 1
                r["hr_tuple"][(tup["script"], tup["mode"])] += 1
                if kind != "resolved":
                    v = "unknown"
                elif code == 0:
                    v = "clean"
                elif code in tup["noop"]:
                    v = "recorded"
                else:
                    v = "found"
                r["hr_verdict"][v] += 1
                story = story_from_args(a) if b == "validate-handoff-evidence.sh" else None
                if story is None:
                    r["hr_nostory"] += 1
                cand.append((s, c, tup, v, story))
    # (4) repeats
    for s, c, tup, v, story in cand:
        for N in (N_SMALL, N_LARGE):
            r = R[s]; anyhit = False
            for (ix, gstory, gate, gk, grefd, gnames) in sorted(gtl.get(c["unit"], []), key=lambda e: e[0]):
                if not (c["idx"] < ix <= c["idx"] + N):
                    continue
                if opts["gatematch"] and gate not in tup["gates"]:
                    continue
                if not anyhit:   # UPPER BOUND, story key ignored: a gate-transition at the tuple's gate within N calls
                    r["any"][N] += 1; anyhit = True
                if opts["story"] and (story is None or story not in gstory):
                    continue
                r["rep"][N] += 1
                if gk != "resolved" or v == "unknown":
                    r["rep_unres"][N] += 1
                else:
                    chk = bool(set(gnames) & tup["checks"])
                    same = (v == "found" and chk) or (v in ("clean", "recorded") and not grefd)
                    (r["rep_same"] if same else r["rep_diff"])[N] += 1
                break
    return R


# ----------------------------------------------------------------------------------------------- control
def parse_control():
    """Rows of out/bash_by_sprint.txt: header window, transcripts, and {(sprint, kind): {key: n}}."""
    rows, hdr, cur = {}, None, None
    for l in open(BBS_OUT):
        m = re.match(r"^root (\S+); transcripts (\d+); window (\S+) \.\. (\S+)$", l.rstrip("\n"))
        if m:
            hdr = dict(root=m.group(1), files=int(m.group(2)), start=m.group(3), end=m.group(4))
            continue
        m = re.match(r"^s(\d+) (lead|sub): Bash wall", l)
        if m:
            cur = (int(m.group(1)), m.group(2)); rows[cur] = {}
            continue
        m = re.match(r"^   (\S.*?)\s+(\d+) calls\s+[\d.]+ h", l)
        if m and cur:
            rows[cur][m.group(1)] = int(m.group(2))
    if not hdr or not rows:
        sys.exit("gate_run_evidence: cannot parse " + BBS_OUT)
    return hdr, rows


D5 = [(321, "gate-transition.sh"), (322, "gate-transition.sh"), (321, "validate-spawn-ledger.sh"), (321, "verdict.sh"),
      (322, "verdict.sh"), (321, "validate-artifact-derivations.sh"), (322, "sprint-status.sh"),
      (322, "validate-snapshot-conservation.sh")]


def control(calls, st, hdr, rows, root):
    """Recount with bash_by_sprint.py's exact keying (result paired, in window, first FAM match, no sidechain filter)."""
    Wc = hdr["end"]
    cnt = collections.Counter()
    for c in calls:
        if c["res_t"] is None or c["res_t"] < BBS_WIN_START or c["res_t"] > Wc or c["t"] > Wc:
            continue
        cnt[(sprint_of(c["t"]), bbs_key(c["cmd"]))] += 1
    bad, lines = 0, []
    for s, key in D5:
        parsed = rows.get((s, "lead"), {}).get(key)
        got = cnt.get((s, key), 0)
        ok = parsed is not None and parsed == got
        bad += 0 if ok else 1
        lines.append(f"  D5 s{s} {key:34} parsed {parsed!s:>5}  recount {got:5d}  {'OK' if ok else 'MISMATCH'}")
    allbad = n = 0
    for (s, kind), d in sorted(rows.items()):
        if kind != "lead":
            continue
        for key, v in d.items():
            n += 1
            if cnt.get((s, key[:42]), 0) != v:
                allbad += 1
                lines.append(f"  ROW s{s} {key}: parsed {v} recount {cnt.get((s, key), 0)}  MISMATCH")
    nfiles = len(glob.glob(root + "/*.jsonl")) + len(glob.glob(root + "/*/subagents/*.jsonl"))
    fok = True   # the file count is not window-bound (sessions started after the committed run add files): informational
    lines.append(f"  all {n} lead rows of the committed file recounted: {allbad} mismatch(es)")
    lines.append(f"  transcripts (informational, not window-bound): committed {hdr['files']}  glob now {nfiles}")
    lines.append(f"  sidechain records seen {st['sidechain_records']}; duplicate Bash tool_use ids {st['dup_tool_use_ids']}; "
                 f"invoked() parity mismatches {st['invoked_parity_mismatch']}")
    return bad + allbad + (0 if fok else 1), lines


# ----------------------------------------------------------------------------------------------- report
def pct(a, b):
    return f"{100.0 * a / b:5.1f}%" if b else "  n/a "


def report(R, tuples, W, out):
    P = out.append
    P(f"window {BBS_WIN_START} .. {W}   root {ROOT}   (step state from {STEP_WIN_START})")
    P(f"threshold: MERGE-candidate if same-verdict repeats >= {int(THRESHOLD * 100)}% of in-step hand-run rows, else KEEP; N={N_SMALL} and N={N_LARGE}")
    for s in SPRINTS:
        r = R[s]
        P(f"\n== s{s}" + ("   [s322 is LIVE: PARTIAL unless the window was pinned after its retro]" if s == 322 else ""))
        P(f"(0) gate-run calls {r['gr_calls']}  (distinct message.id {len(r['gr_mids'])})  refused {r['gr_ref']}  unresolved {r['gr_unres']}")
        for b in sorted(r["gr_prog"]):
            P(f"      {b:44} calls {r['gr_prog'][b]:4d}  refused {r['gr_ref_prog'][b]:4d}")
        o = r["out"]
        P(f"(1) gate-transition.sh: as bash_by_sprint keys it {r['bbs']}  real invocation {r['inv']}  any command containing {r['contain']}")
        P(f"(2)     refused {o['refused']} ({r['reflines']} REFUSED lines)  could-not-run {o['could-not-run']}  passed {o['passed']}  "
          f"UNRESOLVED bg {o['UNRESOLVED-bg']} persisted {o['UNRESOLVED-persisted']} no-result {o['UNRESOLVED-noresult']}  "
          f"[index vs literal --story-file key agree {r['join_ok']}/{r['join_n']}; a call matches a hand-run on either key]")
        P(f"(3) hand-run rows {r['hr_rows']} (calls {len(r['hr_calls'])}); in implementation/gate[implementation] {r['hr_in']}; "
          f"bookkeeping-script rows {sum(r['hr_book'].values())}; unlisted-mode rows {r['hr_notuple']}")
        P("      step of all hand-run rows: " + (", ".join(f"{k} {v}" for k, v in r["hr_steps"].most_common()) or "none"))
        for (sc, md), v in sorted(r["hr_tuple"].items()):
            P(f"      in-step tuple {sc} {md}: {v}")
        hv = r["hr_verdict"]
        P(f"(5) in-step hand-run exit meaning: found {hv['found']}  clean {hv['clean']}  recorded-code {hv['recorded']}  unknown {hv['unknown']}")
        P(f"(4) story not derivable {r['hr_nostory']} of {r['hr_in']}")
        for N in (N_SMALL, N_LARGE):
            P(f"      N={N:2d}: repeats {r['rep'][N]}  same-verdict {r['rep_same'][N]}  differing {r['rep_diff'][N]}  "
              f"unresolved {r['rep_unres'][N]}  share of in-step rows {pct(r['rep_same'][N], r['hr_in'])}  "
              f"[sensitivity, story key IGNORED, gate kept: {r['any'][N]} rows ({pct(r['any'][N], r['hr_in']).strip()}) have a gate-transition at their gate within N]")
        if r["inv"] == 0:
            P("      side: n/a (no gate-transition.sh in this sprint)")
        else:
            P("      side: " + "; ".join(f"N={N}: " + ("MERGE-candidate" if r["hr_in"] and r["rep_same"][N] >= THRESHOLD * r["hr_in"] else "KEEP")
                                         for N in (N_SMALL, N_LARGE)))
    tot = collections.Counter()
    for s in POOL_SPRINTS:
        r = R[s]
        tot["in"] += r["hr_in"]
        for N in (N_SMALL, N_LARGE):
            tot[("same", N)] += r["rep_same"][N]
    P("\n== pooled s321+s322 ONLY (gate-transition.sh did not exist in s317..s320, so those sprints cannot show a repeat)")
    for N in (N_SMALL, N_LARGE):
        P(f"N={N:2d}: same-verdict repeats {tot[('same', N)]} of {tot['in']} in-step hand-run rows {pct(tot[('same', N)], tot['in'])}  -> "
          + ("MERGE-candidate" if tot["in"] and tot[("same", N)] >= THRESHOLD * tot["in"] else "KEEP"))


def tuple_block(tuples, sibs, out):
    P = out.append
    P(f"gate-transition.sh: {GT_PATH}  ({len(tuples)} tuples; sibling list :136 has {len(sibs)} scripts)")
    P("VALIDATOR tuples (failure reaches refuse):")
    for t in tuples:
        if not t["bookkeeping"]:
            P(f"  {t['script']:32} {t['mode']:28} gates {','.join(sorted(t['gates'])) or '-':6} check {','.join(sorted(t['checks'])) or '-':22} "
              f"recorded-exit {sorted(t['noop']) or '-'}  lines {sorted(t['lines'])}")
    P("BOOKKEEPING bucket (never validators):")
    for t in tuples:
        if t["bookkeeping"]:
            P(f"  {t['script']:32} {t['mode']:28} gates {','.join(sorted(t['gates'])) or '-':6} {t['why']:20} lines {sorted(t['lines'])}")
    miss = [t["script"] for t in tuples if not t["in_siblings"]]
    P(f"cross-check: parsed scripts absent from the :136 sibling list: {sorted(set(miss)) or 'none'}")


def main_reading(calls, st, tuples, sibs, hdr, rows):
    out = []
    bad, lines = control(calls, st, hdr, rows, ROOT)
    out.append(f"CONTROL (window {hdr['end']}, parsed from out/bash_by_sprint.txt):")
    out += lines
    if bad:
        print("\n".join(out)); print(f"CONTROL FAILED: {bad} mismatch(es); no reading printed"); sys.exit(2)
    out.append("CONTROL OK\n")
    tuple_block(tuples, sibs, out)
    out.append("")
    report(compute(calls, WIN_END, tuples), tuples, WIN_END, out)
    return out


# ----------------------------------------------------------------------------------------------- self-test
def _rec(t, typ, **kw):
    d = dict(timestamp=t, type=typ); d.update(kw); return json.dumps(d)


def seeded(tmp):
    """Write the synthetic lead transcripts; return the expected case list."""
    n = [0]
    def tid(): n[0] += 1; return f"tu{n[0]:03d}"
    lines_a, T = [], [0]
    def at(sec=1):
        T[0] += sec; return "2026-11-05T10:%02d:%02dZ" % (T[0] // 60, T[0] % 60)
    def use(name, inp, mid):
        i = tid(); lines_a.append(_rec(at(), "assistant", message=dict(id=mid, content=[dict(type="tool_use", id=i, name=name, input=inp)]))); return i
    def res(i, text, err=False, tur=None, t=None):
        r = dict(message=dict(content=[dict(type="tool_result", tool_use_id=i, content=text, is_error=err)]))
        if tur is not None: r["toolUseResult"] = tur
        lines_a.append(_rec(t or at(), "user", **r))
    def bash(cmd, text="", err=False, tur=None, mid=None, **kw):
        i = use("Bash", dict(command=cmd, **kw), mid or "m" + tid()); res(i, text, err, tur); return i
    G = "scripts/ai-dlc/gate-transition.sh"
    W1 = "-C /w --base abc --sprint 321 --story-file _bmad-output/planning-artifacts/s321/stories/story-3-1-foo.md"
    i = use("Read", dict(file_path="/x/.claude/skills/ai-dlc/steps/implementation.md"), "mr"); res(i, "ok")
    # c: hand-run, found; followed by filler then a refusing gate-transition at gate 1 (repeat at N=5, not N=1)
    bash("bash scripts/ai-dlc/validate-handoff-evidence.sh -C /w --strategy abc story-3-1-foo.md", "Exit code 1\nREFUSED x", True)
    bash("echo filler1"); bash("echo filler2")
    bash(f"{G} 3.1 1 {W1}", "gate-transition: REFUSED handoff-strategy: x\n  remedy: y\ngate-transition: 1 refusal(s); no plan written (p)", False)
    # mention, cat of REFUSED text, die, bg, persisted
    bash(f"grep REFUSED {G}", "gate-transition: REFUSED fake: not a run\n")
    bash("cat plan.txt", "gate-transition: REFUSED planned: not a run\n")
    bash(f"{G} 3.1 9 {W1}", "Exit code 2\ngate-transition: the gate must be 1, 2, 3 or close. usage", True)
    bash(f"{G} 3.1 1 {W1}", "started", False, run_in_background=True)
    bash(f"{G} 3.1 1 {W1}", "gate-transition: REFUSED handoff-evidence: z", False, tur=dict(persistedOutputPath="/tmp/o", stdout="", stderr=""))
    # hand-run recorded code (stub-audit 4), no following gate-transition
    bash("bash scripts/ai-dlc/validate-stub-audit.sh --root /w --changed-from a b", "Exit code 4\nnothing audited", True)
    # hand-run + gate-transition in ONE command: not a hand-run
    bash(f"bash scripts/ai-dlc/validate-handoff-evidence.sh -C /w --strategy abc story-9-9-bar.md && {G} 9.9 1 {W1}", "gate-transition: REFUSED handoff-strategy: q", False)
    # different story then gate-transition for 3.1: not a repeat (story key)
    bash("bash scripts/ai-dlc/validate-handoff-evidence.sh -C /w --strategy abc story-7-7-baz.md", "ok", False)
    bash(f"{G} 3.1 1 {W1}", "plan.path", False)
    # right story, wrong gate (gate 2 does not run --strategy): not a repeat (gate match)
    bash("bash scripts/ai-dlc/validate-handoff-evidence.sh -C /w --strategy abc story-2-2-qux.md", "ok", False)
    bash(f"{G} 2.2 2 -C /w --base abc --sprint 321 --story-file _bmad-output/planning-artifacts/s321/stories/story-2-2-qux.md", "plan.path", False)
    # a real invocation whose output mentions REFUSED mid-line only: passed; an unanchored search would call it refused
    bash(f"{G} 5.5 1 {W1}", "plan.path\nnote: an earlier run was REFUSED, now fixed", False)
    # gate-run program with a non-zero exit
    bash("bash scripts/ai-dlc/validate-foo.sh", "Exit code 1\nFAIL", True, mid="mgr")
    # window edge: used before Wc, result after: control excludes it, reading calls it UNRESOLVED
    i = use("Bash", dict(command=f"{G} 3.2 1 {W1}"), "medge")
    lines_a.append(_rec("2026-11-11T10:29:58Z", "assistant", message=dict(id="medge2", content=[dict(type="tool_use", id="tuEDGE", name="Bash", input=dict(command=f"{G} 3.3 1 {W1}"))])))
    lines_a.append(_rec("2026-11-11T10:30:05Z", "user", message=dict(content=[dict(type="tool_result", tool_use_id="tuEDGE", content="gate-transition: REFUSED z: late")])))
    open(os.path.join(tmp, "lead-a.jsonl"), "w").write("\n".join(lines_a) + "\n")
    # lead-b: a hand-run before any step Read (pre-step): counted as a row, not in-step
    b = [_rec("2026-11-05T11:00:01Z", "assistant", message=dict(id="mb", content=[dict(type="tool_use", id="tb1", name="Bash", input=dict(command="bash scripts/ai-dlc/validate-handoff-evidence.sh -C /w --gate2 story-4-4-q.md"))])),
         _rec("2026-11-05T11:00:02Z", "user", message=dict(content=[dict(type="tool_result", tool_use_id="tb1", content="Exit code 1\nx", is_error=True)]))]
    open(os.path.join(tmp, "lead-b.jsonl"), "w").write("\n".join(b) + "\n")


MINI_GT = r'''#!/usr/bin/env bash
refuse() { :; }
run() { local s="$1"; shift; bash "$SELF/$s" "$@"; RC=$?; }
captures() {
  run validate-handoff-evidence.sh -C "$WT" --list-captures "$STORY" "$1"
  case "$RC" in
    0) ;;
    2) input gate-log "x" ;;
    *) refuse list-captures "d" "r" ;;
  esac
}
case "$GATE" in 1|2) ;; esac
case "$GATE" in
1)
  captures "$SHA"
  bash "$SELF/partition-review-diff.sh" --map "$WT" > "$W.out"
  stop_if_refused
  ;;
3)
  arm() { local id="$1" s="$2"; shift 2; ( bash "$SELF/$s" "$@" ); RC=$?; [ "$RC" = 0 ] || refuse "check-$id" "d" "r"; }
  arm 5 sprint-status.sh derive-stories --check
  ( bash "$SELF/validate-stub-audit.sh" --root "$WT" --changed-from "$BASE" "$SHA" ) > "$W.out"; RC=$?
  case "$RC" in
    0) ;;
    4) input gate-log "none" ;;
    *) refuse check-16 "d" "r" ;;
  esac
  ( bash "$SELF/gate-checkpoint.sh" --nonce "$N" open ) > "$W.out" \
    || { refuse open "d" "r"; }
  ( bash "$SELF/validate-steering-budget.sh" --count ) > "$W.out"; RC=$?
  if [ "$RC" = 0 ]; then input a b; else input gate-log "SKIP"; fi
  ;;
esac
'''


def selftest():
    fails = []
    def check(name, cond, detail=""):
        print(f"  {'PASS' if cond else 'FAIL'}  {name} {detail}")
        if not cond: fails.append(name)
    work = os.environ.get("SELFTEST_TMP_BASE") or None
    tmp = tempfile.mkdtemp(prefix="gre-selftest-", dir=work)
    print(f"self-test tree {tmp}")
    # --- parser, seeded mini gate-transition.sh, both directions
    mp = os.path.join(tmp, "mini-gate-transition.sh"); open(mp, "w").write(MINI_GT)
    tups, _ = parse_gt(mp)
    d = {(t["script"], t["mode"]): t for t in tups}
    def isv(k): return k in d and not d[k]["bookkeeping"]
    check("parser: run-in-function refusing site -> validator", isv(("validate-handoff-evidence.sh", "--list-captures")))
    check("parser: run-in-function records exit 2", d.get(("validate-handoff-evidence.sh", "--list-captures"), {}).get("noop") == {2})
    check("parser: arm site -> validator with subcommand+flag mode", isv(("sprint-status.sh", "derive-stories --check")))
    check("parser: bash site with `refuse` below -> validator, records exit 4", isv(("validate-stub-audit.sh", "--changed-from")) and d[("validate-stub-audit.sh", "--changed-from")]["noop"] == {4})
    check("parser: non-refusing bash site (partition) -> bookkeeping", ("partition-review-diff.sh", "--map") in d and d[("partition-review-diff.sh", "--map")]["bookkeeping"])
    check("parser: non-refusing steering site -> bookkeeping (stop_if_refused is not refuse)", d.get(("validate-steering-budget.sh", "--count"), {}).get("bookkeeping") is True)
    check("parser: refusing gate-checkpoint -> bookkeeping script", d.get(("gate-checkpoint.sh", "open"), {}).get("bookkeeping") is True)
    check("parser: gate sets", d[("validate-handoff-evidence.sh", "--list-captures")]["gates"] == {"1"} and d[("validate-stub-audit.sh", "--changed-from")]["gates"] == {"3"})
    # real file: the live contract
    real, sibs = parse_gt(GT_PATH)
    rv = {(t["script"], t["mode"]) for t in real if not t["bookkeeping"]}
    check("real file parses to a non-empty validator set and a non-empty bookkeeping set", len(rv) > 0 and any(t["bookkeeping"] for t in real), f"({len(rv)} validator tuples)")
    check("real file: every parsed script is in the :136 sibling list", all(t["in_siblings"] for t in real))
    # --- seeded transcripts
    seeded(tmp)
    Wc = "2026-11-11T10:30:00Z"
    calls, st = scan(tmp, "2099")
    def run_case(opts, W):
        return compute(calls, W, real, opts)
    R = run_case(OPT0, Wc)[321]
    o = R["out"]
    check("invocation counted: real invocations (refused, could-not-run, bg, persisted, plain-pass x3, edge)", R["inv"] == 9, f"inv={R['inv']}")
    check("mention (grep of the script) is not an invocation but is 'containing'", R["contain"] == R["inv"] + 1, f"contain={R['contain']}")
    check("refused counts only column-0 REFUSED text of a real invocation", o["refused"] == 2, f"refused={o['refused']}")
    check("cat of a file holding REFUSED is not counted", R["reflines"] == 2, f"reflines={R['reflines']}")
    check("exit-2 die line is could-not-run, not refused", o["could-not-run"] == 1)
    check("background and persisted calls are UNRESOLVED, not 0", o["UNRESOLVED-bg"] == 1 and o["UNRESOLVED-persisted"] == 1)
    E = run_case(OPT0, Wc)[322]["out"]
    check("window edge (s322): result after W is UNRESOLVED-noresult at Wc; the s321 call with no result likewise", E["UNRESOLVED-noresult"] == 1 and o["UNRESOLVED-noresult"] == 1)
    R2 = run_case(OPT0, "2099")[322]
    check("window edge: the same call is resolved/refused in a later window (differential differs)", R2["out"]["UNRESOLVED-noresult"] == 0 and R2["out"]["refused"] == 1 and E["refused"] == 0)
    check("gate-run: validate-foo.sh counted and refused by exit", R["gr_prog"]["validate-foo.sh"] == 1 and R["gr_ref_prog"]["validate-foo.sh"] == 1)
    check("gate-run: per-message-id count is distinct ids", len(R["gr_mids"]) <= R["gr_calls"] and "mgr" in R["gr_mids"])
    check("hand-run rows: strategy x3 + stub-audit (combined call excluded); pre-step row in lead-b counted outside step",
          R["hr_rows"] == 5 and R["hr_in"] == 4, f"rows={R['hr_rows']} in={R['hr_in']}")
    check("hand-run verdicts: found 1, clean 2, recorded 1", (R["hr_verdict"]["found"], R["hr_verdict"]["clean"], R["hr_verdict"]["recorded"]) == (1, 2, 1), str(dict(R["hr_verdict"])))
    check("story not derivable: only the stub-audit row", R["hr_nostory"] == 1)
    check("repeat N=5: exactly the 3.1 hand-run (story and gate match)", R["rep"][5] == 1 and R["rep_same"][5] == 1, f"rep={dict(R['rep'])}")
    R1 = compute(calls, Wc, real, OPT0)[321]
    check("repeat respects N: N=20 finds at least the N=5 repeat, and exactly one", R1["rep"][20] >= R1["rep"][5] == 1, f"rep={dict(R1['rep'])}")
    Rall = run_case(OPT0, Wc)
    rep_lines = []
    report(Rall, real, Wc, rep_lines)
    side = [ln for ln in rep_lines if ln.startswith("      side:")]
    check("side verdict: a sprint with no gate-transition.sh prints n/a, never KEEP; a sprint with calls prints a verdict",
          sum("n/a (no gate-transition.sh in this sprint)" in ln for ln in side) == sum(1 for s_ in SPRINTS if Rall[s_]["inv"] == 0)
          and any("n/a" in ln for ln in side) and any(("KEEP" in ln or "MERGE-candidate" in ln) for ln in side), f"({len(side)} side lines)")
    check("pooled block pools s321+s322 only", any(ln.startswith("\n== pooled s321+s322 ONLY") for ln in rep_lines))
    # N differential: rerun with N_SMALL shrunk
    global N_SMALL
    keep = N_SMALL
    N_SMALL = 1
    try:
        Rn = compute(calls, Wc, real, OPT0)[321]
    finally:
        N_SMALL = keep
    check("repeat N=1 finds none, N=5 finds one (the sides differ)", Rn["rep"][1] == 0 and R["rep"][5] == 1)
    # --- mutants must FAIL the same assertions
    def broken(opts, label, fn):
        Rm = compute(calls, Wc, real, opts)[321]
        check(f"mutant FAILS: {label}", fn(Rm), "(the broken predicate changed the reading, so the assertion above would fire)")
    broken(dict(OPT0, inv="substring"), "substring instead of command-position invocation", lambda m: m["inv"] != R["inv"])
    broken(dict(OPT0, anchored=False), "unanchored REFUSED search", lambda m: m["out"]["refused"] != R["out"]["refused"])
    broken(dict(OPT0, excl_gate=False), "no exclusion of gate script in the same command", lambda m: m["hr_rows"] != R["hr_rows"])
    broken(dict(OPT0, story=False), "repeat ignoring the story key", lambda m: m["rep"][5] != R["rep"][5])
    broken(dict(OPT0, gatematch=False), "repeat ignoring the gate that runs the tuple", lambda m: m["rep"][5] != R["rep"][5])
    # --- negative control: an impossible validator token, absent from the corpus, vs a positive control
    tok = "validate-" + "zzimpossible" + "-q7x4kd.sh"
    present = sum(open(p, errors="replace").read().count(tok) for p in glob.glob(ROOT + "/*.jsonl"))
    check("negative-control token is absent from the corpus (raw text count 0)", present == 0, f"(corpus files {len(glob.glob(ROOT + '/*.jsonl'))})")
    real_calls, _ = scan(ROOT, "2026-11-11T10:30:00Z") if os.path.isdir(ROOT) else ([], {})
    cnt = lambda sc: sum(1 for c in real_calls if sc in [b for b, _ in c["invs"]])
    neg, pos = cnt(tok), cnt("validate-spawn-ledger.sh")
    check("negative control counts 0; positive control (validate-spawn-ledger.sh) counts > 0 in the same invocation", neg == 0 and pos > 0, f"neg={neg} pos={pos}")
    print("SELF-TEST " + ("OK" if not fails else "FAILED: " + ", ".join(fails)))
    sys.exit(0 if not fails else 1)


def main():
    if "--self-test" in sys.argv:
        selftest()
    hdr, rows = parse_control()
    tuples, sibs = parse_gt(GT_PATH)
    wmax = max(WIN_END, hdr["end"])
    calls, st = scan(ROOT, wmax)
    if "--control" in sys.argv:
        bad, lines = control(calls, st, hdr, rows, ROOT)
        print(f"CONTROL (window {hdr['end']}, parsed from out/bash_by_sprint.txt):")
        print("\n".join(lines))
        print("CONTROL " + ("OK" if not bad else f"FAILED: {bad} mismatch(es)"))
        sys.exit(2 if bad else 0)
    print("\n".join(main_reading(calls, st, tuples, sibs, hdr, rows)))


if __name__ == "__main__":
    main()
