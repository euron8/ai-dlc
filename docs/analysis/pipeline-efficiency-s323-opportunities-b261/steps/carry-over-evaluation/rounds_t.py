#!/usr/bin/env python3 -I
# rounds_t.py: s323 carry-over spawns assigned to rounds by START TIME window (not description); ops/web-fetch separated.
import json,collections
d='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
sp=[json.loads(l) for l in open(d+'spawns.jsonl')]
W=[('1 analyst draft','2026-11-13T08:00','2026-11-13T08:35'),
   ('2 party seats (28 + dispatcher)','2026-11-13T08:35','2026-11-13T08:53'),
   ('3 party repair, serial, adjudication, closure','2026-11-13T08:53','2026-11-16T23:40'),
   ('4 elicitation, repair, serial','2026-11-16T23:40','2026-11-17T00:34'),
   ('5 adversarial p1, repair, adjudicators, lane','2026-11-17T00:34','2026-11-17T01:22'),
   ('6 closer correction + adversarial p2 + repair + lane','2026-11-17T01:22','2026-11-17T02:22'),
   ('7 adversarial p3 + repair + 4a record','2026-11-17T02:22','2026-11-17T02:50'),
   ('8 gate (repair + 3 adjudicators)','2026-11-17T02:50','2026-11-17T04:00'),
   ('9 MISATTRIBUTED requirements fold','2026-11-17T07:00','2026-11-17T08:00')]
c=collections.defaultdict(lambda:[0,0.0,0.0,0,0.0])
for s in sp:
    if s['sprint']==323 and s['step'] in('carry-over-evaluation','gate-validation[carry-over-evaluation]'):
        k=None
        if s['role'] in('ops','web-fetch'): k='3b live reads (ops x3, web-fetch)'
        else:
            for n,a,b in W:
                if a<=s['start'][:16]<b: k=n
        v=c[k]; v[0]+=1; v[1]+=s['minutes']; v[2]+=s['usd']
        if s['role']=='adversary': v[3]+=1; v[4]+=s['usd']
for k in sorted(c): v=c[k]; print('%-52s n=%2d agent_min=%6.1f usd=%6.1f'%(k,v[0],v[1],v[2]))
print('TOTAL n=%d usd=%.1f'%(sum(v[0] for v in c.values()),sum(v[2] for v in c.values())))
