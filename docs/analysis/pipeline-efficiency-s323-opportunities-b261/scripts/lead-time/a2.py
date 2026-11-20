import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections
from lib import grp
from fam import fam
calls, ivs, res, comps, *_x = pickle.load(open(os.path.dirname(os.path.abspath(__file__))+"/lib.pkl","rb"))
SP=int(sys.argv[1]); CLS=sys.argv[2]; TOP=int(sys.argv[3]); GRP=sys.argv[4] if len(sys.argv)>4 else "ALL"
SK=("model","tool","wake","idle-wait","harness")
def skk(sk): return "tool" if sk.startswith("tool:") else sk
t=collections.defaultdict(lambda:collections.Counter())
for u,s,st,d,cls,mid,sk,ty,det in ivs:
    if mid is None or d>300 or s!=SP: continue
    t[mid][skk(sk)]+=d
agg=collections.defaultdict(lambda:collections.Counter())
for m,c in calls.items():
    if c["s"]!=SP or c["cls"]!=CLS: continue
    if GRP!="ALL" and grp(c["step"])!=GRP: continue
    f=" / ".join(fam(c)).strip(" /")
    a=agg[f]; a["calls"]+=1
    for k,v in t[m].items(): a[k]+=v; a["act"]+=v
    a["fresh"]+=c["uu"][0]+c["uu"][1]; a["out"]+=c["uu"][3]; a["cr"]+=c["uu"][2]
tot=collections.Counter()
for a in agg.values(): tot.update(a)
print("sprint",SP,"class",CLS,"group",GRP,"calls",tot["calls"],"act %.2fh"%(tot["act"]/3600),"| model %.2f tool %.2f wake %.2f idle %.2f harness %.2f"%tuple(tot[k]/3600 for k in SK),"| fresh %.1fM out %.2fM cr %.0fM"%(tot["fresh"]/1e6,tot["out"]/1e6,tot["cr"]/1e6))
for f,a in sorted(agg.items(), key=lambda kv:-kv[1]["act"])[:TOP]:
    print("%-44s n%5d act%5.2fh %5.1fs | mod %.2f tool %.2f wake %.2f idle %.2f har %.2f | fr %.2fM out %.2fM"%(f[:44],a["calls"],a["act"]/3600,a["act"]/a["calls"],*(a[k]/3600 for k in SK),a["fresh"]/1e6,a["out"]/1e6))
