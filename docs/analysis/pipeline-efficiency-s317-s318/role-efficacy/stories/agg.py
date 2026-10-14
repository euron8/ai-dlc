import json, collections, sys
P='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/spawns.jsonl'
rows=[json.loads(l) for l in open(P)]
steps={'stories-test-strategy','ui-direction','sprint-review','gate-validation[stories-test-strategy]','gate-validation[sprint-review]'}
sel=[r for r in rows if r['step'] in steps]
print('selected',len(sel),'of',len(rows))
agg=collections.defaultdict(lambda:[0,0.0,0.0])
for r in sel:
    k=(r['sprint'],r['step'],r['role'],r['model_ran'],r['model_bound'],r['effort_bound'])
    a=agg[k]; a[0]+=1; a[1]+=r['usd'] or 0; a[2]+=r['minutes'] or 0
for k in sorted(agg,key=str):
    a=agg[k]; print(k, a[0], round(a[1],2), round(a[2],1))
tot=collections.defaultdict(float)
for r in sel: tot[(r['sprint'],r['step'])]+=r['usd'] or 0
print({k:round(v,2) for k,v in tot.items()})
