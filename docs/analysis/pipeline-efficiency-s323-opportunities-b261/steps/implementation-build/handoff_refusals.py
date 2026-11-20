#!/usr/bin/env python3
"""Tally validate-handoff-evidence / gate-transition REFUSED labels in the s323 lead's tool results (window 11-18T12:45Z..11-19T03:10Z and the 2.x session),
by (a) distinct tool_result carrying 'REFUSED', (b) label = the token after REFUSED / REFUSED: ... Prints label counts + number of results with any REFUSED,
control: results containing the never-present token QZXW9."""
import json,re,collections
tot=collections.Counter(); res=0; ctrl=0; ex={}
for P,W0,W1 in (('/Users/n8/.claude/projects/-Users-n8-git-graph/53b4296a-8c03-4e97-8dc8-43106688cb6e.jsonl','2026-11-18T12:45','2026-11-19T03:10'),('/Users/n8/.claude/projects/-Users-n8-git-graph/64926214-f7bb-40dd-b276-c5678a934489.jsonl','2026-11-19T12:49','2026-11-19T14:04')):
    for l in open(P):
        if 'REFUSED' not in l and 'QZXW9' not in l: continue
        r=json.loads(l)
        if r.get('type')!='user' or not ('timestamp' in r and W0<=r['timestamp'][:16]<=W1): continue
        c=(r.get('message') or {}).get('content')
        if not isinstance(c,list): continue
        for b in c:
            if b.get('type')!='tool_result': continue
            t=b.get('content'); t=' '.join(x.get('text','') for x in t) if isinstance(t,list) else str(t)
            if 'QZXW9' in t: ctrl+=1
            if 'REFUSED' not in t: continue
            if 'admission: REFUSED' in t or 'dispatch guard' in t[:200]: continue
            res+=1
            for m in re.finditer(r'REFUSED[: ]+\(?([a-z][a-z0-9-]{3,40})',t):
                tot[m.group(1)]+=1; ex.setdefault(m.group(1),t[max(0,m.start()-20):m.start()+160].replace('\n',' '))
print('results with REFUSED (excluding admission/dispatch guard)',res,'control',ctrl)
for k,v in tot.most_common(25): print(v,k,'|',ex[k][:140])
