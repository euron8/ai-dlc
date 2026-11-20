import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections, json, random
from fam import fam
D=os.path.dirname(os.path.abspath(__file__))
calls, ivs, res, comps, *_x = pickle.load(open(D+"/lib.pkl","rb"))
byu=collections.defaultdict(list)
for m,c in calls.items(): byu[c["u"]].append((c["t0"],m))
for u in byu: byu[u].sort()
cs=[c for c in comps if c["s"]==323]
print(len(cs),"compactions s323; trigger",collections.Counter(c.get("trigger") for c in cs))
random.seed(3)
for c in random.sample(cs,3):
    print("--- compaction",c["u"][:8],c["st"],"pre",c.get("preTokens"),"post",c.get("postTokens"),"dur",c.get("durationMs"))
    seq=[(t,m) for t,m in byu[c["u"]] if t>=c["f"]][:16]
    for t,m in seq:
        k=calls[m]; print("  +%5.0fs %-14s %s ctx %dk out %d"%(t-c["f"],k["cls"],"/".join(fam(k))[:70],sum(k["uu"][:3])/1e3,k["uu"][3]))
