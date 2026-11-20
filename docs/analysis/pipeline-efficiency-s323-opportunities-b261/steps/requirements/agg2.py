import json,collections,sys
sp=int(sys.argv[1]); steps=sys.argv[2].split(',')
rows=[json.loads(l) for l in open('readers.jsonl')]
den=collections.Counter(); who=collections.defaultdict(lambda:collections.defaultdict(set)); calls=collections.Counter()
for r in rows:
    if r['sprint']!=sp: continue
    if r['doc']=='_scanned':
        if r['kind']=='sub': den[r['step']]+=1
        continue
    if r['rstep'] in steps:
        who[(r['rstep'],r['doc'])][(r['kind'],r['role'])].add(r['unit']); calls[(r['rstep'],r['doc'],r['kind'])]+=r['n']
for st in steps:
    print('==',st,'sub spawns scanned:',den[st])
    for d in ['prd','brief','spec','locked','archimpact']:
        w=who.get((st,d))
        if w: print('  %-10s'%d,', '.join('%s:%s=%d'%(k[0][:1],k[1],len(v)) for k,v in sorted(w.items(),key=lambda x:-len(x[1]))))
