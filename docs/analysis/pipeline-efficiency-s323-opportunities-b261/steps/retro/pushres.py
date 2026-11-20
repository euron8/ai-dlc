import json,glob,os,sys
root=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/")
f=glob.glob(root+sys.argv[1]+"*.jsonl")[0]; want=set(sys.argv[3:]); ids={}
for l in open(f):
    d=json.loads(l)
    for x in (d.get('message') or {}).get('content') or []:
        if not isinstance(x,dict): continue
        if x.get('type')=='tool_use' and x['name']=='Bash' and 'git push' in x['input'].get('command','') and d['timestamp'][11:19] in want: ids[x['id']]=d['timestamp']
        if x.get('type')=='tool_result' and x['tool_use_id'] in ids:
            c=x['content']; t=c if isinstance(c,str) else " ".join(y.get('text','') for y in c if isinstance(y,dict))
            print(ids[x['tool_use_id']][11:19],len(t)); print(t[-700:].replace("\n"," | ")); print()
