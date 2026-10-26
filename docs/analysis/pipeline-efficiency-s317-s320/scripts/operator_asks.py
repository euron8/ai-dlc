import json,glob,os,datetime as dt,collections
ROOT=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
E=[("2026-10-05T14:00:00Z",None),("2026-10-12T02:30:00Z",317),("2026-10-14T22:00:00Z",318),("2026-10-23T09:53:00Z",319),("2099",320)]
def sp(t):
    for e,n in E:
        if t<e: return n
def ts(s): return dt.datetime.fromisoformat(s.replace("Z","+00:00")).timestamp()
C=collections.defaultdict(lambda:[0,0,0.0,[]])
for p in glob.glob(ROOT+"/*.jsonl"):
    if os.path.getmtime(p)<dt.datetime(2026,10,5).timestamp(): continue
    pend={}
    for line in open(p,errors="replace"):
        try:r=json.loads(line)
        except: continue
        t=r.get("timestamp")
        if not t or t<E[0][0]: continue
        if r.get("type")=="assistant":
            for c in r["message"].get("content") or []:
                if isinstance(c,dict) and c.get("type")=="tool_use" and c.get("name")=="AskUserQuestion":
                    pend[c["id"]]=(t,len(c["input"].get("questions",[])))
        elif r.get("type")=="user" and isinstance(r["message"].get("content"),list):
            for x in r["message"]["content"]:
                if isinstance(x,dict) and x.get("tool_use_id") in pend:
                    t0,nq=pend.pop(x["tool_use_id"]); c=C[sp(t0)]; w=ts(t)-ts(t0)
                    c[0]+=1;c[1]+=nq;c[2]+=w;c[3].append(w)
for n in (317,318,319,320):
    c=C[n]; ws=sorted(c[3])
    print(f"s{n}: AskUserQuestion calls {c[0]}, questions {c[1]}, total answer wait {c[2]/3600:.1f}h, median {ws[len(ws)//2]/60 if ws else 0:.0f} min, >1h: {sum(w>3600 for w in ws)}")
