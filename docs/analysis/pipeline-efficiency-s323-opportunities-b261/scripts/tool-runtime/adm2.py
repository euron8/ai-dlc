import json,glob,os,re,collections
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
H=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
sp=[x for x in map(json.loads,open(M+'spawns.jsonl')) if x['sprint']==323 and 'implementation' in x['step']]
heads=[];need=collections.Counter()
for x in sp:
    g=glob.glob(H+x['sess']+'*/subagents/'+x['unit']+'.jsonl')[0]
    t=open(g).read()
    for m in re.finditer(r'predicate: (\d+) x ([\d.]+) \+ (\d+) = ([\d.]+) GiB <= headroom ([\d.]+) GiB: (REFUSED|ok)',t):
        need[(m.group(1),m.group(4))]+=1
        if m.group(6)=='REFUSED': heads.append(float(m.group(5)))
print('refused predicate lines',len(heads),dict(need))
for thr,n in ((18.5,'n=2'),(21.0,'n=4'),(23.5,'n=6')):
    print(n,'need',thr,'refusals that would have passed',sum(1 for h in heads if h>=thr),f"{100*sum(1 for h in heads if h>=thr)/len(heads):.0f}%")
