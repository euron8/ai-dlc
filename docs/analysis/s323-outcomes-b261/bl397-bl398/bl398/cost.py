"""b261 COPY of step-value-b256/bl398/cost.py, retargeted s322 -> s323, sections 1-3 only (4 and 5 are s322-specific).
BL-398 cost side: stories-test-strategy per story, s323 against s314+s315 (b244 pin), s321 (re-extracted) and s322.

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
XDIR = os.path.normpath(os.environ.get("AI_DLC_XDIR") or os.path.join(HERE, "..", "..", "..", "pipeline-efficiency-s317-s320", "scripts"))  # b261: run.sh points it at the af44929cc blobs (roll.py there carries STORIES[323])
OUT, OUT_ALT, SNAP, GRAPH = sys.argv[1:5]
GREF = sys.argv[5] if len(sys.argv) > 5 else "16fd227d9"
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
      321: IA + "s321/sprint-status.yaml", 322: IA + "s322/sprint-status.yaml", 323: IA + "sprint-status.yaml"}
print(f"== 1. story counts, graph {GREF} (keys `story-<N>-<M>:`, done = `status: done` under the key; naive = lines naming `story-`)")
N = {}; DONE = {}
for n, p in SC.items():
    k, d, nv = story_count(p)
    N[n] = k; DONE[n] = d
    print(f"   s{n}: keys {k}, done {d}, naive {nv}  ({p})")
assert roll.STORIES[321] == N[321] and roll.STORIES[322] == N[322] and roll.STORIES[323] == N[323], "roll.py STORIES disagrees with graph"
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
       ("s322", R_OUT, (322,)), ("s323", R_OUT, (323,))]
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
for sp in ((321,), (322,), (323,)):
    want = f"   s{sp[0]} pipeline {STEP} ({roll.STORIES[sp[0]]} stories): {F[sp]['line']}"
    print(f"   control: s{sp[0]} line found verbatim in roll.py --seats output: {want in seats_txt.splitlines()}")
# control: window ends agree on the s321/s322 rows of this step and its gate
def step_rows(rows):
    return sorted(tuple(sorted(r.items())) for r in rows if r["bucket"] == "pipeline" and int(r["sprint"]) in (321, 322, 323)
                  and roll.step_base(r["step"]) in (STEP, "gate[" + STEP + "]"))
a, b = step_rows(R_OUT), step_rows(R_ALT)
print(f"   control: {len(a)} s321/s322 rows of the step and its gate at OUT, {len(b)} at OUT_ALT, identical: {a == b}")
print(f"   control: an absent step reads {figures(R_OUT, {'no-such-step'}, (323,))['tok']:.1f}M tokens")
B251_END = "2026-11-06T03:23:00Z"   # the EXTRACT_WIN_END BL-398's batch-251 s321 row was taken at
late = collections.defaultdict(float)
for l in open(os.path.join(OUT, "segs.jsonl")):
    s = json.loads(l)
    if s["kind"] == "lead" and s["sprint"] == 323 and s["step"] in (STEP, GATE):
        print(f"   s323 lead segment {s['sess'][:8]} {s['step']}: {s['first'][:19]}Z .. {s['last'][:19]}Z")
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
smap = git_show("_bmad-output/planning-artifacts/s323/stories-adversarial-p1.md") or ""
m = re.search(r"## Shard ordinal map\s*```text\n(.*?)```", smap, re.S)
NR = len([x for x in (m.group(1).splitlines() if m else []) if re.match(r"^\d+\t", x)])
if NR:
    T2 = F[(323,)]["T"]
    print(f"   s323 sensitivity, divided by the {NR} stories the rounds reviewed (shard ordinal map) instead of {N[323]} keys: "
          f"token-equivalent ${(T2['lead$e'] + T2['sub$e']) / NR:.2f}, {(T2['leadtok'] + T2['subtok']) / NR / 1e6:.1f}M tokens")

# ---------------------------------------------------------------- 3. rule
B, S1, S2, S22 = F[(314, 315)], F[(321,)], F[(323,)], F[(322,)]
print("\n== 3. rule (fixed before reading): FELL iff s323 per story < before AND < s321 on token-equivalent AND tokens")
te_ok = S2["te"] < B["te"] and S2["te"] < S1["te"]; tk_ok = S2["tok"] < B["tok"] and S2["tok"] < S1["tok"]
print(f"   token-equivalent: s323 ${S2['te']:.2f} vs before ${B['te']:.2f}, s321 ${S1['te']:.2f} -> below both: {te_ok}")
print(f"   bracket check: s323 ${S2['lo']:.2f}..${S2['hi']:.2f} vs before ${B['lo']:.2f}..${B['hi']:.2f}, s321 ${S1['lo']:.2f}..${S1['hi']:.2f}")
print(f"   tokens: s323 {S2['tok']:.1f}M vs before {B['tok']:.1f}M, s321 {S1['tok']:.1f}M -> below both: {tk_ok}")
print(f"   READING: {'FELL' if te_ok and tk_ok else 'DID NOT FALL'}")
# b261: s322 shown as the third comparand (the entry's own rule names the before and s321; s322 is the previous reading)
print(f"   s322 for reference: token-equivalent ${S22['te']:.2f} (bracket ${S22['lo']:.2f}..${S22['hi']:.2f}), {S22['tok']:.1f}M tokens; "
      f"s323 below s322 on te: {S2['te'] < S22['te']}, on tokens: {S2['tok'] < S22['tok']}")
# controls the reading depends on: the before must reproduce the recorded row (BL-398 b256/b251), s321 the b256 re-extract row
want_before = "1.28 h"
print("   control before reproduces 1.28 h / $20.3 (API $17.5) / 34.8M:", f"{B['te']:.1f} {B['api']:.1f} {B['tok']:.1f}", "ok" if (round(B['te'],1), round(B['api'],1), round(B['tok'],1)) == (20.3, 17.5, 34.8) else "MISMATCH")
print("   control s321 re-extract b256 row $26.88/$26.1 API/47.5M:", f"{S1['te']:.2f} {S1['api']:.1f} {S1['tok']:.1f}", "ok" if (round(S1['te'],2), round(S1['tok'],1)) == (26.88, 47.5) else "MOVED")
