import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections
from lib import grp
from fam import fam
D=os.path.dirname(os.path.abspath(__file__))
calls, ivs, res, comps, *_x = pickle.load(open(D+"/lib.pkl","rb"))
READP={"grep","sed","cat","ls","awk","tail","head","wc","find","jq","diff","sort","stat","date","cut","tr","uniq","xargs","rg","file","basename","dirname","readlink","pwd","test","comm","nl","column","tee"}
def coarse(c):
    n,f=fam(c)
    if n=="no-tool": return "text-only turn (no tool)"
    if n=="AskUserQuestion": return "AskUserQuestion (operator)"
    if "advisor" in n: return "advisor consult"
    if n=="ToolSearch": return "ToolSearch"
    if n in("Skill","TodoWrite","TaskCreate","TaskUpdate","TaskList","ExitPlanMode","EnterPlanMode"): return "Skill/Todo/bookkeeping"
    if n in("ctx_search","ctx_index","ctx_batch_execute","ctx_fetch_and_index"): return "ctx_search/index/batch"
    if n=="ctx_execute":
        if f.startswith("shell:sh:"):
            p=f[9:]; return "ctx_execute shell read" if p in READP else "ctx_execute shell other:"+p
        if f.startswith("shell:"): return "ctx_execute shell "+f[6:]
        return "ctx_execute "+f
    if n=="Bash":
        if f.startswith("sh:"):
            p=f[3:]
            if p in READP: return "Bash shell read (grep/sed/cat/ls/awk/..)"
            if p=="sleep": return "Bash sleep"
            return "Bash other prog"
        if f.startswith("git ") or f.startswith("gh "): return "Bash git/gh"
        if f.startswith("script:"): return "Bash script"
        return "Bash "+f
    if n in("Read",): return "Read "+f
    if n in("Grep","Glob"): return "Grep/Glob"
    if n in("Edit","Write","MultiEdit"): return n+" "+f
    return n
SP=int(sys.argv[1]); TOP=int(sys.argv[2]); GRP=sys.argv[3]
t=collections.defaultdict(collections.Counter)
for u,s,st,d,cls,mid,sk,ty,det in ivs:
    if mid is None or d>300 or s!=SP: continue
    t[mid]["tool" if sk.startswith("tool:") else sk]+=d
agg=collections.defaultdict(collections.Counter)
for m,c in calls.items():
    if c["s"]!=SP or c["cls"]!="other": continue
    if GRP!="ALL" and grp(c["step"])!=GRP: continue
    a=agg[coarse(c)]; a["calls"]+=1
    for k,v in t[m].items(): a[k]+=v; a["act"]+=v
    a["fresh"]+=c["uu"][0]+c["uu"][1]; a["out"]+=c["uu"][3]
for f,a in sorted(agg.items(), key=lambda kv:-kv[1]["act"])[:TOP]:
    print("%-44s n%5d act%5.2fh | mod %.2f tool %.2f wait %.2f | fr %.2fM out %.2fM"%(f[:44],a["calls"],a["act"]/3600,a["model"]/3600,a["tool"]/3600,(a["harness"]+a["wake"]+a["idle-wait"])/3600,a["fresh"]/1e6,a["out"]/1e6))
