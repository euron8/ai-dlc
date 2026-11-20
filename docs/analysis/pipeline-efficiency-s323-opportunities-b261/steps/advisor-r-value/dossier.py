#!/usr/bin/env python3 -I
"""Per first-advisor-call-in-segment dossier: lead activity since compaction, advice, next 10 actions.
Writes dossiers.json (list) and dossiers.txt. Reuses seg.py loaders (copy of functions via import)."""
import json, sys, re
sys.path.insert(0, '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/advisor-r-value')
import importlib.util
src = open(sys.path[0] + '/seg.py').read().replace('\nmain()\n', '\n')
ns = {}; exec(compile(src, 'seg', 'exec'), ns)
load, events, ADV, GATE, OUT = ns['load'], ns['events'], ns['ADV'], ns['GATE'], ns['OUT']
S = json.load(open(OUT + 'segs.json'))
def short(e, n=110):
    i = e.get('inp') or {}
    if e['name'] == 'Bash': s = i.get('command', '')
    elif e['name'] in ('Read', 'Write', 'Edit'): s = i.get('file_path', '').replace('/Users/n8/git/graph/', '') + (' off=%s lim=%s' % (i.get('offset'), i.get('limit')) if e['name'] == 'Read' else '')
    elif e['name'] == 'Agent': s = '%s | %s' % (i.get('subagent_type'), (i.get('description') or '')[:60])
    else: s = json.dumps(i)
    return e['name'] + ': ' + re.sub(r'\s+', ' ', s)[:n]
cache = {}
D = []
for s in S:
    if not s['advs']: continue
    if s['sess'] not in cache:
        f, rows = load(s['sess']); ev = events(rows); cache[s['sess']] = (ev, {e['id']: e for e in ev if e['kind'] == 'res'})
    ev, res = cache[s['sess']]
    ci = next(i for i, e in enumerate(ev) if e['kind'] == 'COMPACT' and e['ln'] == s['cln'])
    ok = [x for x in s['advs'] if not x['err']]
    if not ok: continue
    a = ok[0]; den = len(s['advs']) - len(ok)
    ai = next(i for i, e in enumerate(ev) if e['kind'] == 'use' and e['ln'] == a['ln'] and e['name'] in ADV)
    pre = ev[ci + 1:ai]
    lines = []
    for e in pre:
        if e['kind'] == 'think': lines.append('THINK: ' + re.sub(r'\s+', ' ', e['text'])[:700])
        elif e['kind'] == 'text' and e['role'] == 'assistant': lines.append('SAY: ' + re.sub(r'\s+', ' ', e['text'])[:500])
        elif e['kind'] == 'use':
            r = res.get(e['id']); d = ' [DENIED/ERR]' if r and r.get('err') else ''
            lines.append(short(e, 90) + d)
    # result index
    ri = next((i for i, e in enumerate(ev) if e['kind'] == 'res' and e['ln'] == a['res_ln'] and e['id'] == ev[ai]['id']), ai)
    post = []
    n = 0
    for e in ev[ri + 1:]:
        if e['kind'] == 'COMPACT': post.append('--COMPACT--'); break
        if e['kind'] == 'text' and e['role'] == 'assistant': post.append('SAY: ' + re.sub(r'\s+', ' ', e['text'])[:350])
        elif e['kind'] == 'use':
            r = res.get(e['id']); d = ' [DENIED/ERR]' if r and r.get('err') else ''
            post.append(short(e, 130) + d); n += 1
            if n >= 10: break
    in_r = s['first_ok'] is None or a['j'] < s['first_ok']['j']
    D.append(dict(denied_attempts=den, sess=s['sess'], n=s['n'], cts=s['cts'], cln=s['cln'], adv_ln=a['ln'], secs=a['secs'], err=a['err'],
                  before_first_ok=in_r, first_ok=s['first_ok'], pre=lines, advice=a['text'], post=post))
json.dump(D, open(OUT + 'dossiers.json', 'w'))
print(len(D), 'dossiers', sum(d['before_first_ok'] for d in D), 'before first ok gate')
