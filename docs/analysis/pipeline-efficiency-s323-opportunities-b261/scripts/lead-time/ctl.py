import json,collections,sys
D=sys.argv[1]; M=sys.argv[2]
def agg(p):
    a=collections.defaultdict(lambda:[0,0.0,0.0])
    for l in open(p):
        r=json.loads(l)
        if r.get('kind')!='lead' or r.get('sprint') not in (321,322,323): continue
        x=a[(r['sprint'],r['cls'])]; x[0]+=r['calls']; x[1]+=r['active']/3600; x[2]+=r['gap']/3600
    return a
a=agg(D+'/x/classes.jsonl'); b=agg(M+'/classes.jsonl')
for k in sorted(set(a)|set(b)):
    x=a.get(k,[0,0,0]); y=b.get(k,[0,0,0])
    print(k, 'mine %d %.2f %.2f'%tuple(x), '| MONO %d %.2f %.2f'%tuple(y))
