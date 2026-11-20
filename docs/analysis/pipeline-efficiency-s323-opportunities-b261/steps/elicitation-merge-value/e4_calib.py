import re,json,collections
rows=json.load(open("e3_rows.json"))
doc=open("/Users/n8/git/ai-dlc/docs/analysis/step-value-stories-elicitation-s321.md").read().split("## Per-finding classification")[1]
lab={}
for l in doc.split("\n"):
    c=[x.strip() for x in l.split("|")]
    if len(c)>6 and re.match(r'`?\S+\.md`?$',c[2].strip('`') if len(c)>2 else ''):
        sh=c[2].strip('`')[:-3].lstrip('0') or '0'; f=c[3].replace('-','')
        cl=c[5]
        lab[(sh,f)]=cl
print(len(lab),collections.Counter(lab.values()).most_common())
x=collections.defaultdict(collections.Counter)
miss=0
for r in rows:
    if r['sprint']=='s321' and r['step']=='stories':
        cl=lab.get((r['shard'],r['f']))
        if cl is None: miss+=1; continue
        x[cl]['n']+=1
        for k in ('A_party_repair','seat','p1','p1_orig'): x[cl][k]+=r[k]
        x[cl]['ship']+=r['nship']>0
print('unlabelled',miss)
for k,v in x.items(): print(k,dict(v))
