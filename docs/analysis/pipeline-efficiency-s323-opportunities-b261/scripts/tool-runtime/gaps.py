import json,glob,os,collections,re,sys
from datetime import datetime
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
H=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
def T(s): return datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
sp=[x for x in map(json.loads,open(M+'spawns.jsonl')) if x['sprint']==323 and 'implementation' in x['step']]
want=sys.argv[1:]
for x in sp:
    if not any(w in x['description'] for w in want) or x['minutes']<60: continue
    g=glob.glob(H+x['sess']+'*/subagents/'+x['unit']+'.jsonl')[0]
    prev=None; prevdesc=''; agg=collections.defaultdict(lambda:[0,0.0]); fam={}
    for l in open(g):
        r=json.loads(l); ts=r.get('timestamp')
        if not ts: continue
        t=T(ts); c=(r.get('message') or {}).get('content'); role=(r.get('message') or {}).get('role')
        cur=''
        if isinstance(c,list):
            for b in c:
                if b.get('type')=='tool_use': fam[b['id']]=b['name']+':'+(b['input'].get('command','')[:60].replace('\n',' ') if b['name']=='Bash' else ''); cur='use'
                elif b.get('type')=='tool_result':
                    cont=b.get('content'); s=cont if isinstance(cont,str) else ' '.join(y.get('text','') for y in cont if isinstance(y,dict))
                    cur='res:'+('bg-notify' if 'task-notification' in s[:100] else ('bg-started' if 'running in background' in s[:80] else 'res'))
                elif b.get('type')=='text' and role=='user': cur='user-text:'+('notif' if 'task-notification' in b.get('text','')[:200] else 'text')
        elif isinstance(c,str): cur='user-str:'+('notif' if 'task-notification' in c[:200] else 'str')
        if prev is not None and t-prev>60:
            a=agg[cur if cur else role]; a[0]+=1; a[1]+=t-prev
        prev=t
    print(x['role'],x['description'][:30],f"{x['minutes']:.0f}m",'gaps>60s ending in:',{k:(v[0],round(v[1]/60)) for k,v in sorted(agg.items(),key=lambda kv:-kv[1][1])[:5]})
