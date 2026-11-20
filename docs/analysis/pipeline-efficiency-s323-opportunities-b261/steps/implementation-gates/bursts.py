#!/usr/bin/env python3 -I
"""Per-story ordered bursts for s323 from MONO/spawns.jsonl (read only). A spawn belongs to a story when its description names N.M
(a leading '323-' is stripped first). Type by role/description: build (dev/dev-escalated, step implementation, first per story, desc 'Dev'/'Story'),
rework (dev roles otherwise), g1 (code-reviewer*; 'closing writer' -> close), g2 (qa), g3 (gate-adjudicator), ops.
Burst = overlap-merged spawns of the same type (a new burst when the type changes or the gap to the burst end exceeds 120 s).
Output bursts.tsv: story, idx, type, start, end, dur_min, gap_before_min (to the previous burst end of the same story), n_spawns, desc of first spawn.
Control: sum over stories of spawns assigned + unassigned must equal the selected population."""
import json, re, collections, datetime as dt
SC = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/'
T = lambda s: dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
rows = [json.loads(l) for l in open(SC + 'MONO/spawns.jsonl')]
pop = [r for r in rows if r['sprint'] == 323 and r['step'] in ('implementation', 'gate-validation[implementation]') and '2026-11-18T12:30' <= r['start'] <= '2026-11-19T02:40'
       and r['role'] in ('dev', 'dev-escalated', 'remediator', 'protected-path-editor', 'code-reviewer', 'code-reviewer-escalated', 'qa', 'gate-adjudicator')]
def story(d):
    d = (d or '').replace('323-', '')
    m = re.search(r'(\d)[.-](\d)', d); return f'{m.group(1)}.{m.group(2)}' if m else None
def typ(r):
    ro, d = r['role'], (r['description'] or '').lower()
    if ro in ('code-reviewer', 'code-reviewer-escalated'): return 'close' if 'closing' in d else 'g1'
    if ro == 'qa': return 'g2'
    if ro == 'gate-adjudicator': return 'g3'
    if 'rework' in d or 'fix' in d or r['step'] == 'gate-validation[implementation]': return 'rework'
    return 'build'
by = collections.defaultdict(list); un = []
for r in pop:
    s = story(r['description'])
    (by[s] if s else un).append(r)
print('population', len(pop), 'assigned', sum(len(v) for v in by.values()), 'unassigned', len(un), '(sum must equal population)')
out = open(SC + 'steps/implementation-gates/bursts.tsv', 'w')
for s in sorted(by):
    rs = sorted(by[s], key=lambda r: r['start']); bursts = []
    for r in rs:
        t = typ(r); a, b = T(r['start']), T(r['end'])
        if bursts and bursts[-1]['t'] == t and a - bursts[-1]['b'] <= 120: bursts[-1]['b'] = max(bursts[-1]['b'], b); bursts[-1]['n'] += 1; continue
        bursts.append(dict(t=t, a=a, b=b, n=1, d=r['description']))
    prev = None
    for i, x in enumerate(bursts):
        gap = (x['a'] - prev) / 60 if prev else 0
        out.write('\t'.join([s, str(i), x['t'], dt.datetime.utcfromtimestamp(x['a']).strftime('%m-%dT%H:%M'), dt.datetime.utcfromtimestamp(x['b']).strftime('%m-%dT%H:%M'), f"{(x['b'] - x['a']) / 60:.1f}", f'{gap:.1f}', str(x['n']), x['d'][:50]]) + '\n')
        prev = max(prev or 0, x['b'])
