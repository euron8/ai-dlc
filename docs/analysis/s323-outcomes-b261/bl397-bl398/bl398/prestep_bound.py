"""BL-398 b261: how much of the b244 pin's `pre-step` bucket (pre-BL-927 extractor: party seats were parked there) could belong to
stories-test-strategy, in token-equivalent dollars and tokens per story over the 9 before stories (s314 4 + s315 5).
usage: AI_DLC_XDIR=<extractor dir holding roll.py> python3 -I prestep_bound.py <b244-snapshot dir>
Upper bound: the WHOLE pre-step bucket (both seats) of s314 and s315 is added to the before. Control: the bound on an absent
step is 0, and the stories-test-strategy row of the pin must still read $20.25 / 34.8M (the cost.py before)."""
import csv, importlib.util, os, sys
sys.dont_write_bytecode = True
X = os.environ["AI_DLC_XDIR"]
spec = importlib.util.spec_from_file_location("roll", os.path.join(X, "roll.py")); roll = importlib.util.module_from_spec(spec); spec.loader.exec_module(roll)
rows = list(csv.DictReader(open(os.path.join(sys.argv[1], "steps.csv"))))
HM = {s: roll.hosted_mix(rows, s) for s in ("lead", "sub")}
def per(step, n=9):
    T = roll.seat_sum(rows, HM, "pipeline", {step}, {314, 315})
    return (T["lead$e"] + T["sub$e"]) / n, (T["leadtok"] + T["subtok"]) / n / 1e6
base = per("stories-test-strategy")
pre = per("pre-step")
none = per("no-such-step")
print(f"before stories-test-strategy per story: ${base[0]:.2f}, {base[1]:.1f}M tokens (control: must read 20.25 / 34.8)")
print(f"pre-step bucket per story (upper bound on what the pre-BL-927 extractor left out): ${pre[0]:.2f}, {pre[1]:.2f}M tokens")
print(f"before plus the whole bound: ${base[0] + pre[0]:.2f}, {base[1] + pre[1]:.1f}M tokens")
print(f"absent step (control, must be 0): ${none[0]:.2f}, {none[1]:.2f}M")
