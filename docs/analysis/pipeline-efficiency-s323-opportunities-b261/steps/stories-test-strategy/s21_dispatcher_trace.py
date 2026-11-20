import json,glob,os,sys
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
pref=sys.argv[1]
u=None
for l in open(M+"spawns.jsonl"):
    s=json.loads(l)
    if s['sprint']==323 and s['description'].startswith(pref): u=s['unit']
f=glob.glob(os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/*/subagents/%s.jsonl"%u))[0]
for ln in open(f):
    o=json.loads(ln); c=(o.get('message') or {}).get('content'); ts=o.get('timestamp','')
    if isinstance(c,list):
        for b in c:
            if b.get('type')=='tool_use': print(ts[11:19],b['name'],' '.join(json.dumps(b['input']).split())[:190])
