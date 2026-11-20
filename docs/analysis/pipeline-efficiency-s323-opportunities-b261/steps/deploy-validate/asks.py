#!/usr/bin/env python3
# asks.py SESSION A B -> one TSV row per AskUserQuestion in window: ts, wait_min, header, question(first 160), options, answer(first 200)
import json, sys, os
from datetime import datetime
sess, a, b = sys.argv[1:4]
p = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/%s.jsonl' % sess)
def ts(s): return datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S')
asks = {}; res = {}
for l in open(p):
    try: d = json.loads(l)
    except Exception: continue
    t = d.get('timestamp')
    if not t: continue
    c = d.get('message', {}).get('content')
    if not isinstance(c, list): continue
    for x in c:
        if x.get('type') == 'tool_use' and x.get('name') == 'AskUserQuestion' and a <= t <= b:
            asks[x['id']] = (t, x['input'])
        if x.get('type') == 'tool_result' and x.get('tool_use_id') in asks or (x.get('type') == 'tool_result' and x.get('tool_use_id') in res):
            pass
        if x.get('type') == 'tool_result':
            cc = x.get('content')
            if isinstance(cc, list): cc = ' '.join(y.get('text', '') for y in cc if isinstance(y, dict))
            res[x['tool_use_id']] = (t, str(cc))
for i, (t, inp) in asks.items():
    qs = inp.get('questions', [])
    q = qs[0] if qs else {}
    r = res.get(i)
    w = (ts(r[0]) - ts(t)).total_seconds() / 60 if r else -1
    opts = ' / '.join(o.get('label', '') for o in q.get('options', []))
    print('\t'.join([t[5:19], '%.1f' % w, str(len(qs)), q.get('header', ''), q.get('question', '')[:170].replace('\n', ' '), opts[:160], (r[1] if r else 'NO RESULT')[:220].replace('\n', ' ')]))
