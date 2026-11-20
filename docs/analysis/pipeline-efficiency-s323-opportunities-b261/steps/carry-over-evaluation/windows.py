#!/usr/bin/env python3 -I
# windows.py <sid> <t0> <t1> [split...] : lead active (gaps<=300s between consecutive transcript records), long gaps split
# into operator-wait (gap closed by a human message that is not a task-notification) vs other, per window.
# Control: whole-range sum compared with segs.jsonl active/op_wait for the same session+step.
import json,sys,os,datetime
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
sid=sys.argv[1]; bounds=sys.argv[2:]
def P(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
b=[P(x) for x in bounds]
ev=[]
for l in open(R+sid+'.jsonl'):
    try: r=json.loads(l)
    except: continue
    ts=r.get('timestamp')
    if not ts: continue
    t=P(ts)
    if t<b[0] or t>b[-1]: continue
    kind='x'
    m=r.get('message') or {}
    c=m.get('content')
    if r.get('type')=='user':
        if isinstance(c,list) and any(x.get('type')=='tool_result' for x in c if isinstance(x,dict)):
            tr=[x for x in c if isinstance(x,dict) and x.get('type')=='tool_result']
            kind='toolres'
            # AskUserQuestion answer?
        else:
            s=c if isinstance(c,str) else ' '.join(x.get('text','') for x in c if isinstance(x,dict))
            kind='notif' if '<task-notification>' in s or 'system-reminder' in s[:40] else 'human'
    ev.append((t,kind,r))
ev.sort(key=lambda e:e[0])
asks=set()
for t,k,r in ev:
    m=r.get('message') or {}
    c=m.get('content')
    if r.get('type')=='assistant' and isinstance(c,list):
        for x in c:
            if x.get('type')=='tool_use' and x['name']=='AskUserQuestion': asks.add(x['id'])
res=[]
for i in range(len(b)-1):
    act=op=oth=0.0; n=0
    prev=None
    for t,k,r in ev:
        if not(b[i]<=t<b[i+1]): continue
        n+=1
        if prev is not None:
            g=t-prev[0]
            if g<=300: act+=g
            else:
                c=(r.get('message') or {}).get('content')
                ans=isinstance(c,list) and any(isinstance(x,dict) and x.get('type')=='tool_result' and x.get('tool_use_id') in asks for x in c)
                if k=='human' or ans: op+=g
                else: oth+=g
        prev=(t,k)
    res.append((bounds[i],bounds[i+1],round(act/60,1),round(op/60,1),round(oth/60,1),n))
for x in res: print('window',x[0][5:19],'->',x[1][5:19],'active_min',x[2],'operator_wait_min',x[3],'other_gap_min(agent wait/idle)',x[4],'records',x[5])
