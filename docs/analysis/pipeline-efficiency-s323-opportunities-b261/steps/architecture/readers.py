import json,glob,os,re,collections,sys
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
pats={'SPINE':re.compile(r'ARCHITECTURE-SPINE\.md|architecture-spine/'),
'IMPACT':re.compile(r'architecture-impact'),
'ARCHDOC':re.compile(r'docs/architecture\.md'),
'ARCHIDX':re.compile(r'architecture-index'),
'ARCHCTX':re.compile(r'architecture-context'),
'ARCHCHAIN':re.compile(r'architecture-chain'),
'READINESS':re.compile(r'implementation-readiness-architecture'),
'CHGLOG':re.compile(r'changelog-architecture'),
'UIMOCK':re.compile(r'ui-mockups'),
'ARCHHIST':re.compile(r'architecture-history'),
'AD-':re.compile(r'\bAD-\d+')}
idx={}
for p in glob.glob(R+'*/subagents/agent-*.jsonl'):
    idx[os.path.basename(p)[:-6]]=p
out=collections.defaultdict(lambda:collections.Counter())
nsp=collections.Counter()
for l in open(M+'spawns.jsonl'):
    r=json.loads(l)
    if r['sprint'] not in (321,322,323): continue
    p=idx.get(r['unit'])
    if not p: nsp[(r['sprint'],'missing')]+=1; continue
    key=(r['sprint'],r['step'],r['role'])
    nsp[key]+=1
    uses={}; errs=set()
    for ln in open(p):
        try: d=json.loads(ln)
        except: continue
        m=d.get('message',{}); c=m.get('content')
        if not isinstance(c,list): continue
        for x in c:
            if x.get('type')=='tool_use': uses[x['id']]=(x['name'],json.dumps(x['input']))
            elif x.get('type')=='tool_result' and x.get('is_error'): errs.add(x.get('tool_use_id'))
    seen=set()
    for i,(n,s) in uses.items():
        if i in errs: continue
        if n not in('Read','Bash','Grep','Glob','Edit','Write'): continue
        for k,pt in pats.items():
            if pt.search(s):
                out[key][(k,n)]+=1; seen.add(k)
    for k in seen: out[key][(k,'SPAWNS_WITH')]+=1
json.dump({'|'.join(map(str,k)):{'|'.join(kk):v for kk,v in c.items()} for k,c in out.items()},open('readers.json','w'),indent=0)
json.dump({str(k):v for k,v in nsp.items()},open('readers_nsp.json','w'))
print(len(out),sum(nsp.values()))
