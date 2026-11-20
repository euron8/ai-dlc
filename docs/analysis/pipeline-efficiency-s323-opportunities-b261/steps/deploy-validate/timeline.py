#!/usr/bin/env python3
# timeline.py SESSION_ID START_ISO END_ISO  -> compact event timeline of a lead transcript window.
# Events: human text (user msgs not tool_result), AskUserQuestion, Agent spawns (description), Bash (first 110 chars),
# gaps >=GAP seconds between consecutive timestamped records. Read only.
import json, sys, os
from datetime import datetime
sess, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
GAP = float(os.environ.get('GAP', '300'))
p = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/%s.jsonl' % sess)
def ts(s): return datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S')
prev = None
out = []
for l in open(p):
    try: d = json.loads(l)
    except Exception: continue
    t = d.get('timestamp')
    if not t or t < a or t > b: continue
    ty = d.get('type')
    if ty not in ('user', 'assistant'): continue
    if prev is not None:
        g = (ts(t) - ts(prev)).total_seconds()
        if g >= GAP: out.append((prev, 'GAP', '%.0f min' % (g / 60)))
    prev = t
    m = d.get('message', {})
    c = m.get('content')
    if ty == 'user':
        if isinstance(c, str):
            out.append((t, 'HUMAN', c[:300].replace('\n', ' ')))
        else:
            for x in c or []:
                if x.get('type') == 'text' and not d.get('isMeta'):
                    out.append((t, 'HUMAN?', x['text'][:300].replace('\n', ' ')))
    else:
        for x in c or []:
            if x.get('type') == 'tool_use':
                n = x['name']; i = x.get('input', {})
                if n == 'Agent': out.append((t, 'SPAWN', (i.get('subagent_type') or '') + ' | ' + (i.get('description') or '')))
                elif n == 'AskUserQuestion': out.append((t, 'ASK', json.dumps(i)[:400]))
                elif n == 'Bash': out.append((t, 'bash', (i.get('command') or '')[:110].replace('\n', ' ')))
                elif n.startswith('mcp__plugin_context-mode'): out.append((t, 'ctx', (i.get('code') or json.dumps(i))[:90].replace('\n', ' ')))
                else: out.append((t, n, json.dumps(i)[:90]))
for e in out: print(e[0][5:19], e[1], e[2])
