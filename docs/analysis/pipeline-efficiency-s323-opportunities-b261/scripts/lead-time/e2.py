import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json,collections,pickle,re,datetime as dt,statistics as S
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
def T(s): return dt.datetime.fromisoformat(s.replace("Z","+00:00")).timestamp()
sp={}
for l in open(M+"spawns.jsonl"):
    r=json.loads(l); sp[(r["sess"],r["unit"])]=r
units=collections.OrderedDict()
for l in open('x/rec.jsonl'):
    e=json.loads(l); units.setdefault(e['u0'],[]).append(e)

_keep=set()
for _l in open('x/units.jsonl'):
    _r=json.loads(_l)
    if any(k.split('|',1)[0]!='pre-step' for k in _r['tok']): _keep.add(_r['unit'])
units=collections.OrderedDict((u,v) for u,v in units.items() if u in _keep)
def pct(a,p):
    a=sorted(a); return a[min(len(a)-1,int(p*len(a)))] if a else 0
STATE=("Agent","Task","SendMessage","Edit","Write","MultiEdit")
for SP in (321,322,323):
    out=[]
    for u,evs in units.items():
        sess=u[:8]
        mine=[r for (s,un),r in sp.items() if s==sess and r["sprint"]==SP]
        starts=[(T(r["start"]),T(r["end"])) for r in mine]
        for i,e in enumerate(evs):
            if e["s"]!=SP or e["ty"]!="queue-operation" or e.get("op")!="enqueue": continue
            tx=e.get("tx") or ""; m=re.search(r"<task-id>([0-9a-f]{8,})</task-id>",tx)
            if not tx.startswith("<task-notification") or not m: continue
            r=sp.get((sess,"agent-"+m.group(1)))
            if not r: continue
            Tn=e["f"]; Tend=T(r["end"])
            if any(a<Tend-1e-3 and Tend+1e-3<b for a,b in starts): continue   # not last of round
            # in-flight state
            pend={}; state="idle"; 
            j=i-1; last=None
            while j>=0:
                x=evs[j]
                if x["ty"]=="assistant" and x.get("b"):
                    last=x; break
                if x["ty"]=="system" and x.get("sub") in("turn_duration",): state="idle(turn ended)"; break
                j-=1
            if state=="idle":
                # was there a tool_use without result before i?
                tus={}; 
                for x in evs[max(0,i-60):i]:
                    for b in x.get("b",[]) if x["ty"]=="assistant" else []:
                        if b[0]=="tu": tus[b[2]]=b
                    for rr in x.get("res") or []: tus.pop(rr[0],None)
                if tus:
                    b=list(tus.values())[-1]; sm=b[3]
                    if "wait-for-deliverable" in sm: state="in own wait-for-deliverable.sh poll"
                    elif re.search(r"\bsleep\b",sm): state="in own sleep"
                    elif b[1] in("Agent","Task"): state="in Agent dispatch call"
                    elif b[1]=="AskUserQuestion": state="operator ask pending"
                    elif b[1]=="mcp__advisor__consult": state="in advisor consult"
                    else: state="in other tool: "+("Bash" if b[1]=="Bash" else b[1].split("__")[-1])
                else:
                    state="model generating / between calls"
            # delivery and first call, next state change
            T2=None
            for k in range(i+1,len(evs)):
                x=evs[k]
                if x["ty"]=="queue-operation" and x.get("op") in("remove","dequeue") and m.group(1) in (x.get("tx") or ""): T2=x["f"]; break
            if T2 is None: T2=Tn
            first=None; nxt=None; comp=False
            for k in range(i+1,len(evs)):
                x=evs[k]
                if x["ty"]=="system" and x.get("sub")=="compact_boundary": comp=True
                if x["ty"]=="assistant" and x["f"]>=T2 and first is None: first=x["f"]
                if x["ty"]=="assistant" and any(b[0]=="tu" and (b[1] in STATE or (b[1]=="Bash" and re.search(r"gate-|git commit|git push",b[3]))) for b in x.get("b",[])) and x["f"]>=T2: nxt=x["f"]; break
            if nxt is None: continue
            out.append(dict(state=state,deliver=T2-Tn,first=(first or T2)-Tn,react=nxt-Tn,comp=comp,role=r["role"]))
    print("== s%d LAST-of-round subagent completions with a later dispatch/edit/gate/commit: n=%d  | enqueue->next action: median %.0fs p90 %.0fs sum %.2fh; capped at 600s per event %.2fh"%(SP,len(out),S.median(o["react"] for o in out),pct([o["react"] for o in out],.9),sum(o["react"] for o in out)/3600,sum(min(600,o["react"]) for o in out)/3600))
    print("   enqueue->first lead response record: median %.0fs sum(cap600) %.2fh ; delivery lag median %.1fs sum(cap600) %.2fh"%(S.median(o["first"] for o in out),sum(min(600,o["first"]) for o in out)/3600,S.median(o["deliver"] for o in out),sum(min(600,o["deliver"]) for o in out)/3600))
    by=collections.defaultdict(list)
    for o in out: by[o["state"]].append(o)
    for k,v in sorted(by.items(), key=lambda kv:-sum(min(600,o["react"]) for o in kv[1])):
        print("      %-40s n%4d  first-response median %5.0fs sum(cap600) %.2fh | to-next-action median %5.0fs sum(cap600) %.2fh | compaction in window %d"%(k[:40],len(v),S.median(o["first"] for o in v),sum(min(600,o["first"]) for o in v)/3600,S.median(o["react"] for o in v),sum(min(600,o["react"]) for o in v)/3600,sum(o["comp"] for o in v)))
