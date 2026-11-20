import json,sys
from datetime import datetime
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
f=lambda x: datetime.fromisoformat(x.replace('Z','+00:00'))
for sprint in (321,322,323):
    sp=[json.loads(l) for l in open(M+"spawns.jsonl")]
    sp=[s for s in sp if s['sprint']==sprint and s['step'] in('stories-test-strategy','gate-validation[stories-test-strategy]')]
    disp=[s for s in sp if s['role']=='general-purpose']
    print('sprint',sprint,'dispatchers',len(disp),'$',round(sum(s['usd'] for s in disp),1))
    tl=0
    for d in sorted(disp,key=lambda s:s['start']):
        ch=[s for s in sp if s is not d and s['role']!='general-purpose' and f(d['start'])<=f(s['start'])<=f(d['end'])]
        if not ch: print('  ',d['start'][5:16],d['description'][:48],'min',d['minutes'],'no children'); continue
        last=max(f(s['end']) for s in ch)
        lag=(f(d['end'])-last).total_seconds()/60
        tl+=max(lag,0)
        print('  ',d['start'][5:16],d['description'][:48].ljust(48),'dur',round((f(d['end'])-f(d['start'])).total_seconds()/60,1),'children',len(ch),'last-child-end->disp-end lag min',round(lag,1))
    print('  total lag',round(tl,1))
