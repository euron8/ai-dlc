import json,glob,os,re,subprocess,collections,sys
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
G="/Users/n8/git/graph"; P="_bmad-output/planning-artifacts/s323/stories"
CF="a9b015557"
idx={}
for f in glob.glob(os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/*/subagents/agent-*.jsonl")):
    idx[os.path.basename(f)[:-6]]=f
def show(c,p):
    r=subprocess.run(["git","-C",G,"show",f"{c}:{p}"],capture_output=True,text=True); return r.stdout if r.returncode==0 else ""
secmap={}
for l in subprocess.run(["git","-C",G,"ls-tree","--name-only",CF,P+"/"],capture_output=True,text=True).stdout.split():
    t=show("ae63caf38",l)  # story gate version: stable section starts for early sections
    heads=[]
    for i,line in enumerate(t.split('\n'),1):
        if line.startswith('## ') : heads.append((i,line[3:].strip()))
    key=re.match(r'story-(\d+-\d+)',os.path.basename(l)).group(1)
    secmap[key]=(os.path.basename(l),heads,len(t.split('\n')))
def sec(key,a,b):
    heads=secmap[key][1]; out=set()
    names=[("FRONT",1)]+[(h[1],h[0]) for h in heads]
    for i,(n,s) in enumerate(names):
        e=names[i+1][1]-1 if i+1<len(names) else 10**9
        if a<=e and b>=s:
            nn=n
            for pre,lab in (("Acceptance","AC"),("Scope","SCOPE"),("LOCKED","LR"),("Gate-2","HARDGATE"),("Production","PIT"),("Smoke","SMOKE"),("Rename","RENAME"),("Strategy","STRATIDS"),("Deferred","DEFER"),("Dev Agent","DAR"),("Changelog","CHANGELOG")):
                if n.startswith(pre): nn=lab
            out.add(nn)
    return out
res=collections.defaultdict(lambda: collections.Counter())
byts=collections.defaultdict(lambda: collections.Counter())
perspawn=[]
ROLES={'dev','dev-escalated','code-reviewer','code-reviewer-escalated','qa','pre-reviewer','tea','gate-adjudicator'}
for l in open(M+"spawns.jsonl"):
    s=json.loads(l)
    if s['sprint']!=323 or s['role'] not in ROLES: continue
    if s['step'] not in('implementation','gate-validation[implementation]','sprint-review'): continue
    m=re.search(r'[Ss]tory\s+(\d+)[.-](\d+)',s['description']); 
    f=idx.get(s['unit'])
    if not f: continue
    calls={};results={}
    for ln in open(f):
        try:o=json.loads(ln)
        except: continue
        c=(o.get('message') or {}).get('content')
        if not isinstance(c,list): continue
        for b in c:
            if b.get('type')=='tool_use': calls[b['id']]=b
            elif b.get('type')=='tool_result': results[b['tool_use_id']]=b
    nread=0; hits=collections.Counter(); ts=0; sizes=0
    for i,b in calls.items():
        r=results.get(i)
        if not r or r.get('is_error'): continue
        inp=b.get('input',{}); nm=b['name']
        path=inp.get('file_path','') if nm=='Read' else ''
        cmd=inp.get('command','') if nm=='Bash' else ''
        size=len(json.dumps(r.get('content','')))
        if nm=='Read' and '/planning-artifacts/s323/stories/story-' in path:
            key=re.search(r'story-(\d+-\d+)',path).group(1)
            a=int(inp.get('offset') or 1); n=int(inp.get('limit') or 2000)
            for x in sec(key,a,a+n-1): hits[x]+=1; byts[s['role']][x]+=size/max(1,len(sec(key,a,a+n-1)))
            nread+=1
        elif nm=='Read' and path.endswith('s323/test-strategy.md'): hits['TESTSTRATEGY']+=1; ts+=1; byts[s['role']]['TESTSTRATEGY']+=size
        elif nm=='Bash' and 'planning-artifacts/s323/stories/story-' in cmd: hits['BASH-story']+=1
        elif nm=='Bash' and 'planning-artifacts/s323/test-strategy.md' in cmd: hits['BASH-ts']+=1
    for k,v in hits.items(): res[s['role']][k]+=v
    res[s['role']]['SPAWNS']+=1
    perspawn.append((s['role'],s['step'][:6],s['description'][:50],dict(hits)))
json.dump(perspawn,open(sys.argv[1],'w'))
for r,c in res.items(): print(r,dict(c))
print({r:{k:int(v/1000) for k,v in c.items()} for r,c in byts.items()})
