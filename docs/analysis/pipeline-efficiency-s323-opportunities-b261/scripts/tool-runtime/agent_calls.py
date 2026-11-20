import json,glob,re,sys,os,collections
from datetime import datetime
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
H=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
def T(s): return datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
SPR=[int(x) for x in sys.argv[1].split(',')]
OUT=sys.argv[2]
sp=[json.loads(l) for l in open(M+'spawns.jsonl')]
sel=[x for x in sp if x['sprint'] in SPR and 'implementation' in x['step']]
res=[];missing=0
for x in sel:
    g=glob.glob(H+x['sess']+'*/subagents/'+x['unit']+'.jsonl')
    if not g: missing+=1; continue
    uses={}
    for l in open(g[0]):
        try: r=json.loads(l)
        except Exception: continue
        ts=r.get('timestamp')
        if not ts: continue
        c=(r.get('message') or {}).get('content')
        if not isinstance(c,list): continue
        for b in c:
            if b.get('type')=='tool_use': uses[b['id']]=(T(ts),b['name'],b['input'])
            elif b.get('type')=='tool_result' and b.get('tool_use_id') in uses:
                t0,n,i=uses.pop(b['tool_use_id'])
                cont=b.get('content')
                txt=cont if isinstance(cont,str) else ' '.join(y.get('text','') for y in cont if isinstance(y,dict))
                res.append(dict(sprint=x['sprint'],unit=x['unit'],role=x['role'],desc=x['description'],step=x['step'],tool=n,lat=T(ts)-t0,err=bool(b.get('is_error')),cmd=(i.get('command','') if n=='Bash' else ''),head=txt[:200],t0=t0))
json.dump(res,open(OUT,'w'))
print('spawns',len(sel),'missing transcripts',missing,'calls',len(res))
