#!/usr/bin/env python3 -I
"""timeline.py SESSION_ID START_ISO END_ISO OUT_TSV
Reads a lead transcript (read-only), emits one row per tool call in [START,END]:
ts, dur_s (tool_use ts -> matching tool_result ts), think_s (gap since previous event end),
tool, err, summary. Pairs tool_use with tool_result by id.
"""
import sys, json, glob, os
from datetime import datetime
sess, t0, t1, out = sys.argv[1:5]
root = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/")
f = glob.glob(root + sess + "*.jsonl")[0]
def P(s): return datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
a, b = P(t0), P(t1)
uses = {}; results = {}; order = []
for l in open(f):
    try: d = json.loads(l)
    except Exception: continue
    ts = d.get('timestamp')
    if not ts: continue
    t = P(ts)
    m = d.get('message') or {}
    c = m.get('content')
    if not isinstance(c, list): continue
    for x in c:
        if not isinstance(x, dict): continue
        if x.get('type') == 'tool_use':
            inp = x.get('input', {})
            if x['name'] == 'Bash': s = (inp.get('description') or '') + ' || ' + (inp.get('command') or '')[:160]
            elif x['name'] in ('Agent', 'Task'): s = (inp.get('subagent_type') or '') + ' | ' + (inp.get('description') or '')
            elif x['name'] == 'Skill': s = inp.get('skill', '')
            else: s = (inp.get('file_path') or inp.get('path') or inp.get('pattern') or inp.get('query') or str(inp))[:160]
            uses[x['id']] = (t, x['name'], s.replace('\n', ' ').replace('\t', ' '))
            order.append(x['id'])
        elif x.get('type') == 'tool_result':
            results[x['tool_use_id']] = (t, bool(x.get('is_error')))
rows = []; prev_end = None
for i in order:
    t, n, s = uses[i]
    if t < a or t > b: continue
    r = results.get(i)
    e = r[0] if r else t
    dur = e - t
    think = (t - prev_end) if prev_end is not None else 0
    rows.append((t, dur, think, n, int(r[1]) if r else -1, s))
    prev_end = max(prev_end or 0, e)
with open(out, 'w') as o:
    o.write("ts\tdur_s\tthink_s\ttool\terr\tsummary\n")
    for t, dur, think, n, er, s in rows:
        o.write("%s\t%.1f\t%.1f\t%s\t%d\t%s\n" % (datetime.utcfromtimestamp(t).strftime('%H:%M:%S'), dur, think, n, er, s))
print(len(rows), 'rows;', 'sum dur h', round(sum(r[1] for r in rows) / 3600, 2), 'sum think h', round(sum(r[2] for r in rows) / 3600, 2))
