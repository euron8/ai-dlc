#!/usr/bin/env python3
"""Errored/denied tool results in dev + dev-escalated seats (s323 build window), by tool and first 90 chars of the result (digits->N). Pairs tool_use with tool_result by id."""
import importlib.util,collections,json,glob,re
spec=importlib.util.spec_from_file_location('da','dev_activity.py'); da=importlib.util.module_from_spec(spec); spec.loader.exec_module(da)
c=collections.Counter(); n=0; tot=0
for u in da.load_units():
    if u['role']=='pre-reviewer': continue
    uid,_=da.unit_id(u); f=glob.glob(da.H+'*/subagents/'+uid+'.jsonl')[0]; uses={}
    for l in open(f):
        r=json.loads(l); t=r.get('type')
        if t=='assistant':
            for b in r['message'].get('content') or []:
                if b.get('type')=='tool_use': uses[b['id']]=b['name']
        elif t=='user':
            cc=(r.get('message') or {}).get('content')
            if isinstance(cc,list):
                for b in cc:
                    if b.get('type')=='tool_result' and b.get('tool_use_id') in uses:
                        tot+=1
                        if b.get('is_error'):
                            x=b.get('content'); x=' '.join(y.get('text','') for y in x) if isinstance(x,list) else str(x)
                            c[(uses[b['tool_use_id']],re.sub(r'\d+','N',re.sub(r'[0-9a-f]{7,}','H',x.replace('\n',' ')))[:100])]+=1; n+=1
print('results',tot,'errored',n)
for k,v in c.most_common(14): print(v,k)
