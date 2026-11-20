#!/usr/bin/env python3 -I
"""Per-sprint round table for requirements (s317-s323), from spawns.jsonl. Rounds are separated by the FIRST start of each round's own
seat/shard descriptions: party = first architect/dev spawn; elicitation = first desc containing 'lic'; adversarial = first adversary
whose desc has no 'lic' and no 'verif' after party start. Spawns are assigned to the latest round whose start <= spawn start.
Hours = agent-hours (sum of spawn minutes); wall = first start to last end of the round's spawns."""
import json,collections,re,datetime
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
sp=[json.loads(l) for l in open(M+'spawns.jsonl')]
def ts(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00'))
for sprint in (317,318,319,320,321,322,323):
    S=[s for s in sp if s['sprint']==sprint and s['step']=='requirements']
    S.sort(key=lambda s:s['start'])
    if not S:
        print('s%d: no spawns with step requirements'%sprint); continue
    party=[s['start'] for s in S if s['role'] in('architect','dev') or 'arty' in s['description']]
    elic=[s['start'] for s in S if 'lic' in s['description']]
    t_party=min(party) if party else None
    t_elic=min(elic) if elic else None
    adv=[s['start'] for s in S if s['role']=='adversary' and 'lic' not in s['description'] and t_party and s['start']>=t_party and (not t_elic or s['start']>t_elic)]
    t_adv=min(adv) if adv else None
    marks=[('authoring',S[0]['start'])]
    for n,t in (('party',t_party),('elicitation',t_elic),('adversarial',t_adv)):
        if t: marks.append((n,t))
    marks.sort(key=lambda x:x[1])
    agg=collections.OrderedDict((n,[0,0.0,0.0,'z','']) for n,_ in marks)
    for s in S:
        n=[m for m in marks if m[1]<=s['start']][-1][0]
        a=agg[n];a[0]+=1;a[1]+=s['minutes']/60;a[2]+=s['usd'];a[3]=min(a[3],s['start']);a[4]=max(a[4],s['end'])
    print('== s%d requirements spawns %d'%(sprint,len(S)))
    for n,a in agg.items():
        print('  %-12s n=%3d agent-h=%6.2f usd=%7.1f wall-h=%5.2f  %s..%s'%(n,a[0],a[1],a[2],(ts(a[4])-ts(a[3])).total_seconds()/3600,a[3][5:16],a[4][5:16]))
