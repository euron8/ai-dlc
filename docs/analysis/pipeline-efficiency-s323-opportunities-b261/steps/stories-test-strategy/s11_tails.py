import json
from datetime import datetime
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
exec(open("/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/stories-test-strategy/s10_round_cost.py").read().split("tot=")[0])
f=lambda x: datetime.fromisoformat(x.replace('Z','+00:00'))
for n,a,b in W:
    g=sorted([s for s in sp if a<=s['start'][11:16]<b and s['role'] not in('general-purpose',)],key=lambda s:s['end'])
    if len(g)<3: continue
    st=min(f(s['start']) for s in g)
    ends=[(f(s['end'])-st).total_seconds()/60 for s in g]
    top=g[-1]
    print(f"{n:34s} n={len(g):2d} median-end {ends[len(ends)//2]:5.1f} p90 {ends[int(len(ends)*0.9)-1]:5.1f} last {ends[-1]:5.1f} min | last: {top['role']} {top['minutes']}m {top['description'][:40]}")
