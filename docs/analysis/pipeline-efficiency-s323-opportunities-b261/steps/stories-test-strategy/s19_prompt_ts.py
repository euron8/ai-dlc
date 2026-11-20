import json,glob,os,collections
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
idx={os.path.basename(f)[:-6]:f for f in glob.glob(os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/*/subagents/agent-*.jsonl"))}
a=collections.defaultdict(collections.Counter)
for l in open(M+"spawns.jsonl"):
    s=json.loads(l)
    if s['sprint']!=323 or s['step'] not in('implementation','gate-validation[implementation]'): continue
    f=idx.get(s['unit'])
    if not f: continue
    first=None
    for ln in open(f):
        try:o=json.loads(ln)
        except: continue
        if o.get('type')=='user' or (o.get('message') or {}).get('role')=='user':
            c=o['message']['content']
            first=c if isinstance(c,str) else ' '.join(b.get('text','') for b in c if isinstance(b,dict))
            break
    k=s['role']; a[k]['n']+=1
    if first is None: a[k]['noprompt']+=1; continue
    if 'test-strategy' in first: a[k]['prompt_names_test-strategy']+=1
    if 'ST323-' in first: a[k]['prompt_has_ST323_ids']+=1
    a[k]['prompt_chars']+=len(first)
for k,v in a.items(): print(k,dict(v))
