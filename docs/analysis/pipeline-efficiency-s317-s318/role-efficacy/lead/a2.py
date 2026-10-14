import json, collections, os
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
sess=collections.defaultdict(lambda: dict(first='9',last='0',steps=collections.Counter(),models=collections.Counter(),sprint=None))
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    if 'tok' not in r: continue
    s=sess[r['sess']]
    s['first']=min(s['first'],r['first']); s['last']=max(s['last'],r['last']); s['sprint']=r['sprint']
    for m,v in r['tok'].items():
        s['steps'][(r['step'],m.replace('claude-',''))]+=1
        s['models'][m]+=v[0] if v else 0
for k,s in sorted(sess.items(), key=lambda x:x[1]['first']):
    ms={m:c for m,c in s['models'].items()}
    steps=sorted(set(st for st,_ in s['steps']))
    print(k[:8], s['sprint'], s['first'][:16], s['last'][:16], ms, steps[:12])
