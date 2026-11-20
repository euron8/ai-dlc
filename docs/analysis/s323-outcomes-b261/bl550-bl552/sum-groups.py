"""Sum the four planning steps (carry-over-evaluation, requirements, architecture, stories-test-strategy) per story
from a `roll.py OUT --seats` text, for the sprints given. roll.py has no four-step group; this reads its printed
"every step, per sprint" `pipeline` rows (per story, rounded to 0.01 h / $0.1 / 0.1M) and adds them.

Usage: python3 -I sum-groups.py ROLL_SEATS_TXT SPRINT [SPRINT ...]
Prints, per sprint: the four steps as labelled, the same plus the four planning-gate rows (upper bound), and the
three steps without carry-over-evaluation (the step whose s323 round ran before the 0.1135.0 engine).
Rounding: each printed figure is rounded, so a sum carries at most +-0.02 h / +-0.2 $ / +-0.2M.
Exit 0; 2 when a sprint lacks one of the eight rows (a zero is not read as a sum).
"""
import re, sys

STEPS = ["carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"]
GATES = ["gate[%s]" % s for s in STEPS]
ROW = re.compile(
    r"^   s(\d+) pipeline (\S+) \((\d+) stories\): ([\d.]+) h gap-inclusive \(gap ([\d.]+) h\), "
    r"token-equivalent \$([\d.]+) \(API \$([\d.]+)\), ([\d.]+)M tokens")


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    rows = {}
    for ln in open(argv[0]):
        m = ROW.match(ln)
        if m:
            sp, step, ns, h, gap, te, api, tok = m.groups()
            rows[(int(sp), step)] = (int(ns), float(h), float(gap), float(te), float(api), float(tok))
    rc = 0
    for sp in (int(x) for x in argv[1:]):
        for label, names in (("four steps as labelled", STEPS), ("plus four planning-gate rows", STEPS + GATES),
                             ("three steps without carry-over-evaluation", STEPS[1:])):
            miss = [n for n in names if (sp, n) not in rows]
            if miss:
                print("s%d %s: MISSING rows %s" % (sp, label, miss))
                rc = 2
                continue
            t = [sum(rows[(sp, n)][i] for n in names) for i in range(1, 6)]
            print("s%d %s (%d stories): %.2f h gap-inclusive (gap %.2f h), token-equivalent $%.1f (API $%.1f), %.1fM tokens, per story"
                  % (sp, label, rows[(sp, names[0])][0], t[0], t[1], t[2], t[3], t[4]))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
