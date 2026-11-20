import json,glob,os,sys
root=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/")
sid=sys.argv[1]; n=0
f=glob.glob(root+sid+"*.jsonl")[0]
for l in open(f):
    d=json.loads(l)
    if d.get('type')=='user':
        c=d['message']['content']
        t=c if isinstance(c,str) else " ".join(x.get('text','') for x in c if isinstance(x,dict) and x.get('type')=='text')
        if t.strip():
            print(d['timestamp'],len(t)); print(t[:int(sys.argv[2])]); n+=1
            if n>=1: break
