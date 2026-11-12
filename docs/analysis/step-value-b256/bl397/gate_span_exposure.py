"""BL-397 / BL-1003: does an unclosed gate move the implementation plus gate-validation[implementation] group?

Usage: EXTRACT_WIN_END=<iso> python3 gate_span_exposure.py [transcript-root [extract-OUT]]
       (root defaults to ~/.claude/projects/-Users-n8-git-graph, read only)

Counts both LEAD SPAWNS and LEAD RECORDS (assistant messages with usage, one per message id, with their tokens) in a
leak state, since the group sums lead hours and tokens by label as well as spawns. With extract-OUT, the positive
control is also counted over owner.json, which adds spawns made by subagents (BL-1003's 61 is over that set).

BL-1003: extract.py ends a gate span only on `gate-checkpoint.sh ... close`, so a gate left open keeps its label
gate-validation[X] while a whole read of another step file moves `main` to Y != X. Every spawn the lead makes in that
state is a LEAK: labelled gate-validation[X], belonging to Y. This script replays extract.py's own lead state machine
(gate_event, strip_heredocs, STEP_RE, SUBPROC, EDGES and sprint_of are loaded from extract.py's source by ast, never
restated or edited) over every lead transcript and records, for each lead Agent/Task spawn, (label, main).

Two leaks move THIS group (a leak inside it, X = Y = implementation, is not a leak, and implementation work labelled
gate-validation[implementation] moves nothing because the group sums both labels):
  OUT  label gate-validation[implementation], main != implementation: another step's spawn inflates the group;
  IN   main == implementation, label gate-validation[X] with X != implementation: the group is deflated.
Every other (label, main) leak pair is printed too, as the sprint's whole exposure.

Controls in the same run:
  positive  s322 must show the BL-1003 leak: label gate-validation[carry-over-evaluation] with main requirements
            (BL-1003 measured 61 such spawns, 14:00Z..19:08Z). Zero exits 3.
  extent    per sprint, the count of lead spawns labelled implementation and gate-validation[implementation], so a zero
            leak sits beside a non-zero population.
"""
import ast, collections, glob, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXT = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")
ns = {"re": __import__("re"), "os": os, "dt": __import__("datetime")}
WANT = {"STEP_RE", "SUBPROC", "EDGES", "ts", "sprint_of", "strip_heredocs", "gate_event"}
for node in ast.parse(open(EXT).read()).body:
    names = {getattr(t, "id", None) for t in getattr(node, "targets", [])} | {getattr(node, "name", None)}
    if names & WANT:
        exec(compile(ast.Module([node], []), EXT, "exec"), ns)
missing = WANT - set(ns)
if missing: print("extract.py lacks", sorted(missing)); sys.exit(2)
ns["WIN_START"] = os.environ.get("EXTRACT_WIN_START") or "2026-09-26T00:35:00Z"   # extract.py's default
WIN_END = os.environ.get("EXTRACT_WIN_END")
WIN_END_TS = ns["ts"](WIN_END) if WIN_END else None
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
STEP_RE, SUBPROC, gate_event, sprint_of = ns["STEP_RE"], ns["SUBPROC"], ns["gate_event"], ns["sprint_of"]

pairs = collections.Counter(); ext = collections.Counter(); span = {}
recs = collections.Counter(); rtok = collections.Counter()   # LEAD records (with usage) in a leak state, and their tokens
files = sorted(glob.glob(os.path.join(ROOT, "*.jsonl")))
earliest = None
for p in files:
    step = main = "pre-step"; gate = None; whole = set(); seen = set()
    for line in open(p, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t: continue
        earliest = t if earliest is None or t < earliest else earliest
        if t < ns["WIN_START"] or (WIN_END_TS is not None and ns["ts"](t) > WIN_END_TS): continue
        if r.get("type") != "assistant": continue
        mid = (r.get("message") or {}).get("id")
        if (r.get("message") or {}).get("usage") and mid not in seen and step.startswith("gate-validation[") and step[16:-1] != main:
            seen.add(mid)   # one count per message id, as extract.py keys usage
            u = r["message"]["usage"]
            k = (sprint_of(t), step, main); recs[k] += 1
            rtok[k] += sum(int(u.get(x) or 0) for x in ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
        for c in (r.get("message") or {}).get("content") or []:
            if not isinstance(c, dict) or c.get("type") != "tool_use": continue
            inp = json.dumps(c.get("input", {}))
            if c.get("name") in ("Agent", "Task"):
                n = sprint_of(t)
                if step in ("implementation", "gate-validation[implementation]"): ext[(n, step)] += 1
                if step.startswith("gate-validation[") and step[16:-1] != main:
                    k = (n, step, main); pairs[k] += 1
                    a, b = span.get(k, (t, t)); span[k] = (min(a, t), max(b, t))
            if c.get("name") == "Bash":
                ev = gate_event(str((c.get("input") or {}).get("command") or ""))
                if ev == "open": gate = "gate-validation[" + main + "]"; step = gate
                elif ev == "close": gate = None; step = main
            mm = STEP_RE.search(inp)
            if mm and c.get("name") == "Read":
                name = mm.group(1)
                isslice = "offset" in c.get("input", {}) or "limit" in c.get("input", {})
                sliced = isslice and name in whole
                if not isslice: whole.add(name)
                if name not in SUBPROC and not sliced:
                    if name == "gate-validation": step = gate or "gate-validation[" + main + "]"
                    else:
                        main = name
                        if gate is None: step = name

print(f"lead transcripts {len(files)} under {ROOT}; earliest record {earliest}; WIN_END {WIN_END}")
for n in sorted({k[0] for k in ext} | {k[0] for k in pairs}, key=lambda x: (x is None, x)):
    if n is None or n < 317: continue
    print(f"s{n}: lead spawns labelled implementation {ext[(n, 'implementation')]}, gate-validation[implementation] "
          f"{ext[(n, 'gate-validation[implementation]')]}")
    out = sum(v for (m, s, mn), v in pairs.items() if m == n and s == "gate-validation[implementation]")
    inn = sum(v for (m, s, mn), v in pairs.items() if m == n and mn == "implementation" and s != "gate-validation[implementation]")
    ro = sum(v for (m, s, mn), v in recs.items() if m == n and s == "gate-validation[implementation]")
    ri = sum(v for (m, s, mn), v in recs.items() if m == n and mn == "implementation" and s != "gate-validation[implementation]")
    print(f"   OUT leak {out} spawns, {ro} lead records; IN leak {inn} spawns, {ri} lead records")
    for (m, s, mn), v in sorted(pairs.items(), key=lambda kv: str(kv[0])):
        if m == n: print(f"   leak: label {s}, main {mn}: {v} lead spawns, {span[(m, s, mn)][0][:19]}..{span[(m, s, mn)][1][:19]}")
    for (m, s, mn), v in sorted(recs.items(), key=lambda kv: str(kv[0])):
        if m == n: print(f"   leak: label {s}, main {mn}: {v} lead records, {rtok[(m, s, mn)]/1e6:.1f}M lead tokens")
pos = pairs[(322, "gate-validation[carry-over-evaluation]", "requirements")]
print(f"positive control s322 label gate-validation[carry-over-evaluation] main requirements: {pos} lead spawns")
if len(sys.argv) > 2:
    # BL-1003 counted 61 over spawns.jsonl, whose owner rows include spawns made BY subagents (depth 2), resolved to the
    # step their parent was spawned under. owner.json is that set; count it over the same leak window.
    k = (322, "gate-validation[carry-over-evaluation]", "requirements")
    if k in span:
        a, b = span[k]
        own = json.load(open(os.path.join(sys.argv[2], "owner.json")))
        allsp = sum(1 for _, st, t in own.values() if st == k[1] and a <= t <= b)
        print(f"   same window in {os.path.basename(os.path.normpath(sys.argv[2]))}/owner.json (lead AND subagent-made spawns): {allsp}")
sys.exit(0 if pos else 3)
