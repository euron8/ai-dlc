import json,glob,collections,os
base='/Users/n8/git/graph/_bmad-output/implementation-artifacts/'
tot=collections.defaultdict(collections.Counter)
fails=[]
n=0
for s in ('s321','s322','s323'):
    for f in sorted(glob.glob(base+s+'/gate-adjudication/*.verdict.json')):
        d=json.load(open(f)); n+=1
        gt=d['gate_type']
        for v in d['verdicts']:
            tot[(gt,v['check_id'])][v['verdict']]+=1
            if v['verdict'] not in ('PASS','SKIP','NA','SKIPPED'):
                fails.append((s,os.path.basename(f),gt,v['check_id'],v['verdict'],v['evidence'][:400]))
print('verdict files',n)
for k in sorted(tot,key=lambda x:(x[0],len(x[1]),x[1])): print(k,dict(tot[k]))
print(len(fails))
for x in fails: print(x[0],x[1],x[2],'chk',x[3],x[4],'\n    ',x[5])
