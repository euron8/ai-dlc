#!/usr/bin/env python3 -I
"""Natural-control probe: for each compaction segment, successful Agent dispatches in its FIRST 20 actions after the first
successful dispatch/write; flag a dispatch whose (subagent_type, description) equals a successful dispatch in the PREVIOUS
segment of the same session (re-dispatch of work already out before the compaction). Compare groups by advisor timing."""
import json, sys, collections
sys.path.insert(0, '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/advisor-r-value')
src = open(sys.path[0] + '/seg.py').read().replace('\nmain()\n', '\n')
ns = {}; exec(compile(src, 'seg', 'exec'), ns)
load, events, OUT = ns['load'], ns['events'], ns['OUT']
S = json.load(open(OUT + 'segs.json')); TB = json.load(open(OUT + 'table.json'))
cache = {}; res_rows = []
def dispatches(seg, res, limit=None):
    out = []
    for e in seg:
        if e['kind'] == 'use' and e['name'] == 'Agent':
            r = res.get(e['id'])
            if r and r.get('err'): continue
            i = e.get('inp') or {}
            out.append(((i.get('subagent_type'), (i.get('description') or '').strip()), e['ln']))
    return out
for k, (s, t) in enumerate(zip(S, TB)):
    if s['sess'] not in cache:
        f, rows = load(s['sess']); ev = events(rows); cache[s['sess']] = (ev, {e['id']: e for e in ev if e['kind'] == 'res'}, [i for i, e in enumerate(ev) if e['kind'] == 'COMPACT'])
    ev, res, cidx = cache[s['sess']]
    n = s['n']
    a = cidx[n] + 1; b = cidx[n + 1] if n + 1 < len(cidx) else len(ev)
    seg = ev[a:b]
    prev = ev[(cidx[n - 1] + 1 if n > 0 else 0):cidx[n]]
    pd = set(d for d, _ in dispatches(prev, res))
    cur = dispatches(seg, res)
    dup = [(d, ln) for d, ln in cur if d in pd and d[1]]
    res_rows.append(dict(sess=s['sess'], n=n, pop=t['pop'], ndisp=len(cur), ndup=len(dup), dups=[(d[0], d[1][:60], ln) for d, ln in dup][:4]))
json.dump(res_rows, open(OUT + 'dupdispatch.json', 'w'))
g = collections.defaultdict(lambda: [0, 0, 0, 0])
for r in res_rows:
    x = g[r['pop']]; x[0] += 1; x[1] += r['ndisp']; x[2] += r['ndup']; x[3] += 1 if r['ndup'] else 0
for k, x in g.items(): print(k, 'segs', x[0], 'dispatches', x[1], 'repeat-of-prev-segment', x[2], 'segs with >=1', x[3])
for r in res_rows:
    if r['ndup'] and r['pop'] != 'advisor before first dispatch/write': print(r['sess'][:4], r['n'], r['pop'][:30], r['dups'])
