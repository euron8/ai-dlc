# m2_planning_hours.py -- BL-911 band: planning machine hours of s317..s323 on BOTH segs clocks, from two extract OUT dirs.
# usage: python3 -I m2_planning_hours.py <OUT default clock> <OUT monotone clock>
# Planning = the four planning steps plus their own gates (steps.csv rows of bucket `pipeline`, step base name as in
# s323_provisional.py: gate-validation[x] is x).
# MACHINE HOURS = lead active + agent wait, operator wait excluded (docs/backlog.md BL-812's definition). Control: on the
# default clock this reproduces BL-911's recorded s318 33.1, s319 35.5 and s320 34.8 (asserted below to 0.05 h).
# elapsed_h = active + op-wait + agent-wait is printed beside it.
import csv, os, sys, collections
DEF, MONO = sys.argv[1:3]
PLAN = ("carry-over-evaluation", "requirements", "architecture", "stories-test-strategy")
RECORDED = {317: 38.3, 318: 33.1, 319: 35.5, 320: 34.8, 321: 35.9}   # BL-911 text, old clock
def base(st): return st.split("[")[0] if not st.startswith("gate-validation") else st[16:-1]
def load(out):
    T = collections.defaultdict(lambda: collections.defaultdict(float)); n = 0
    for r in csv.DictReader(open(os.path.join(out, "steps.csv"))):
        n += 1
        if r["bucket"] != "pipeline" or base(r["step"]) not in PLAN: continue
        t = T[int(r["sprint"])]
        for k in ("elapsed_h", "active_h", "op_wait_h", "agent_wait_h"): t[k] += float(r[k])
    assert n > 0
    return T
D, M = load(DEF), load(MONO)
mh = lambda t: t["active_h"] + t["agent_wait_h"]
print("planning (four steps + gates), pipeline bucket, hours. machine h = active + agent-wait (op-wait excluded)")
print("sprint | BL-911 recorded | default clock: machine | elapsed | active | op-wait | agent-wait || monotone clock: machine | elapsed | active | op-wait | agent-wait")
for n in range(317, 324):
    d, m = D[n], M[n]
    print("s%d | %s | %.1f | %.1f | %.1f | %.1f | %.1f || %.1f | %.1f | %.1f | %.1f | %.1f" % (n, RECORDED.get(n, "-"), mh(d), d["elapsed_h"], d["active_h"], d["op_wait_h"], d["agent_wait_h"],
          mh(m), m["elapsed_h"], m["active_h"], m["op_wait_h"], m["agent_wait_h"]))
for n in (318, 319, 320):
    ok = abs(mh(D[n]) - RECORDED[n]) < 0.05
    print("CONTROL s%d default-clock machine h %.2f vs recorded %.1f: %s" % (n, mh(D[n]), RECORDED[n], "REPRODUCED" if ok else "NOT REPRODUCED"))
    assert ok
for n in (317, 321):
    print("NOT reproduced s%d default-clock machine h %.2f vs recorded %.1f (s321 was open when recorded; s317 cause not investigated)" % (n, mh(D[n]), RECORDED[n]))
v = [RECORDED[n] for n in range(317, 322)]
print("recorded band s317-s321 (old clock): %.1f to %.1f" % (min(v), max(v)))
v = [mh(D[n]) for n in range(318, 322)]
print("recomputed band s318-s321, default clock machine h (s317 excluded: partial planning, %.1f h): %.1f to %.1f" % (mh(D[317]), min(v), max(v)))
v = [mh(M[n]) for n in range(318, 322)]
print("recomputed band s318-s321, monotone clock machine h: %.1f to %.1f" % (min(v), max(v)))
print("s322: default %.1f monotone %.1f; s323: default %.1f monotone %.1f" % (mh(D[322]), mh(M[322]), mh(D[323]), mh(M[323])))
