import json,re,collections,sys
sys.path.insert(0,'/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10')
from lead import fam,T,P
path=P+'53b4296a-8c03-4e97-8dc8-43106688cb6e.jsonl'
ta=T('2026-11-18T12:45:29Z'); tb=T('2026-11-19T03:09:29Z')
prev=None; fam_of={}; model=collections.defaultdict(lambda:[0,0.0]); tool=collections.defaultdict(lambda:[0,0.0]); other=collections.Counter()
for l in open(path):
    try: r=json.loads(l)
    except Exception: continue
    ts=r.get('timestamp')
    if not ts: continue
    t=T(ts); m=r.get('message') or {}; c=m.get('content')
    gap=(t-prev) if prev else 0; prev=t
    if not(ta<=t<=tb): continue
    g=gap if gap<=300 else 0
    if isinstance(c,list):
        uses=[b for b in c if b.get('type')=='tool_use']; res=[b for b in c if b.get('type')=='tool_result']
        for b in uses: fam_of[b['id']]=fam(b['name'],b['input'])
        if uses: x=model[fam_of[uses[0]['id']]]; x[0]+=1; x[1]+=g
        elif res: f=fam_of.get(res[0].get('tool_use_id'),'?'); x=tool[f]; x[0]+=1; x[1]+=g
        elif m.get('role')=='assistant': other['assistant-text']+=g
        else: other['user/other']+=g
    else: other['str-content']+=g
tm=sum(v[1] for v in model.values()); tt=sum(v[1] for v in tool.values())
print('model-gap h',tm/3600,'tool-wait h',tt/3600,'other',{k:round(v/3600,2) for k,v in other.items()})
allf=set(model)|set(tool)
print('family: calls | model s/call | tool s/call | total h')
for f in sorted(allf,key=lambda f:-(model[f][1]+tool[f][1]))[:20]:
    n=max(model[f][0],1)
    print(f"{f:28s} n={model[f][0]:5d} model {model[f][1]/n:5.1f}s tool {tool[f][1]/n:5.1f}s total {(model[f][1]+tool[f][1])/3600:5.2f}h")
