import json,re,collections,sys
sys.path.insert(0,'/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10')
from lead import P,T
ta=T('2026-11-18T12:45:29Z'); tb=T('2026-11-19T03:09:29Z')
uses={}; c=collections.Counter(); ex={}; rd=collections.Counter()
for l in open(P+'53b4296a-8c03-4e97-8dc8-43106688cb6e.jsonl'):
    r=json.loads(l); ts=r.get('timestamp')
    if not ts: continue
    t=T(ts)
    cc=(r.get('message') or {}).get('content')
    if not isinstance(cc,list): continue
    for b in cc:
        if b.get('type')=='tool_use': uses[b['id']]=(b['name'],b['input'])
        elif b.get('type')=='tool_result' and b.get('is_error') and ta<=t<=tb:
            n,i=uses.get(b['tool_use_id'],('?',{}))
            cont=b.get('content'); s=cont if isinstance(cont,str) else ' '.join(y.get('text','') for y in cont if isinstance(y,dict))
            if n=='Agent':
                k=re.sub(r'[\d]+','N',s[:90]); c[k]+=1; ex.setdefault(k,s[:260])
            if n=='Read': rd[re.sub(r'\d+','N',s[:70])]+=1
for k,v in c.most_common(6): print(v,ex[k].replace('\n',' '))
print(rd.most_common(3))
