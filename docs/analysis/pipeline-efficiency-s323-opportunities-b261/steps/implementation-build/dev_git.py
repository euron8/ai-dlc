#!/usr/bin/env python3
"""What are the dev seats' 'git:read' Bash calls? Subcommand histogram, result bytes, and the biggest results. Population: dev+dev-escalated spawns of the s323 build window."""
import importlib.util,collections,json,glob,re
spec=importlib.util.spec_from_file_location('da','dev_activity.py'); da=importlib.util.module_from_spec(spec); spec.loader.exec_module(da)
sub=collections.defaultdict(lambda:[0,0]); big=[]; tot=0
for u in da.load_units():
    if u['role']=='pre-reviewer': continue
    uid,_=da.unit_id(u); f=glob.glob(da.H+'*/subagents/'+uid+'.jsonl')[0]
    uses={}
    for l in open(f):
        r=json.loads(l); t=r.get('type')
        if t=='assistant':
            for b in r['message'].get('content') or []:
                if b.get('type')=='tool_use' and b['name']=='Bash': uses[b['id']]=b['input'].get('command','')
        elif t=='user':
            c=(r.get('message') or {}).get('content')
            if isinstance(c,list):
                for b in c:
                    if b.get('type')=='tool_result' and b.get('tool_use_id') in uses:
                        cmd=uses[b['tool_use_id']]
                        if da.classify('Bash',{'command':cmd})!='git:read': continue
                        t_=b.get('content'); t_=' '.join(x.get('text','') for x in t_) if isinstance(t_,list) else str(t_)
                        m=re.search(r'\bgit\s+(?:-C\s+\S+\s+)?(?:-c\s+\S+\s+)?([a-z-]+)',cmd); k=m.group(1) if m else '?'
                        sub[k][0]+=1; sub[k][1]+=len(t_); tot+=len(t_); big.append((len(t_),u['story'],cmd[:110].replace('\n',' ')))
print('git:read calls',sum(v[0] for v in sub.values()),'result bytes',tot)
for k,v in sorted(sub.items(),key=lambda kv:-kv[1][1])[:10]: print(k.ljust(14),v[0],'calls',v[1],'bytes')
for b in sorted(big,reverse=True)[:6]: print(b)
