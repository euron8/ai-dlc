#!/usr/bin/env python3 -I
"""Per-story gate seat timeline for one sprint (default 323) from MONO/spawns.jsonl.
Gate map: role code-reviewer/-escalated in step implementation|gate-validation[implementation] -> g1; qa in those steps -> g2;
gate-adjudicator in gate-validation[implementation] (or implementation) -> g3; dev/dev-escalated/remediator in gate-validation[implementation] -> rework.
Story id parsed from description (first N.M or 'story N-M'); unparsed rows reported (must be few).
Output: seat_timeline.<sprint>.tsv rows story gate wave_idx n_seats start end wall_min seat_min usd, plus summary per gate:
union wall (min), sum seat-min, sum $, waves.   Waves = seats whose start is within 10 min of the previous seat's end of the same story+gate.
Control: sprint 999 -> 0 spawns."""
import json, re, sys, collections, datetime as dt
SC = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/'
sp = int(sys.argv[1]) if len(sys.argv) > 1 else 323
T = lambda s: dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
rows = [json.loads(l) for l in open(SC + 'MONO/spawns.jsonl')]
print('control sprint 999 spawns:', sum(1 for r in rows if r['sprint'] == 999), '(must be 0)')
IMPL = ('implementation', 'gate-validation[implementation]')
def gate(r):
    if r['step'] not in IMPL: return None
    ro = r['role']
    if ro in ('code-reviewer', 'code-reviewer-escalated'): return 'g1'
    if ro == 'qa': return 'g2'
    if ro == 'gate-adjudicator': return 'g3'
    if ro in ('dev', 'dev-escalated', 'remediator', 'protected-path-editor') and r['step'] == 'gate-validation[implementation]': return 'rework'
    if ro in ('dev', 'dev-escalated'): return 'build'
    return None
def story(d):
    m = re.search(r'(?:story\s*)?(\d+)[.-](\d+)', d or '')
    return f'{m.group(1)}-{m.group(2)}' if m else '?'
sel = [r for r in rows if r['sprint'] == sp and gate(r)]
unp = collections.Counter(gate(r) for r in sel if story(r['description']) == '?')
print('spawns', len(sel), 'unparsed story by gate', dict(unp))
by = collections.defaultdict(list)
for r in sel: by[(story(r['description']), gate(r))].append(r)
out = open(f'{SC}steps/implementation-gates/seat_timeline.{sp}.tsv', 'w')
tot = collections.defaultdict(lambda: [0, 0.0, 0.0, 0])
allint = collections.defaultdict(list)
for (st, g), rs in sorted(by.items()):
    rs.sort(key=lambda r: r['start'])
    waves = []; cur = []; cend = 0
    for r in rs:
        s, e = T(r['start']), T(r['end'])
        if cur and s - cend > 600: waves.append(cur); cur = []
        cur.append(r); cend = max(cend, e) if cur[:-1] else e
    if cur: waves.append(cur)
    for i, w in enumerate(waves):
        s = min(T(r['start']) for r in w); e = max(T(r['end']) for r in w)
        out.write('\t'.join([st, g, str(i + 1), str(len(w)), w[0]['start'], w[-1]['end'], f'{(e - s) / 60:.1f}', f"{sum(r['minutes'] or 0 for r in w):.1f}", f"{sum(r['usd'] or 0 for r in w):.2f}"]) + '\n')
        t = tot[g]; t[0] += len(w); t[1] += (e - s) / 60; t[2] += sum(r['usd'] or 0 for r in w); t[3] += 1
        allint[g].append((s, e))
def union(iv):
    iv.sort(); m = 0; cs, ce = None, None
    for s, e in iv:
        if ce is None or s > ce:
            if ce is not None: m += ce - cs
            cs, ce = s, e
        else: ce = max(ce, e)
    return (m + (ce - cs)) / 60 if ce is not None else 0
print('gate: seats, waves, sum wave-wall min, union wall min (all stories), $')
for g in ('build', 'g1', 'g2', 'g3', 'rework'):
    t = tot[g]; print(g, t[0], t[3], round(t[1]), round(union(allint[g])), round(t[2], 1))
