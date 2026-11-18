"""Provisional s323 reader (batch 259, C4b): both segs clocks side by side, planning per step, lead classes.

usage: python3 -I s323_provisional.py OUT_DEFAULT OUT_MONOTONE
  OUT_DEFAULT   extract.py + spawns.py + analyze.py output, EXTRACT_WIN_END at the s323 pin, default segs clock
  OUT_MONOTONE  the same with EXTRACT_MONOTONE_SEGS=1
Reads only the two OUT dirs. Pricing is roll.py's own usd()/hosted_mix()/FALLBACK, imported, not restated.
PLANNED holds planned story counts (the count fixed at the stories gate); it is used for the four planning steps
only. No per-story figure is printed for a step that is still open."""
import csv, collections, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts"))
import roll  # noqa: E402

DEF, MONO = sys.argv[1:3]
SP = (317, 318, 319, 320, 321, 322, 323)
PLANNED = {320: 13, 321: 25, 322: 8, 323: 18}   # s323: 18 story files under planning-artifacts/s323/stories at graph e70a344c0
PLAN = ("carry-over-evaluation", "requirements", "architecture", "stories-test-strategy")
STEPS = PLAN + ("implementation", "sprint-review", "deploy-validate", "retro", "handoff", "route", "pre-step", "ui-direction")

def base(st):
    return st.split("[")[0] if not st.startswith("gate-validation") else st[16:-1]

def load(out):
    rows = list(csv.DictReader(open(os.path.join(out, "steps.csv"))))
    HM = {seat: roll.hosted_mix(rows, seat) for seat in ("lead", "sub")}
    A = collections.defaultdict(lambda: collections.defaultdict(float))
    for r in rows:
        if r["bucket"] != "pipeline": continue
        n = int(r["sprint"]); a = A[(n, base(r["step"]))]
        a["el"] += float(r["elapsed_h"]); a["act"] += float(r["active_h"])
        a["aw"] += float(r["agent_wait_h"]); a["op"] += float(r["op_wait_h"]); a["comp"] += float(r["compactions"])
        for seat in ("lead", "sub"):
            mix = HM[seat][n]
            if sum(mix.values()) <= 0 and n in roll.FALLBACK: mix = HM[seat][roll.FALLBACK[n]]
            v = roll.usd(r, seat, True, mix)
            a["api"] += roll.usd(r, seat); a["te"] += roll.usd(r, seat) if v is None else v
            a["calls_" + seat] += sum(roll.calls(r, seat).values())
    return A

def tot(A, n, steps=None):
    T = collections.defaultdict(float)
    for (m, s), a in A.items():
        if m == n and (steps is None or s in steps):
            for k, v in a.items(): T[k] += v
    return T

D, M = load(DEF), load(MONO)
print("== sprint totals, pipeline bucket: default segs clock | monotone segs clock (EXTRACT_MONOTONE_SEGS=1)")
print("   dollars and calls must not move between the clocks; the DIFF column asserts it")
for n in SP:
    d, m = tot(D, n), tot(M, n)
    same = abs(d["te"] - m["te"]) < 1e-6 and abs(d["api"] - m["api"]) < 1e-6 and d["calls_lead"] == m["calls_lead"]
    print(f"s{n}: elapsed {d['el']:6.1f} h | {m['el']:6.1f} h ({100 * (m['el'] / d['el'] - 1):+.0f}%)   active {d['act']:5.1f} | {m['act']:5.1f}"
          f"   op-wait {d['op']:5.1f} | {m['op']:5.1f}   agent-wait {d['aw']:5.1f} | {m['aw']:5.1f}"
          f"   token-eq ${m['te']:.0f} API ${m['api']:.0f} lead calls {m['calls_lead']:.0f} compactions {m['comp']:.0f}   $/calls {'EQUAL' if same else 'DIFF'}")

sp = [json.loads(l) for l in open(os.path.join(MONO, "spawns.jsonl"))]
nsp = collections.Counter((x["sprint"], base(x["step"])) for x in sp)
print("\n== per step (step plus its own gate), MONOTONE clock: elapsed h = active + op-wait + agent-wait | token-eq $ (API $) | lead calls | spawns")
for st in STEPS:
    print(st)
    for n in (320, 321, 322, 323):
        a = M.get((n, st))
        if not a: print(f"   s{n}: -"); continue
        print(f"   s{n}: {a['el']:5.1f} h = {a['act']:4.1f} + {a['op']:4.1f} + {a['aw']:4.1f} | ${a['te']:5.0f} (${a['api']:5.0f}) | {a['calls_lead']:5.0f} | {nsp[(n, st)]:4d}"
              f"   [default clock {D[(n, st)]['el']:5.1f} h]")

print("\n== planning (the four planning steps and their gates), MONOTONE clock; per PLANNED story", PLANNED)
for n in (320, 321, 322, 323):
    m, d = tot(M, n, PLAN), tot(D, n, PLAN); k = PLANNED[n]; s = sum(nsp[(n, st)] for st in PLAN)
    print(f"s{n}: {m['el']:5.1f} h (less op-wait {m['el'] - m['op']:5.1f} h; active {m['act']:4.1f}) token-eq ${m['te']:.0f} API ${m['api']:.0f} lead calls {m['calls_lead']:.0f} spawns {s}"
          f" | per story: {m['el'] / k:.2f} h, less op-wait {(m['el'] - m['op']) / k:.2f} h, ${m['te'] / k:.1f}, API ${m['api'] / k:.1f}, {m['calls_lead'] / k:.0f} lead calls"
          f"   [default clock {d['el']:5.1f} h]")

print("\n== lead call classes inside planning (classes.jsonl, already on a monotone clock in both runs): calls / active h")
units = {}
for l in open(os.path.join(MONO, "units.jsonl")):
    u = json.loads(l); units[u["unit"]] = u
C = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0.0]))
for l in open(os.path.join(MONO, "classes.jsonl")):
    r = json.loads(l); u = units.get(r["unit"])
    if u and u.get("sprint") in PLANNED and base(r["step"]) in PLAN:
        c = C[u["sprint"]][r["cls"]]; c[0] += r.get("calls", 0); c[1] += r.get("active", 0) / 3600
for c in ("other", "merge", "snapshot", "step-reread", "compaction-recovery", "gate-run", "dispatch", "repair", "idle-wait"):
    print(f"   {c:20}" + " | ".join(f"s{n} {C[n][c][0]:5d} / {C[n][c][1]:4.1f} h" for n in sorted(PLANNED)))
print("   " + "total".ljust(20) + " | ".join(f"s{n} {sum(v[0] for v in C[n].values()):5d} / {sum(v[1] for v in C[n].values()):4.1f} h" for n in sorted(PLANNED)))

print("\n== control: s323 lead session spans (first to last record, pipeline sessions that entered a step) against the monotone total")
T = lambda s: __import__("datetime").datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
segs = [json.loads(l) for l in open(os.path.join(MONO, "segs.jsonl"))]
piped = {s["sess"] for s in segs if s["kind"] == "lead" and s["sprint"] == 323 and base(s["step"]) in STEPS and s["step"] != "pre-step"}
span = sum(T(u["last"]) - T(u["first"]) for u in units.values() if u["kind"] == "lead" and u["unit"] in piped) / 3600
print(f"   {len(piped)} lead sessions, span sum {span:.1f} h; monotone s323 total {tot(M, 323)['el']:.1f} h; default-clock s323 total {tot(D, 323)['el']:.1f} h")
print("   a total above the span sum counts some second twice; the default clock does, the monotone clock cannot")
