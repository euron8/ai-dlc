
import json,sys
# usage: timeline.py <session> <start> <end>  -- prints lead tool calls in window with brief input
sess,s,e=sys.argv[1:4]
p='/Users/n8/.claude/projects/-Users-n8-git-graph/%s.jsonl'%sess
res={}
rows=[]
for l in open(p):
    try:r=json.loads(l)
    except: continue
    ts=r.get('timestamp','')
    if not(s<=ts<=e): continue
    m=r.get('message') or {}
    c=m.get('content')
    if isinstance(c,list):
        for b in c:
            if b.get('type')=='tool_use':
                i=b['input']
                if b['name']=='Bash': br=i.get('command','').replace('\n',' ; ')
                elif b['name'] in('Read','Edit','Write'): br=i.get('file_path','')+' '+str(i.get('offset',''))+'+'+str(i.get('limit',''))
                elif b['name']=='Agent': br=i.get('description','')
                else: br=json.dumps(i)[:200]
                rows.append((ts,b['name'],br[:int(sys.argv[4]) if len(sys.argv)>4 else 170]))
for r in rows: print(r[0][11:19],r[1][:12],r[2])
