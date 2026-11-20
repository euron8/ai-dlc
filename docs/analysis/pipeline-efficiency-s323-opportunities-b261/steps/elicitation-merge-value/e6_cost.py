import json,re
from datetime import datetime
rows=[json.loads(l) for l in open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/spawns.jsonl')]
P=lambda s:datetime.fromisoformat(s.replace('Z','+00:00'))
rep=re.compile(r'repair|serial|remediat|fan-?in|adjudicat',re.I)
for sp,st in [(321,'requirements'),(321,'architecture'),(321,'stories-test-strategy'),(322,'stories-test-strategy'),(323,'requirements'),(323,'architecture'),(323,'carry-over-evaluation'),(323,'stories-test-strategy')]:
    rs=[r for r in rows if r['sprint']==sp and r['step']==st]
    el=[r for r in rs if re.search('elicit',r['description'],re.I)]
    t0=min(P(r['start']) for r in el); t1=max(P(r['end']) for r in el)
    win=[r for r in rs if P(r['start'])>=t0 and P(r['start'])<=t1]
    rnd=[r for r in el if not rep.search(r['description'])]; tail=[r for r in win if r not in rnd]
    f=lambda x:(len(x),round(sum(r['usd'] for r in x)),round(sum(r['minutes'] for r in x)))
    r_end=max(P(r['end']) for r in rnd)
    print(sp,st,'round(n,$,agent-min)',f(rnd),'round wall',round((r_end-t0).total_seconds()/60),'| tail in window',f(tail),'tail wall',round((t1-r_end).total_seconds()/60),'| window total',f(win),'wall',round((t1-t0).total_seconds()/60), t0.strftime('%m-%dT%H:%MZ'))
