#!/usr/bin/env python3 -I
"""Join segs.json (134 compactions), dossiers.json (116 first advisor results) and cls.json (hand classes) with the
extraction's step segments. Writes table.tsv and prints counts."""
import json, collections, re
from datetime import datetime
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/'
D = B + 'steps/advisor-r-value/'
T = lambda s: datetime.fromisoformat(s.replace('Z', '+00:00'))
S = json.load(open(D + 'segs.json')); DS = json.load(open(D + 'dossiers.json')); C = json.load(open(D + 'cls.json'))
segs = [json.loads(l) for l in open(B + 'MONO/segs.jsonl')]
L = [s for s in segs if s['kind'] == 'lead' and s['sprint'] == 323]
def step_of(sess, ts):
    t = T(ts)
    for s in L:
        if s['sess'][:8] == sess and T(s['first']) <= t <= T(s['last']):
            return re.sub(r'^gate-validation\[(.*)\]$', r'\1', s['step'])
    return 'UNMAPPED'
dmap = {(d['sess'], d['n']): (i, d) for i, d in enumerate(DS)}
rows = []
for s in S:
    key = (s['sess'], s['n']); fo = s['first_ok']
    ok = [x for x in s['advs'] if not x['err']]
    pre = [x for x in s['advs'] if fo is None or x['j'] < fo['j']]
    pre_ok = [x for x in pre if x in ok]
    if fo is None: pop = 'no dispatch/write before next compaction' + (' (advisor called)' if ok else ' (no advisor)')
    elif pre_ok: pop = 'advisor before first dispatch/write'
    elif ok: pop = 'dispatch/write first, advisor later'
    else: pop = 'dispatch/write, no advisor in segment'
    i, d = dmap.get(key, (None, None)); c = C.get(str(i)) if i is not None else None
    rows.append(dict(sess=s['sess'], n=s['n'], ts=s['cts'], step=step_of(s['sess'], s['cts']), pop=pop, idx=i,
                     secs=(d['secs'] if d else None), cls=(c['cls'] if c else ''), err=(c['err'] if c else ''), ev=(c['ev'] if c else ''),
                     n_adv=len(s['advs']), denied_attempts=(d['denied_attempts'] if d else 0), adv_ln=(d['adv_ln'] if d else None)))
json.dump(rows, open(D + 'table.json', 'w'))
with open(D + 'table.tsv', 'w') as f:
    f.write('ts\tsess\tcompaction#\tstep\tpopulation\tadv_ln\tsecs\tclass\terr_type\tevidence\n')
    for r in rows:
        f.write('\t'.join(str(x) for x in (r['ts'][:19], r['sess'], r['n'], r['step'], r['pop'], r['adv_ln'] or '', int(r['secs']) if r['secs'] is not None else '', r['cls'], r['err'], r['ev'])) + '\n')
print('rows', len(rows))
print(collections.Counter(r['pop'] for r in rows))
print(collections.Counter(r['step'] for r in rows))
