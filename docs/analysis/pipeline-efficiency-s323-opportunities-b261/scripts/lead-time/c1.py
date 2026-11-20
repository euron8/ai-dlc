import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections, statistics as S
from fam import fam
D=os.path.dirname(os.path.abspath(__file__))
calls, ivs, res, comps, flows, order = pickle.load(open(D+"/lib.pkl","rb"))
t=collections.defaultdict(float)
for u,s,st,d,cls,mid,sk,ty,det in ivs:
    if mid and d<=300: t[mid]+=d
def pct(a,p):
    a=sorted(a); return a[min(len(a)-1,int(p*len(a)))] if a else 0
STATE_TOOLS=("Agent","Task","SendMessage","Edit","Write","MultiEdit","NotebookEdit")
def reorient(c):
    if c["cls"] in("compaction-recovery","step-reread"): return True
    n,f=fam(c)
    if n in("Read",) and f in("snapshot","step-file","claude-skill/rules","task-output"): return True
    if n in("ToolSearch","Skill","ListAgents"): return True
    return False
def state_change(c):
    if c["cls"] in("dispatch","repair","gate-run"): return True
    n,f=fam(c)
    if n in STATE_TOOLS: return True
    if n=="Bash" and (f.startswith("git commit") or f.startswith("git push") or (f.startswith("script:") and "wait-for" not in f)): return True
    return False
for SP in (321,322,323):
    B=[c for c in comps if c["s"]==SP and not c.get("cs")]; CS=[c for c in comps if c["s"]==SP and c.get("cs")]
    d=[c.get("durationMs",0)/1000 for c in B]; pre=[c.get("preTokens",0) for c in B]; post=[c.get("postTokens",0) for c in B]
    print("== s%d: compact_boundary %d, summary records %d | trigger %s | summarizer durationMs: sum %.2fh median %.1fs p90 %.1fs max %.0fs; <1s: %d | preTokens mean %.0fk median %.0fk max %.0fk | postTokens mean %.0fk"%(SP,len(B),len(CS),dict(collections.Counter(c.get("trigger") for c in B)),sum(d)/3600,S.median(d) if d else 0,pct(d,.9),max(d) if d else 0,sum(1 for x in d if x<1),S.mean(pre)/1e3 if pre else 0,S.median(pre)/1e3 if pre else 0,max(pre)/1e3 if pre else 0,S.mean(post)/1e3 if post else 0))
    WA=[];WB=[]
    for c in CS:
        seq=order[c["u"]][c["ci"]:]
        a=[];i=0
        while i<len(seq) and reorient(calls[seq[i]]): a.append(seq[i]); i+=1
        b=[];i=0
        while i<len(seq) and i<60 and not state_change(calls[seq[i]]): b.append(seq[i]); i+=1
        hit = i<len(seq) and i<60
        WA.append(a); WB.append((b,hit))
    def tot(ms):
        n=len(ms); act=sum(t[m] for m in ms); fr=sum(calls[m]["uu"][0]+calls[m]["uu"][1]+calls[m]["uu"][3] for m in ms); cr=sum(calls[m]["uu"][2] for m in ms)
        return n,act/3600,fr/1e6,cr/1e6
    na=[tot(a) for a in WA]; nb=[tot(b) for b,h in WB]
    print("   window A (leading reorient reads: step/snapshot/skill/task-output/ToolSearch/Skill): calls %d (mean %.1f/compaction), active %.2fh (mean %.0fs), fresh+out %.2fM tok, cache-read %.0fM"%(sum(x[0] for x in na),S.mean(x[0] for x in na) if na else 0,sum(x[1] for x in na),3600*sum(x[1] for x in na)/max(1,len(na)),sum(x[2] for x in na),sum(x[3] for x in na)))
    print("   window B (until first dispatch/edit/gate/commit call, cap 60): calls %d (mean %.1f), active %.2fh (mean %.0fs), fresh+out %.2fM, cache-read %.0fM; windows that hit the cap/never ended: %d"%(sum(x[0] for x in nb),S.mean(x[0] for x in nb) if nb else 0,sum(x[1] for x in nb),3600*sum(x[1] for x in nb)/max(1,len(nb)),sum(x[2] for x in nb),sum(x[3] for x in nb),sum(1 for b,h in WB if not h)))
    # first call after compaction latency: time from CS to first call
    # classer class totals
    cr_calls=[m for m,c in calls.items() if c["s"]==SP and c["cls"]=="compaction-recovery"]
    print("   Classer compaction-recovery: calls %d active %.2fh fresh+out %.2fM; step-reread calls %d active %.2fh"%(len(cr_calls),sum(t[m] for m in cr_calls)/3600,sum(calls[m]["uu"][0]+calls[m]["uu"][1]+calls[m]["uu"][3] for m in cr_calls)/1e6,sum(1 for c in calls.values() if c["s"]==SP and c["cls"]=="step-reread"),sum(t[m] for m,c in calls.items() if c["s"]==SP and c["cls"]=="step-reread")/3600))
    # compactions by step group
    sc=collections.Counter(c["st"].split("[")[0] for c in CS)
    print("   by step:", dict(sc.most_common(8)))
    # cycle length: calls between consecutive CS in same unit, and elapsed time
    gaps=[]; 
    byu=collections.defaultdict(list)
    for c in CS: byu[c["u"]].append(c)
    for u,l in byu.items():
        for a,b in zip(l,l[1:]): gaps.append((b["ci"]-a["ci"], b["f"]-a["f"]))
    if gaps: print("   calls between compactions: median %d mean %.0f ; minutes between: median %.1f mean %.1f"%(S.median(g[0] for g in gaps),S.mean(g[0] for g in gaps),S.median(g[1] for g in gaps)/60,S.mean(g[1] for g in gaps)/60))
