import json,glob,os,sys
from datetime import datetime
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
H=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
def T(s): return datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
sp=[x for x in map(json.loads,open(M+'spawns.jsonl')) if x['sprint']==323 and sys.argv[1] in x['description'] and x['minutes']>60]
x=sp[0]; g=glob.glob(H+x['sess']+'*/subagents/'+x['unit']+'.jsonl')[0]
prev=None; pk=''
for l in open(g):
    r=json.loads(l); ts=r.get('timestamp')
    if not ts: continue
    t=T(ts); c=(r.get('message') or {}).get('content')
    if prev is not None and t-prev>300:
        s=c if isinstance(c,str) else json.dumps(c)
        print(ts[11:19],f"{(t-prev)/60:.0f}m",'prev:',pk[:90].replace('\n',' '),'| next:',s[:230].replace('\n',' '))
    prev=t
    if isinstance(c,list):
        for b in c:
            if b.get('type')=='tool_use': pk=b['name']+' '+(b['input'].get('command','') or '')[:80]
            if b.get('type')=='text': pk='text:'+b['text'][:80]
