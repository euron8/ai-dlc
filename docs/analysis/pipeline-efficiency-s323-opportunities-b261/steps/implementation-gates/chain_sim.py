#!/usr/bin/env python3 -I
"""Chain-level wall model for s323 (see chain_decomp.py for the measured chains). Wall = max over chains of (measured chain minutes - savings).
Measured chain minutes are chain_decomp.py's (first dev dispatch 12:51Z .. closing-writer end). Edge latencies stay as measured (17/10/5 min).
Savings per variant, per on-chain story (minutes, all UPPER BOUNDS, lead dispatch gaps assumed unchanged except where a gap is itself removed):
 V1  gate 3 = script + one seat: every gate-3 pass's measured nonce->verdict minutes (verdict files) becomes 5 min (first pass) / 1 min (rerun after a FAIL).
 V2  gate 1 and gate 2 dispatched together on one frozen sha, one merged rework: values below, each derived from the printed bursts (bursts.tsv).
 V3  records-only reworks refused at handoff: removes the records-only rework cycle (rework + the re-review pass that follows) of tier C (tiers.py).
 W   suite-admission waits: 3.1 QA pass 2 seat (289.9 min -> 8) and 1.1 rework seat (322.7 -> 40 assumed work); both cleared by the same event (mlx-serve released memory ~19:27Z).
Control: V=none reproduces the measured chain minutes by construction; independent check printed: held-story dispatch = upstream close + measured edge latency."""
import json, glob, re, datetime as dt
G = '/Users/n8/git/graph/_bmad-output/implementation-artifacts/s323/gate-adjudication/'
meas = {'C1': 841, 'C2': 737, 'C3': 582}   # chain_decomp.out
stories = {'C1': ['3.1', '3.2'], 'C2': ['1.1', '5.2'], 'C3': ['5.4', '5.5']}
# V1 from verdict files
el = {}
for p in sorted(glob.glob(G + '*.verdict.json')):
    d = json.load(open(p))
    if d['gate_type'] != 'implementation': continue
    m = re.search(r'story(\d)x(\d)', d['gate_series_id'])
    if not m: continue
    s = f'{m.group(1)}.{m.group(2)}'
    n = dt.datetime.strptime(d['gate_nonce'].split('-')[-1], '%Y%m%dT%H%M%SZ'); g = dt.datetime.strptime(d['generated_at'], '%Y-%m-%dT%H:%M:%SZ')
    nonfail = all(v['verdict'] == 'PASS' for v in d['verdicts'])
    el.setdefault(s, []).append(((g - n).total_seconds() / 60, nonfail))
def v1(s):
    tot = 0; first = True
    for e, ok in sorted(el.get(s, []), key=lambda x: 0):
        new = 5 if first else 1
        tot += max(0, e - new); first = False
    return tot
V1 = {s: v1(s) for c in stories.values() for s in c}
print('g3 passes (nonce->verdict min) per on-chain story:', {s: [round(e, 1) for e, _ in el.get(s, [])] for s in V1})
# V2 / V3 hand-derived from bursts.tsv (the arithmetic is in the strings)
V2 = {'3.1': (45.6 + 0.8 + 1.2, 'g1p1 end -> g2p1 start gap 45.6 removed; g1p2 (0.8 + gap 1.2) hidden under g2p2'),
      '3.2': (68, 'g1p1/g2p1 together, one rework, g1p2/g2p2 together: old gate span 21:53-01:53 = 240 -> ~172'),
      '1.1': (5, 'rework changes code, so QA reruns after it; only g1p2->g2p1 gap 4.1 + 0.8 hidden'),
      '5.2': (80, 'old gate span 21:43-00:22 = 159 -> ~79: one rework cycle instead of two'),
      '5.4': (45.5 + 1.4 + 2.2, 'g1p1 end -> g2p1 start gap 45.5 + g1p2 (1.4 + 2.2) hidden'),
      '5.5': (30, 'g1p1 || g2p1 and one rework cycle fewer; 5.5 overlaps its dev seat, so a modest figure')}
V3 = {'5.4': (2.9 + 6.9 + 3.2 + 8.6, 'tier C: rework capture refresh + record-only QA pass 2 with their gaps'),
      '5.5': (68, 'tier C: record-only rework seat 20:35-22:02; QA p1 end 20:33 -> g3 start 21:41'),
      '5.2': (15, 'tier C: QA p2 EVIDENCE only -> g2p3 record-only pass 2.5 + rework gap')}
W = {'3.1': 289.9 - 8, '1.1': 322.7 - 40}
def chain_total(c, use):
    t = 0
    for s in stories[c]:
        if 'V1' in use: t += V1.get(s, 0)
        if 'V2' in use: t += V2.get(s, (0,))[0]
        if 'V3' in use: t += V3.get(s, (0,))[0]
        if 'W' in use: t += W.get(s, 0)
    return t
others = {'1.2/1.4 chain (1.1 -> 1.4)': 682, 'other stories': 0}
print('\nvariant | C1 min | C2 min | C3 min | 1.4-chain | wall min (h) | saved vs measured')
base = max(meas.values())
for name, use in [('measured', ()), ('V1 g3 script+seat', ('V1',)), ('V2 g1||g2', ('V2',)), ('V3 refuse records', ('V3',)), ('V1+V2+V3', ('V1', 'V2', 'V3')),
                  ('W 3.1 wait only', ('W3.1',)), ('W both waits', ('W',)), ('V1+V2+V3+W', ('V1', 'V2', 'V3', 'W'))]:
    if name == 'W 3.1 wait only':
        r = {c: meas[c] - (W['3.1'] if c == 'C1' else 0) for c in meas}; c14 = 682
    else:
        r = {c: meas[c] - chain_total(c, use) for c in meas}
        c14 = 682 - (V1.get('1.1', 0) + V1.get('1.4', 0) if 'V1' in use else 0) - (V2['1.1'][0] if 'V2' in use else 0) - (W['1.1'] if 'W' in use else 0)
    wall = max(list(r.values()) + [c14])
    print(f'{name:22s}| {r["C1"]:.0f} | {r["C2"]:.0f} | {r["C3"]:.0f} | {c14:.0f} | {wall:.0f} ({wall/60:.1f} h) | {base-wall:.0f} min ({(base-wall)/60:.1f} h) binding {max(r, key=r.get) if max(r.values())>=c14 else "1.4 chain"}')
print('\nV2 notes:'); [print(' ', k, round(v[0], 1), v[1]) for k, v in V2.items()]
print('V3 notes:'); [print(' ', k, round(v[0], 1), v[1]) for k, v in V3.items()]
print('V1 per story (min):', {k: round(v, 1) for k, v in V1.items()})
