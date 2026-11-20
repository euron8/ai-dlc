#!/usr/bin/env python3 -I
"""Lead timeline for a requirements segment. usage: timeline.py <uuid-prefix> <startISO> <endISO> [minGapSec]
Prints one line per tool_use (Agent description, AskUserQuestion, Bash cmd head, Read/Edit/Write path) with gap from previous event."""
import sys,glob,os,json,datetime
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
u,a,b=sys.argv[1:4]
f=glob.glob(R+u+'*.jsonl')[0]
def ts(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00'))
prev=None
for l in open(f):
    try: o=json.loads(l)
    except: continue
    t=o.get('timestamp')
    if not t or t<a or t>b: continue
    m=o.get('message') or {}
    c=m.get('content')
    if o.get('type')=='user' and isinstance(c,str):
        print(t[11:19],'USER-TEXT',c[:200].replace('\n',' '));continue
    if not isinstance(c,list): continue
    for x in c:
        if x.get('type')=='tool_use':
            i=x['input'];n=x['name']
            if n=='Agent': d='%s | %s'%(i.get('subagent_type'),i.get('description'))
            elif n=='Bash': d=(i.get('command') or '')[:110].replace('\n',' ')
            elif n in('Read','Edit','Write'): d=i.get('file_path','')+' '+str(i.get('offset',''))
            elif n=='AskUserQuestion': d=json.dumps(i)[:160]
            else: d=json.dumps(i)[:90]
            g=(ts(t)-prev).total_seconds() if prev else 0
            print(t[11:19],'+%4ds'%g,n,d)
            prev=ts(t)
        elif x.get('type')=='tool_result' and o.get('type')=='user':
            pass
