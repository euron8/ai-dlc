import json,glob,os,re
root=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/")
for sid,rx in [("6c14d949",r"next-inputs|retro-artifacts|docs/retro/s321"),("9a646a3b",r"docs/retro/s321"),("53b4296a",r"docs/retro/s322"),("68cf8de7",r"docs/retro/")]:
    f=glob.glob(root+sid+"*.jsonl")[0]
    for l in open(f):
        if '"tool_use"' not in l: continue
        d=json.loads(l)
        for x in (d.get('message') or {}).get('content') or []:
            if isinstance(x,dict) and x.get('type')=='tool_use':
                s=json.dumps(x['input'])
                m=re.search(rx,s)
                if m: print(sid,x['name'],(d.get('timestamp') or '')[11:19],"...",s[max(0,m.start()-110):m.end()+110].replace("\\n"," "))
