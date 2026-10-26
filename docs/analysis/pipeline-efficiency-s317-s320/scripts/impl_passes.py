import json,collections,re,sys
S=sys.argv[1]
rows=[]
for l in open(S+"/spawns.jsonl"):
    s=json.loads(l)
    st=s['step']; st=st[16:-1] if st.startswith('gate-validation[') else st
    if st!='implementation' or s['sprint'] not in (317,318,319): continue
    if not s['role'].startswith(('code-reviewer','qa')): continue
    d=s['description']
    story=re.search(r'(?<![\d.])(\d{1,2}\.\d{1,2})(?![\d.])',d)
    g=re.search(r'(?:[Gg]ate[- ]?|\bG)(\d)',d)
    p=re.search(r'(?:\bp|pass )(\d)',d)
    kind='closing' if 'losing' in d else ('delta' if 'delta' in d.lower() else ('qa' if 'QA' in d or s['role'].startswith('qa') else 'cr'))
    rows.append(dict(sp=s['sprint'],story=story.group(1) if story else '?',gate=g.group(1) if g else '?',ps=int(p.group(1)) if p else 1,kind=kind,usd=s['usd'],d=d,start=s['start'],role=s['role']))
for n in (317,318,319):
    R=[r for r in rows if r['sp']==n]
    unparsed=sum(1 for r in R if r['story']=='?' or r['gate']=='?')
    passes=collections.defaultdict(set); shards=collections.Counter(); usd=collections.Counter()
    for r in R:
        k=(r['story'],r['gate'],r['kind']=='qa')
        passes[k].add(r['ps']); shards[(k,r['ps'])]+=1; usd[r['ps']]+=r['usd']
    cr=[k for k in passes if not k[2] and k[1]=='1']
    print(f"s{n}: {len(R)} spawns, unparsed {unparsed}; gate-1 CR story count {len(cr)}; passes per story(gate1 CR): {sorted(collections.Counter(max(passes[k]) for k in cr).items())}")
    print("   $ by pass#:", {k:round(v) for k,v in sorted(usd.items())}, " kinds:",dict(collections.Counter(r['kind'] for r in R)))
    gp=collections.Counter((r['gate'],r['kind']) for r in R); print("   by gate/kind:",dict(sorted(gp.items())))
    # shards per pass for gate1 cr
    sh=[shards[(k,p)] for k in cr for p in passes[k]]
    print("   gate1 CR shards/pass: mean %.1f max %d" % (sum(sh)/max(1,len(sh)),max(sh or [0])))
json.dump(rows,open(S+"/implrows.json","w"))
