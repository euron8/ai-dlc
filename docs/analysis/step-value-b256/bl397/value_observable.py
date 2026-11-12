"""BL-397 value observable: did a dev-side full-collection run catch a failure OUTSIDE the story's targeted set and
was it fixed BEFORE the handoff?

Usage: [GRAPH_REF=ed61de745] python3 value_observable.py <graph-clone> <extract-OUT> [transcript-root]
  <extract-OUT> is extract.py's output dir (units.jsonl, owner.json) for the same window; transcripts are read only.

THE OBSERVABLE, fixed before this script was written (contract FOLD D6, verbatim in substance): a dev-side
full-collection run, recorded in a Dev Agent Record or QA Handoff Evidence block or made by the dev seat, that shows a
failure in a test file OUTSIDE the story's targeted set, fixed BEFORE the handoff. Contrast: s315 story 1.5, whose dev
record ran two pytest files only and never the full server suite (graph docs/reviews/s315/5-qa-report.md:29), and
whose regression surfaced only at gate-2. "The preventive rule works" predicts this observable at some rate; "the step
buys nothing" predicts none. Disclosure: the s322 story files at graph's tip were read before this script existed.

Channel A, the committed record. Each s322 story file at its FIRST gate-2 handoff sha (the go-signal or reviewed-sha in
its first QA report, HANDOFF below), its column-0 `Full-collection run:` line classified by classify():
REPO-WIDE (pytest, no file/node/-k selection), TARGETED (names test files, node ids or -k), COLLECT-ONLY, NON-PYTEST
(a bash harness), or NONE. Printed with the line's failed count.

Channel A2, the committed form of the observable: every s317..s322 story file at GRAPH_REF (and each s322 story at its
handoff sha), the lines that name a test .py file AND a regression word AND a fixed word AND no pre-existing or carried
word (record_catches()). A grammar floor: a catch recorded in other words is missed.

Channel B is blind where the dev's full run writes its counts to an artifact (the s322 footprint-watchdog runs): the
tool result then carries no count, so the run is not counted. Measured on s322: story 1.8's 3-failed proof run was read
back by `cut` of the artifact and is invisible to B, while A2 finds it in the Dev Agent Record.

Channel B, the dev seat's own runs. Every s<N> subagent transcript whose agentType is dev, dev-escalated or
protected-path-editor and whose spawn extract.py charged to implementation or gate-validation[implementation]. In each,
every Bash pytest invocation is classified as above and joined to its tool_result; the result's `N failed` count and its
`FAILED <file>::...` ids are read (ids with the summary cut off count as that many failed). A run whose command
names a mutation (validate-mutation-red, a `-mut-` worktree, `UNFIXED`) is excluded: its failures are the point. The
seat's TARGETED SET, taken AT EACH RUN, is every .py file it edited or wrote before that run (Edit/Write/MultiEdit/
NotebookEdit file_path) plus every file an earlier TARGETED invocation of its own named. A seat FIRES when a
REPO-WIDE run names a FAILED file outside the targeted set at that run, and the seat's LAST REPO-WIDE run no longer
names it with a lower failed count (fixed before the seat handed off). A failure still named in the seat's last REPO-WIDE run
is PERSISTED (pre-existing or carried, never a catch). A drop in the failed count with no FAILED ids is UNNAMED-DROP,
printed for reading and never counted as a fire.

Controls in the same run, BEFORE the corpus (a synthetic transcript under mktemp, scanned by the same scan()):
  fire       out-of-target FAILED in a repo-wide run, gone in a later repo-wide run          -> must FIRE
  near-miss  the failing file is one the seat edited (in the targeted set)                    -> must not fire
  near-miss  the failure persists to the seat's last repo-wide run (pre-existing)            -> must not fire
  fire       the same, fixed by editing the failing file itself (targeted set is per run)      -> must FIRE
  fire       FAILED ids printed with the summary line cut off (`| grep FAILED`)              -> must FIRE
  near-miss  the failing run is a mutation run (`-mut-` worktree)                             -> must not fire
  near-miss  the failure and the fix are seen only in TARGETED runs                          -> must not fire
  classify   s315 story 1.5's shape, `pytest tests/test_a.py tests/test_b.py`, reads TARGETED
Any probe failure exits 3 before the corpus is read. Channel A classifies the line's first backticked span (else the
text before " (", " from " or ", "), so prose on the line cannot change the class. Extent: per sprint, seats, REPO-WIDE runs with a parsed count,
and REPO-WIDE runs with failed > 0 are printed beside every zero.
"""
import glob, json, os, re, subprocess, sys, tempfile

HANDOFF = {   # s322 story -> first gate-2 handoff sha, from docs/reviews/s322/<M>-qa-validation.md (go-signal or reviewed-sha)
    1: "11bb6e80018bfac8a7237b5c70b13d9deab94631", 2: "1f72de258290c0022205a3f95b3bca6627f6319a",
    3: "c6ebe5c96ddd8b3946854b53a81023d0b2d02b96", 4: "7a9c48c209ca8b546f49131a27092e84db61cab1",
    5: "8998f533f6646f80e868186a39db07b0c9a1a94f", 6: "0023c404271cd788c20b73ab685488ebfa4ad60e",
    7: "19e6c380711a2d7c445fb113a63cfb2b5fef6e55", 8: "613d4aa8d32607593157afbd24242d4c11cb56f4"}
DEV_TYPES = {"dev", "dev-escalated", "protected-path-editor"}
GROUP = {"implementation", "gate-validation[implementation]"}
FAILED_RE = re.compile(r"(\d+) failed|failed[ :=]+(\d+)")
FAILED_ID = re.compile(r"FAILED ([^\s:]+\.py)")

# pytest in COMMAND position: `-m pytest`, a bare `pytest ` word, or a watchdog wrapper (`*watchdog.py `), which runs
# pytest with the arguments after its ` -- `. A path that merely contains "pytest" (`head x/pytest-run.txt`,
# `pip install pytest==9.1.1`) is not an invocation.
INVOKED = re.compile(r"-m\s+pytest\b|(^|[;&|(\s])pytest\s|watchdog\.py\s")

def classify(cmd):
    if not INVOKED.search(cmd): return "NON-PYTEST"
    if re.search(r"--collect-only|(^|\s)--co(\s|$)", cmd): return "COLLECT-ONLY"
    if "watchdog" in cmd and " -- " in cmd: args = cmd.split(" -- ", 1)[1]
    else:
        m = re.search(r"(?:-m\s+pytest|\bpytest)(?![-\w.])(.*)", cmd, re.S)
        args = m.group(1) if m else ""
    args = re.split(r"[|;>]|&&", args)[0]
    if re.search(r"\S+\.py\b|::|(^|\s)-k(\s|$)", args): return "TARGETED"
    return "REPO-WIDE"

def failed_of(text):
    m = FAILED_RE.findall(text or "")
    if m: return int(next(x for x in m[-1] if x))
    return 0 if re.search(r"\d+ passed", text or "") else None   # a pytest summary with no failed token is 0 failed

def tool_text(c):
    x = c.get("content")
    if isinstance(x, list): x = "\n".join(str(i.get("text", "")) for i in x if isinstance(i, dict))
    return str(x or "")

MUTATION = re.compile(r"validate-mutation-red|mutation|[-_]mut[-_/]|UNFIXED")

def scan(path):
    """-> runs = [(class, failed or None, {FAILED files}, targeted-set snapshot, is_mutation)] in transcript order.
    The targeted set is taken AT EACH RUN: files edited or named by a TARGETED run before it, so a later edit that
    fixes an out-of-target file does not retro-actively make it targeted."""
    pend = {}; runs = []; touched = set()
    for line in open(path, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        c = r.get("message", {}).get("content")
        if not isinstance(c, list): continue
        for x in c:
            if not isinstance(x, dict): continue
            if x.get("type") == "tool_use":
                inp = x.get("input") or {}
                if x.get("name") in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
                    fp = str(inp.get("file_path") or inp.get("notebook_path") or "")
                    if fp.endswith(".py"): touched.add(fp)
                if x.get("name") == "Bash" and INVOKED.search(str(inp.get("command", ""))):
                    cmd = str(inp["command"]); k = classify(cmd)
                    if k == "TARGETED": touched.update(re.findall(r"[\w./-]+\.py\b", cmd.split("pytest", 1)[-1]))
                    pend[x["id"]] = (k, frozenset(touched), bool(MUTATION.search(cmd)))
            elif x.get("type") == "tool_result" and x.get("tool_use_id") in pend:
                t = tool_text(x); k, snap, mut = pend.pop(x["tool_use_id"])
                ids = set(FAILED_ID.findall(t)); n = failed_of(t)
                if n is None and ids: n = len(ids)      # a FAILED list with its summary cut off still failed
                runs.append((k, n, ids, snap, mut))
    return runs

def outside(f, touched):
    return not any(t.endswith(f) or f.endswith(t.lstrip("./")) or os.path.basename(t) == os.path.basename(f) for t in touched)

def judge(runs):
    """FIRE: a REPO-WIDE non-mutation run names FAILED file f outside the targeted set at that run, and the seat's LAST
    REPO-WIDE non-mutation run has a lower failed count and does not name f. PERSISTED: f is named in that last run or
    there is no later run. UNNAMED-DROP: failed > 0 with no ids, and a later run's count is lower."""
    rw = [r for r in runs if r[0] == "REPO-WIDE" and r[1] is not None and not r[4]]
    fires = []; persisted = set(); unnamed = False
    for i, (k, n, fs, snap, mut) in enumerate(rw):
        later = rw[i + 1:]
        for f in fs:
            if not outside(f, snap): continue
            if later and f not in later[-1][2] and later[-1][1] < n: fires.append(f)
            elif not later or f in later[-1][2]: persisted.add(f)
        if n and not fs and any(l[1] < n for l in later): unnamed = True
    return sorted(set(fires)), sorted(persisted), unnamed, rw

CATCH_TEST = re.compile(r"[\w/.-]+\.py\b")
CATCH_REG = re.compile(r"REGRESSION|regress|broken by (the|this) (story|change)|broke ", re.I)
CATCH_FIX = re.compile(r"\bFIXED\b|fixed in|fixed by")
CATCH_NOT = re.compile(r"PRE-EXISTING|pre-existing|identically at base|carry-over|carried")

def record_catches(text):
    """Channel A2: (line no, line) of record lines naming a test .py file, a regression word and a fixed word, and no
    pre-existing or carried word: the committed form of the observable."""
    return [(i, l) for i, l in enumerate(text.split("\n"), 1)
            if CATCH_TEST.search(l) and CATCH_REG.search(l) and CATCH_FIX.search(l) and not CATCH_NOT.search(l)]

def probe():
    d = tempfile.mkdtemp(prefix="bl397-probe-")
    def tr(name, events):
        p = os.path.join(d, name); recs = []
        for i, (kind, a, b) in enumerate(events):
            tid = f"t{i}"
            if kind == "edit": recs.append({"message": {"content": [{"type": "tool_use", "id": tid, "name": "Edit", "input": {"file_path": a}}]}})
            else:
                recs.append({"message": {"content": [{"type": "tool_use", "id": tid, "name": "Bash", "input": {"command": a}}]}})
                recs.append({"message": {"content": [{"type": "tool_result", "tool_use_id": tid, "content": b}]}})
        open(p, "w").write("\n".join(json.dumps(r) for r in recs) + "\n"); return p
    fail_b = "FAILED tests/test_b.py::test_x - AssertionError\n== 1 failed, 10 passed in 1s =="
    ok = "== 11 passed in 1s =="
    cases = [
        ("fire", True, [("edit", "src/a.py", ""), ("edit", "tests/test_a.py", ""), ("run", "python -m pytest tests -q", fail_b),
                        ("edit", "src/a.py", ""), ("run", "python -m pytest tests -q", ok)]),
        ("near-miss targeted-set", False, [("edit", "tests/test_b.py", ""), ("run", "python -m pytest tests -q", fail_b),
                                           ("run", "python -m pytest tests -q", ok)]),
        ("near-miss persisted", False, [("edit", "tests/test_a.py", ""), ("run", "python -m pytest tests -q", fail_b),
                                        ("run", "python -m pytest tests -q", fail_b)]),
        ("fire fixed-by-editing-it", True, [("edit", "tests/test_a.py", ""), ("run", "python -m pytest tests -q", fail_b),
                                            ("edit", "tests/test_b.py", ""), ("run", "python -m pytest tests -q", ok)]),
        ("fire ids-without-summary", True, [("edit", "tests/test_a.py", ""), ("run", "python -m pytest tests -q | grep FAILED", "FAILED tests/test_b.py::test_x"),
                                            ("run", "python -m pytest tests -q", ok)]),
        ("near-miss mutation-run", False, [("edit", "tests/test_a.py", ""), ("run", "cd /w-mut-1 && python -m pytest tests -q", fail_b),
                                           ("run", "python -m pytest tests -q", ok)]),
        ("near-miss targeted-runs-only", False, [("run", "python -m pytest tests/test_c.py tests/test_d.py -q", fail_b),
                                                 ("run", "python -m pytest tests/test_c.py tests/test_d.py -q", ok)]),
    ]
    bad = 0
    for name, want, ev in cases:
        fires = judge(scan(tr(name.replace(" ", "_") + ".jsonl", ev)))[0]
        got = bool(fires); bad += got != want
        print(f"  probe {name}: fires {fires} -> {'ok' if got == want else 'PROBE-FAILED'}")
    for name, want, line in (
            ("A2 fire", True, "- `tests/test_b.py::test_x`: STORY-REGRESSION, FIXED in `abc1234`. Passed at base, failed at head."),
            ("A2 near-miss pre-existing", False, "- `tests/test_b.py::test_x`: PRE-EXISTING (fails identically at base)."),
            ("A2 near-miss carried", False, "- `tests/test_b.py::test_x` regression, carried as a carry-over, not fixed here (FIXED later)."),
            ("A2 near-miss no test file", False, "Rework: the regression was FIXED in the hook.")):
        got = bool(record_catches(line)); bad += got != want
        print(f"  probe {name}: {got} -> {'ok' if got == want else 'PROBE-FAILED'}")
    k = classify("head -12 test-results/s322-1-7-canonical-n8.txt; pip install pytest==9.1.1")
    bad += k != "NON-PYTEST"; print(f"  probe classify a pytest path that is not an invocation: {k}")
    k = classify(".venv/bin/python -m pytest tests/test_a.py tests/test_b.py -q")
    bad += k != "TARGETED"; print(f"  probe classify s315 shape: {k}")
    k = classify("python3 scripts/pytest-footprint-watchdog.py --cwd /w --python /w/.venv-ci/bin/python --artifact a.txt -- rebalancer/tests -q -n 8")
    bad += k != "REPO-WIDE"; print(f"  probe classify watchdog repo-wide: {k}")
    return bad

if __name__ == "__main__":
    G, OUT = sys.argv[1], sys.argv[2]
    REF = os.environ.get("GRAPH_REF", "ed61de745")
    ROOT = sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
    print("probes (synthetic transcripts under mktemp, same scan/judge as the corpus):")
    if probe(): print("PROBE FAILED, corpus not read"); sys.exit(3)
    print("== channel A: s322 handoff record at each story's first gate-2 handoff sha")
    stories = subprocess.run(["git", "-C", G, "ls-tree", "--name-only", REF, "_bmad-output/planning-artifacts/s322/stories/"],
                             capture_output=True, text=True).stdout.split()
    for p in sorted(stories):
        m = int(re.search(r"story-1-(\d+)-", p).group(1))
        t = subprocess.run(["git", "-C", G, "show", f"{HANDOFF[m]}:{p}"], capture_output=True, text=True).stdout
        ls = [l for l in t.split("\n") if re.match(r"^(- )?Full-collection run:", l)]
        line = ls[-1] if ls else ""
        bt = re.findall(r"`([^`]+)`", line)
        inv = bt[0] if bt else re.split(r" \(| from |, ", line.split(":", 1)[-1])[0] if ls else ""
        k = "NONE" if not ls else classify(inv)
        print(f"  story 1.{m} @ {HANDOFF[m][:9]}: {k}, failed {failed_of(line)}; {len(ls)} Full-collection line(s); "
              f"A2 catch lines at handoff {[i for i, _ in record_catches(t)]}")
    print(f"== channel A2: story files at {REF}, lines recording a regression in a named test file, fixed")
    for n in (317, 318, 319, 320, 321, 322):
        fs = [p for p in subprocess.run(["git", "-C", G, "ls-tree", "--name-only", REF, f"_bmad-output/planning-artifacts/s{n}/stories/"],
                                        capture_output=True, text=True).stdout.split() if p.endswith(".md")]
        hits = []
        for p in fs:
            t = subprocess.run(["git", "-C", G, "show", f"{REF}:{p}"], capture_output=True, text=True).stdout
            hits += [(os.path.basename(p)[:40], i, l[:160]) for i, l in record_catches(t)]
        print(f"  s{n}: story files {len(fs)}, catch lines {len(hits)}")
        for h in hits: print(f"     {h[0]}:{h[1]}: {h[2]}")
    print("== channel B: dev-seat transcripts, spawns charged to implementation or gate-validation[implementation]")
    owner = json.load(open(os.path.join(OUT, "owner.json")))
    seats = {}
    for l in open(os.path.join(OUT, "units.jsonl")):
        u = json.loads(l); mt = u.get("meta") or {}
        if u["kind"] != "sub" or mt.get("agentType") not in DEV_TYPES: continue
        o = owner.get(mt.get("toolUseId"))
        if not o or o[1] not in GROUP: continue
        p = os.path.join(ROOT, u["sess"], "subagents", u["unit"] + ".jsonl")
        if os.path.exists(p): seats.setdefault(u["sprint"], []).append((p, mt.get("description", "")))
    for n in sorted(seats):
        nrw = nfail = 0; F = []; P = []; U = []
        for p, desc in seats[n]:
            fires, pers, unnamed, rw = judge(scan(p))
            nrw += len(rw); nfail += sum(1 for r in rw if r[1])
            seq = " -> ".join(f"{r[1]}" for r in rw)
            if fires: F.append((desc, fires + [f"repo-wide failed counts {seq}"]))
            elif any(r[1] for r in rw): P.append((desc, sorted(pers) + [f"persisted out-of-target {len(pers)}; repo-wide failed counts {seq}"]))
            if unnamed: U.append(desc)
        print(f"  s{n}: dev seats {len(seats[n])}, REPO-WIDE runs with a parsed count {nrw}, of them failed>0 {nfail}; "
              f"FIRES {len(F)}, seats with failed>0 and no fire {len(P)}, UNNAMED-DROP seats {len(U)}")
        for desc, f in F: print(f"     FIRE  {desc[:60]}: {f[:4]}")
        for desc, f in P: print(f"     NO-FIRE  {desc[:60]}: {f[-5:]}")
        for desc in U: print(f"     UNNAMED-DROP  {desc[:60]}")
