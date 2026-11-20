import json,sys
from datetime import datetime
F=sys.argv[1]
f=lambda x: datetime.fromisoformat(x.replace('Z','+00:00'))
ts=[]
for l in open(F):
    try:o=json.loads(l)
    except: continue
    t=o.get('timestamp')
    if t and '2026-11-18T03:36'<=t<='2026-11-18T12:41': ts.append(t)
ts.sort()
W=[("A pre/readiness/epics/briefs","03:36","03:59"),("B party round","03:59","04:31"),("C party repair+serial","04:31","05:55"),("D elicitation","05:55","06:21"),("E elicitation repair","06:21","07:41"),("F adv p1","07:41","08:00"),("G adv p1 repair","08:00","08:38"),("H adv p2","08:38","09:50"),("I adv p2 repair","09:50","10:20"),("J ts author","10:20","10:46"),("K ts p1+repair+bind+commit","10:46","11:43"),("L gate","11:43","12:41")]
act={w[0]:0 for w in W}; wait={w[0]:0 for w in W}
for a,b in zip(ts,ts[1:]):
    g=(f(b)-f(a)).total_seconds()
    k=a[11:16]
    for n,s,e in W:
        if s<=k<e:
            if g<=300: act[n]+=g
            else: wait[n]+=g
tot=[0,0]
for n,s,e in W:
    print(f"{n:30s} active {act[n]/60:6.1f} min  gap>300s {wait[n]/60:6.1f} min")
    tot[0]+=act[n];tot[1]+=wait[n]
print('TOTAL active',round(tot[0]/60,1),'gap>300',round(tot[1]/60,1),'(control: segs say active 355.0, agent_wait 104.5, step+gate)')
