import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections, sys
from lib import grp
from fam import fam
calls, ivs, res, comps = pickle.load(open("lib.pkl","rb"))
SP=int(sys.argv[1]) if len(sys.argv)>1 else 323
# per mid time
t=collections.defaultdict(lambda:[0.0,0.0,0.0,0.0])  # act, gap, model, tool
for u,s,st,d,cls,mid,sk,ty in ivs:
    if mid is None: continue
    x=t[mid]
    if d<=300:
        x[0]+=d
        if sk=="model": x[2]+=d
        elif sk.startswith("tool:"): x[3]+=d
    else: x[1]+=d
# fate
fate={}
for tid,r in res.items():
    pass
bymid=collections.defaultdict(list)
for tid,r in res.items():
    if r["mid"]: bymid[r["mid"]].append(r)
def fate_of(m,c):
    tus=[b for b in c["b"] if b[0]=="tu"]
    if not tus: return "TEXT"
    rs=bymid.get(m,[])
    if len(rs)<len(tus): return "RAN?"  # missing results
    if all(r["head"].startswith("PreToolUse:") or "hook" in r["head"][:40].lower() and r["err"] for r in rs): return "DENIED"
    if all(r["err"] for r in rs): return "ERRORED"
    return "RAN"
rows=collections.defaultdict(lambda:[0,0.0,0.0,0.0,0,0,0,0.0]) # calls act gap model tool in cc cr out
tot=[0,0.0]
G=collections.defaultdict(lambda:collections.defaultdict(lambda:[0,0.0,0.0,0.0,0,0,0,0]))
for m,c in calls.items():
    if c["s"]!=SP or c["cls"]!="other": continue
    f=fam(c); g=grp(c["step"]); x=t[m]
    for key in ((g,)+f,("ALL",)+f):
        r=G[key[0]][key[1:]]
        r[0]+=1; r[1]+=x[0]; r[2]+=x[1]; r[3]+=x[2]; r[4]+=x[3]; 
        r[5]+=c["uu"][0]+c["uu"][1]; r[6]+=c["uu"][2]; r[7]+=c["uu"][3]
pickle.dump({k:dict(v) for k,v in G.items()},open("a1_%d.pkl"%SP,"wb"))
for g in ("ALL","planning","impl+gate","sprint-review","rest"):
    tt=sum(v[0] for v in G[g].values()); ta=sum(v[1] for v in G[g].values())
    print("=====",g,"calls",tt,"active h %.2f"%(ta/3600), "gap h %.2f"%(sum(v[2] for v in G[g].values())/3600), "model h %.2f tool h %.2f"%(sum(v[3] for v in G[g].values())/3600, sum(v[4] for v in G[g].values())/3600), "fresh+out Mtok %.1f cacheread Mtok %.0f"%(sum(v[5]+v[7] for v in G[g].values())/1e6, sum(v[6] for v in G[g].values())/1e6))
    for k,v in sorted(G[g].items(), key=lambda kv:-kv[1][1])[:(30 if g=="ALL" else 14)]:
        print("  %-52s calls %5d act %5.2fh (%4.1f s/call) model %.2fh tool %.2fh  fresh+out %6.2fM  cr %7.1fM"%(" / ".join(k)[:52],v[0],v[1]/3600,v[1]/v[0],v[3]/3600,v[4]/3600,(v[5]+v[7])/1e6,v[6]/1e6))
