import json,sys,glob,os
sess,t0,t1=sys.argv[1],sys.argv[2],sys.argv[3]; n=int(sys.argv[4]) if len(sys.argv)>4 else 600
p=glob.glob(os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/"+sess+"*.jsonl"))[0]
for l in open(p,errors="replace"):
    try:r=json.loads(l)
    except: continue
    t=r.get("timestamp","")
    if not(t0<=t<=t1): continue
    typ=r.get("type"); c=(r.get("message") or {}).get("content")
    if typ=="assistant" and isinstance(c,list):
        for b in c:
            if b.get("type")=="text" and b["text"].strip(): print(f"{t[11:19]} A: {b['text'][:n]!r}")
            elif b.get("type")=="tool_use":
                i=b.get("input") or {}; d=i.get("description") or i.get("command") or i.get("file_path") or i.get("summary") or ""
                print(f"{t[11:19]} T {b['name']}: {str(d)[:150]!r}")
    elif typ=="user":
        if isinstance(c,list):
            for b in c:
                if b.get("type")=="text": print(f"{t[11:19]} U: {b['text'][:n]!r}")
        elif isinstance(c,str): print(f"{t[11:19]} U: {c[:n]!r}")
