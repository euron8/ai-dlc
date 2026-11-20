#!/usr/bin/env python3
# phases.py SESSION A B "label=ISO,label=ISO,..." -> per phase: wall min, active min (intervals<=300s between records),
# gap min (>300s) split into op (ask pending or ended by human text) vs agent; ask count; spawn count + agent-minutes
# (spawn rows from MONO/spawns.jsonl for the sprint, step deploy-validate, start inside phase). Approximation of the
# extractor's classes; totals are compared against MONO/segs.jsonl in the caller (control).
import json, sys, os
from datetime import datetime
sess, a, b, ph = sys.argv[1:5]
sprint = int(sys.argv[5])
M = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
def ts(s): return datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S')
cuts = [x.split('=') for x in ph.split(',')]
labels = [c[0] for c in cuts]; starts = [c[1] for c in cuts]
def which(t):
    k = 0
    for i, s in enumerate(starts):
        if t >= s: k = i
    return k
p = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/%s.jsonl' % sess)
recs = []; pend = {}; asks = []
for l in open(p):
    try: d = json.loads(l)
    except Exception: continue
    t = d.get('timestamp')
    if not t or d.get('type') not in ('user', 'assistant') or t < a or t > b: continue
    human = False; c = d.get('message', {}).get('content')
    if d['type'] == 'user' and not d.get('isMeta'):
        if isinstance(c, str) and not c.startswith('<task-notification') and 'Stop hook feedback' not in c: human = True
        elif isinstance(c, list):
            for x in c:
                if x.get('type') == 'text' and not x['text'].startswith('<task-notification') and 'Stop hook feedback' not in x['text']: human = True
    if isinstance(c, list):
        for x in c:
            if x.get('type') == 'tool_use' and x['name'] == 'AskUserQuestion': pend[x['id']] = t; asks.append(t)
            if x.get('type') == 'tool_result' and x['tool_use_id'] in pend: pend.pop(x['tool_use_id'])
    recs.append((t, human, len(pend) > 0))
recs.sort()
n = len(labels)
wall = [0.0] * n; act = [0.0] * n; opg = [0.0] * n; agg = [0.0] * n; nask = [0] * n
for i in range(1, len(recs)):
    t0, _, pend0 = recs[i - 1]; t1, h1, _ = recs[i]
    d = (ts(t1) - ts(t0)).total_seconds(); k = which(t0)
    wall[k] += d
    if d <= 300: act[k] += d
    elif pend0 or h1: opg[k] += d
    else: agg[k] += d
for t in asks: nask[which(t)] += 1
sp = [json.loads(l) for l in open(M + 'spawns.jsonl')]
sp = [s for s in sp if s['sprint'] == sprint and s['step'] == 'deploy-validate' and a <= s['start'] <= b]
ns = [0] * n; sm = [0.0] * n; su = [0.0] * n
for s in sp:
    k = which(s['start']); ns[k] += 1; sm[k] += s['minutes']; su[k] += s['usd']
print('%-14s %6s %6s %6s %6s %6s %5s %5s %7s %7s' % ('phase', 'wall', 'active', 'opgap', 'agentg', 'asks', 'spawn', 'agmin', 'usd', 'start'))
for i in range(n):
    print('%-14s %6.0f %6.0f %6.0f %6.0f %6d %5d %5.0f %7.2f %s' % (labels[i], wall[i] / 60, act[i] / 60, opg[i] / 60, agg[i] / 60, nask[i], ns[i], sm[i], su[i], starts[i][5:16]))
print('TOTAL wall %.1f h active %.1f h opgap %.1f h agentgap %.1f h; spawns %d usd %.2f' % (sum(wall) / 3600, sum(act) / 3600, sum(opg) / 3600, sum(agg) / 3600, sum(ns), sum(su)))
