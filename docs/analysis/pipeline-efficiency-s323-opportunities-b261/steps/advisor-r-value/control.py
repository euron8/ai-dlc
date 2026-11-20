#!/usr/bin/env python3 -I
"""Control view: compactions where no advisor call preceded the first successful dispatch/write.
For each, the 20 tool actions from the first ok dispatch/write on, flagged for denial/error on Agent/Write/Edit and for
correction-cue lead text. Out: control.json + printed flagged view."""
import json, re, sys
sys.path.insert(0, '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/advisor-r-value')
src = open(sys.path[0] + '/seg.py').read().replace('\nmain()\n', '\n')
ns = {}; exec(compile(src, 'seg', 'exec'), ns)
load, events, OUT = ns['load'], ns['events'], ns['OUT']
S = json.load(open(OUT + 'segs.json')); TB = json.load(open(OUT + 'table.json'))
CUE = re.compile(r"\b(wrong|mistake|oops|my error|typo|invented|stale|redo|re-do|re-?dispatch|duplicate|already (dispatched|delivered|done|written|exist)|reverting|revert|undo|did not|didn.t (run|land|write)|correct(ing|ion)|actually|missed|forgot|not what)\b", re.I)
cache = {}; out = []
for s, t in zip(S, TB):
    if t['pop'] not in ('dispatch/write first, advisor later', 'dispatch/write, no advisor in segment') and not t['pop'].startswith('no dispatch'): continue
    if s['sess'] not in cache:
        f, rows = load(s['sess']); ev = events(rows); cache[s['sess']] = (ev, {e['id']: e for e in ev if e['kind'] == 'res'})
    ev, res = cache[s['sess']]
    ci = next(i for i, e in enumerate(ev) if e['kind'] == 'COMPACT' and e['ln'] == s['cln'])
    end = next((i for i in range(ci + 1, len(ev)) if ev[i]['kind'] == 'COMPACT'), len(ev))
    seg = ev[ci + 1:end]
    fo = s['first_ok']
    start = fo['j'] if fo else 0
    acts, flags, says = [], [], []
    n = 0
    for e in seg[start:]:
        if e['kind'] == 'use':
            r = res.get(e['id']); bad = bool(r and r.get('err')); n += 1
            adv = e['name'] in ('advisor', 'mcp__advisor__consult')
            acts.append((e['ln'], e['name'], bad, adv))
            if bad and e['name'] in ('Agent', 'Write', 'Edit'): flags.append('DENIED %s ln%d: %s' % (e['name'], e['ln'], (r['text'][:110]).replace('\n', ' ')))
            if adv: flags.append('ADVISOR at action %d (ln%d)' % (n, e['ln']))
            if n >= 20: break
        elif e['kind'] in ('text', 'think') and e['role'] == 'assistant' and n < 20:
            m = CUE.search(e['text'])
            if m and e['kind'] == 'text': says.append('ln%d: ...%s...' % (e['ln'], re.sub(r'\s+', ' ', e['text'][max(0, m.start() - 70):m.end() + 90])))
    out.append(dict(sess=s['sess'], n=s['n'], pop=t['pop'], first=(fo['name'], fo['ln']) if fo else None, nact=n, flags=flags, says=says[:3]))
json.dump(out, open(OUT + 'control.json', 'w'))
print(len(out))
