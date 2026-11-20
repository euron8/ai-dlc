import json,sys
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
sprint=323
W=[("A preflight analyst","03:00","03:55"),("B party round","03:55","04:30"),("C party repair (+lanes, fan-in)","04:30","05:55"),("D elicitation","05:55","06:20"),("E elicitation repair (+serial)","06:20","07:40"),("F adv p1 review","07:40","08:00"),("G adv p1 repair","08:00","08:37"),("H adv p2 review (+retries)","08:37","09:48"),("I adv p2 repair","09:48","10:20"),("J ts author","10:20","10:45"),("K ts p1 review","10:45","11:10"),("L ts repair (serial lane)","11:10","11:40"),("M gate repairs","11:40","12:20"),("N gate adjudicators","12:20","13:00")]
sp=[json.loads(l) for l in open(M+"spawns.jsonl")]
sp=[s for s in sp if s['sprint']==sprint and s['step'] in('stories-test-strategy','gate-validation[stories-test-strategy]') and s['start'][:10]=='2026-11-18']
tot=[0,0,0]
for n,a,b in W:
    g=[s for s in sp if a<=s['start'][11:16]<b]
    if not g: continue
    st=min(s['start'] for s in g); en=max(s['end'] for s in g)
    from datetime import datetime
    f=lambda x: datetime.fromisoformat(x.replace('Z','+00:00'))
    wall=(f(en)-f(st)).total_seconds()/60
    print(f"{n:34s} spawns {len(g):3d} ${sum(s['usd'] for s in g):6.1f} spawn-min {sum(s['minutes'] for s in g):7.1f} wall-min {wall:5.1f} {st[11:16]}-{en[11:16]}")
    tot[0]+=len(g);tot[1]+=sum(s['usd'] for s in g)
print(tot, 'step spawns total', len(sp))
