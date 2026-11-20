import json,collections,re
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/'
M=D+'MONO/'
sp={x['unit']:x for x in map(json.loads,open(M+'spawns.jsonl')) if x['sprint']==323 and 'implementation' in x['step']}
R=json.load(open(D+'h10/calls323.json'))
a=collections.defaultdict(lambda:collections.defaultdict(float)); n=collections.Counter()
def f(c):
    if 'wait-for-deliverable' in c: return 'wfd'
    if re.search(r'pytest|vitest|merge-review|watchdog|ci-local|playwright|npx',c): return 'tests'
    if re.search(r'\bsleep\b|until ',c): return 'sleep/until'
    if re.search(r'\bgit\b',c): return 'git'
    return 'bash-other'
for r in R:
    k=f(r['cmd']) if r['tool']=='Bash' else 'nonbash'
    a[r['unit']][k]+=r['lat']; n[r['unit']]+=1
rows=sorted(sp.values(),key=lambda x:-x['minutes'])[:12]
print('role | desc | min | calls | tool-time breakdown (min) | residual(model+queue) min')
for x in rows:
    tt=sum(a[x['unit']].values()); 
    print(x['role'][:12],x['description'][:28],f"{x['minutes']:.0f}",n[x['unit']],{k:round(v/60) for k,v in a[x['unit']].items() if v>60},f"resid {x['minutes']-tt/60:.0f}", f"${x['usd']:.0f}")
