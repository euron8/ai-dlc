"""BL-912 seat figures per story for the declared step and the planning group, s320 / s321 / s322.

Usage: python3 -I bl912_seats.py <OUT>
<OUT> is the directory the chain wrote:
  EXTRACT_WIN_END=<instant> python3 -I docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py $OUT
  python3 -I docs/analysis/pipeline-efficiency-s317-s318/scripts/spawns.py $OUT
  python3 -I docs/analysis/pipeline-efficiency-s317-s318/scripts/analyze.py $OUT
Every figure is roll.py's own seat_sum()/seat_line() (imported, not restated) over steps.csv, pipeline bucket, so
it reads exactly as `roll.py $OUT --seats` does: gap-inclusive hours, token-equivalent $ with API $ beside it,
tokens, lead and subagent seats. Agent wait is printed beside them (steps.csv agent_wait_h, operator wait excluded).
Groups: the planning group of bl912_counts.py (architecture, carry-over-evaluation, requirements,
stories-test-strategy, ui-direction), the same plus bug-investigation, implementation, and stories-test-strategy.
Control, same run: roll.py's whole-pipeline-bucket subagent $ per story for s321 and s319 (BL-812 records $75.1
against $88.1), and the steps.csv token total over every row and seat.
"""
import csv, importlib.util, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "roll", os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "roll.py"))
roll = importlib.util.module_from_spec(spec); spec.loader.exec_module(roll)

OUT = sys.argv[1]
rows = list(csv.DictReader(open(os.path.join(OUT, "steps.csv"))))
HM = {seat: roll.hosted_mix(rows, seat) for seat in ("lead", "sub")}

tok = sum(float(v or 0) for r in rows for c, v in r.items()
          if c.startswith(("lead_", "sub_")) and c.endswith(("_in", "_out", "_cr", "_cw")))
print("control: steps.csv token total, every row and seat:", int(tok))
for n in (319, 321):
    T = roll.seat_sum(rows, HM, "pipeline", None, {n})
    print("control: s%d whole pipeline bucket subagent $ per story: token-equivalent $%.1f API $%.1f"
          % (n, T["sub$e"] / roll.STORIES[n], T["sub$"] / roll.STORIES[n]))

PLAN = {"architecture", "carry-over-evaluation", "requirements", "stories-test-strategy", "ui-direction"}
VERDICT4 = {"carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"}   # the Verdict: field's group
GROUPS = [("stories-test-strategy", {"stories-test-strategy"}), ("verdict group (4 steps)", VERDICT4), ("planning", PLAN),
          ("planning+bug-investigation", PLAN | {"bug-investigation"}), ("implementation", {"implementation"})]
for label, steps in GROUPS:
    print("--", label, "[pipeline]")
    for n in (320, 321, 322):
        sn = roll.STORIES[n]
        T = roll.seat_sum(rows, HM, "pipeline", steps, {n})
        aw = sum(float(r["agent_wait_h"]) for r in rows if r["bucket"] == "pipeline" and int(r["sprint"]) == n
                 and roll.step_base(r["step"]) in steps)
        print("   s%d (%d stories): agent wait %.2f h; %s" % (n, sn, aw / sn, roll.seat_line(T, sn)))
