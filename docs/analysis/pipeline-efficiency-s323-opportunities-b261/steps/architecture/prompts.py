import json,glob,os,re,collections
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
idx={os.path.basename(p)[:-6]:p for p in glob.glob(R+'*/subagents/agent-*.jsonl')}
pt={'SPINE':re.compile(r'ARCHITECTURE-SPINE'),'ARCHDOC':re.compile(r'docs/architecture\.md|architecture\.md'),'AD':re.compile(r'\bAD-\d+'),'IMPACT':re.compile(r'architecture-impact|architecture_impact'),'ARCHREFS':re.compile(r'architecture_refs')}
c=collections.defaultdict(collections.Counter); n=collections.Counter()
for l in open(M+'spawns.jsonl'):
    r=json.loads(l)
    if r['sprint']!=323 or r['step'] not in('implementation','stories-test-strategy','sprint-review'): continue
    p=idx.get(r['unit'])
    if not p: continue
    with open(p) as f:
        for ln in f:
            d=json.loads(ln)
            if d.get('type')=='user':
                cc=d['message']['content']
                s=cc if isinstance(cc,str) else ' '.join(x.get('text','') for x in cc if isinstance(x,dict))
                break
    k=(r['step'][:6],r['role']); n[k]+=1
    for name,rx in pt.items():
        if rx.search(s): c[k][name]+=1
for k in sorted(n): print(k,n[k],dict(c[k]))
