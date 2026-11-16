"""BL-514: what the subagent GAP (every wait over 300 s between two records) was spent on, per sprint.

Usage:
  gapclass.py <EXTRACT_OUT> [--hook HOOK]   classify every sub gap of the extract, print the per-sprint table
  gapclass.py --probe [--hook HOOK]         self-probe only (also runs before every corpus read)

Population: the same one as gap.py. The transcripts are extract.py's (EXTRACT_ROOT, its default otherwise), read
with extract.py's record rules: every line that parses and carries a timestamp, from EXTRACT_WIN_START (or extract's
default) to EXTRACT_WIN_END, so set the same window as the extract. Control, refusing: for every sub transcript, the
summed gap this script finds equals the summed `gap` of that transcript's rows in <EXTRACT_OUT>/segs.jsonl, to the
millisecond, and the two transcript sets are equal. Story divisors are roll.py's STORIES.

Each gap is classed by the state when it opened, first match wins:
  open-model-request   the record before the gap is an api-request (the agent sent a model call)
  open-tool:poll       a Bash tool_use with no tool_result yet, whose command the hook calls a poll (loopsleep or
                       longsleep, lifted from the hook by lift.sh, never retyped)
  open-tool:<name>     any other tool_use with no tool_result yet (Bash, Read, Agent, ...)
  own-background-wait  the record ending the gap is a user or attachment line carrying a task-notification or
                       the harness's background-task event: the agent's own background job ended the wait
  parked-bg:poll       the record before is an assistant line, the one ending the gap is a user TEXT line (not a
  parked-bg:other      tool_result), and at least one of the agent's own background launches (Bash with
                       run_in_background, or Monitor) was still outstanding: :poll when any outstanding launch
                       is one the hook calls a poll. The launch-to-notification join is join.sh's (scan()).
  parked-until-message the same, with no own background launch outstanding: nothing of the agent's ran until a
                       message arrived
  other                anything else
A tool_use whose result never arrives stops being open at the next user TEXT line.
The sprint of a gap is the sprint of the segs row whose [first, last] holds the gap's closing record.
"""
import importlib.util, json, os, re, subprocess, sys, tempfile, collections, glob
import datetime as dt

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, "..", "pipeline-efficiency-s317-s320", "scripts")
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CLASSES = ["open-model-request", "open-tool:poll", "open-tool:other", "own-background-wait",
           "parked-bg:poll", "parked-bg:other", "parked-until-message", "other"]
BGID = re.compile(r"(?:with ID: |Monitor started \(task )([A-Za-z0-9_-]+)")
MOVED = re.compile(r"moved to the background \(ID: ([A-Za-z0-9_-]+)")
STATS = collections.Counter()   # launches, with-task-id, no-task-id, completed, error-dropped, moved, moved-raw
NOTE_TASK = re.compile(r"<task-id>([^<]*)</task-id>")
NOTE_TUID = re.compile(r"<tool-use-id>([^<]*)</tool-use-id>")

def die2(msg):
    print("REFUSED: " + msg, file=sys.stderr); sys.exit(2)

def ts(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()

def load_stories():
    spec = importlib.util.spec_from_file_location("roll", os.path.join(SCRIPTS, "roll.py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return dict(m.STORIES)

def lift(hook, work):
    """The hook's poll predicate, via lift.sh -> a jq program reading one command string per input."""
    r = subprocess.run(["bash", "-c", 'die2() { echo "$*" >&2; exit 2; }; . "$1"; bl514_lift "$2" "$3"', "_",
                        os.path.join(HERE, "lift.sh"), hook, work], capture_output=True, text=True)
    if r.returncode != 0: die2("lift.sh failed on %s: %s" % (hook, r.stderr.strip()))
    prog = os.path.join(work, "poll.jq")
    with open(prog, "w") as f:
        f.write(open(os.path.join(work, "prelude.jq")).read() + "\n(loopsleep or longsleep)\n")
    return prog

def is_poll(prog, cmds):
    if not cmds: return []
    inp = "".join(json.dumps(c) + "\n" for c in cmds)
    r = subprocess.run(["jq", "-c", "-f", prog], input=inp, capture_output=True, text=True)
    if r.returncode != 0: die2("jq poll predicate failed: " + r.stderr.strip())
    out = r.stdout.split()
    if len(out) != len(cmds): die2("jq answered %d of %d commands" % (len(out), len(cmds)))
    return [o == "true" for o in out]

def content(r):
    return (r.get("message") or {}).get("content")

def user_text(r):
    c = content(r)
    if isinstance(c, str): return True
    return isinstance(c, list) and not any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c)

def note_text(r):
    return json.dumps(content(r)) + json.dumps(r.get("attachment"))

def notification(r):
    s = note_text(r)
    return "<task-notification>" in s or "automated background-task event" in s

def result_text(b):
    c = b.get("content")
    if isinstance(c, list): return " ".join(x.get("text", "") for x in c if isinstance(x, dict))
    return str(c or "")

def scan(path, win_start, win_end_ts):
    """[(gap_s, class, close_ts, [bash commands], detail)] for one transcript, extract.py's record rules.
    A background launch is a Bash call with run_in_background, a Monitor call, or a foreground Bash call
    whose result says the harness "moved [it] to the background (ID: X)". It is OUTSTANDING from its
    tool_result until a task-notification names its task id ("with ID: X" / "Monitor started (task X" /
    the moved ID) or its tool_use id: the same join as join.sh. A launch whose result names no task id
    stays outstanding, keyed on its tool_use id alone; one whose result is an error never starts."""
    out = []; prev_t = None; prev = None; pend = {}; launch = {}; bg = {}; bash = {}; atext = ""
    for line in open(path, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < win_start: continue
        tt = ts(t)
        if win_end_ts is not None and tt > win_end_ts: continue
        typ = r.get("type")
        if prev_t is not None:
            g = max(0.0, tt - prev_t)
            if g > 300:
                cmds = []
                if prev == "api-request": k = "open-model-request"
                elif pend:
                    name, inp = list(pend.values())[-1]
                    if name == "Bash": k = "open-tool:bash"; cmds = [(inp or {}).get("command", "")]
                    else: k = "open-tool:other"
                elif typ in ("user", "attachment") and notification(r): k = "own-background-wait"
                elif prev == "assistant" and typ == "user" and user_text(r):
                    if bg: k = "parked-bg"; cmds = [c for _, c in bg.values()]
                    else: k = "parked-until-message"
                else: k = "other"
                ctext = (user_text(r) and json.dumps(content(r))[:300]) or ""
                out.append((g, k, t, cmds, dict(prev_text=atext[-300:], close_text=ctext)))
        prev_t = tt; prev = typ
        if notification(r):
            s_ = note_text(r)
            done = set(NOTE_TASK.findall(s_)); tus = set(NOTE_TUID.findall(s_))
            gone = [x for x, (tu, _) in bg.items() if x in done or tu in tus]
            for x in gone: del bg[x]
            STATS["completed"] += len(gone)
        if typ == "assistant":
            for b in content(r) or []:
                if isinstance(b, dict) and b.get("type") == "text": atext = b.get("text") or atext
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    pend[b.get("id")] = (b.get("name"), b.get("input"))
                    inp = b.get("input") or {}
                    if b.get("name") == "Bash": bash[b.get("id")] = str(inp.get("command") or "")
                    if (b.get("name") == "Bash" and inp.get("run_in_background")) or b.get("name") == "Monitor":
                        launch[b.get("id")] = str(inp.get("command") or json.dumps(inp))
        elif typ == "user":
            c = content(r)
            if user_text(r) and not notification(r): pend = {}
            for b in (c if isinstance(c, list) else []):
                if isinstance(b, dict) and b.get("type") == "tool_result":
                    tu = b.get("tool_use_id"); pend.pop(tu, None); rt = result_text(b)
                    # control: the harness's own phrase with its ID. Narrowed from the bare phrase, which a
                    # printed file also carried once (agent-ac987c29af1e3bb2, 2026-10-24: prose, no move)
                    if "moved to the background (ID:" in rt: STATS["moved-raw"] += 1
                    mv = MOVED.search(rt)
                    if tu in launch:
                        STATS["launches"] += 1
                        if b.get("is_error"): STATS["error-dropped"] += 1
                        else:
                            m = BGID.search(rt)
                            if m: STATS["with-task-id"] += 1; bg[m.group(1)] = (tu, launch[tu])
                            else: STATS["no-task-id"] += 1; bg["tu:" + str(tu)] = (tu, launch[tu])
                        del launch[tu]
                    elif mv and tu in bash and not b.get("is_error"):
                        STATS["launches"] += 1; STATS["moved"] += 1; STATS["with-task-id"] += 1
                        bg[mv.group(1)] = (tu, bash[tu])
    return out

def resolve(prog, gaps):
    """open-tool:bash -> open-tool:poll|other; parked-bg -> parked-bg:poll (any outstanding launch the
    hook calls a poll) or parked-bg:other. One jq for all commands."""
    idx = [i for i, x in enumerate(gaps) if x[1] in ("open-tool:bash", "parked-bg")]
    flat = [c for i in idx for c in gaps[i][3]]
    ans = iter(is_poll(prog, flat))
    for i in idx:
        g = gaps[i]; p = any([next(ans) for _ in g[3]])
        base = "open-tool" if g[1] == "open-tool:bash" else "parked-bg"
        gaps[i] = (g[0], base + (":poll" if p else ":other"), g[2], g[3], g[4])
    return gaps

def probe(prog):
    d = tempfile.mkdtemp(prefix="gapclass-probe-")
    T = lambda s: "2026-01-01T%02d:%02d:%02d.000Z" % (s // 3600, (s // 60) % 60, s % 60)
    A = lambda s, c=None: dict(type="assistant", timestamp=T(s), message=dict(role="assistant", content=c or [dict(type="text", text="x")]))
    U = lambda s, c: dict(type="user", timestamp=T(s), message=dict(role="user", content=c))
    tu = lambda i, cmd: [dict(type="tool_use", id=i, name="Bash", input=dict(command=cmd))]
    tr = lambda i: [dict(type="tool_result", tool_use_id=i, content="ok")]
    bgu = lambda i, cmd: [dict(type="tool_use", id=i, name="Bash", input=dict(command=cmd, run_in_background=True))]
    bgr = lambda i, x: [dict(type="tool_result", tool_use_id=i, content="Command running in background with ID: %s. Output" % x)]
    recs = [U(0, "go"),
            A(10), U(410, "The coordinator sent a message"),                                  # 400 parked
            A(420), U(920, "[SYSTEM NOTIFICATION] <task-notification>x</task-notification>"),  # 500 own-bg
            A(930, tu("t1", "until test -f /x; do sleep 5; done")), U(1530, tr("t1")),       # 600 poll
            A(1540, tu("t2", "pytest -q")), U(2240, tr("t2")),                                # 700 other tool
            dict(type="api-request", timestamp=T(2250)), A(3050),                             # 800 model
            A(3250),                                                                          # 200: active, not a gap
            dict(type="attachment", timestamp=T(3260)), U(4160, "late"),                      # 900 other
            A(4170, bgu("b1", "until test -f /y; do sleep 5; done")), U(4171, bgr("b1", "bx1")),
            A(4180), U(5180, "The coordinator sent a message"),                               # 1000 parked, bg poll out
            A(5190, bgu("b2", "pytest -q")), U(5191, bgr("b2", "bx2")),
            A(5200), U(6300, "The coordinator sent a message"),                               # 1100 parked, both out
            dict(type="attachment", timestamp=T(6301), attachment=dict(type="queued_command",
                 prompt="<task-notification><task-id>bx1</task-id><status>completed</status></task-notification>")),
            A(6310), U(7510, "The coordinator sent a message"),                               # 1200 parked, bg other out
            U(7511, "[SYSTEM NOTIFICATION] <task-notification><task-id>bx2</task-id></task-notification>"),
            A(7520), U(8820, "The coordinator sent a message"),                               # 1300 parked, none out
            A(8830, bgu("b3", "sleep 60; echo done")), U(8831, [dict(type="tool_result", tool_use_id="b3", content="started")]),
            A(8840), U(10240, "The coordinator sent a message"),                              # 1400 parked, id-less poll out
            dict(type="attachment", timestamp=T(10241), attachment=dict(type="queued_command",
                 prompt="<task-notification><tool-use-id>b3</tool-use-id><status>completed</status></task-notification>")),
            A(10250, tu("t9", "make build")),
            U(10370, [dict(type="tool_result", tool_use_id="t9", content="Command did not complete within its 120s timeout and was moved to the background (ID: mv1). Output")]),
            A(10380), U(11880, "The coordinator sent a message")]                             # 1500 parked, moved build out
    p = os.path.join(d, "agent-probe.jsonl")
    with open(p, "w") as f:
        for r in recs: f.write(json.dumps(r) + "\n")
    got = [(round(g), k) for g, k, _, _, _ in resolve(prog, scan(p, "2025-01-01T00:00:00Z", None))]
    want = [(400, "parked-until-message"), (500, "own-background-wait"), (600, "open-tool:poll"),
            (700, "open-tool:other"), (800, "open-model-request"), (900, "other"),
            (1000, "parked-bg:poll"), (1100, "parked-bg:poll"), (1200, "parked-bg:other"),
            (1300, "parked-until-message"), (1400, "parked-bg:poll"), (1500, "parked-bg:other")]
    if got != want:
        print("probe got  %s\nprobe want %s" % (got, want), file=sys.stderr)
        die2("self-probe FAILED")
    want_s = dict(launches=4, completed=3, moved=1, **{"with-task-id": 3, "no-task-id": 1, "moved-raw": 1})
    if {k: STATS[k] for k in want_s} != want_s:
        die2("self-probe FAILED: launch counts %s, want %s" % (dict(STATS), want_s))
    STATS.clear()
    print("probe synthetic transcript (eight classes, background-launch join incl. id-less and harness-moved launches, 300 s boundary, lifted poll predicate): PASS")

def main(argv):
    hook = os.path.join(REPO, "core", "hooks", "ai-dlc-foreground-budget.sh")
    if "--hook" in argv:
        i = argv.index("--hook"); hook = argv[i + 1]; del argv[i:i + 2]
    detail = None
    if "--detail" in argv:
        i = argv.index("--detail"); detail = argv[i + 1]; del argv[i:i + 2]
    if not os.path.isfile(hook): die2("no hook at " + hook)
    work = tempfile.mkdtemp(prefix="gapclass-")
    prog = lift(hook, work)
    probe(prog)
    if argv == ["--probe"]: return 0
    if len(argv) != 1: die2("usage: gapclass.py <EXTRACT_OUT> [--hook HOOK] | --probe")
    out = argv[0]
    root = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
    win_start = os.environ.get("EXTRACT_WIN_START") or "2026-09-26T00:35:00Z"
    win_end = os.environ.get("EXTRACT_WIN_END")
    win_end_ts = ts(win_end) if win_end else None
    segs = [json.loads(l) for l in open(os.path.join(out, "segs.jsonl"))]
    sub = [r for r in segs if r.get("kind") == "sub"]
    if not sub: die2("segs.jsonl has no sub rows")
    by_unit = collections.defaultdict(list)
    for r in sub: by_unit[(r["sess"], r["unit"])].append(r)
    files = {}
    for p in glob.glob(root + "/*/subagents/*.jsonl"):
        files[(os.path.basename(os.path.dirname(os.path.dirname(p))), os.path.basename(p)[:-6])] = p
    missing = [k for k in by_unit if k not in files]
    if missing: die2("%d segs unit(s) have no transcript under %s, e.g. %s" % (len(missing), root, missing[0]))
    allg = {}
    for k in by_unit: allg[k] = scan(files[k], win_start, win_end_ts)
    snap = STATS.copy()   # the extra-file check below scans outside the population; its counts are not kept
    extra = [k for k in files if k not in by_unit and k not in allg and scan(files[k], win_start, win_end_ts)]
    STATS.clear(); STATS.update(snap)
    if extra: die2("%d transcript(s) with gaps are absent from segs.jsonl, e.g. %s" % (len(extra), extra[0]))
    flat = [(k, i) for k in allg for i in range(len(allg[k]))]
    keys = [k for k, _ in flat]
    resolved = resolve(prog, [allg[k][i] for k, i in flat])
    allg = collections.defaultdict(list)
    for k, g in zip(keys, resolved): allg[k].append(g)
    bad = 0; tot = collections.defaultdict(lambda: collections.Counter()); amb = 0; det_rows = []
    segtot = collections.Counter()
    for k, rows in by_unit.items():
        want = sum(float(r["gap"]) for r in rows); got = sum(g for g, _, _, _, _ in allg.get(k, []))
        if abs(want - got) > 0.001: bad += 1
        for r in rows:
            if r.get("sprint") is not None: segtot[int(r["sprint"])] += float(r["gap"])
        for g, c, t, _, det in allg.get(k, []):
            sp = {r["sprint"] for r in rows if r.get("first") and r["first"] <= t <= r["last"] and r.get("sprint") is not None}
            if len(sp) != 1:
                amb += 1
                sp = {max(rows, key=lambda r: float(r["gap"]))["sprint"]}
            s = sp.pop()
            if s is not None: tot[int(s)][c] += g
            if detail is not None:
                det_rows.append(dict(unit=k[1], sess=k[0], sprint=s, cls=c, secs=round(g), close_ts=t, **det))
    if bad: die2("%d sub transcript(s) whose gap differs from segs.jsonl: the window or the record rules differ" % bad)
    if detail is not None:
        with open(detail, "w") as f:
            for d in det_rows: f.write(json.dumps(d) + "\n")
    stories = load_stories()
    print("background launches %d: with task id %d (moved by the harness %d), no task id %d, error results %d; "
          "completions joined %d. Control: results carrying \"moved to the background (ID:\" %d = moved %d"
          % (STATS["launches"], STATS["with-task-id"], STATS["moved"], STATS["no-task-id"], STATS["error-dropped"],
             STATS["completed"], STATS["moved-raw"], STATS["moved"]))
    if STATS["moved-raw"] != STATS["moved"]:
        die2("a result says the harness moved a call to the background but no task id was parsed from %d of them"
             % (STATS["moved-raw"] - STATS["moved"]))
    print("units %d, gaps %d, per-unit gap equal to segs.jsonl for all %d; sprint resolved by unit fallback for %d gap(s)"
          % (len(by_unit), len(resolved), len(by_unit), amb))
    print("hours per story")
    print("%-7s %7s %8s " % ("sprint", "stories", "gap") + " ".join("%20s" % c for c in CLASSES) + "  segs-gap")
    for s in sorted(tot):
        if s not in stories: continue
        n = stories[s]; c = tot[s]
        print("s%-6d %7d %8.2f " % (s, n, sum(c.values()) / 3600 / n) + " ".join("%20.2f" % (c[k] / 3600 / n) for k in CLASSES)
              + "  %8.2f" % (segtot[s] / 3600 / n))
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
