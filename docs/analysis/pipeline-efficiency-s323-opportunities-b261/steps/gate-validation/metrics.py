import json,collections
f='/Users/n8/git/graph/_bmad-output/implementation-artifacts/gate-metrics.jsonl'
rows=[]
bad=0
for l in open(f):
    l=l.strip()
    if not l: continue
    try: rows.append(json.loads(l))
    except: bad+=1
print(len(rows),'bad',bad)
print(collections.Counter(r.get('sprint') for r in rows).most_common(12))
print(rows[-1])
sel=[r for r in rows if r.get('sprint') in (321,322,323)]
print('sel',len(sel),collections.Counter((r['sprint'],r['gate']) for r in sel))
c=collections.defaultdict(collections.Counter); tok={}
for r in sel:
    c[r['check']][r['verdict']]+=1; tok.setdefault(r['check'],[]).append(r.get('tok_slice') or 0)
for k in sorted(c,key=lambda x:(len(x),x)): print(k,dict(c[k]),'tok',max(tok[k]))
