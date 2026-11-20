#!/usr/bin/env python3
# leadtime.py SESSION A B -> lead active seconds (intervals <=300 s ending at an assistant record) attributed to the
# category of the FIRST tool_use in that assistant message (interval = prior record -> this record = generation + prior tool).
# Categories by regex over command/tool. Approximation (control: sum must be near segs active for the window).
import json, sys, os, re, collections
from datetime import datetime
sess, a, b = sys.argv[1:4]
p = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/%s.jsonl' % sess)
def ts(s): return datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S') + __import__('datetime').timedelta(milliseconds=int(s[20:23]) if len(s) > 22 and s[19] == '.' else 0)
def cat(n, i):
    if n == 'Bash':
        c = i.get('command') or ''
        if re.search(r'git\s+(-C\s+\S+\s+)?(add|commit|push)', c): return 'git commit/push (evidence, cont records)'
        if re.search(r'snapshot-update\.sh', c): return 'snapshot-update.sh (pipeline-snapshot)'
        if re.search(r'wait-for-deliverable|until |sleep ', c): return 'wait loops'
        if re.search(r'\baws\b|ssm|apiread|prefire|lockread|psql|curl', c): return 'live probes (aws/ssm/api)'
        if re.search(r'gate-|validate-|check-stories|sprint-status', c): return 'gate/validate scripts'
        if re.search(r'\bgit\b', c): return 'git read (log/show/diff/status)'
        if re.search(r'\bgh\b', c): return 'gh pr'
        return 'bash read (grep/sed/cat/tail...)'
    if n in ('Edit', 'Write'):
        f = os.path.basename(i.get('file_path', ''))
        if 'gate-log' in f: return 'edit gate-log'
        if f.startswith('s323') or 'brief' in f or f.endswith(('.sh', '.py')): return 'write briefs/scripts'
        return 'edit/write other artifacts'
    if n == 'Read': return 'Read'
    if n.startswith('mcp__plugin_context-mode'): return 'ctx_execute/search'
    if 'advisor' in n: return 'advisor'
    if n in ('Agent', 'SendMessage'): return 'dispatch'
    if n == 'AskUserQuestion': return 'AskUserQuestion'
    return 'other:' + n
tot = collections.defaultdict(float); cnt = collections.Counter()
# group assistant records by message.id; generation interval = last non-assistant record time -> last record of the message
recs = []
for l in open(p):
    try: d = json.loads(l)
    except Exception: continue
    t = d.get('timestamp')
    if not t or d.get('type') not in ('user', 'assistant') or not (a <= t <= b): continue
    recs.append(d)
last_user = None; groups = collections.OrderedDict()
for d in recs:
    t = d['timestamp']
    if d['type'] == 'user': last_user = t; continue
    mid = d.get('message', {}).get('id') or d.get('uuid')
    g = groups.setdefault(mid, {'start': last_user, 'end': t, 'tu': []})
    g['end'] = max(g['end'], t)
    for x in d.get('message', {}).get('content') or []:
        if isinstance(x, dict) and x.get('type') == 'tool_use': g['tu'].append(x)
for mid, g in groups.items():
    if g['start'] is None: continue
    dt = (ts(g['end']) - ts(g['start'])).total_seconds()
    k = cat(g['tu'][0]['name'], g['tu'][0].get('input', {})) if g['tu'] else 'text-only (no tool)'
    cnt[k] += 1
    if dt <= 300: tot[k] += dt
T = sum(tot.values())
print('total attributed active min %.0f' % (T / 60))
for k, v in sorted(tot.items(), key=lambda kv: -kv[1]): print('  %-42s %5.1f min %4d calls %4.1f s/call' % (k, v / 60, cnt[k], v / max(1, cnt[k])))
