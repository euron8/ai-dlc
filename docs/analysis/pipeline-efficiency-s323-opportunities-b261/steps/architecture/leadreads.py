import json,os,re,collections,bisect
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
segs=collections.defaultdict(list)
for l in open(M+'segs.jsonl'):
    r=json.loads(l)
    if r['sprint']==323 and r['kind']=='lead': segs[r['unit']].append((r['first'],r['last'],r['step']))
pat={'SPINE':re.compile(r'ARCHITECTURE-SPINE\.md'),'ARCHDOC':re.compile(r'docs/architecture\.md'),'ARCHIDX':re.compile(r'architecture-index'),'IMPACT':re.compile(r'architecture-impact'),'ARCHCTX':re.compile(r'architecture-context'),'CHGLOG':re.compile(r'changelog-architecture')}
out=collections.defaultdict(collections.Counter)
for u,ss in segs.items():
    p=R+u+'.jsonl'
    if not os.path.exists(p): print('missing',u); continue
    ss.sort()
    for ln in open(p):
        if 'rchitecture' not in ln and 'ARCHITECTURE' not in ln: continue
        try: d=json.loads(ln)
        except: continue
        if d.get('type')!='assistant': continue
        ts=d.get('timestamp','')
        step=None
        for a,b,s in ss:
            if a<=ts<=b: step=s;break
        c=d['message'].get('content')
        if not isinstance(c,list): continue
        for x in c:
            if x.get('type')=='tool_use' and x['name'] in('Read','Bash','Grep','Edit','Write'):
                s=json.dumps(x['input'])
                for k,rx in pat.items():
                    if rx.search(s): out[step][(k,x['name'])]+=1
for st,c in sorted(out.items(),key=lambda a:str(a[0])): print(st,dict(c))
