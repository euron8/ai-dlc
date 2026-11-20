import json,re,collections,sys
sys.path.insert(0,'/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10')
from lead import T,P
path=P+'53b4296a-8c03-4e97-8dc8-43106688cb6e.jsonl'
ta=T('2026-11-18T12:45:29Z'); tb=T('2026-11-19T03:09:29Z')
prev=None; txt=[]; usr=collections.defaultdict(lambda:[0,0.0]); sizes=[]
mod=collections.Counter()
for l in open(path):
    try: r=json.loads(l)
    except Exception: continue
    ts=r.get('timestamp')
    if not ts: continue
    t=T(ts); m=r.get('message') or {}; c=m.get('content')
    gap=(t-prev) if prev else 0; prev=t
    if not(ta<=t<=tb) or gap>300: continue
    if m.get('role')=='assistant':
        mod[m.get('model')]+=1
        if isinstance(c,list) and not any(b.get('type')=='tool_use' for b in c):
            L=sum(len(b.get('text','')) for b in c if b.get('type')=='text'); th=sum(len(b.get('thinking','')) for b in c if b.get('type')=='thinking')
            txt.append((gap,L,th))
    elif isinstance(c,str):
        k='task-notification' if '<task-notification' in c[:200] else ('system-reminder' if '<system-reminder' in c[:80] else ('summary' if 'continued from a previous' in c[:300] else 'other'))
        usr[k][0]+=1; usr[k][1]+=gap
    elif isinstance(c,list) and c and c[0].get('type')=='text':
        s=c[0].get('text','')
        k='task-notification' if '<task-notification' in s[:200] else 'user-text-other'
        usr[k][0]+=1; usr[k][1]+=gap
print('models',dict(mod))
print('assistant text-only records',len(txt),'gap h',sum(g for g,_,_ in txt)/3600,'chars',sum(L for _,L,_ in txt),'think chars',sum(t for _,_,t in txt))
txt.sort(reverse=True); print('top gaps',[(round(g),L) for g,L,_ in txt[:8]])
print('short(<300 chars) text records',sum(1 for g,L,_ in txt if L<300),'gap h',sum(g for g,L,_ in txt if L<300)/3600)
print({k:(v[0],round(v[1]/3600,2)) for k,v in usr.items()})
