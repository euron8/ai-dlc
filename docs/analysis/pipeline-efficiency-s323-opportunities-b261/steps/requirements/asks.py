#!/usr/bin/env python3 -I
"""Operator asks (AskUserQuestion) inside requirements lead segments, with answer latency.
Reads MONO/segs.jsonl for requirements lead segments of sprints 321-323; pairs tool_use with tool_result by id; drops errored."""
import json,glob,os,datetime
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
def ts(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00'))
segs=[json.loads(l) for l in open(M+'segs.jsonl')]
for sp in (321,322,323):
    tot=0
    for s in sorted([s for s in segs if s['sprint']==sp and s['step']=='requirements' and s['kind']=='lead'],key=lambda s:s['first']):
        f=glob.glob(R+s['unit']+'.jsonl')[0]
        open_={}
        for l in open(f):
            try:o=json.loads(l)
            except:continue
            t=o.get('timestamp')
            if not t or t<s['first'] or t>s['last']: continue
            c=(o.get('message') or {}).get('content')
            if not isinstance(c,list):continue
            for x in c:
                if x.get('type')=='tool_use' and x['name']=='AskUserQuestion':
                    open_[x['id']]=(t,x['input'])
                if x.get('type')=='tool_result' and x.get('tool_use_id') in open_:
                    t0,inp=open_.pop(x['tool_use_id'])
                    mins=(ts(t)-ts(t0)).total_seconds()/60
                    tot+=mins
                    qs=inp.get('questions',[])
                    print(sp,s['unit'][:8],t0[5:16],'wait %.0f min'%mins,'err' if x.get('is_error') else 'ok','nq=%d'%len(qs),'|',' / '.join((q.get('header') or q.get('question','')[:50]) for q in qs)[:150])
    print(sp,'TOTAL ask wait min %.0f'%tot)
