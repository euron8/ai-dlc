import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json,collections,pickle,re,datetime as dt,statistics as S
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
def T(s): return dt.datetime.fromisoformat(s.replace("Z","+00:00")).timestamp()
sp={}
for l in open(M+"spawns.jsonl"):
    r=json.loads(l); sp[(r["sess"],r["unit"])]=r
calls, ivs, res, comps, flows, order = pickle.load(open("lib.pkl","rb"))
units=collections.OrderedDict()
for l in open('x/rec.jsonl'):
    e=json.loads(l); units.setdefault(e['u0'],[]).append(e)
def pct(a,p):
    a=sorted(a); return a[min(len(a)-1,int(p*len(a)))] if a else 0
STATE_TOOLS=("Agent","Task","SendMessage","Edit","Write","MultiEdit")
for SP in (321,322,323):
    out=[]; nspawn_total=0; unmatched=0
    for u,evs in units.items():
        sess=u[:8]
        # open spawns of this lead: from spawns
        mine=[r for (s,un),r in sp.items() if s==sess and r["sprint"]==SP]
        starts=sorted((T(r["start"]),T(r["end"])) for r in mine)
        # index of calls by unit sorted
        seq=[calls[m] for m in order[u]]
        pend_ask=[]  # (t_use, t_res)
        for i,e in enumerate(evs):
            if e["s"]!=SP or e["ty"]!="queue-operation" or e.get("op")!="enqueue": continue
            tx=e.get("tx") or ""
            m=re.search(r"<task-id>([0-9a-f]{8,})</task-id>",tx)
            if not tx.startswith("<task-notification") or not m: continue
            r=sp.get((sess,"agent-"+m.group(1)))
            if not r: unmatched+=1; continue
            nspawn_total+=1
            Tn=e["f"]; Tend=T(r["end"])
            # state at enqueue
            j=i-1; st="busy"
            while j>=0 and evs[j]["ty"] in("queue-operation","attachment","api-request","file-history-delta","pr-link","api-request-shape"): j-=1
            if j>=0:
                p=evs[j]
                if p["ty"]=="system" and p.get("sub") in("turn_duration","stop_hook_summary"): st="idle"
                elif p["ty"]=="assistant" and all(b[0]!="tu" for b in p.get("b",[])): st="idle-textend"
            # delivery
            T2=None; k=i+1
            while k<len(evs):
                x=evs[k]
                if x["ty"]=="queue-operation" and x.get("op") in("remove","dequeue") and m.group(1) in (x.get("tx") or ""): T2=x["f"]; break
                k+=1
            if T2 is None: T2=Tn
            # last-of-round: no other spawn of this lead running at Tend (start<Tend<end)
            others=[1 for a,b in starts if a<Tend<b and abs(b-Tend)>1e-3]
            # next state change after T2
            nxt=None; compact=False; ask=False
            for k2 in range(i,len(evs)):
                x=evs[k2]
                if x["f"]<T2-1e-6 and x["ty"]!="system": pass
                if x["ty"]=="system" and x.get("sub")=="compact_boundary" and x["f"]>=Tn-30: compact=True
                if x["ty"]=="assistant" and k2>i:
                    tus=[b for b in x.get("b",[]) if b[0]=="tu"]
                    if any(b[1] in STATE_TOOLS or b[1]=="Bash" and ("gate-" in b[3] or "git commit" in b[3] or "git push" in b[3]) for b in tus):
                        if x["f"]>=Tn: nxt=x["f"]; 
                        if nxt is not None:
                            if any(b[1]=="AskUserQuestion" for b in tus): ask=True
                            break
                    if any(b[1]=="AskUserQuestion" for b in tus) and x["f"]>=Tn: ask=True
            if nxt is None: continue
            out.append(dict(lag_end=Tn-Tend, deliver=T2-Tn, react=nxt-Tn, st=st, last=(len(others)==0), compact=compact, ask=ask, role=r["role"]))
    print("== s%d notifications of subagent end matched %d (unmatched task-ids %d), with a following state change %d"%(SP,nspawn_total,unmatched,len(out)))
    if not out: continue
    print("   subagent end -> notification enqueued: median %.1fs p90 %.1fs max %.0fs"%(S.median(o["lag_end"] for o in out),pct([o["lag_end"] for o in out],.9),max(o["lag_end"] for o in out)))
    print("   enqueue -> delivered into lead context: median %.1fs p90 %.1fs"%(S.median(o["deliver"] for o in out),pct([o["deliver"] for o in out],.9)))
    for name,sel in (("ALL",lambda o:True),("LAST-of-round",lambda o:o["last"])):
        w=[o for o in out if sel(o)]
        print("   %s n=%d: enqueue->next dispatch/edit/gate/commit: median %.0fs p90 %.0fs sum %.1fh | capped(<=300s) sum %.2fh"%(name,len(w),S.median(o["react"] for o in w),pct([o["react"] for o in w],.9),sum(o["react"] for o in w)/3600,sum(min(300,o["react"]) for o in w)/3600))
        for cat in ("busy","idle","idle-textend"):
            x=[o for o in w if o["st"]==cat and not o["compact"] and not o["ask"]]
            print("      lead %-12s n%4d median %5.0fs sum(cap300) %.2fh sum(all) %.2fh"%(cat,len(x),S.median(o["react"] for o in x) if x else 0,sum(min(300,o["react"]) for o in x)/3600,sum(o["react"] for o in x)/3600))
        x=[o for o in w if o["compact"]]; print("      compaction inside window n%4d sum(all) %.2fh sum(cap300) %.2fh"%(len(x),sum(o["react"] for o in x)/3600,sum(min(300,o["react"]) for o in x)/3600))
        x=[o for o in w if o["ask"] and not o["compact"]]; print("      operator ask inside window n%4d sum(all) %.2fh sum(cap300) %.2fh"%(len(x),sum(o["react"] for o in x)/3600,sum(min(300,o["react"]) for o in x)/3600))
