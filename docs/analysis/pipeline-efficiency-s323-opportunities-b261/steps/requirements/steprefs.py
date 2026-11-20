#!/usr/bin/env python3 -I
"""Reads (tool_use paired with non-error tool_result) of steps/discovery.md and steps/research-requirements.md by the lead (requirements windows)
and by requirements-step subagents of roles pm-escalated/pm/analyst, sprints 321-323. Also reads of requirements.md itself by the lead.
Control: requirements.md reads must be >0 for the lead."""
import json,glob,os,re,collections
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
RX={'discovery':re.compile(r'steps/discovery\.md'),'research-req':re.compile(r'steps/research-requirements\.md'),'requirements.md':re.compile(r'steps/requirements\.md'),'_gate-procedures':re.compile(r'_gate-procedures\.md')}
def scan(path,win=None):
    pend={};cnt=collections.Counter();byts=collections.Counter()
    for l in open(path,errors='replace'):
        if 'steps/' not in l and '"tool_result"' not in l: continue
        try:o=json.loads(l)
        except:continue
        c=(o.get('message') or {}).get('content')
        if not isinstance(c,list):continue
        t=o.get('timestamp') or ''
        for x in c:
            if x.get('type')=='tool_use':
                if win and not any(a<=t<=b for a,b in win): continue
                s=json.dumps(x['input'])
                h=[k for k,rx in RX.items() if rx.search(s)]
                if h: pend[x['id']]=(h,x['name'])
            elif x.get('type')=='tool_result' and x.get('tool_use_id') in pend:
                h,nm=pend.pop(x['tool_use_id'])
                if x.get('is_error'):continue
                for k in h: cnt[k]+=1
    return cnt
segs=[json.loads(l) for l in open(M+'segs.jsonl')]
sp=[json.loads(l) for l in open(M+'spawns.jsonl')]
full={os.path.basename(d.rstrip('/'))[:8]:d for d in glob.glob(R+'*/')}
for sprint in (321,322,323):
    tot=collections.Counter()
    for s in segs:
        if s['sprint']==sprint and s['kind']=='lead' and s['step']=='requirements':
            tot.update(scan(R+s['unit']+'.jsonl',[(s['first'],s['last'])]))
    print(sprint,'LEAD requirements windows',dict(tot))
    for s in sp:
        if s['sprint']==sprint and s['step']=='requirements' and s['role'] in('pm-escalated','pm','analyst'):
            p=full[s['sess']]+'subagents/'+s['unit']+'.jsonl'
            print('  ',s['role'],s['description'][:40],dict(scan(p)))
