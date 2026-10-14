import json,collections,sys
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/'
rows=[json.loads(l) for l in open(D+'out/spawns.jsonl')]
P=('carry-over-evaluation','requirements','architecture')
def ph(s):
    for p in P:
        if s==p or s==f'gate-validation[{p}]': return s
    return None
agg=collections.defaultdict(lambda:[0,0.0,0.0])
for r in rows:
    if not ph(r['step']): continue
    k=(r['sprint'],r['step'],r['role'],r['model_ran'],r['model_bound'],str(r['effort_bound']))
    a=agg[k]; a[0]+=1; a[1]+=r['usd'] or 0; a[2]+=r['minutes'] or 0
for k in sorted(agg,key=str): print(k, agg[k][0], round(agg[k][1],2), round(agg[k][2],1))
tot=sum(v[1] for v in agg.values()); print('planning total usd',round(tot,2), 'n',sum(v[0] for v in agg.values()))
