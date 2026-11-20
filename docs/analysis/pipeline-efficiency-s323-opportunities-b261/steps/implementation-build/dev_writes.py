#!/usr/bin/env python3
"""Bytes the dev/dev-escalated seats WROTE through Edit/Write (new_string/content), by target path class, per spawn set.
Classes: tests (test files), code (other source), story-file, dar-etc records (_bmad-output/docs/reviews/test-results/captures), other.
Also counts Bash heredoc writes (cat > path <<) by target class (bytes of the command text).
Uses dev_activity.load_units/unit_id (same spawn set: dev + dev-escalated + pre-reviewer of s323 build window).
"""
import json, glob, re, collections
import importlib.util
spec=importlib.util.spec_from_file_location('da','dev_activity.py'); da=importlib.util.module_from_spec(spec); spec.loader.exec_module(da)
def pc(p):
    if re.search(r'(^|/)(tests?|__tests__|e2e)/|(^|/)test_[^/]*$|\.(test|spec)\.[jt]sx?$|conftest\.py$',p): return 'tests'
    if re.search(r'planning-artifacts/.*/stories/story-',p): return 'story-file'
    if re.search(r'sprint-status',p): return 'sprint-status'
    if re.search(r'^.*(_bmad-output|docs/reviews|docs/escalations|test-results/|dev-report)|\.(txt|log|out)$',p): return 'other-record'
    return 'code'
tot=collections.defaultdict(lambda:[0,0]); per=collections.defaultdict(lambda:collections.defaultdict(int))
for u in da.load_units():
    if u['role']=='pre-reviewer': continue
    uid,_=da.unit_id(u)
    f=glob.glob(da.H+'*/subagents/'+uid+'.jsonl')[0]
    seen=set()
    for l in open(f):
        r=json.loads(l)
        if r.get('type')!='assistant': continue
        for b in (r['message'].get('content') or []):
            if b.get('type')!='tool_use' or b['id'] in seen: continue
            seen.add(b['id']); i=b.get('input') or {}
            if b['name']=='Edit': c=pc(i.get('file_path','')); n=len(i.get('new_string',''))
            elif b['name']=='Write': c=pc(i.get('file_path','')); n=len(i.get('content',''))
            elif b['name']=='Bash':
                cmd=i.get('command','')
                m=re.search(r"cat\s*>>?\s*(\S+)\s*<<",cmd)
                if not m: continue
                c='heredoc:'+pc(m.group(1)); n=len(cmd)
            else: continue
            tot[c][0]+=1; tot[c][1]+=n; per[u['story']][c]+=n
T=sum(v[1] for k,v in tot.items())
for k,v in sorted(tot.items(),key=lambda kv:-kv[1][1]): print(k.ljust(24),v[0],'writes',v[1],'bytes','%.0f%%'%(100*v[1]/T))
print('total bytes',T)
