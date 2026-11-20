import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections
from fam import path_family, bash_fam
calls, ivs, res, comps, flows, order = pickle.load(open("lib.pkl","rb"))
def key(kind,name,summ,b):
    if kind=="res":
        n=name.split("__")[-1] if name else "?"
        if n=="Read": return "Read:"+path_family(summ.split(" |")[0])
        if n=="Bash": return "Bash result"
        return {"ctx_execute":"ctx_execute result","Agent":"Agent result"}.get(n,n+" result")
    if kind=="utext":
        if name.startswith("Base directory for this"): return "SKILL text load (Skill tool)"
        if name.startswith("<task"): return "task-notification text"
        if name.startswith("This session is being"): return "compaction summary"
        if name.startswith("Stop hook feedback"): return "Stop-hook feedback"
        return "user text other"
    return "att:"+name.split(":")[0]+(":"+name.split(":")[1] if name.startswith("hook_additional") else "")
SPR=(321,322,323)
A={s:collections.defaultdict(lambda:[0,0]) for s in SPR}; nB={}
for s in SPR: nB[s]=len([c for c in comps if c["s"]==s and not c.get("cs")])
for u,s,ci,kind,name,summ,b in flows:
    if s not in SPR or name=="prompt_snapshot": continue
    k=key(kind,name,summ,b); A[s][k][0]+=1; A[s][k][1]+=b or 0
tot323=sum(v[1] for v in A[323].values())
print("excluding attachment prompt_snapshot (a system-prompt log). KB per compaction cycle (count/cycle in parens). cycles: "+str(nB))
for k,v in sorted(A[323].items(), key=lambda kv:-kv[1][1])[:20]:
    print("%-44s "%k[:44]+"  ".join("s%d %6.1fKB(%4.1f)"%(s,A[s][k][1]/nB[s]/1e3,A[s][k][0]/nB[s]) for s in SPR)+"  s323 share %.1f%%"%(100*v[1]/tot323))
