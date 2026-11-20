import json,glob,os
from datetime import datetime
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
f_=lambda x: datetime.fromisoformat(x.replace('Z','+00:00'))
u=None
for l in open(M+"spawns.jsonl"):
    s=json.loads(l)
    if s['sprint']==323 and s['description']=='Adversary shard 06' and s['start'].startswith('2026-11-18T08:40'): u=s['unit']
f=glob.glob(os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/*/subagents/%s.jsonl"%u))[0]
prev=None;ev=[]
for ln in open(f):
    o=json.loads(ln); ts=o.get('timestamp')
    if not ts: continue
    c=(o.get('message') or {}).get('content')
    desc=''
    if isinstance(c,list):
        for b in c:
            if b.get('type')=='tool_use': desc='USE '+b['name']+' '+' '.join(json.dumps(b['input']).split())[:150]
            elif b.get('type')=='tool_result': desc='RESULT '+str(b.get('content'))[:100].replace('\n',' ')
    ev.append((ts,desc))
gaps=[]
for a,b in zip(ev,ev[1:]):
    g=(f_(b[0])-f_(a[0])).total_seconds()
    gaps.append((g,a,b))
gaps.sort(reverse=True)
for g,a,b in gaps[:3]: print(round(g/60,1),'min gap after',a[0][11:19],a[1][:170],'| next',b[0][11:19],b[1][:90])
print('events',len(ev))
