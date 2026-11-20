"""BL-508 / BL-543 four-step group HOURS per story on the monotone clock (b261). The clock is the code at af44929cc8ca96ab91e8526516e9ac4efa7d21cd,
run IN PLACE from a detached checkout (extract.py default monotone) with WIN_END 2026-11-20T04:20:00Z; this script copies none of it.
usage: ROLL_DIR=<af44929cc>/docs/analysis/pipeline-efficiency-s317-s320/scripts python3 -I group_four_steps_hours.py OUT"""
import csv, os, sys
sys.path.insert(0, os.environ["ROLL_DIR"])
import roll
OUT = sys.argv[1]
rows = list(csv.DictReader(open(os.path.join(OUT, "steps.csv"))))
HM = {s: roll.hosted_mix(rows, s) for s in ("lead", "sub")}
ST = dict(roll.STORIES); ST[323] = 18
FOUR = {"carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"}
UP = FOUR | {"gate[%s]" % s for s in FOUR}
for lab, steps in (("four steps as labelled", FOUR), ("upper bound (plus four gate rows)", UP)):
    print("==", lab, "(hours per story, gap-inclusive = active + op-wait + agent-wait; gap = op-wait + agent-wait)")
    for pl, ns in (("s318 (s317 truncated in the corpus, not used)", (318,)), ("s319", (319,)), ("s320", (320,)), ("s321", (321,)), ("s322", (322,)), ("s323", (323,))):
        sn = sum(ST[n] for n in ns); T = roll.seat_sum(rows, HM, "pipeline", steps, set(ns))
        print(f"  {pl} ({sn} stories): {T['el']/sn:.2f} h gap-inclusive (gap {T['gap']/sn:.2f} h, lead active {T['act']/sn:.2f} h), total {T['el']:.1f} h")
print("== s323 per step, hours total (as labelled)")
for st in sorted(FOUR):
    T = roll.seat_sum(rows, HM, "pipeline", {st}, {323}); print(f"  {st}: {T['el']:.1f} h gap-inclusive (gap {T['gap']:.1f} h)")
print("== roll.py seat_line, four steps as labelled (lead and subagent seats separately)")
for pl, ns in (("s319", (319,)), ("s322", (322,)), ("s323", (323,))):
    sn = sum(ST[n] for n in ns); T = roll.seat_sum(rows, HM, "pipeline", FOUR, set(ns))
    sublocal = sum(float(r.get("sub_%s_calls" % m, 0) or 0) for r in rows if r["bucket"] == "pipeline" and int(r["sprint"]) in ns
                   and r["step"].split("[")[0] in FOUR for m in roll.LOCAL)
    print(f"  {pl}: " + roll.seat_line(T, sn) + f"; subagent local calls {sublocal:.0f}")
