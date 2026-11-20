import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections
D=os.path.dirname(os.path.abspath(__file__))
calls, ivs, res, comps, *_x = pickle.load(open(D+"/lib.pkl","rb"))
for SP in (321,322,323):
    a=collections.Counter(); g=collections.Counter(); tool=collections.Counter(); harn=collections.Counter()
    for u,s,st,d,cls,mid,sk,ty,det in ivs:
        if s!=SP: continue
        if d>300: g[sk if not sk.startswith("tool:") else "tool"]+=d; continue
        k="tool" if sk.startswith("tool:") else sk
        a[k]+=d
        if k=="tool": tool[sk[5:]]+=d
        if k=="harness": harn[(ty,det)]+=d
    tot=sum(a.values())
    print("sprint",SP,"active %.1fh: "%(tot/3600)+" ".join("%s %.1f(%d%%)"%(k,v/3600,100*v/tot) for k,v in a.most_common()),"| gap(>300s) %.1fh"%(sum(g.values())/3600))
    print("   tool top:", ", ".join("%s %.2f"%(k[:28],v/3600) for k,v in tool.most_common(9)))
    print("   harness top:", ", ".join("%s/%s %.2f"%(k[0],k[1][:22],v/3600) for k,v in harn.most_common(6)))
