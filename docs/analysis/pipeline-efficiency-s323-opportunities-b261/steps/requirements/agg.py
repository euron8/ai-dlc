import json,collections,sys
rows=[json.loads(l) for l in open('readers.jsonl')]
scanned=collections.Counter(); 
for r in rows:
    if r['doc']=='_scanned': scanned[(r['sprint'],r['kind'],r['rstep'])]+=1
# distinct units reading doc by sprint, step
units=collections.defaultdict(set); calls=collections.Counter()
for r in rows:
    if r['doc']=='_scanned': continue
    k=(r['sprint'],r['rstep'],r['doc'])
    units[k].add(r['unit']); calls[k]+=r['n']
docs=['prd','brief','spec','locked','archimpact','reqctx','reqchangelog','reqadv','prdhist']
steps=sorted({k[1] for k in units})
sp=int(sys.argv[1])
print('sprint',sp,'units scanned (sub+lead segs):',sum(v for k,v in scanned.items() if k[0]==sp))
print('%-34s'%'step',*['%11s'%d for d in docs])
for st in steps:
    line=[]
    for d in docs:
        k=(sp,st,d)
        line.append('%4d/%-6d'%(len(units[k]),calls[k]) if k in units else '%11s'%'.')
    if any(l.strip()!='.' for l in line): print('%-34s'%st[:34],*line)
