import json,glob,os,collections,re
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
H=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
sp=[json.loads(l) for l in open(M+'spawns.jsonl')]
for S in (323,322,321):
    sel=[x for x in sp if x['sprint']==S and 'implementation' in x['step']]
    c=collections.Counter(); who=collections.Counter(); heads=[]
    for x in sel:
        g=glob.glob(H+x['sess']+'*/subagents/'+x['unit']+'.jsonl')[0]
        txt=open(g).read()
        n=len(re.findall(r'admission: REFUSED',txt))
        a=len(re.findall(r'admission: ADMITTED',txt))
        for m in re.findall(r'headroom ([\d.]+) GiB: (?:REFUSED)',txt): heads.append(float(m))
        if n: who[(x['role'],x['description'][:30])]+=n
        c['refused']+=n; c['admitted']+=a
    print(S,dict(c),'agents with refusals',len(who),'headroom refused values min/median/max',(min(heads),sorted(heads)[len(heads)//2],max(heads)) if heads else None)
    print(who.most_common(6))
