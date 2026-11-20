import json,collections
d='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
for S in (322,323):
    c=collections.defaultdict(lambda:[0,0.0,0.0])
    tok=collections.defaultdict(lambda:[0]*5)
    for l in open(d+'classes.jsonl'):
        r=json.loads(l)
        if r['sprint']==S and r['step']=='carry-over-evaluation' and r['kind']=='lead':
            v=c[r['cls']]; v[0]+=r['calls']; v[1]+=r['active']; v[2]+=r['gap']
            for m,t in r['tok'].items():
                for i in range(5): tok[m][i]+=t[i]
    print('S',S)
    for k,v in sorted(c.items(),key=lambda kv:-kv[1][1]): print('  %-22s calls=%5d active_min=%6.1f gap_min=%6.1f'%(k,v[0],v[1]/60,v[2]/60))
    print('  total calls',sum(v[0] for v in c.values()),'active_min %.1f'%(sum(v[1] for v in c.values())/60), dict(tok))
