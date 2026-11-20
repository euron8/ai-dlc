import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections, statistics as S, json
D=os.path.dirname(os.path.abspath(__file__))
calls, ivs, res, comps, flows, order = pickle.load(open(D+"/lib.pkl","rb"))
def pct(a,p):
    a=sorted(a); return a[min(len(a)-1,int(p*len(a)))] if a else 0
# wall time around boundary: last call end before boundary -> first call start after
for SP in (321,322,323):
    B=[c for c in comps if c["s"]==SP and not c.get("cs")]
    rows=[]
    for c in B:
        seq=order[c["u"]]; i=c["ci"]
        if i==0 or i>=len(seq): continue
        prev=calls[seq[i-1]]; nxt=calls[seq[i]]
        # nxt.treq is the api-request for first post-compaction call
        rows.append((c.get("durationMs",0)/1000, c["f"]-prev["t1"], nxt["t1"]-c["f"], (nxt["t1"]-nxt["treq"]) if nxt["treq"] else None, nxt["uu"][0]+nxt["uu"][1], c.get("postTokens",0), nxt["model"]))
    long_=[r for r in rows if r[0]>=1]; short=[r for r in rows if r[0]<1]
    print("s%d n=%d  (summarizer dur>=1s: %d, <1s: %d)"%(SP,len(rows),len(long_),len(short)))
    for name,rr in (("dur>=1s",long_),("dur<1s",short)):
        if not rr: continue
        print("   %-8s pre-call end -> boundary stamp: median %.0fs p90 %.0fs | boundary -> first post call end: median %.0fs p90 %.0fs | first post call own latency median %.1fs p90 %.1fs; uncached tok median %.0fk"%(name,S.median(r[1] for r in rr),pct([r[1] for r in rr],.9),S.median(r[2] for r in rr),pct([r[2] for r in rr],.9),S.median(r[3] for r in rr if r[3] is not None),pct([r[3] for r in rr if r[3] is not None],.9),S.median(r[4] for r in rr)/1e3))
    # compare: steady state qwen latency by uncached bucket
