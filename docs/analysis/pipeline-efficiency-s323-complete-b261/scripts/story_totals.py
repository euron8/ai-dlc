"""Per-story whole-bucket totals from two outcome_row.py outputs (BL-812 item 1 row, both clocks).

usage: python3 -I story_totals.py OUTCOME_MONOTONE.txt OUTCOME_DEFAULT.txt
Sums the step rows under each 'sN whole pipeline bucket' header: machine h, spawns, subagent $, lead tokens, lead calls
(all per story, as outcome_row prints them). Wrapper over outcome_row.py (docs/analysis/pipeline-efficiency-s317-s322/scripts)."""
import re, sys

def read(f):
    res, sp = {}, None
    for l in open(f):
        m = re.match(r"s(\d+) whole pipeline", l)
        if m:
            sp = int(m.group(1)); res[sp] = dict(sp=0.0, sd=0.0, mh=0.0, lm=0.0, lc=0.0, rows=0); continue
        m = re.match(r"\s{3}(\S+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+\$[\d.]+ .*?\|\s+([\d.]+)\s+\$[\d.]+\s+\|\s+([\d.]+)\s+([\d.]+) \|\s+([\d.]+)", l)
        if m and sp:
            r = res[sp]; r["lm"] += float(m.group(4)); r["lc"] += float(m.group(3)); r["sp"] += float(m.group(6))
            r["sd"] += float(m.group(7)); r["mh"] += float(m.group(8)); r["rows"] += 1
    return res

M, D = read(sys.argv[1]), read(sys.argv[2])
print("whole pipeline bucket, per story, summed over every step row (machine h = lead active + agent wait, operator wait excluded; spawns, subagent $, tokens, calls are clock-invariant)")
for sp in sorted(M, reverse=True):
    a, b = M[sp], D[sp]
    print(f"s{sp}: machine h/story {a['mh']:.2f} monotone | {b['mh']:.2f} default; spawns/story {a['sp']:.1f}; subagent $/story {a['sd']:.1f}; "
          f"lead tokens M/story {a['lm']:.1f}; lead calls/story {a['lc']:.0f}; step rows {a['rows']}")
