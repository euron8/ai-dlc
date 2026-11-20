import json,glob,os,re,sys,collections
root=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/")
MONO="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
S=int(sys.argv[1]); excl=sys.argv[2]; prev=S-1
sess=sorted({s['sess'] for s in map(json.loads,open(MONO+"segs.jsonl")) if s['sprint']==S and s['kind']=='lead' and not s['sess'].startswith(excl)})
names=r"(gate-log-archive|pipeline-continuation-log-archive|compaction-log-archive|context-mode-protection-log-archive|s%d/gate-adjudication|audit-anchors-archive|pending-archive|carry-over-backlog-archive|party-mode-transcripts/s%d)"%(prev,prev)
cnt=collections.Counter(); ex={}
for sid in sess:
    f=glob.glob(root+sid+"*.jsonl")[0]; uses={};res={}
    for l in open(f):
        if names.replace('(','').split('|')[0][:5] not in l and not re.search(names,l): 
            if '"tool_result"' not in l: continue
        d=json.loads(l)
        for x in (d.get('message') or {}).get('content') or []:
            if not isinstance(x,dict): continue
            if x.get('type')=='tool_use':
                s=json.dumps(x.get('input',{}))
                if re.search(names,s): uses[x['id']]=(x['name'],s)
            elif x.get('type')=='tool_result': res[x['tool_use_id']]=bool(x.get('is_error'))
    for i,(n,s) in uses.items():
        if i in res and not res[i]:
            m=re.search(names,s).group(1); cnt[(m)]+=1; ex.setdefault(m,(sid[:8],n,s[:120]))
print(S,"lead sessions",len(sess),dict(cnt))
for k,v in ex.items(): print("  ",k,v)
