import json,os,sys
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
W=[('4b34031d-4ef7-461c-9983-762b690b0725','2026-11-17T20:45:00Z','2026-11-18T00:33:00Z'),('53b4296a-8c03-4e97-8dc8-43106688cb6e','2026-11-18T02:18:00Z','2026-11-18T03:37:00Z')]
for u,a,b in W:
    uses={}; res={}
    for ln in open(R+u+'.jsonl'):
        if '"Agent"' not in ln and 'tool_result' not in ln: continue
        try: d=json.loads(ln)
        except: continue
        ts=d.get('timestamp','')
        if not(a<=ts<=b): continue
        c=d.get('message',{}).get('content')
        if not isinstance(c,list): continue
        for x in c:
            if x.get('type')=='tool_use' and x['name']=='Agent': uses[x['id']]=(ts,x['input'].get('description',''))
            elif x.get('type')=='tool_result' and x.get('tool_use_id') in uses or (x.get('type')=='tool_result' and x.get('tool_use_id','') in uses):
                cc=x.get('content'); s=cc if isinstance(cc,str) else ' '.join(y.get('text','') for y in cc if isinstance(y,dict))
                res[x['tool_use_id']]=(bool(x.get('is_error')),s[:200].replace('\n',' '))
    n=len(uses); bad=[(uses[i][0][11:19],uses[i][1][:30],res.get(i,(None,''))[1][:140]) for i in uses if res.get(i,(0,))[0]]
    print(u[:8],'agent calls',n,'errored',len(bad))
    for x in bad: print('  ',x)
