#!/usr/bin/env python3 -I
"""phases_s323.py: aggregate tl_s323.tsv (from timeline.py) into hand-set phases.
Phase boundaries are read by hand from the timeline (see README). Wall = next phase start - this start.
Also totals re-read calls (Read of step/digest/snapshot files, ctx_search recall) = post-compaction recovery."""
import os, re
D = os.path.dirname(os.path.abspath(__file__)) + "/"
rows = [l.rstrip('\n').split('\t') for l in open(D + "tl_s323.tsv")][1:]
def sec(t):
    h, m, s = map(int, t.split(':')); return h * 3600 + m * 60 + s
B = [("1 carry+context", "01:36:00"), ("2 party mode (6 personas+transcript commit+classify)", "01:38:56"),
     ("3 doc-split draft (7 analyst shards + join)", "01:46:13"),
     ("4 close-out gather+rule audit+improvements+dispositions", "01:58:46"),
     ("4b steering audit+rotate+rm scratch", "02:25:17"),
     ("4c dev reclass wait + 2nd archive + recover lost table + write retro sections", "02:26:56"),
     ("5/5b commentary pause + anchor + prune", "02:39:15"),
     ("5c-prep snapshot trim (Check14) + gate worklist + script arms", "02:40:57"),
     ("5c gate: 3 adjudicator shards + lead merge+re-verify+gate entry", "02:50:19"),
     ("6a classify dirty paths + commit + validators + amend", "03:25:47"),
     ("6b foreground push #1 (retro branch)", "03:45:08"),
     ("6d PR + 7a merge + 5b backfill + push #2", "03:52:45"),
     ("7a-post rotation + terminal snapshot + push #3", "03:57:10"),
     ("7b next-inputs analysts + bundle + 7d + pushes #4/#5", "04:03:51")]
END = sec("04:17:36")
REREAD = re.compile(r"steps/retro\.md|postcompact-digest|pipeline-snapshot\.md|gate-validation\.md|_gate-procedures|ctx_search|rejected approaches|select:mcp__plugin")
agg = {}
for r in rows:
    ts, dur, th, tool, err, s = r; t = sec(ts)
    p = max(i for i, b in enumerate(B) if sec(b[1]) <= t)
    a = agg.setdefault(p, [0, 0.0, 0, 0.0, 0.0])
    a[0] += 1
    rr = tool in ('Read', 'ToolSearch') and REREAD.search(s) or ('queries' in s and tool.startswith('mcp'))
    if rr: a[2] += 1; a[3] += float(th) + float(dur)
    a[4] += float(dur)
tot = [0, 0, 0, 0.0]
for i, (n, st) in enumerate(B):
    en = sec(B[i + 1][1]) if i + 1 < len(B) else END
    w = en - sec(st); a = agg.get(i, [0, 0, 0, 0, 0])
    print("%-80s wall %5.1f min  calls %3d  reread %2d (%.1f min)  tooldur %.1f min" % (n, w / 60, a[0], a[2], a[3] / 60, a[4] / 60))
    tot[0] += w; tot[1] += a[0]; tot[2] += a[2]; tot[3] += a[3]
print("TOTAL wall %.1f min calls %d reread calls %d reread min %.1f" % (tot[0] / 60, tot[1], tot[2], tot[3] / 60))
