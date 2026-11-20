#!/usr/bin/env python3 -I
# timeline.py <session-id> <start-iso> <end-iso> : condensed lead timeline (human msgs, tool_use brief, results errors)
import json,sys,os
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
sid,t0,t1=sys.argv[1:4]
res={}
recs=[]
for l in open(R+sid+'.jsonl'):
    try: r=json.loads(l)
    except: continue
    ts=r.get('timestamp')
    if not ts or ts<t0 or ts>t1: continue
    recs.append(r)
def txt(c):
    if isinstance(c,str): return c
    return ' '.join(b.get('text','') for b in c if isinstance(b,dict) and b.get('type')=='text')
for r in recs:
    m=r.get('message') or {}
    c=m.get('content')
    ts=r['timestamp'][5:19]
    if r.get('type')=='user':
        if isinstance(c,list):
            for b in c:
                if b.get('type')=='tool_result':
                    cc=b.get('content'); s=txt(cc) if not isinstance(cc,str) else cc
                    res[b.get('tool_use_id')]=(bool(b.get('is_error')),len(s),s[:200].replace('\n',' '))
        t=txt(c) if c is not None else ''
        if t.strip() and not (isinstance(c,list) and all(b.get('type')=='tool_result' for b in c)):
            print(ts,'HUMAN/USER:',t[:300].replace('\n',' '))
    elif r.get('type')=='assistant' and isinstance(c,list):
        for b in c:
            if b.get('type')=='tool_use':
                i=b['input']; n=b['name']
                if n=='Agent': d=i.get('description')
                elif n=='Bash': d=i.get('command','')[:140].replace('\n',' ')
                elif n in('Read','Edit','Write'): d=i.get('file_path','')+' '+str(i.get('offset',''))
                elif n=='AskUserQuestion': d=json.dumps(i)[:300]
                else: d=json.dumps(i)[:120]
                print(ts,n,d,'|',b['id'][-6:])
            elif b.get('type')=='text' and b['text'].strip():
                print(ts,'SAY:',b['text'][:200].replace('\n',' '))
