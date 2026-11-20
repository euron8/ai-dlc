import json,re,collections,sys
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10/'
sp=sys.argv[1]
R=json.load(open(D+f'calls{sp}.json'))
def story(d):
    m=re.search(r'(?<![\d.])([1-9])[.-]([1-9])(?![\d])',d.replace('323-',''))
    return f"{m.group(1)}.{m.group(2)}" if m else None
def norm(c):
    c=re.sub(r'/Users/n8/git/graph-[\w.-]+','<W>',c)
    c=re.sub(r'/private/tmp/claude-501/\S*','<S>',c)
    c=re.sub(r'/tmp/\S+','<S>',c)
    c=re.sub(r'\b[0-9a-f]{7,40}\b','<sha>',c)
    c=re.sub(r'\s+',' ',c)
    return c.strip()[:300]
def issuite(c): return bool(re.search(r'pytest|vitest|merge-review-shards\.sh --record-run|watchdog|npm (run )?test|ci-local|playwright',c)) and 'wait-for-deliverable' not in c and not re.match(r'\s*(cat|ls|grep|head|tail)\b',c)
seen=collections.defaultdict(lambda:collections.defaultdict(list))
for r in R:
    if r['tool']!='Bash' or not issuite(r['cmd']): continue
    s=story(r['desc']) or '?'
    role='dev' if r['role'].startswith('dev') else ('cr' if r['role'].startswith('code') else ('qa' if r['role']=='qa' else 'other'))
    seen[s][norm(r['cmd'])].append((role,r['lat'],r['unit']))
tot=collections.Counter(); 
for s in sorted(seen):
    cmds=seen[s]
    multi=[(k,v) for k,v in cmds.items() if len({x[0] for x in v})>=2]
    n=sum(len(v) for v in cmds.values()); sec=sum(x[1] for v in cmds.values() for x in v)
    msec=sum(x[1] for k,v in multi for x in v)
    # redundant = all but first execution of identical normalized cmd in a different seat
    red=0.0; redn=0
    for k,v in cmds.items():
        v=sorted(v,key=lambda x:0)  # order not tracked; take later seats' runs
        roles=[]; 
        firstrole=v[0][0]
        for x in v[1:]:
            if x[0]!=firstrole: red+=x[1]; redn+=1
    tot['n']+=n; tot['sec']+=sec; tot['multi_cmds']+=len(multi); tot['distinct']+=len(cmds); tot['redn']+=redn; tot['redsec']+=red
    print(s,f"suite-cmds {n} distinct {len(cmds)} shared-by-2+-roles {len(multi)} ; cross-seat repeat runs {redn} = {red/60:.1f} min of {sec/60:.1f} min")
print({k:round(v) for k,v in tot.items()})
