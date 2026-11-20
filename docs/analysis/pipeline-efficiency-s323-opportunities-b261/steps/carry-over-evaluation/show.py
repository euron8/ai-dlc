#!/usr/bin/env python3 -I
# show.py <sid> <t0> <t1> [maxchars] : full assistant text + tool_result text (truncated) in window
import json,sys,os
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
sid,t0,t1=sys.argv[1:4]; mx=int(sys.argv[4]) if len(sys.argv)>4 else 700
def txt(c):
    if isinstance(c,str): return c
    return ' '.join((b.get('text','') if b.get('type')=='text' else (txt(b.get('content')) if b.get('type')=='tool_result' else '')) for b in c if isinstance(b,dict))
for l in open(R+sid+'.jsonl'):
    try: r=json.loads(l)
    except: continue
    ts=r.get('timestamp')
    if not ts or ts<t0 or ts>t1: continue
    m=r.get('message') or {}; c=m.get('content')
    if r.get('type')=='assistant' and isinstance(c,list):
        for b in c:
            if b.get('type')=='text': print(ts[11:19],'SAY:',b['text'][:mx].replace('\n',' '))
            elif b.get('type')=='tool_use': print(ts[11:19],'CALL',b['name'],json.dumps(b['input'])[:mx//2])
    elif r.get('type')=='user' and isinstance(c,list):
        for b in c:
            if b.get('type')=='tool_result': print(ts[11:19],'RESULT:',txt(b.get('content'))[:mx].replace('\n',' | '))
