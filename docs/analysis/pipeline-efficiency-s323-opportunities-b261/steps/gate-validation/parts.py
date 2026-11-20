
import json,glob,collections,os,re
base='/Users/n8/git/graph/_bmad-output/implementation-artifacts/'
stems=collections.defaultdict(dict)   # (sprint,stem)-> check->verdict (parts + verdict)
for s in ('s321','s322','s323'):
    for f in sorted(glob.glob(base+s+'/gate-adjudication/*')):
        b=os.path.basename(f)
        stem=b.split('.part')[0].split('.verdict')[0]
        if b.endswith('.jsonl'):
            for l in open(f):
                l=l.strip()
                if not l: continue
                try:r=json.loads(l)
                except: continue
                if 'check_id' in r and 'verdict' in r: stems[(s,stem)][r['check_id']]=(r['verdict'],r.get('evidence','')[:300])
        elif b.endswith('.verdict.json'):
            d=json.load(open(f))
            for v in d['verdicts']: stems[(s,stem)].setdefault(v['check_id'],(v['verdict'],v['evidence'][:300]))
tot=collections.defaultdict(collections.Counter)
fails=[]
for (s,stem),cs in stems.items():
    gt=stem.split('-')[0]
    for c,(v,e) in cs.items():
        tot[(gt,c)][v]+=1
        if v!='PASS': fails.append((s,stem,gt,c,v,e))
print('stems',len(stems),collections.Counter(k[1].split('-')[0] for k in stems))
for k in sorted(tot,key=lambda x:(x[0],len(x[1]),x[1])):
    if k[0]!='implementation': print(k,dict(tot[k]))
print('--- non-impl fails')
for x in sorted(fails):
    if x[2]!='implementation': print(x[0],x[1],'chk',x[3],x[4],'|',x[5][:260].replace('\n',' '))
