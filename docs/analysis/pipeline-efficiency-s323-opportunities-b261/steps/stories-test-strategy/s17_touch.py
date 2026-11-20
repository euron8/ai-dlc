import json,glob,os,re,collections
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
idx={os.path.basename(f)[:-6]:f for f in glob.glob(os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/*/subagents/agent-*.jsonl"))}
agg=collections.defaultdict(lambda:collections.Counter())
for l in open(M+"spawns.jsonl"):
    s=json.loads(l)
    if s['sprint']!=323 or s['step'] not in('implementation','gate-validation[implementation]'): continue
    f=idx.get(s['unit'])
    key=(s['step'][:4],s['role'])
    agg[key]['spawns']+=1
    if not f: agg[key]['notranscript']+=1; continue
    calls={};res={}
    for ln in open(f):
        try:o=json.loads(ln)
        except: continue
        c=(o.get('message') or {}).get('content')
        if not isinstance(c,list): continue
        for b in c:
            if b.get('type')=='tool_use': calls[b['id']]=b
            elif b.get('type')=='tool_result': res[b['tool_use_id']]=b
    st=ts=0
    for i,b in calls.items():
        r=res.get(i)
        if not r or r.get('is_error'): continue
        txt=json.dumps(b.get('input',{}))
        if 'planning-artifacts/s323/stories/' in txt or re.search(r'story-\d-\d-',txt): st+=1
        if 'test-strategy' in txt and 'planning-artifacts' in txt: ts+=1
    agg[key]['story_calls']+=st; agg[key]['ts_calls']+=ts
    if st: agg[key]['spawns_touch_story']+=1
    if ts: agg[key]['spawns_touch_ts']+=1
for k,v in sorted(agg.items()): print(k,dict(v))
