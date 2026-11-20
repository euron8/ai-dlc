#!/usr/bin/env python3 -I
"""Wall decomposition of the three executed dependency chains of s323 (wave-dag.md edges 3.1->3.2, 1.1->{1.2,1.3,1.4,5.2}, 5.4->5.5).
Window of a chain = first dev dispatch of its first story (UTC) .. 'closing writer' end of its last story. Within the window:
 agent-active = union of intervals of every spawn tied to the chain's stories (bursts.py population, by story id in the description) -> split by type
 gap = window minus agent-active; lead-busy share of the gap = minutes of the gap inside which the lead made >=1 Bash call within 120 s (hand-s323late/out/bash.jsonl, kind=lead, sprint 323;
 a lower bound on lead activity: Read/Edit/Agent calls are not in that corpus).
Edges: latency L = next story's first dev start minus upstream closing-writer end.
Control: the union of ALL story windows' agent-active cannot exceed window length (asserted per chain); gap >= 0."""
import json, re, collections, datetime as dt, sys
SC = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/'
T = lambda s: dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
H = lambda t: dt.datetime.utcfromtimestamp(t).strftime('%d %H:%M')
sp = [json.loads(l) for l in open(SC + 'MONO/spawns.jsonl')]
def story(d):
    d = (d or '').replace('323-', ''); m = re.search(r'(\d)[.-](\d)', d); return f'{m.group(1)}.{m.group(2)}' if m else None
pop = [r for r in sp if r['sprint'] == 323 and r['step'] in ('implementation', 'gate-validation[implementation]') and '2026-11-18T12:30' <= r['start'] <= '2026-11-19T03:00'
       and r['role'] in ('dev', 'dev-escalated', 'remediator', 'code-reviewer', 'code-reviewer-escalated', 'qa', 'gate-adjudicator')]
lead = sorted(T(json.loads(l)['ts']) for l in open(SC + 'hand-s323late/out/bash.jsonl') if '"kind": "lead"' in l and '"sprint": 323' in l)
def typ(r):
    ro, d = r['role'], (r['description'] or '').lower()
    if ro.startswith('code-reviewer'): return 'close' if 'closing' in d else 'g1'
    if ro == 'qa': return 'g2'
    if ro == 'gate-adjudicator': return 'g3'
    return 'dev'
def close_end(s):
    return max(T(r['end']) for r in pop if story(r['description']) == s and typ(r) == 'close')
def first_dev(s):
    return min(T(r['start']) for r in pop if story(r['description']) == s and typ(r) == 'dev')
def union(iv):
    iv = sorted(iv); m = 0; cs = ce = None
    for a, b in iv:
        if ce is None or a > ce:
            if ce is not None: m += ce - cs
            cs, ce = a, b
        else: ce = max(ce, b)
    return m + (ce - cs if ce is not None else 0)
def leadbusy(a, b):
    # minutes of [a,b] within 120 s of a lead Bash call
    import bisect
    cov = []; i = bisect.bisect_left(lead, a - 120)
    while i < len(lead) and lead[i] <= b + 120:
        cov.append((max(a, lead[i] - 120), min(b, lead[i] + 120))); i += 1
    return union([c for c in cov if c[1] > c[0]])
chains = {'C1 3.1->3.2': ['3.1', '3.2'], 'C2 1.1->5.2': ['1.1', '5.2'], 'C3 5.4->5.5': ['5.4', '5.5']}
for name, st in chains.items():
    w0 = first_dev(st[0]); w1 = close_end(st[-1]); W = w1 - w0
    seg = []
    iv_all = []; bytype = collections.defaultdict(list)
    for s in st:
        for r in pop:
            if story(r['description']) == s:
                a, b = T(r['start']), T(r['end']); iv_all.append((a, b)); bytype[typ(r)].append((a, b))
    act = union(iv_all); assert act <= W + 1 and act > 0
    gaps = []
    iv = sorted(iv_all); cur = w0
    for a, b in iv:
        if a > cur: gaps.append((cur, a))
        cur = max(cur, b)
    gsum = sum(b - a for a, b in gaps); lb = sum(leadbusy(a, b) for a, b in gaps)
    L = first_dev(st[-1]) - close_end(st[0])
    print(f'{name}: window {H(w0)}Z .. {H(w1)}Z = {W/60:.0f} min; agent-active union {act/60:.0f} min ({act/W:.0%}); gaps {gsum/60:.0f} min of which lead made a Bash call within 120 s for {lb/60:.0f} min; edge latency {st[0]} close -> {st[-1]} first dev = {L/60:.0f} min')
    print('   union by type (min):', {k: round(union(v) / 60) for k, v in bytype.items()})
    big = sorted(gaps, key=lambda g: g[0] - g[1])[:4]
    print('   largest gaps:', [(H(a), round((b - a) / 60), round(leadbusy(a, b) / 60)) for a, b in big])
print('control: lead rows', len(lead))
