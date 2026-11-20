#!/usr/bin/env python3
# bashcls.py SESSION A B -> classify ok (non-error) Bash calls by purpose (first matching rule), with count and total tool latency
# (tool_use->tool_result timestamp delta); also total latency of all tools vs. window, and the 15 slowest calls.
import json, sys, os, re, collections
from datetime import datetime
sess, a, b = sys.argv[1:4]
p = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/%s.jsonl' % sess)
def ts(s): return datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S') + __import__('datetime').timedelta(milliseconds=int(s[20:23]) if len(s) > 22 and s[19] == '.' else 0)
uses = {}; results = {}
for l in open(p):
    try: d = json.loads(l)
    except Exception: continue
    t = d.get('timestamp'); c = d.get('message', {}).get('content')
    if not t or not isinstance(c, list): continue
    for x in c:
        if x.get('type') == 'tool_use' and a <= t <= b: uses[x['id']] = (t, x['name'], x.get('input', {}))
        if x.get('type') == 'tool_result': results[x['tool_use_id']] = (t, bool(x.get('is_error')))
RULES = [
 ('snapshot-update', r'snapshot-update\.sh'),
 ('aws logs', r'aws logs'),
 ('aws ecs/ssm/other', r'\baws\b'),
 ('gh pr/api', r'\bgh\b'),
 ('git', r'\bgit\b'),
 ('wait/until loop', r'\buntil\b|wait-for|sleep'),
 ('curl/api probe', r'\bcurl\b|apiread|ssm-tunnel|psql'),
 ('smoke/test run', r'smoke|pytest|playwright|npm'),
 ('gate/validate script', r'gate-|validate-|check-stories'),
 ('grep/sed/cat/ls/wc/head', r'\b(grep|sed|cat|ls|wc|head|tail|awk|find|diff|cmp|test)\b'),
]
cls = collections.defaultdict(lambda: [0, 0.0]); slow = []
tot = collections.defaultdict(float)
for i, (t, n, inp) in uses.items():
    r = results.get(i)
    if not r or r[1]: continue
    dt = (ts(r[0]) - ts(t)).total_seconds()
    tot[n] += dt
    if n != 'Bash': continue
    cmd = inp.get('command') or ''
    k = 'other'
    for name, rx in RULES:
        if re.search(rx, cmd): k = name; break
    cls[k][0] += 1; cls[k][1] += dt
    slow.append((dt, cmd[:130].replace('\n', ' ')))
print('BASH by purpose (n, total_s):', {k: (v[0], round(v[1])) for k, v in sorted(cls.items(), key=lambda kv: -kv[1][1])})
print('TOOL latency total s by tool:', {k: round(v) for k, v in sorted(tot.items(), key=lambda kv: -kv[1])[:8]}, 'ALL', round(sum(tot.values())))
for dt, c in sorted(slow, reverse=True)[:12]: print('  %5.0fs %s' % (dt, c))
