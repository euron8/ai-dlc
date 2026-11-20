#!/usr/bin/env python3 -I
# rounds.py : per-round spawns / agent-minutes / usd / wall span for carry-over-evaluation spawns (+gate), sprints 322,323.
import json,re,collections,datetime
d='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
sp=[json.loads(l) for l in open(d+'spawns.jsonl')]
def P(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
def cls(s):
    D=s['description'].lower(); r=s['role']
    if s['step'].startswith('gate'): return '9 gate'
    if 'fold answered' in D: return '8b misattributed (requirements fold)'
    if D.startswith('gate repair') or '4a recurrence' in D: return '9 gate'
    if ('party repair' in D or 'repair re-run' in D or 'rerun of part' in D or 'serial repair after assembly' in D or 'adjudication remediator' in D or 'closure' in D or 'party repair' in D or 'fan-in party' in D or 'serial lane 1 of party' in D): return '3 party repair+adjudication+closure'
    if r=='analyst' and 'triage' in D: return '8 other (minors triage)'
    if r=='analyst': return '1 analyst draft'
    if 'elicitation' in D: return '4 elicitation (+repair)'
    if re.search(r'\bp3\b',D): return '7 adversarial p3 (+repair)'
    if re.search(r'\bp2\b|pass 2|lane record|stale fence|lane-1|lane 1|serial lane|operator-decision|adjudicator lane',D) and 'party' not in D: return '6 adversarial p2 (+repair)'
    if re.search(r'\bp1\b|cross-section remediator|adversarial',D): return '5 adversarial p1 (+repair)'
    if r in('pm','architect','dev','tea') or 'party' in D or 'round-dispatcher' in D: return '2 party seats'
    if r in('ops','web-fetch'): return '3b live reads (ops/web)'
    if 'repair' in D or 'adjudicat' in D or 'closure' in D or 'serial' in D or 'fan-in' in D: return '3 party repair+adjudication+closure'
    if 'gate' in D: return '9 gate'
    return '8 other'
for S in (322,323):
    c=collections.defaultdict(lambda:[0,0.0,0.0,1e18,0])
    for s in sp:
        if s['sprint']==S and s['step'] in('carry-over-evaluation','gate-validation[carry-over-evaluation]'):
            k=cls(s); v=c[k]; v[0]+=1; v[1]+=s['minutes']; v[2]+=s['usd']; v[3]=min(v[3],P(s['start'])); v[4]=max(v[4],P(s['end']))
    print('SPRINT',S)
    tot=[0,0,0]
    for k in sorted(c):
        v=c[k]; tot[0]+=v[0];tot[1]+=v[1];tot[2]+=v[2]
        print(f'  {k:40s} n={v[0]:3d} agent_min={v[1]:7.1f} usd={v[2]:6.1f} wall_span_min={(v[4]-v[3])/60:7.1f}')
    print('  TOTAL n=%d agent_h=%.2f usd=%.1f'%(tot[0],tot[1]/60,tot[2]))
