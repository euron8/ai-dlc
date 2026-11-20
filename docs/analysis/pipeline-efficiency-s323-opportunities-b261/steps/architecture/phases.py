import re,collections
# (name, start, end) HH:MM:SS; ev_a spans midnight; ev_b separate
A=[('P0 read step+dispatch prep','20:45:25','20:48:00'),('P1 architect chain (join)','20:48:00','21:09:00'),('P2 adopt+pm routing+fold','21:09:00','21:15:30'),('P3 party 20 seats','21:15:30','21:33:30'),('P4 party repair+lane+fanin+rulings','21:33:30','22:31:37'),('P5 V1 advisor+ripple fixes','22:31:37','22:40:09'),('P6 elicitation 5 shards','22:40:09','22:54:00'),('P7 elicitation repair+serial','22:54:00','23:14:00'),('P8 R12 verify+advisor+fixer','23:14:00','23:31:38'),('P9 adv p1 5 shards+merge','23:31:38','23:50:00'),('P10 p1 repair 4+serial','23:50:00','24:15:00'),('P11 adv p2','24:15:00','24:32:00'),('P12 handoff+push','24:32:00','24:40:00')]
B=[('Q1 resume+postMET repair dispatch','02:18:00','02:35:00'),('Q2 changelog+index+commit+Seam B','02:35:00','02:44:40'),('Q3 gate load+script arms','02:44:40','02:52:47'),('Q4 gate adj1+Check2 fail+repair','02:52:47','03:07:00'),('Q5 gate re-run(adj2)+verdicts','03:07:00','03:24:00'),('Q6 gate log+snapshot+check35','03:24:00','03:36:38')]
def sec(t):
    h,m,s=map(int,t.split(':')); return h*3600+m*60+s
def load(f,add):
    rows=[]
    for l in open(f):
        p=l.split(' ',2)
        if len(p)<3: continue
        s=sec(p[0]); 
        if add and s<12*3600: s+=86400
        rows.append((s,p[1]))
    return rows
for f,ph,add in (('ev_a.txt',A,True),('ev_b.txt',B,False)):
    rows=load(f,add)
    for n,a,b in ph:
        sa,sb=sec(a),sec(b)
        c=collections.Counter(t for s,t in rows if sa<=s<sb)
        calls=sum(v for k,v in c.items() if k not in('TEXT','USER'))
        print(f"{n:38} {(sb-sa)/60:5.0f}min calls={calls:3} adv={c['mcp__advisor__consult']} agent={c['Agent']} bash={c['Bash']} read={c['Read']} edit={c['Edit']}")
