import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle,collections,re
from fam import fam, path_family
calls, ivs, res, comps, flows, order = pickle.load(open("lib.pkl","rb"))
t=collections.defaultdict(float)
for u,s,st,d,cls,mid,sk,ty,det in ivs:
    if mid and d<=300: t[mid]+=d
PATH=re.compile(r"(?:/[\w.@+-]+){2,}|(?:[\w.@+-]+/){2,}[\w.@+*-]+")
def norm(s): return re.sub(r"\s+"," ",s).strip()
def keys(b):
    n,s=b[1],b[3]
    if n in("Edit","Write","MultiEdit","NotebookEdit","Agent","Task","SendMessage","AskUserQuestion","ToolSearch","TaskStop","Skill"): return None
    ex=n+"|"+norm(s)
    if n=="Bash" or "ctx_execute" in n:
        p=PATH.findall(s); fm=fam({"b":[["tu",n,"",s]]})
        ne=n+"|"+"/".join(fm)+"|"+(p[0] if p else norm(s)[:60])
    else: ne=ex
    return ex,ne
for SP in (321,322,323):
    cyc={}  # unit-> cs count by call index
    cscount=collections.defaultdict(list)
    for c in comps:
        if c.get("cs"): cscount[c["u"]].append(c["ci"])
    seenE={}; seenN={}; ex=collections.defaultdict(lambda:[0,0.0,0.0,0,0]); ne=collections.defaultdict(lambda:[0,0.0,0.0,0,0])
    tot=[0,0.0,0.0]
    for m,c in calls.items():
        if c["s"]!=SP: continue
        tus=[b for b in c["b"] if b[0]=="tu"]
        if not tus: continue
        cy=sum(1 for ci in cscount[c["u"]] if ci<=c["i"])
        w=t[m]/len(tus); fr=(c["uu"][0]+c["uu"][1]+c["uu"][3])/len(tus)
        tot[0]+=len(tus); tot[1]+=t[m]; tot[2]+=c["uu"][0]+c["uu"][1]+c["uu"][3]
        for b in tus:
            k=keys(b)
            if not k: continue
            rb=res.get(b[2],{}).get("b")
            for K,seen,agg in ((k[0],seenE,ex),(k[1],seenN,ne)):
                kk=(c["u"],c["step"],K)
                if kk in seen:
                    pcy,prb=seen[kk]
                    fam_=b[1].split("__")[-1]
                    if b[1]=="Bash":
                        f=fam({"b":[["tu","Bash","",b[3]]]})[1]
                        fam_="Bash "+(f if f.startswith(("script:","git ")) else "other")
                    a=agg[("same-cycle" if pcy==cy else "after-compaction",fam_)]
                    a[0]+=1; a[1]+=w; a[2]+=fr; a[3]+= (1 if rb is not None and rb==prb else 0)
                seen[kk]=(cy,rb)
    print("== s%d lead tool_use blocks %d, active %.1fh (per-call shared over blocks)"%(SP,tot[0],tot[1]/3600))
    for nm,agg in (("EXACT repeat (same unit+step+tool+command/path)",ex),("NEAR repeat (same tool+program+first path)",ne)):
        n=sum(v[0] for v in agg.values()); h=sum(v[1] for v in agg.values())/3600; fr=sum(v[2] for v in agg.values())/1e6; same=sum(v[3] for v in agg.values())
        sc=sum(v[0] for k,v in agg.items() if k[0]=="same-cycle"); hs=sum(v[1] for k,v in agg.items() if k[0]=="same-cycle")/3600
        print("  %s: %d blocks, %.2fh, fresh+out %.2fM, identical result size %d | of which within one compaction cycle %d (%.2fh)"%(nm,n,h,fr,same,sc,hs))
        if SP==323:
            for k,v in sorted(agg.items(), key=lambda kv:-kv[1][1])[:9]:
                print("      %-34s n%4d %.2fh same-size %3d"%(" / ".join(k)[:34],v[0],v[1]/3600,v[3]))
