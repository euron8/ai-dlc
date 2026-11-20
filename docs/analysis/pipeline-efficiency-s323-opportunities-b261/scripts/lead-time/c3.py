import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections, statistics as S
from fam import path_family, bash_fam
D=os.path.dirname(os.path.abspath(__file__))
calls, ivs, res, comps, flows, order = pickle.load(open(D+"/lib.pkl","rb"))
SP=int(sys.argv[1])
agg=collections.defaultdict(lambda:[0,0])
tot=0
for u,s,ci,kind,name,summ,b in flows:
    if s!=SP: continue
    if kind=="res":
        n=name.split("__")[-1] if name else "?"
        if n=="Read": k="Read:"+path_family(summ.split(" |")[0])
        elif n=="Bash": k="Bash:"+bash_fam(summ)
        elif n=="ctx_execute": k="ctx_execute"
        else: k=n
    elif kind=="utext":
        h=name
        k="user-text:"+("task-notification" if h.startswith("<task-notif") else "system-reminder" if h.startswith("<system-rem") else "teammate/cross-session" if h.startswith("<teammate") or h.startswith("<cross") else "compaction-summary" if h.startswith("This session is being") else "other/human")
    else:
        k="attachment:"+name
    a=agg[k]; a[0]+=1; a[1]+=b or 0; tot+=b or 0
nB=len([c for c in comps if c["s"]==SP and not c.get("cs")])
outtok=sum(c["uu"][3] for c in calls.values() if c["s"]==SP); ncalls=sum(1 for c in calls.values() if c["s"]==SP)
print("s%d: flows into lead context %.1f MB over %d calls (%d compaction cycles); assistant output %.1fM tokens"%(SP,tot/1e6,ncalls,nB,outtok/1e6))
print("  per cycle: %.0f KB result/attachment/text bytes + %.0fk output tokens; context grows ~ (pre-post) %.0fk tokens per cycle => %.2f tokens/byte if outputs counted"%(tot/nB/1e3,outtok/nB/1e3,S.mean([c.get("preTokens",0)-c.get("postTokens",0) for c in comps if c["s"]==SP and not c.get("cs")])/1e3,(S.mean([c.get("preTokens",0)-c.get("postTokens",0) for c in comps if c["s"]==SP and not c.get("cs")])-outtok/nB)/(tot/nB)))
for k,v in sorted(agg.items(), key=lambda kv:-kv[1][1])[:int(sys.argv[2])]:
    print("  %-46s n%6d  %7.2f MB  %4.1f%%  avg %6.0f B"%(k[:46],v[0],v[1]/1e6,100*v[1]/tot,v[1]/max(1,v[0])))
