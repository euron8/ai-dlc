"""BL-508 / BL-543 four-step planning group, per story, dollars / tokens / calls only (b261, s323 complete).
usage: python3 -I group_four_steps.py OUT        (OUT = extract.py + spawns.py + analyze.py output; read only)
Elapsed figures are deliberately NOT printed (held for BL-1174's corrected clock). Pricing and seat sums are
roll.py's own seat_sum/usd/hosted_mix imported, not restated. roll.STORIES has no 323: PLANNED below holds it
(18 story files under _bmad-output/planning-artifacts/s323/stories at graph 16fd227d9)."""
import csv, os, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("ROLL_DIR") or os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts"))   # ROLL_DIR: the clock sha's scripts dir, run in place, never copied here
import roll
OUT = sys.argv[1]
rows = list(csv.DictReader(open(os.path.join(OUT, "steps.csv"))))
HM = {s: roll.hosted_mix(rows, s) for s in ("lead", "sub")}
STORIES = dict(roll.STORIES); STORIES[323] = 18
FOUR = {"carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"}
UPPER = FOUR | {"gate[%s]" % s for s in FOUR}
POPS = [("s318 (s317 is truncated in today's transcript corpus, not used)", (318,)), ("s319", (319,)), ("s320", (320,)), ("s321 (no carry-over-evaluation)", (321,)),
        ("s322", (322,)), ("s323", (323,))]
def line(T, sn):
    te = T["lead$e"] + T["sub$e"]; api = T["lead$"] + T["sub$"]
    return (f"{sn} stories: token-equivalent ${te/sn:.2f} per story (API ${api/sn:.2f}), {(T['leadtok']+T['subtok'])/sn/1e6:.2f}M tokens per story; "
            f"lead ${T['lead$e']/sn:.2f} (API ${T['lead$']/sn:.2f}), subagent ${T['sub$e']/sn:.2f}; total ${te:.1f} (API ${api:.1f}), "
            f"{(T['leadtok']+T['subtok'])/1e6:.1f}M tokens, lead calls {T['leadcalls']:.0f}, subagent calls {T['subcalls']:.0f}, "
            f"lead local share {100*T['leadlocal']/T['leadcalls'] if T['leadcalls'] else 0:.0f}%")
for label, steps in (("as labelled (four steps)", FOUR), ("upper bound (four steps plus their four planning-gate rows)", UPPER)):
    print("==", label)
    for pl, ns in POPS:
        sn = sum(STORIES[n] for n in ns)
        T = roll.seat_sum(rows, HM, "pipeline", steps, set(ns))
        print(f"  {pl}: " + line(T, sn))
for n in (323,):
    print("== per step, s323, token-equivalent $ (API), tokens, lead calls, subagent calls")
    for st in sorted(FOUR):
        T = roll.seat_sum(rows, HM, "pipeline", {st}, {n})
        print(f"  {st}: ${T['lead$e']+T['sub$e']:.1f} (API ${T['lead$']+T['sub$']:.1f}), {(T['leadtok']+T['subtok'])/1e6:.1f}M, {T['leadcalls']:.0f}, {T['subcalls']:.0f}")
