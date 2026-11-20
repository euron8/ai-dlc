import json,re,collections,sys
sys.path.insert(0,'/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10')
from lead import P,T,fam
from datetime import datetime
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
sp=[x for x in map(json.loads,open(M+'spawns.jsonl')) if x['sprint']==323 and 'implementation' in x['step']]
def story(d):
    m=re.search(r'(?<![\d.])([1-5])[.-]([1-9])(?![\d])',d.replace('323-',''))
    return f"{m.group(1)}.{m.group(2)}" if m else None
by=collections.defaultdict(list)
for x in sp:
    s=story(x['description'])
    if s: by[s].append((T(x['start']),T(x['end'])))
gaps=[]
for s,l in by.items():
    l.sort(); cur=l[0][1]
    for a,b in l[1:]:
        if a>cur: gaps.append((a-cur,s,cur,a))
        cur=max(cur,b)
gaps.sort(reverse=True)
# lead calls timeline
calls=[]; uses={}
for l in open(P+'53b4296a-8c03-4e97-8dc8-43106688cb6e.jsonl'):
    r=json.loads(l); ts=r.get('timestamp')
    if not ts: continue
    c=(r.get('message') or {}).get('content')
    if isinstance(c,list):
        for b in c:
            if b.get('type')=='tool_use': calls.append((T(ts),fam(b['name'],b['input'])))
for g,s,a,b in gaps[:8]:
    fc=collections.Counter(f for t,f in calls if a<=t<=b)
    print(s,datetime.utcfromtimestamp(a).strftime('%d %H:%M'),f"{g/60:.0f}m lead calls in gap {sum(fc.values())}:",dict(fc.most_common(5)))
