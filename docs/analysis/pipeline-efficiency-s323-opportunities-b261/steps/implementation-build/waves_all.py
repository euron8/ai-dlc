#!/usr/bin/env python3
"""Dev dispatch clusters (starts within 10 min of each other) per sprint for dev/dev-escalated/protected-path-editor spawns whose description
looks like a first dispatch (not rework/fix/re-). Population: step label implementation or gate-validation[implementation]."""
import json,re
from datetime import datetime
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/spawns.jsonl'
def T(s): return datetime.strptime(s[:19],'%Y-%m-%dT%H:%M:%S').timestamp()
for sp in (321,322,323):
    rs=[json.loads(l) for l in open(M)]
    rs=[r for r in rs if int(r['sprint'])==sp and r['role'] in('dev','dev-escalated','protected-path-editor') and r['step'] in('implementation','gate-validation[implementation]')]
    rs=[r for r in rs if not re.search(r'rework|fix|re-?dispatch|resume|seat|verif|record|follow',r['description'],re.I)]
    rs.sort(key=lambda r:r['start'])
    print('sprint',sp,len(rs),'first-dispatch dev spawns')
    cl=[];cur=[]
    for r in rs:
        if cur and T(r['start'])-T(cur[-1]['start'])>600: cl.append(cur);cur=[]
        cur.append(r)
    if cur: cl.append(cur)
    t0=T(rs[0]['start'])
    for c in cl: print('  +%5.1f h  n=%2d  %s'%((T(c[0]['start'])-t0)/3600,len(c),', '.join(re.sub(r'(?i)dev story |story ','',r['description'])[:18] for r in c[:6])))
