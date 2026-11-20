import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json,collections,pickle,re
calls, ivs, res, comps, flows, order = pickle.load(open("lib.pkl","rb"))
t=collections.defaultdict(float)
for u,s,st,d,cls,mid,sk,ty,det in ivs:
    if mid and d<=300: t[mid]+=d
def hookname(h):
    m=re.match(r"PreToolUse:[\w_.\-]+ hook error: (.{0,60})",h)
    if m:
        x=m.group(1)
        for k in ("post-compact recovery","context-mode: ","steering budget","dispatch guard","core-guard","acknowledge","gate-remediation","advisor"):
            if k in x: return k.strip(": ")
        return x[:40]
    return h[:40]
for SP in (321,322,323):
    agg=collections.defaultdict(lambda:[0,0.0,0,0,0.0]); seen=set()
    for tid,r in res.items():
        c=calls.get(r["mid"]) if r["mid"] else None
        if not c or c["s"]!=SP: continue
        h=r["head"]
        if not (h.startswith("PreToolUse:") or ("hook" in h[:60].lower() and r["err"])): continue
        k=(r["name"].split("__")[-1] if r["name"] else "?")+" | "+hookname(h)
        a=agg[k]; a[0]+=1
        if r["mid"] not in seen:
            seen.add(r["mid"]); a[1]+=t[r["mid"]]; a[3]+=c["uu"][0]+c["uu"][1]+c["uu"][3]
        # retry: next call same tool name within order
        seq=order[c["u"]]; i=c["i"]
        if i+1<len(seq):
            n=calls[seq[i+1]]; nn=[b[1] for b in n["b"] if b[0]=="tu"]
            if nn and r["name"] in nn: a[2]+=1; a[4]+=t[seq[i+1]]
    tot=sum(v[0] for v in agg.values())
    print("== s%d denied tool results %d, calls' own active %.2fh, next-call-same-tool (retry) %d with active %.2fh"%(SP,tot,sum(v[1] for v in agg.values())/3600,sum(v[2] for v in agg.values()),sum(v[4] for v in agg.values())/3600))
    for k,v in sorted(agg.items(), key=lambda kv:-kv[1][0])[:7]:
        print("   %-62s denied %3d  active %.2fh  retried-next-call %3d (%.2fh)  fresh+out %.2fM"%(k[:62],v[0],v[1]/3600,v[2],v[4]/3600,v[3]/1e6))
