import json,collections
M='../../MONO/'
rows=[json.loads(l) for l in open(M+'spawns.jsonl')]
for r in rows:
    r['sprint']=int(r['sprint'])
sel=[r for r in rows if r['sprint']>=321 and r['role'] in ('dev','dev-escalated','pre-reviewer','protected-path-editor')]
agg=collections.defaultdict(lambda:[0,0,0,0])
for r in sel:
    a=agg[(r['sprint'],r['step'],r['role'])]
    a[0]+=1;a[1]+=float(r['minutes']);a[2]+=float(r['usd']);a[3]+=float(r['tok'])
for k,v in sorted(agg.items()): print(k,v[0],round(v[1]),round(v[2],1),int(v[3]/1e6))
print()
for r in sorted([r for r in sel if r['sprint']==323 and r['step']=='implementation'],key=lambda r:r['start']):
    print(r['start'][5:16],r['role'],r['minutes'],r['calls'],r['usd'],r['description'][:90])
