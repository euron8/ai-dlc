#!/usr/bin/env python3
"""BL-512: per-story total of every `gate[...]` step, from `roll.py <extract> --seats` output.

Usage: python3 -I gate_total.py <roll --seats output file> <sprint> [<sprint> ...]

roll.py --seats prints PER-STORY MEANS for each step, so a per-story total over steps is the SUM of the step
lines (never divided again). Prints, per sprint, the steps summed and the sums: gap-inclusive hours, gap hours,
token-equivalent $, API $ (the token-equivalent figure where no API figure is printed), M tokens, lead active
hours and $, subagent active hours and $. Refuses on a line it cannot parse, on zero gate lines for a sprint,
and when the absent-sprint control finds anything.
"""
import re, sys

PAT = re.compile(r"^\s+s(\d+) pipeline (gate\[[^\]]+\]) \((\d+) stories\): ([\d.]+) h gap-inclusive \(gap ([\d.]+) h\), "
                 r"token-equivalent \$([\d.]+)(?: \(API \$([\d.]+)\))?, ([\d.]+)M tokens; lead active ([\d.]+) h, "
                 r"lead \$([\d.]+)(?: \(API \$[\d.]+\))?, subagent active ([\d.]+) h, subagent \$([\d.]+)(?: \(API \$[\d.]+\))?")
NAMES = ["gap-inclusive h", "gap h", "token-equivalent $", "API $", "M tokens", "lead active h", "lead $",
         "subagent active h", "subagent $"]


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    lines = open(sys.argv[1]).read().split("\n")
    want = [int(x.lstrip("s")) for x in sys.argv[2:]]
    tot = {}
    for l in lines:
        if " pipeline gate[" not in l:
            continue
        m = PAT.match(l)
        if not m:
            raise SystemExit("UNPARSED gate line: " + l[:160])
        sp = int(m.group(1))
        if sp not in want:
            continue
        v = [float(m.group(4)), float(m.group(5)), float(m.group(6)), float(m.group(7) or m.group(6)),
             float(m.group(8)), float(m.group(9)), float(m.group(10)), float(m.group(11)), float(m.group(12))]
        t = tot.setdefault(sp, [int(m.group(3)), [0.0] * 9, []])
        t[1] = [a + b for a, b in zip(t[1], v)]
        t[2].append(m.group(2))
    for sp in want:
        if sp not in tot:
            raise SystemExit("no gate lines for s%d" % sp)
        st, v, steps = tot[sp]
        print("s%d (%d stories), %d steps: %s" % (sp, st, len(steps), ", ".join(steps)))
        print("  per story: " + "; ".join("%s %.2f" % (n, x) for n, x in zip(NAMES, v)))
    print("control: sprint s999 gate lines = %d (must be 0)" % sum(1 for l in lines if " s999 pipeline gate[" in l))


if __name__ == "__main__":
    main()
