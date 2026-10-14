import json, collections, datetime
H='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/lead/'
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
ad=json.load(open(H+'agentdesc.json'))
for s,lst in ad.items():
    by=collections.defaultdict(list)
    for ts,m,st,desc,typ,tid in lst: by[desc].append(ts)
    for d,tss in by.items():
        if len(tss)>1 and d.startswith(('Gate','4.3a','QA cross','Architect seat story 10')):
            gaps=[(datetime.datetime.fromisoformat(b[:19])-datetime.datetime.fromisoformat(a[:19])).total_seconds()/60 for a,b in zip(tss,tss[1:])]
            if min(gaps)<30: print(s[:8],d[:40],[t[11:16] for t in tss][:6],'gap_min',[round(g,1) for g in gaps][:5])
# pre-step (reconcile/update) sessions: duration and model
segs=[json.loads(l) for l in open(D+'segs.jsonl')]
units={json.loads(l)['unit']:json.loads(l) for l in open(D+'units.jsonl')}
pre=collections.defaultdict(lambda:[None,None,collections.Counter(),set()])
for r in segs:
    if r.get('kind')!='lead': continue
    allsteps=pre[r['sess']][3]; allsteps.add(r['step'])
    if r['step']!='pre-step': continue
    p=pre[r['sess']]; p[0]=min(p[0] or r['first'],r['first']); p[1]=max(p[1] or r['last'],r['last'])
    for m,v in r.get('tok',{}).items(): p[2][m]+=v[0]
n=0; tot=0
for s,(a,b,c,st) in sorted(pre.items(),key=lambda x:x[1][0] or ''):
    if st=={'pre-step'}:
        u=units.get(s,{}); dur=(datetime.datetime.fromisoformat(b[:19])-datetime.datetime.fromisoformat(a[:19])).total_seconds()/60
        n+=1; tot+=dur
        print('PRE-ONLY',s[:8],u.get('sprint'),a[:16],round(dur),'min',dict(c),str(u.get('skills'))[:80])
print('pre-only sessions',n,'total min',round(tot))
