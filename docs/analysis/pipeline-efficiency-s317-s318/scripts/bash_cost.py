import json,glob,os,re,collections,datetime as dt
ROOT=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
cut=dt.datetime(2026,10,5,9,0).timestamp()
files=[p for p in glob.glob(ROOT+"/*.jsonl")+glob.glob(ROOT+"/*/subagents/*.jsonl") if os.path.getmtime(p)>=cut]
def T(s): return dt.datetime.fromisoformat(s.replace("Z","+00:00")).timestamp()
lat=collections.Counter(); n=collections.Counter(); first=collections.Counter(); firstn=collections.Counter()
for p in files:
    kind="sub" if "/subagents/" in p else "lead"
    pend={}; firstcall=True
    for l in open(p,errors="replace"):
        try: r=json.loads(l)
        except: continue
        t=r.get("timestamp")
        if not t or t<"2026-10-05T14:00:00Z": continue
        if r.get("type")=="assistant":
            u=r["message"].get("usage")
            if u and firstcall and kind=="sub":
                first["cw"]+=u.get("cache_creation_input_tokens",0); first["cr"]+=u.get("cache_read_input_tokens",0); firstn["n"]+=1; firstcall=False
            for c in r["message"].get("content") or []:
                if isinstance(c,dict) and c.get("type")=="tool_use" and c.get("name")=="Bash":
                    cmd=c.get("input",{}).get("command","")
                    m=re.findall(r"(?:pytest|npm (?:run )?\w+|npx \w+|[\w.-]+\.sh|git (?:push|fetch|merge|pull|rebase|commit|log|diff|status|worktree)|cargo \w+|make \w+|sleep|python3? [\w./-]+)",cmd)
                    key=m[0] if m else cmd.split()[0] if cmd.split() else "?"
                    key=re.sub(r"^.*/","",key)
                    pend[c["id"]]=(kind,key,T(t))
        elif r.get("type")=="user":
            c=r.get("message",{}).get("content")
            if isinstance(c,list):
                for x in c:
                    if isinstance(x,dict) and x.get("type")=="tool_result" and x.get("tool_use_id") in pend:
                        k,key,t0=pend.pop(x["tool_use_id"]); d=T(t)-t0
                        lat[(k,key)]+=d; n[(k,key)]+=1
print("subagent first-call context: n",firstn["n"],"avg cw",first["cw"]//max(1,firstn["n"]),"avg cr",first["cr"]//max(1,firstn["n"]))
for k,v in sorted(lat.items(),key=lambda x:-x[1])[:35]: print(k[0],k[1][:45].ljust(45),n[k],round(v/3600,2),"h",round(v/max(1,n[k])),"s/call")
