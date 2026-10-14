import json, re, glob, collections, os
S='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/spawns.jsonl'
rows=[json.loads(l) for l in open(S)]
G={317:'2026-10-09T05:48',318:'2026-10-13T21:13'}
# 1 split stories rows at gate
for sp in (317,318):
    a=collections.defaultdict(lambda:[0,0.0,0.0])
    for r in rows:
        if r['sprint']==sp and r['step']=='stories-test-strategy':
            k=('pre' if r['start']<G[sp] else 'POST',r['role'],r['model_ran'],r['effort_bound'])
            a[k][0]+=1;a[k][1]+=r['usd'];a[k][2]+=r['minutes']
    for k in sorted(a,key=str): print(sp,k,a[k][0],round(a[k][1],2),round(a[k][2]))
    print(sp,'POST descs',sorted(set(re.sub(r'\d+','#',r['description'])[:45] for r in rows if r['sprint']==sp and r['step']=='stories-test-strategy' and r['start']>=G[sp])))
# 7 per-seat costs: party seats only
def kind(r):
    d=r['description']
    if re.search(r'elicit',d,re.I): return 'elicit'
    if re.search(r'seat|party|Party|cross g|part #',re.sub(r'\d+','#',d)): return 'party-seat'
    return 'other'
a=collections.defaultdict(lambda:[0,0.0])
for r in rows:
    if r['step'] in('stories-test-strategy','sprint-review') and r['role'] in('architect','tea','sm','dev','pm','qa'):
        if r['sprint']==317 and r['step']=='stories-test-strategy' and r['start']>=G[317]: continue
        k=(r['sprint'],r['step'],r['role'],r['model_ran'],r['effort_bound'],kind(r))
        a[k][0]+=1;a[k][1]+=r['usd']
for k in sorted(a,key=str): print(k,a[k][0],round(a[k][1],2),'per',round(a[k][1]/a[k][0],2))
# ux and tea-authoring final text, transcripts
for r in rows:
    if r['role']=='ux' or re.search('TEA sprint 318 test strategy|TEA test strategy and trace',r['description']):
        print('==',r['description'],r['unit'],r['sess'],r['calls'],r['out'])
        print((r['final_text'] or '')[-900:].replace('\n',' | '))
