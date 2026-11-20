import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections
D=os.path.dirname(os.path.abspath(__file__))
calls, ivs, res, comps, *_x = pickle.load(open(D+"/lib.pkl","rb"))
SP=int(sys.argv[1])
c=collections.defaultdict(lambda:[0,0.0])
for u,s,st,d,cls,mid,sk,ty,det in ivs:
    if s!=SP or d>300 or cls!="other" or mid is None: continue
    if sk!="harness": continue
    k=(ty,det); c[k][0]+=1; c[k][1]+=d
for k,v in sorted(c.items(), key=lambda kv:-kv[1][1])[:14]: print(k, v[0], "%.2fh"%(v[1]/3600))
