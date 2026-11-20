"""A3: per-story gaps in which no agent of that story runs and the next dispatch is owed, s323 implementation window.
Story id = first N.M in the spawn description (build reader's rule; unnamed dev seats are dropped and counted).
Phase by role: B dev/dev-escalated, G1 code-reviewer*, G2 qa, G3 gate-adjudicator, C closing writer, R remediator.
Gap = start of next block - end of previous block, blocks = union of the story's spawn intervals (merged when they overlap).
Type = (phase of the spawn that ends last in the previous block, phase of the spawn that starts first in the next block)."""
import json, re, collections, statistics, sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from lib import *
W = [('2026-11-18T12:45:00Z', '2026-11-19T03:10:00Z'), ('2026-11-19T12:49:00Z', '2026-11-19T14:04:00Z')]
sp = [json.loads(l) for l in open(MONO + 'spawns.jsonl')]
PH = {'dev': 'B', 'dev-escalated': 'B', 'code-reviewer': 'G1', 'code-reviewer-escalated': 'G1', 'qa': 'G2', 'gate-adjudicator': 'G3', 'remediator': 'R', 'pre-reviewer': 'G1'}
by = collections.defaultdict(list); drop = 0
for s in sp:
    if s['sprint'] != 323 or not any(a <= s['start'] <= b for a, b in W): continue
    ph = PH.get(s['role'])
    if not ph: continue
    m = re.search(r'(?<![\d.])([1-5])[.-]([1-9])(?![\d.])', s['description'])
    if not m: drop += 1; continue
    if 'closing writer' in s['description'].lower(): ph = 'C'
    by[m.group(1) + '.' + m.group(2)].append((T(s['start']), T(s['end']), ph))
gaps = collections.defaultdict(list)
for st, L in sorted(by.items()):
    L.sort()
    blocks = []
    for a, b, ph in L:
        if blocks and a <= blocks[-1]['end']:
            if b > blocks[-1]['end']: blocks[-1]['end'] = b; blocks[-1]['last'] = ph
        else: blocks.append(dict(start=a, end=b, first=ph, last=ph))
    for x, y in zip(blocks, blocks[1:]):
        gaps[(x['last'], y['first'])].append((y['start'] - x['end'], st))
print('stories', len(by), 'unnamed-story spawns dropped', drop)
allg = []
for k in sorted(gaps, key=lambda k: -sum(g for g, _ in gaps[k])):
    v = [g for g, _ in gaps[k]]; allg += v
    print(f'{k[0]:>2} -> {k[1]:<2} n={len(v):3d} median {statistics.median(v)/60:6.1f} min  p90 {sorted(v)[int(.9*(len(v)-1))]/60:6.1f}  >10min {sum(1 for g in v if g > 600):3d}  >60min {sum(1 for g in v if g > 3600):2d} sum {sum(v)/3600:5.2f} h  sum capped600 {sum(min(g,600) for g in v)/3600:5.2f} h')
print(f'ALL n={len(allg)} median {statistics.median(allg)/60:.1f} min >10min {sum(1 for g in allg if g>600)} sum {sum(allg)/3600:.2f} h capped600 {sum(min(g,600) for g in allg)/3600:.2f} h')
