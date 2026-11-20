import collections,sys
W=[("A pre/readiness/epics/briefs","03:36","03:59"),("B party round","03:59","04:31"),("C party repair+serial","04:31","05:55"),("D elicitation","05:55","06:21"),("E elicitation repair","06:21","07:41"),("F adv p1","07:41","08:00"),("G adv p1 repair","08:00","08:38"),("H adv p2","08:38","09:50"),("I adv p2 repair","09:50","10:20"),("J ts author","10:20","10:46"),("K ts p1+repair+bind+commit","10:46","11:43"),("L gate","11:43","12:41")]
rows=[l.rstrip('\n') for l in open(sys.argv[1])]
for name,a,b in W:
    c=collections.Counter(); n=0
    for r in rows:
        t=r[6:11]   # MM-DDTHH:MM -> r[0:11] is '11-18T03:36'
        t=r[6:11]
        if a<=t<b: c[r.split(' ')[1]]+=1; n+=1
    print(name,a,b,n,dict(c.most_common(6)))
