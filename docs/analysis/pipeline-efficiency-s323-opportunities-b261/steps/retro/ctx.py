import json,glob,os,re,sys
root=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/")
for sid,rx in [("4b34031d",r"docs/retro/s322"),("53b4296a",r"docs/retro/s322"),("68cf8de7",r"docs/retro/")]:
    f=glob.glob(root+sid+"*.jsonl")[0]
    for l in open(f):
        if rx not in l or '"tool_use"' not in l: continue
        d=json.loads(l)
        for x in (d.get('message') or {}).get('content') or []:
            if isinstance(x,dict) and x.get('type')=='tool_use':
                s=json.dumps(x['input'])
                for m in re.finditer(rx,s):
                    print(sid,x['name'],d['timestamp'][11:19],"...",s[max(0,m.start()-160):m.end()+160].replace("\\n"," "))
                    break
