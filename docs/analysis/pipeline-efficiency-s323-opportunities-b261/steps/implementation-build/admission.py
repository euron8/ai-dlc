#!/usr/bin/env python3
"""Count tool_results containing 'admission: REFUSED' (graph pytest-admission wrapper) in subagent transcripts of lead session
53b4296a started inside the s323 build window (11-18T12:45Z..11-19T14:04Z), by role of the spawn (spawns.jsonl unit->role).
Control: count of results containing 'admission: ADMITTED'-like or 'predicate:' lines without REFUSED, and a never-present token.
"""
import json,glob,re,collections
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/spawns.jsonl'
H='/Users/n8/.claude/projects/-Users-n8-git-graph/53b4296a-8c03-4e97-8dc8-43106688cb6e/subagents/'
role={}
for l in open(M):
    r=json.loads(l)
    if int(r['sprint'])==323: role[r['unit']]=(r['role'],r['start'],r['description'])
ref=collections.Counter(); pred=collections.Counter(); ctrl=collections.Counter(); perunit=collections.Counter()
for f in glob.glob(H+'agent-*.jsonl'):
    u=f.split('/')[-1][:-6]
    if u not in role: continue
    if not ('2026-11-18T12:45'<=role[u][1]<='2026-11-19T14:04'): continue
    for l in open(f):
        if 'predicate:' not in l and 'NEVERPRESENT_TOKEN_x9' not in l: continue
        r=json.loads(l)
        if r.get('type')!='user': continue
        c=r['message'].get('content')
        if not isinstance(c,list): continue
        for b in c:
            if b.get('type')!='tool_result': continue
            t=b.get('content'); t=' '.join(x.get('text','') for x in t) if isinstance(t,list) else str(t)
            if 'predicate:' in t:
                pred[role[u][0]]+=1
                if 'admission: REFUSED' in t: ref[role[u][0]]+=1; perunit[(role[u][0],role[u][2][:30])]+=1
            if 'NEVERPRESENT_TOKEN_x9' in t: ctrl['never']+=1
print('predicate results by role',dict(pred)); print('REFUSED by role',dict(ref),'total',sum(ref.values()),'control never-token',dict(ctrl))
for k,v in perunit.most_common(8): print(v,k)
