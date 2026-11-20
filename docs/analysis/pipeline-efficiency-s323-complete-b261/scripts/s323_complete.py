"""Complete-s323 reader (batch 261, C5): both segs clocks, planning, BL-819 / BL-1175 / BL-912 rows.

usage: python3 -I s323_complete.py OUT_DEFAULT OUT_MONOTONE POLES_TXT
  OUT_DEFAULT  extract.py + spawns.py + analyze.py output at EXTRACT_WIN_END=2026-11-20T04:20:00Z, EXTRACT_MONOTONE_SEGS=0
  OUT_MONOTONE the same with EXTRACT_MONOTONE_SEGS=1
  POLES_TXT    poles_allroles.py output on OUT_MONOTONE (busy / solo-role hours per step)
Reads only those. Pricing is roll.py's usd()/hosted_mix()/FALLBACK, imported. Story counts are passed here (PLANNED),
so bl812_rederive.py's STORIES is not touched. s317 is not read: its transcripts are partly gone from disk."""
import csv, collections, json, os, re, sys, datetime
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts"))
import roll  # noqa: E402

DEF, MONO, POLES = sys.argv[1:4]
SP = (318, 319, 320, 321, 322, 323)
PLANNED = {321: 25, 322: 8, 323: 18}
PLAN = ("carry-over-evaluation", "requirements", "architecture", "stories-test-strategy")
STEPS = PLAN + ("implementation", "sprint-review", "deploy-validate", "retro")

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
print("== sprint totals, pipeline bucket: default segs clock | monotone segs clock; $ and calls must not move (EQUAL)")
for n in SP:
    d, m = tot(D, n), tot(M, n)
    same = abs(d["te"] - m["te"]) < 1e-6 and abs(d["api"] - m["api"]) < 1e-6 and d["calls_lead"] == m["calls_lead"]
    print(f"s{n}: elapsed {d['el']:6.1f} h | {m['el']:6.1f} h ({100 * (m['el'] / d['el'] - 1):+.0f}%)   active {d['act']:5.1f} | {m['act']:5.1f}"
          f"   op-wait {d['op']:5.1f} | {m['op']:5.1f}   agent-wait {d['aw']:5.1f} | {m['aw']:5.1f}"
          f"   token-eq ${m['te']:.0f} API ${m['api']:.0f} lead calls {m['calls_lead']:.0f} compactions {m['comp']:.0f}"
          f" per elapsed h {m['comp'] / m['el']:.2f} (default clock {d['comp'] / d['el']:.2f})   $/calls {'EQUAL' if same else 'DIFF'}")

sp = [json.loads(l) for l in open(os.path.join(MONO, "spawns.jsonl"))]
nsp = collections.Counter((x["sprint"], base(x["step"])) for x in sp)
print("\n== per step (step plus its own gate), MONOTONE clock: elapsed h = active + op-wait + agent-wait | token-eq $ (API $) | lead calls | spawns   [default clock h]")
for st in STEPS:
    print(st)
    for n in (321, 322, 323):
        a = M.get((n, st))
        if not a: print(f"   s{n}: -"); continue
        print(f"   s{n}: {a['el']:5.1f} h = {a['act']:4.1f} + {a['op']:4.1f} + {a['aw']:4.1f} | ${a['te']:5.0f} (${a['api']:5.0f}) | {a['calls_lead']:5.0f} | {nsp[(n, st)]:4d}   [default clock {D[(n, st)]['el']:5.1f} h]")

busy = collections.defaultdict(float); solo = collections.defaultdict(lambda: collections.defaultdict(float))
for l in open(POLES):
    m = re.match(r"s(\d+) (\S+)\s+intervals\s+\d+ busy\s+([\d.]+) h .*solo-role h: (.*)", l)
    if not m: continue
    n, st = int(m.group(1)), m.group(2)
    busy[(n, st)] += float(m.group(3))
    for kv in m.group(4).split(", "):
        r, h = kv.rsplit(" ", 1); solo[(n, base(st))][r] += float(h)
print("\n== planning (four planning steps and their gates), MONOTONE clock, per PLANNED story", PLANNED)
for n in (321, 322, 323):
    m, d = tot(M, n, PLAN), tot(D, n, PLAN); k = PLANNED[n]; s = sum(nsp[(n, st)] for st in PLAN)
    bz = sum(busy[(n, st)] for st in PLAN); bg = bz + sum(busy[(n, "gate-validation[%s]" % st)] for st in PLAN)
    lo = m["el"] - m["op"] - bz
    print(f"s{n}: {m['el']:5.1f} h (default clock {d['el']:5.1f}) less op-wait {m['el'] - m['op']:5.1f} h (op-wait {m['op']:4.1f}; active {m['act']:4.1f}; agent-wait {m['aw']:4.1f})"
          f" token-eq ${m['te']:.0f} API ${m['api']:.0f} lead calls {m['calls_lead']:.0f} spawns {s}")
    print(f"      subagent running (busy, steps without gates) {bz:4.1f} h; with gates {bg:4.1f} h; lead-only lower bound {lo:4.1f} h"
          f" | per story: {m['el'] / k:.2f} h, less op-wait {(m['el'] - m['op']) / k:.2f} h, ${m['te'] / k:.1f}, API ${m['api'] / k:.1f}, {m['calls_lead'] / k:.0f} lead calls")
    rem = sum(solo[(n, st)]["remediator"] for st in PLAN)
    print(f"      still held (shares of {m['el']:.1f} h): BL-716 remediator solo {rem:.1f} h ({100 * rem / m['el']:.0f}%, steps+gates, solo-role rows summed);"
          f" BL-972 operator wait {m['op']:.1f} h ({100 * m['op'] / m['el']:.0f}%); BL-819 lead calls {m['calls_lead']:.0f}, lead active {m['act']:.1f} h ({100 * m['act'] / m['el']:.0f}%)")

units = {}
for l in open(os.path.join(MONO, "units.jsonl")):
    u = json.loads(l); units[u["unit"]] = u
CL = ("other", "merge", "snapshot", "step-reread", "compaction-recovery", "gate-run", "dispatch", "repair", "idle-wait")
def classes(key):
    C = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0.0]))
    for l in open(os.path.join(MONO, "classes.jsonl")):
        r = json.loads(l); u = units.get(r["unit"])
        if not u or u.get("sprint") not in PLANNED: continue
        k = key(r["step"])
        if k is None: continue
        c = C[(u["sprint"], k)][r["cls"]]; c[0] += r.get("calls", 0); c[1] += r.get("active", 0) / 3600
    return C
print("\n== BL-819 rows: lead call classes inside the four planning steps (classes.jsonl, monotone in both runs): calls / active h")
C = classes(lambda s: "plan" if base(s) in PLAN else None)
for c in CL:
    print(f"   {c:20}" + " | ".join(f"s{n} {C[(n, 'plan')][c][0]:5d} / {C[(n, 'plan')][c][1]:4.1f} h" for n in sorted(PLANNED)))
print("   " + "total".ljust(20) + " | ".join(f"s{n} {sum(v[0] for v in C[(n, 'plan')].values()):5d} / {sum(v[1] for v in C[(n, 'plan')].values()):4.1f} h" for n in sorted(PLANNED)))
print("   compactions per elapsed h over the whole pipeline bucket, monotone clock: " + " | ".join(
    f"s{n} {tot(M, n)['comp']:.0f} in {tot(M, n)['el']:.1f} h = {tot(M, n)['comp'] / tot(M, n)['el']:.2f}" for n in sorted(PLANNED)))

print("\n== BL-912 rows: snapshot-class lead calls and active h per step (gate folded into its step) / all lead calls in the step")
C2 = classes(lambda s: base(s))
for st in PLAN + ("implementation",):
    print(st)
    for n in sorted(PLANNED):
        x = C2[(n, st)]; allc = sum(v[0] for v in x.values()); alla = sum(v[1] for v in x.values())
        print(f"   s{n}: snapshot {x['snapshot'][0]:4d} of {allc:5d} lead calls ({100 * x['snapshot'][0] / max(allc, 1):.0f}%), {x['snapshot'][1]:.2f} active h of {alla:.1f}")
C3 = classes(lambda s: "impl-only" if s == "implementation" else None)
print("implementation, the implementation label only (gate[implementation] excluded)")
for n in sorted(PLANNED):
    x = C3[(n, "impl-only")]; allc = sum(v[0] for v in x.values()); alla = sum(v[1] for v in x.values())
    print(f"   s{n}: snapshot {x['snapshot'][0]:4d} of {allc:5d} lead calls ({100 * x['snapshot'][0] / max(allc, 1):.0f}%), {x['snapshot'][1]:.2f} active h of {alla:.1f}")

print("\n== control: s323 lead session spans (first to last record, pipeline sessions that entered a step) against the monotone total")
T = lambda s: datetime.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
segs = [json.loads(l) for l in open(os.path.join(MONO, "segs.jsonl"))]
piped = {s["sess"] for s in segs if s["kind"] == "lead" and s["sprint"] == 323 and base(s["step"]) in STEPS and s["step"] != "pre-step"}
span = sum(T(u["last"]) - T(u["first"]) for u in units.values() if u["kind"] == "lead" and u["unit"] in piped) / 3600
print(f"   {len(piped)} lead sessions, span sum {span:.1f} h; monotone s323 total {tot(M, 323)['el']:.1f} h; default-clock s323 total {tot(D, 323)['el']:.1f} h")
