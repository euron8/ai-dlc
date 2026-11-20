#!/usr/bin/env python3
"""Dev/dev-escalated test runs: foreground run:tests/lint calls with tool latency, background runs (Bash run_in_background) measured start->the matching wait-for-deliverable DELIVERED beat is NOT reconstructed; instead report
(a) foreground run:tests calls > 120 s (story, minutes, first 90 chars of command) and (b) per-spawn sum of wait-own-job + foreground test minutes, vs the spawn's active minutes."""
import importlib.util,json,glob,collections,re
from datetime import datetime
spec=importlib.util.spec_from_file_location('da','dev_activity.py'); da=importlib.util.module_from_spec(spec); spec.loader.exec_module(da)
T=da.T
long=[];per=collections.defaultdict(lambda:[0.0,0.0,0,0.0]); bg=collections.Counter()
for u in da.load_units():
    if u['role']=='pre-reviewer': continue
    uid,_=da.unit_id(u); f=glob.glob(da.H+'*/subagents/'+uid+'.jsonl')[0]; uses={}
    for l in open(f):
        r=json.loads(l); t=r.get('type')
        if t=='assistant':
            for b in r['message'].get('content') or []:
                if b.get('type')=='tool_use' and b['name']=='Bash': uses[b['id']]=(r['timestamp'],b['input'])
        elif t=='user':
            cc=(r.get('message') or {}).get('content')
            if isinstance(cc,list):
                for b in cc:
                    if b.get('type')=='tool_result' and b.get('tool_use_id') in uses:
                        ts,inp=uses[b['tool_use_id']]; cmd=inp.get('command',''); k=da.classify('Bash',inp); dt=T(r['timestamp'])-T(ts)
                        key=(u['story'],u['desc'][:30])
                        if k=='bash:wait-own-job': per[key][0]+=dt
                        elif k=='run:tests/lint':
                            if inp.get('run_in_background'): bg[key]+=1
                            else:
                                per[key][1]+=dt; per[key][2]+=1
                                if dt>120: long.append((round(dt/60,1),u['story'],re.sub(r'\s+',' ',cmd)[:100]))
print('foreground test/lint calls >120 s:',len(long),' total min',round(sum(x[0] for x in long)))
for x in sorted(long,reverse=True)[:12]: print(x)
print('\nper spawn: wait-own-job min | foreground test min (n) | background test launches')
for k,v in sorted(per.items(),key=lambda kv:-(kv[1][0]+kv[1][1]))[:12]: print(k,round(v[0]/60),round(v[1]/60),v[2],bg[k])
tw=sum(v[0] for v in per.values())/60; tf=sum(v[1] for v in per.values())/60
print('TOTAL wait-own-job min',round(tw),'foreground test min',round(tf),' bg launches',sum(bg.values()))
