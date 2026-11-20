#!/usr/bin/env python3
"""Lead pickup lag: for each <task-notification> status=completed of an Agent (summary Agent "<desc>" completed), lag = first lead tool_use ts
at/after the notification minus the notification ts. Role from the lead's Agent call with the same description. Notifications whose
description is ambiguous (several roles) are dropped. NOTE: the lead was often mid-turn (a long generation), so lag includes the
lead finishing its current step; 'lag' is the agent's idle time as seen from the lead side.
"""
import json,re,collections,statistics,bisect
from datetime import datetime
rows=[json.loads(l) for l in open('lead_calls.jsonl')]
def T(s): return datetime.strptime(s[:23],'%Y-%m-%dT%H:%M:%S.%f').timestamp()
calls=sorted(T(r['ts']) for r in rows if 'name' in r)
d2r=collections.defaultdict(set)
for r in rows:
    if r.get('name')=='Agent' and not r.get('err') and r.get('desc'): d2r[r['desc']].add(r['subtype'])
# need full head: rerun with longer heads? heads are 300 chars: summary may be cut; handle
lags=collections.defaultdict(list); unk=0
for r in rows:
    if r.get('ev')!='notif': continue
    h=r['head']
    m=re.search(r'<status>(\w+)</status>\s*<summary>Agent "([^"]+)" (\w+)',h)
    if not m: continue
    st,desc=m.group(1),m.group(2)
    if st!='completed' or desc not in d2r or len(d2r[desc])!=1: unk+=1; continue
    role=next(iter(d2r[desc])); t=T(r['ts']); k=bisect.bisect_left(calls,t)
    if k<len(calls): lags[role].append(calls[k]-t)
allv=[x for v in lags.values() for x in v]
print('all agents n',len(allv),'median s',round(statistics.median(allv)),'mean',round(statistics.mean(allv)),'unmatched notifs',unk)
for ro,v in sorted(lags.items(),key=lambda kv:-len(kv[1])): print(ro.ljust(26),len(v),'median s',round(statistics.median(v)),'p90',round(sorted(v)[int(.9*len(v))-1]),'sum min',round(sum(v)/60))
