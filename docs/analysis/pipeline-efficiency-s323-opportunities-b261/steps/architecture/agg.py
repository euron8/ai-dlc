import json,collections,sys
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
steps={'architecture','ui-direction'}
def rd(f):
    for l in open(M+f): yield json.loads(l)
print("SEGS")
a=collections.defaultdict(lambda:[0,0,0,0,0])
for r in rd('segs.jsonl'):
    if r['sprint'] in (321,322,323) and r['step'] in steps:
        k=(r['sprint'],r['step'],r['kind'])
        v=a[k]; v[0]+=r['active']; v[1]+=r['op_wait']; v[2]+=r['agent_wait']; v[3]+=r['humans']; v[4]+=1
for k in sorted(a): print(k,[round(x/60,1) if i<3 else x for i,x in enumerate(a[k])])
print("CLASSES")
c=collections.defaultdict(lambda:[0,0])
for r in rd('classes.jsonl'):
    if r['sprint'] in (321,322,323) and r['step'] in steps:
        v=c[(r['sprint'],r['step'],r['kind'],r['cls'])]; v[0]+=r['active']; v[1]+=r['calls']
for k in sorted(c): print(k,round(c[k][0]/60,1),c[k][1])
print("SPAWNS")
s=collections.defaultdict(lambda:[0,0,0])
for r in rd('spawns.jsonl'):
    if r['sprint'] in (321,322,323) and r['step'] in steps:
        v=s[(r['sprint'],r['step'],r['role'],r['model_ran'])]; v[0]+=1; v[1]+=r['minutes']; v[2]+=r['usd']
for k in sorted(s): print(k,s[k][0],round(s[k][1],1),round(s[k][2],1))
