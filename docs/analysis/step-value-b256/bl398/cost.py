"""BL-398 cost side: stories-test-strategy per story, s322 against s314+s315 (b244 pin) and s321 (re-extracted).

usage: python3 -I cost.py OUT OUT_ALT SNAPSHOT_DIR GRAPH_CLONE [GRAPH_REF]

  OUT           an extract.py + analyze.py output dir (EXTRACT_WIN_END=2026-11-12T10:00:00Z)
  OUT_ALT       the same at a second window end (2026-11-12T09:00:00Z); its s321/s322 step rows must match OUT's
  SNAPSHOT_DIR  docs/analysis/pipeline-efficiency-s317-s320/b244-snapshot (its steps.csv holds s314 and s315)
  GRAPH_CLONE   a clone of graph (read only); story counts are derived from it at GRAPH_REF (default ed61de745)

Reuses roll.py's seat_sum/seat_line/usd/hosted_mix (loaded from the extractor directory, not restated) and
extract.py's gate_event/strip_heredocs/STEP_RE (loaded by ast, as roll.py loads analyze.py). Prints:
  1. story counts per sprint (story-<N>-<M>: keys, and `status: done` under each), with the naive count beside
  2. the seat-split per-story row for each population, plus the sonnet..opus token-equivalent bracket
  3. the decision rule, applied
  4. the s322 subagent spend of the step split by round (party / elicitation / stories adversarial / TS ladder)
  5. BL-1003 exposure: s322 spawns whose gate label and the lead's current step disagree, with a positive control
"""
import ast, collections, contextlib, csv, glob, importlib.util, io, json, os, re, subprocess, sys
sys.dont_write_bytecode = True   # loading roll.py must not leave a __pycache__ beside the extractor

HERE = os.path.dirname(os.path.abspath(__file__))
XDIR = os.path.normpath(os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts"))
OUT, OUT_ALT, SNAP, GRAPH = sys.argv[1:5]
GREF = sys.argv[5] if len(sys.argv) > 5 else "ed61de745"
STEP = "stories-test-strategy"
GATE = "gate-validation[" + STEP + "]"

spec = importlib.util.spec_from_file_location("roll", os.path.join(XDIR, "roll.py"))
roll = importlib.util.module_from_spec(spec); spec.loader.exec_module(roll)

def extract_defs():
    p = os.path.join(XDIR, "extract.py"); tree = ast.parse(open(p).read()); ns = {"re": re, "os": os}
    exec("import datetime as dt, json", ns)
    want = {"strip_heredocs", "gate_event", "ts", "sprint_of"}
    for n in tree.body:
        if isinstance(n, ast.FunctionDef) and n.name in want or \
           isinstance(n, ast.Assign) and any(getattr(t, "id", None) in ("STEP_RE", "SUBPROC", "EDGES") for t in n.targets):
            exec(compile(ast.Module([n], []), p, "exec"), ns)
    ns["WIN_START"] = "2026-09-26T00:35:00Z"
    return ns
X = extract_defs()

# ---------------------------------------------------------------- 1. story counts
def git_show(path):
    r = subprocess.run(["git", "-C", GRAPH, "show", f"{GREF}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None
def story_count(path):
    t = git_show(path)
    if t is None: return None
    keys = done = 0; cur = False
    for ln in t.splitlines():
        if re.match(r"^\s+story-\d+-\d+:\s*$", ln): keys += 1; cur = True; continue
        if cur and re.match(r"^\s+status:\s*done\b", ln): done += 1; cur = False
        elif re.match(r"^\s{0,2}\S", ln): cur = False
    naive = sum(1 for ln in t.splitlines() if "story-" in ln)
    return keys, done, naive
IA = "_bmad-output/implementation-artifacts/"
SC = {314: IA + "s314/sprint-status.yaml", 315: IA + "s315/sprint-status.yaml",
      321: IA + "s321/sprint-status.yaml", 322: IA + "sprint-status.yaml"}
print(f"== 1. story counts, graph {GREF} (keys `story-<N>-<M>:`, done = `status: done` under the key; naive = lines naming `story-`)")
N = {}; DONE = {}
for n, p in SC.items():
    k, d, nv = story_count(p)
    N[n] = k; DONE[n] = d
    print(f"   s{n}: keys {k}, done {d}, naive {nv}  ({p})")
assert roll.STORIES[321] == N[321] and roll.STORIES[322] == N[322], "roll.py STORIES disagrees with graph"
roll.STORIES[314] = N[314]; roll.STORIES[315] = N[315]

# ---------------------------------------------------------------- 2. seat rows
def rows_of(d): return list(csv.DictReader(open(os.path.join(d, "steps.csv"))))
R_SNAP, R_OUT, R_ALT = rows_of(SNAP), rows_of(OUT), rows_of(OUT_ALT)
def bracket(rows, steps, sprints):
    lo = hi = 0.0
    for r in rows:
        if r["bucket"] != "pipeline" or int(r["sprint"]) not in sprints: continue
        if roll.step_base(r["step"]) not in steps: continue
        for seat in ("lead", "sub"):
            lo += roll.usd(r, seat, True, {"sonnet": 1.0}); hi += roll.usd(r, seat, True, {"opus": 1.0})
    return lo, hi
def figures(rows, steps, sprints):
    HM = {s: roll.hosted_mix(rows, s) for s in ("lead", "sub")}
    T = roll.seat_sum(rows, HM, "pipeline", steps, set(sprints)); sn = sum(roll.STORIES[n] for n in sprints)
    lo, hi = bracket(rows, steps, set(sprints))
    return dict(T=T, sn=sn, te=(T["lead$e"] + T["sub$e"]) / sn, api=(T["lead$"] + T["sub$"]) / sn,
                tok=(T["leadtok"] + T["subtok"]) / sn / 1e6, lo=lo / sn, hi=hi / sn, line=roll.seat_line(T, sn))
POP = [("before s314+s315 pooled (b244 snapshot)", R_SNAP, (314, 315)), ("s321 (re-extracted)", R_OUT, (321,)),
       ("s322", R_OUT, (322,))]
print(f"\n== 2. per story, {STEP} (roll.py seat_sum; token-equivalent bracket = every local call at sonnet .. at opus)")
F = {}
for label, rows, sp in POP:
    f = figures(rows, {STEP}, sp); F[sp] = f
    fb = " FALLBACK " + ", ".join(f"s{n}->s{roll.FALLBACK[n]}" for n in sp if n in roll.FALLBACK) if any(n in roll.FALLBACK for n in sp) else ""
    print(f"   {label} ({f['sn']} stories): {f['line']}")
    print(f"      bracket ${f['lo']:.2f} .. ${f['hi']:.2f}; token-equivalent ${f['te']:.2f}, API ${f['api']:.2f}, {f['tok']:.1f}M tokens{fb}")
    dn = sum(DONE[n] for n in sp)
    if dn != f["sn"]:
        print(f"      per DONE story ({dn}): token-equivalent ${f['te'] * f['sn'] / dn:.2f}, {f['tok'] * f['sn'] / dn:.1f}M tokens")
for n in (314, 315):   # BL-927 item a1 moved party seats out of pre-step; bound what the old pin could have parked there
    ps = sum(roll.usd(r, "sub") for r in R_SNAP if r["bucket"] == "pipeline" and int(r["sprint"]) == n and r["step"] == "pre-step")
    print(f"   b244 s{n} pre-step subagent spend (an upper bound on what the pre-BL-927 extractor could have left out of the before): ${ps:.2f}")
for label, rows, sp in POP[1:]:
    g = figures(rows, {"gate[" + STEP + "]"}, sp)
    print(f"   neighbour {GATE}, {label}: {g['line']}")
# control: the s321 and s322 lines are byte-identical to roll.py --seats on OUT
buf = io.StringIO()
with contextlib.redirect_stdout(buf): roll.seats(R_OUT)
seats_txt = buf.getvalue()
for sp in ((321,), (322,)):
    want = f"   s{sp[0]} pipeline {STEP} ({roll.STORIES[sp[0]]} stories): {F[sp]['line']}"
    print(f"   control: s{sp[0]} line found verbatim in roll.py --seats output: {want in seats_txt.splitlines()}")
# control: window ends agree on the s321/s322 rows of this step and its gate
def step_rows(rows):
    return sorted(tuple(sorted(r.items())) for r in rows if r["bucket"] == "pipeline" and int(r["sprint"]) in (321, 322)
                  and roll.step_base(r["step"]) in (STEP, "gate[" + STEP + "]"))
a, b = step_rows(R_OUT), step_rows(R_ALT)
print(f"   control: {len(a)} s321/s322 rows of the step and its gate at OUT, {len(b)} at OUT_ALT, identical: {a == b}")
print(f"   control: an absent step reads {figures(R_OUT, {'no-such-step'}, (322,))['tok']:.1f}M tokens")
B251_END = "2026-11-06T03:23:00Z"   # the EXTRACT_WIN_END BL-398's batch-251 s321 row was taken at
late = collections.defaultdict(float)
for l in open(os.path.join(OUT, "segs.jsonl")):
    s = json.loads(l)
    if s["kind"] == "lead" and s["sprint"] == 322 and s["step"] in (STEP, GATE):
        print(f"   s322 lead segment {s['sess'][:8]} {s['step']}: {s['first'][:19]}Z .. {s['last'][:19]}Z")
    if s["kind"] == "lead" and s["sprint"] == 321 and s["step"] == STEP and s["last"] > B251_END:
        late["n"] += 1
        print(f"   s321 lead segment with records after {B251_END} (the b251 window end): {s['sess'][:8]} {s['first'][:19]}Z .. {s['last'][:19]}Z")
OB = os.environ.get("BL398_OUT_B251")   # the same extractor at EXTRACT_WIN_END=B251_END, to attribute the drift
if OB and os.path.exists(os.path.join(OB, "steps.csv")):
    fb_ = figures(rows_of(OB), {STEP}, (321,))
    print(f"   s321 at EXTRACT_WIN_END={B251_END} (this extractor): {fb_['line']}")
    print(f"   s321 drift = records after {B251_END} in {late['n']:.0f} lead segment(s): token-equivalent "
          f"${F[(321,)]['te'] - fb_['te']:+.2f}, tokens {F[(321,)]['tok'] - fb_['tok']:+.2f}M, gap-inclusive "
          f"{(F[(321,)]['T']['el'] - fb_['T']['el']) / N[321]:+.3f} h, subagent ${(F[(321,)]['T']['sub$e'] - fb_['T']['sub$e']) / N[321]:+.2f} per story")
# sensitivity divisor: the stories the step's rounds reviewed (the stories pass-1 shard ordinal map), not the sprint's keys
smap = git_show("_bmad-output/planning-artifacts/s322/stories-adversarial-p1.md") or ""
m = re.search(r"## Shard ordinal map\s*```text\n(.*?)```", smap, re.S)
NR = len([x for x in (m.group(1).splitlines() if m else []) if re.match(r"^\d+\t", x)])
if NR:
    T2 = F[(322,)]["T"]
    print(f"   s322 sensitivity, divided by the {NR} stories the rounds reviewed (shard ordinal map) instead of {N[322]} keys: "
          f"token-equivalent ${(T2['lead$e'] + T2['sub$e']) / NR:.2f}, {(T2['leadtok'] + T2['subtok']) / NR / 1e6:.1f}M tokens")

# ---------------------------------------------------------------- 3. rule
B, S1, S2 = F[(314, 315)], F[(321,)], F[(322,)]
print("\n== 3. rule (fixed before reading): FELL iff s322 per story < before AND < s321 on token-equivalent AND tokens")
te_ok = S2["te"] < B["te"] and S2["te"] < S1["te"]; tk_ok = S2["tok"] < B["tok"] and S2["tok"] < S1["tok"]
print(f"   token-equivalent: s322 ${S2['te']:.2f} vs before ${B['te']:.2f}, s321 ${S1['te']:.2f} -> below both: {te_ok}")
print(f"   bracket check: s322 ${S2['lo']:.2f}..${S2['hi']:.2f} vs before ${B['lo']:.2f}..${B['hi']:.2f}, s321 ${S1['lo']:.2f}..${S1['hi']:.2f}")
print(f"   tokens: s322 {S2['tok']:.1f}M vs before {B['tok']:.1f}M, s321 {S1['tok']:.1f}M -> below both: {tk_ok}")
print(f"   READING: {'FELL' if te_ok and tk_ok else 'DID NOT FALL'}")

# ---------------------------------------------------------------- 4. s322 subagent split by round
units = [json.loads(l) for l in open(os.path.join(OUT, "units.jsonl"))]
owner = json.load(open(os.path.join(OUT, "owner.json")))
bucket = {}
for u in units:
    if u["kind"] == "lead":
        bucket[u["sess"]] = "pipeline" if any(k.split("|", 1)[0] != "pre-step" for k in u["tok"]) else "x"
sub_step = {}; meta = {}
for u in units:
    if u["kind"] != "sub": continue
    o = owner.get((u["meta"] or {}).get("toolUseId")); sub_step[u["unit"]] = o[1] if o else "unjoined"
    meta[u["unit"]] = (u["meta"] or {}, o)
HM_OUT = {s: roll.hosted_mix(R_OUT, s) for s in ("lead", "sub")}
def seg_cost(s, n):
    r = collections.defaultdict(float)
    for m, d in (s.get("tok") or {}).items():
        f = roll_fam(m)
        r[f"sub_{f}_in"] += d[0]; r[f"sub_{f}_cw"] += d[1]; r[f"sub_{f}_cr"] += d[2]; r[f"sub_{f}_out"] += d[3]; r[f"sub_{f}_calls"] += d[4]
    mix = HM_OUT["sub"][n]
    if sum(mix.values()) <= 0 and n in roll.FALLBACK: mix = HM_OUT["sub"][roll.FALLBACK[n]]
    api = roll.usd(r, "sub"); te = roll.usd(r, "sub", True, mix)
    return api, (api if te is None else te), sum(sum(d[:4]) for d in (s.get("tok") or {}).values())
RELABEL, roll_fam = roll.analyze_defs()
per = collections.defaultdict(lambda: [0.0, 0.0, 0.0, 0.0])   # unit -> api, te, tok, active s
for l in open(os.path.join(OUT, "segs.jsonl")):
    s = json.loads(l)
    if s["kind"] != "sub" or s["sprint"] != 322 or bucket.get(s["sess"]) != "pipeline": continue
    if sub_step.get(s["unit"]) != STEP: continue
    a, t, k = seg_cost(s, 322); P = per[s["unit"]]; P[0] += a; P[1] += t; P[2] += k; P[3] += s["active"]
OPEN = [("party", re.compile(r"(?i)round-dispatcher .*party|\bseat\b")),
        ("elicitation", re.compile(r"(?i)^elicitation (cross )?shard")),
        ("stories adversarial passes and repairs", re.compile(r"(?i)^adversary (shard|cross)")),
        ("test-strategy ladder (TS passes and repairs)", re.compile(r"(?i)^TS p\d"))]
# A description naming ANOTHER round's distinctive word, inside the round it was assigned to, is a disagreement.
DISTINCT = {"party": re.compile(r"(?i)\bseat\b|party"), "elicitation": re.compile(r"(?i)elicit"),
            "stories adversarial passes and repairs": re.compile(r"(?i)^adversary"),
            "test-strategy ladder (TS passes and repairs)": re.compile(r"(?i)\bTS\b")}
def disagrees(phase, d): return [k for k, rx in DISTINCT.items() if k != phase and rx.search(d)]
probe = disagrees("test-strategy ladder (TS passes and repairs)", "Elicitation shard 9 (story 1.9)"), \
        disagrees("elicitation", "Elicitation repair shard 9")
order = sorted(per, key=lambda u: (meta[u][1][2], meta[u][0].get("description") or ""))
phase = "other (before the first round)"; split = collections.OrderedDict(); disagree = []
for u in order:
    d = meta[u][0].get("description") or ""
    for name, rx in OPEN:
        if rx.search(d): phase = name; break
    if disagrees(phase, d): disagree.append((phase, d))
    S = split.setdefault(phase, [0, 0.0, 0.0, 0.0, 0.0]); S[0] += 1
    for i in range(4): S[i + 1] += per[u][i]
tot = [sum(v[i] for v in split.values()) for i in range(5)]
print(f"\n== 4. s322 {STEP} subagent spend by round ({tot[0]} spawns; phase = the round whose first spawn most recently "
      f"preceded it, by owner timestamp)")
for k, v in split.items():
    print(f"   {k}: {v[0]} spawns, token-equivalent ${v[2]:.2f} ({100 * v[2] / tot[2]:.0f}%), API ${v[1]:.2f}, "
          f"{v[3] / 1e6:.1f}M tokens, {v[4] / 3600:.2f} subagent-h")
row = F[(322,)]["T"]
print(f"   control: split total API ${tot[1]:.4f} vs steps.csv row ${row['sub$']:.4f}; token-eq ${tot[2]:.4f} vs ${row['sub$e']:.4f}; "
      f"tokens {tot[3]:.0f} vs {row['subtok']:.0f}; equal: {abs(tot[1] - row['sub$']) < 1e-6 and abs(tot[2] - row['sub$e']) < 1e-6 and abs(tot[3] - row['subtok']) < 1}")
print(f"   control: description/round disagreements {len(disagree)}" + (f": {disagree[:5]}" if disagree else "")
      + f" (self-probe: a seeded 'Elicitation shard 9' in the TS round flags {len(probe[0])}, an elicitation repair in its own round flags {len(probe[1])})")

# ---------------------------------------------------------------- 5. BL-1003 exposure
WIN_END = os.environ.get("EXTRACT_WIN_END", "2026-11-12T10:00:00Z"); WE = X["ts"](WIN_END)
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
SPR5 = (321, 322)
sess5 = {v[0] for v in owner.values() if X["sprint_of"](v[2]) in SPR5}
rec = {}; timeline = collections.defaultdict(list); gate_ev = []
lead_x = collections.defaultdict(lambda: [0, 0, None, None]); seen_mid = set()   # (label, main) -> calls, tokens, first, last
for sess in sorted(sess5):
    p = os.path.join(ROOT, sess + ".jsonl")
    if not os.path.exists(p): continue
    step = main = "pre-step"; gate = None; whole = set()
    for line in open(p, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < X["WIN_START"] or X["ts"](t) > WE: continue
        if r.get("type") != "assistant": continue
        msg = r.get("message") or {}
        if msg.get("usage") and msg.get("id") and msg["id"] not in seen_mid:
            seen_mid.add(msg["id"]); u_ = msg["usage"]
            L = lead_x[(X["sprint_of"](t), step, main)]; L[0] += 1
            L[1] += sum((u_.get(k, 0) or 0) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"))
            L[2] = t if L[2] is None else L[2]; L[3] = t
        for c in msg.get("content") or []:
            if not isinstance(c, dict) or c.get("type") != "tool_use": continue
            if c.get("name") in ("Agent", "Task"): rec[c["id"]] = (sess, step, main, t)
            if c.get("name") == "Bash":
                ev = X["gate_event"](str((c.get("input") or {}).get("command") or ""))
                if ev == "open": gate = "gate-validation[" + main + "]"; step = gate
                elif ev == "close": gate = None; step = main
                if ev: gate_ev.append((t, sess, ev, step))
            mm = X["STEP_RE"].search(json.dumps(c.get("input", {})))
            if mm and c.get("name") == "Read":
                name = mm.group(1)
                isslice = "offset" in c.get("input", {}) or "limit" in c.get("input", {})
                sliced = isslice and name in whole
                if not isslice: whole.add(name)
                if name not in X["SUBPROC"] and not sliced:
                    if name == "gate-validation": step = gate or "gate-validation[" + main + "]"
                    else:
                        main = name
                        if gate is None: step = name
            timeline[sess].append((t, step, main))
agree = sum(1 for k, v in rec.items() if k in owner and owner[k][1] == v[1])
joined = sum(1 for k in rec if k in owner)
print(f"\n== 5. BL-1003 exposure, s321 and s322 (lead re-scan of {len(sess5)} sessions, EXTRACT_WIN_END={WIN_END})")
print(f"   control: re-scan label == owner.json label on {agree} of {joined} lead-recorded spawns")
def main_at(sess, t):
    m = None
    for tt, st, mn in timeline.get(sess, []):
        if tt <= t: m = mn
        else: break
    return m
cross = collections.defaultdict(lambda: [0, 0.0, 0.0, 0, None, None])
unit_tok = {x["unit"]: x["tok"] for x in units if x["kind"] == "sub"}
for u in sorted(unit_tok):
    if u not in meta: continue
    m, o = meta[u]
    if not o or X["sprint_of"](o[2]) not in SPR5: continue
    tid = m.get("toolUseId"); label = o[1]
    mn = rec[tid][2] if tid in rec else main_at(o[0], o[2])
    depth2 = tid not in rec
    if not label.startswith("gate-validation["): continue
    k = (X["sprint_of"](o[2]), label, mn, depth2)
    C = cross[k]; C[0] += 1
    C[4] = o[2] if C[4] is None or o[2] < C[4] else C[4]; C[5] = o[2] if C[5] is None or o[2] > C[5] else C[5]
    for kk, d in unit_tok[u].items():
        f = roll_fam(kk.split("|", 1)[1]); rr = {f"sub_{f}_in": d[0], f"sub_{f}_cw": d[1], f"sub_{f}_cr": d[2], f"sub_{f}_out": d[3]}
        C[1] += roll.usd(rr, "sub")
print("   gate-labelled spawns by (sprint, label, lead's current step at the spawn, depth-2): spawns, API $ (whole unit), first..last")
for k in sorted(cross, key=lambda k: (k[0], k[1], str(k[2]), k[3])):
    C = cross[k]; inner = k[1][len("gate-validation["):-1]
    flag = "" if k[2] == inner else "   <-- CROSSES (label is not the lead's step)"
    print(f"   s{k[0]} {k[1]} | main={k[2]} | depth2={k[3]}: {C[0]} spawns, ${C[1]:.2f}, {C[4][:19]}..{C[5][:19]}{flag}")
pc = sum(C[0] for k, C in cross.items() if k[:3] == (322, "gate-validation[carry-over-evaluation]", "requirements"))
pcd = sum(C[1] for k, C in cross.items() if k[:3] == (322, "gate-validation[carry-over-evaluation]", "requirements"))
print(f"   positive control (BL-1003: 61 spawns, $167.41): gate-validation[carry-over-evaluation] with main=requirements: {pc} spawns, ${pcd:.2f}")
for n in SPR5:
    mine_in = sum(C[0] for k, C in cross.items() if k[0] == n and k[2] == STEP and k[1] != GATE)
    mine_out = sum(C[0] for k, C in cross.items() if k[0] == n and k[1] == GATE and k[2] != STEP)
    print(f"   s{n}: {STEP} work filed under another gate label: {mine_in} spawns; {GATE} holding another step's work: {mine_out} spawns")
print("   lead seat, s321 and s322: usage-bearing messages whose gate label is not the lead's step (label | main: calls, tokens, first..last)")
nx = 0
for (sn, lab, mn), L in sorted(lead_x.items(), key=lambda x: (str(x[0][0]), x[0][1], x[0][2])):
    if sn in SPR5 and lab.startswith("gate-validation[") and lab[len("gate-validation["):-1] != mn:
        nx += 1; print(f"     s{sn} {lab} | main={mn}: {L[0]} calls, {L[1] / 1e6:.1f}M tokens, {L[2][:19]}..{L[3][:19]}")
print(f"   ({nx} crossing lead rows; same-invocation control: lead rows whose label equals the step, {sum(1 for (n_, a, b) in lead_x if a == b and n_ in SPR5)})")
print("   s322 gate events in the lead scan (utc, session, event, label after):")
for t, s, ev, st in gate_ev:
    if X["sprint_of"](t) == 322: print(f"     {t[:19]} {s[:8]} {ev} {st}")
ev321 = collections.Counter(ev for t, s, ev, st in gate_ev if X["sprint_of"](t) == 321)
print(f"   s321 gate events: {dict(ev321)}")
