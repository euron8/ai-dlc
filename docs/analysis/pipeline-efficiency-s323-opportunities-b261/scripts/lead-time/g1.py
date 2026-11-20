import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json,collections,pickle,bisect,datetime as dt
from lib import grp
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
def T(s): return dt.datetime.fromisoformat(s.replace("Z","+00:00")).timestamp()
calls, ivs, res, comps, flows, order = pickle.load(open("lib.pkl","rb"))
sp=collections.defaultdict(list)
for l in open(M+"spawns.jsonl"):
    r=json.loads(l); sp[r["sess"]].append((T(r["start"]),T(r["end"])))
# need interval end time: recompute from rec stream. Rebuild minimal: iterate rec in same order
units=collections.OrderedDict()
for l in open('x/rec.jsonl'):
    e=json.loads(l); units.setdefault(e['u0'],[]).append(e)

_keep=set()
for _l in open('x/units.jsonl'):
    _r=json.loads(_l)
    if any(k.split('|',1)[0]!='pre-step' for k in _r['tok']): _keep.add(_r['unit'])
units=collections.OrderedDict((u,v) for u,v in units.items() if u in _keep)
# we need per-interval timestamp: ivs are in same order as records (excluding first per unit). rebuild index list
ts=[]
for u,evs in units.items():
    for k,e in enumerate(evs):
        if k==0: continue
        ts.append((u,e["f"]))
assert len(ts)==len(ivs), (len(ts),len(ivs))
def running(sess,t):
    return any(a<=t<=b for a,b in sp.get(sess,[]))
for SP in (321,322,323):
    A=collections.defaultdict(lambda:collections.Counter())
    for (u,f),(u2,s,st,d,cls,mid,sk,ty,det) in zip(ts,ivs):
        assert u==u2
        if s!=SP or d>300: continue
        g=grp(st)
        k="tool" if sk.startswith("tool:") else sk
        if k in("harness","idle-wait","wake"):
            k=("wait while subagent running" if running(u[:8],f-d/2) else "wait, no subagent running")+" ("+k+")"
        A[g][k]+=d; A["ALL"][k]+=d
    print("== s%d lead active (<=300s intervals) split; hours"%SP)
    for g in ("ALL","planning","impl+gate","sprint-review","rest"):
        a=A[g]; tot=sum(a.values())
        agg=collections.Counter()
        for k,v in a.items():
            kk="model" if k=="model" else "tool" if k=="tool" else "WAIT(agent running)" if k.startswith("wait while") else "idle/harness (no agent running)"
            agg[kk]+=v
        print("  %-14s total %5.1fh | "%(g,tot/3600)+" | ".join("%s %.1f"%(k,v/3600) for k,v in agg.most_common()))
    if SP==323:
        for k,v in A["ALL"].most_common(): print("      ",k,"%.2f"%(v/3600))
