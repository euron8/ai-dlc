import json,glob,os,sys
root=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/")
f=glob.glob(root+sys.argv[1]+"*.jsonl")[0]
for l in open(f):
    d=json.loads(l); ts=d.get('timestamp','')
    if ts>=sys.argv[2] and ts<=sys.argv[3]:
        c=(d.get('message') or {}).get('content'); 
        t=c if isinstance(c,str) else " ".join((x.get('text') or x.get('name') or x.get('type') or '')[:150] for x in (c or []) if isinstance(x,dict))
        print(ts[11:19],d.get('type'),t[:200].replace("\n"," "))
