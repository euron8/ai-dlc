#!/usr/bin/env python3 -I
"""s323 requirements: phase table. Spawn phases by START time window (UTC, 2026-11-17); lead calls and 'active' (sum of gaps between
consecutive transcript events, each gap capped at 300 s, same cap idea as segs 'active') per window; ask waits from asks.py."""
import json,glob,os,datetime,collections
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
D='2026-11-17T'
PH=[('0 analyst+authoring chain',D+'03:00',D+'07:00'),
    ('1 party round+repair+6 serial passes',D+'07:00',D+'14:43'),
    ('2 elicitation+repair+serial',D+'14:43',D+'17:15'),
    ('3 adversarial p1+repair+serial',D+'17:15',D+'19:35'),
    ('4 adv p2 verify+post-MET repair',D+'19:35',D+'20:30'),
    ('5 gate adjudicators',D+'20:30',D+'21:00')]
def ph(t):
    for n,a,b in PH:
        if a<=t<b: return n
sp=[json.loads(l) for l in open(M+'spawns.jsonl')]
S=[s for s in sp if s['sprint']==323 and s['step'] in('requirements','research-requirements','gate-validation[requirements]')]
agg=collections.defaultdict(lambda:[0,0.0,0.0,0.0,0.0])  # n, agent-min, usd, first, last
for s in S:
    p=ph(s['start'][:16]); a=agg[p]; a[0]+=1;a[1]+=s['minutes'];a[2]+=s['usd']
    a[3]=min(a[3] or 9e9,s['start']) if False else a[3]
first={};last={}
for s in S:
    p=ph(s['start'][:16]); first[p]=min(first.get(p,'z'),s['start']); last[p]=max(last.get(p,''),s['end'])
def ts(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00'))
lead=collections.defaultdict(lambda:[0,0.0])
for u,a,b in (('68cf8de7','2026-11-17T03:02:00Z','2026-11-17T15:20:00Z'),('4b34031d','2026-11-17T16:02:00Z','2026-11-17T20:40:00Z')):
    f=glob.glob(R+u+'*.jsonl')[0]; prev=None
    for l in open(f):
        try:o=json.loads(l)
        except:continue
        t=o.get('timestamp')
        if not t or t<a or t>b: continue
        c=(o.get('message') or {}).get('content')
        p=ph(t[:16])
        if prev is not None:
            g=(ts(t)-prev).total_seconds()
            if g>=0: lead[p][1]+=min(g,300)
        if prev is None or ts(t)>prev: prev=ts(t)
        if o.get('type')=='assistant' and isinstance(c,list):
            lead[p][0]+=sum(1 for x in c if x.get('type')=='tool_use')
print('%-40s %5s %8s %8s  %-6s %-6s %8s %9s'%('phase','spawn','agent-h','usd','first','last','lead-calls','lead-act-min'))
T=[0,0,0,0]
for n,_,_ in PH:
    a=agg[n]; l=lead[n]
    print('%-40s %5d %8.2f %8.1f  %s %s %8d %9.0f'%(n,a[0],a[1]/60,a[2],first.get(n,'-')[11:16],last.get(n,'-')[11:16],l[0],l[1]/60))
    T[0]+=a[0];T[1]+=a[1]/60;T[2]+=a[2];T[3]+=l[1]/60
print('TOTAL spawns %d agent-h %.2f usd %.1f lead-act-min %.0f'%tuple(T))
