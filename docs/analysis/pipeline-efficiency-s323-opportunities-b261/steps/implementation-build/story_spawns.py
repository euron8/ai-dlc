#!/usr/bin/env python3
"""s323 per-story spawn table from MONO/spawns.jsonl, window = implementation session windows (lead 53b4296a
11-18T12:45Z..11-19T03:10Z and 64926214 11-19T12:49Z..14:04Z). Story id = first N.M in description (None -> '-').
Prints role x story: n, wall minutes, usd. Also writes story_spawns.tsv.
"""
import json, re, collections
M = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
D = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/implementation-build/'
W = [('2026-11-18T12:45:00Z', '2026-11-19T03:10:00Z'), ('2026-11-19T12:49:00Z', '2026-11-19T14:04:00Z')]
rows = [json.loads(l) for l in open(M + 'spawns.jsonl')]
sel = []
for r in rows:
    if int(r['sprint']) != 323: continue
    if any(a <= r['start'] <= b for a, b in W):
        m = re.search(r'(\d)\.(\d)', r['description'])
        r['story'] = m.group(0) if m else '-'
        sel.append(r)
sel.sort(key=lambda r: r['start'])
with open(D + 'story_spawns.tsv', 'w') as o:
    o.write('start\tend\trole\tstory\tmin\tcalls\tusd\ttok\tout\tdesc\n')
    for r in sel:
        o.write('\t'.join(map(str, [r['start'], r['end'], r['role'], r['story'], r['minutes'], r['calls'], r['usd'], r['tok'], r['out'], r['description']])) + '\n')
tab = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0.0, 0.0]))
for r in sel:
    a = tab[r['story']][r['role']]
    a[0] += 1; a[1] += float(r['minutes']); a[2] += float(r['usd'])
roles = sorted({r['role'] for r in sel})
print('spawns in window:', len(sel), 'usd', round(sum(float(r['usd']) for r in sel), 1))
print('story'.ljust(6), ' | '.join(x[:10].ljust(14) for x in roles))
for s in sorted(tab):
    print(s.ljust(6), ' | '.join((('%dx %dm $%.1f' % (tab[s][x][0], tab[s][x][1], tab[s][x][2])) if x in tab[s] else '').ljust(14) for x in roles))
tot = collections.defaultdict(lambda: [0, 0.0, 0.0])
for r in sel:
    a = tot[r['role']]; a[0] += 1; a[1] += float(r['minutes']); a[2] += float(r['usd'])
print()
for k, v in sorted(tot.items(), key=lambda kv: -kv[1][2]): print(k.ljust(26), v[0], round(v[1]), round(v[2], 1))
