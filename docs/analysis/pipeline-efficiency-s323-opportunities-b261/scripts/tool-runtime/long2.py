import json,collections
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
sp=[x for x in map(json.loads,open(M+'spawns.jsonl')) if x['sprint']==323 and 'implementation' in x['step'] and x['role'] in('dev','dev-escalated','qa','code-reviewer','code-reviewer-escalated')]
for x in sorted(sp,key=lambda x:-x['minutes'])[:10]:
    print(x['role'][:10],x['description'][:26],f"{x['minutes']:.0f}m",x['calls'],'calls',x['model_ran'],x['effort_bound'],'out',x['out'],'s/call',round(x['minutes']*60/max(1,x['calls'])),'out tok/min',round(x['out']/x['minutes']))
# by role: median s/call and out tok per min
by=collections.defaultdict(list)
for x in sp:
    if x['minutes']>5: by[(x['role'],x['model_ran'],x['effort_bound'])].append((x['minutes']*60/max(1,x['calls']),x['out']/x['minutes']))
for k,v in by.items():
    v.sort(); print(k,len(v),'median s/call',round(v[len(v)//2][0]),'max',round(v[-1][0]))
