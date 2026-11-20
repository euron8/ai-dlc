import json,re,collections,sys
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10/'
R=json.load(open(D+'calls323.json'))
def story(d):
    m=re.search(r'(?<![\d.])([1-9])[.-]([1-9])(?![\d])',d.replace('323-',''))
    return f"{m.group(1)}.{m.group(2)}" if m else '?'
def full(c):
    if 'wait-for-deliverable' in c: return None
    if 'pytest-footprint-watchdog' in c and re.search(r'rebalancer/tests|server/tests|-n 8',c): return 'py-full(watchdog)'
    if re.search(r'merge-review-shards\.sh\s+--record-run',c): return 'record-run'
    if re.search(r'npx vitest run\s*(>|$|2|\|)|npm (run )?test\b',c) and 'vitest run src' not in c: return 'web-full'
    return None
a=collections.defaultdict(lambda:collections.defaultdict(lambda:[0,0.0]))
for r in R:
    if r['tool']!='Bash': continue
    f=full(r['cmd'])
    if not f: continue
    role='dev' if r['role'].startswith('dev') else ('cr' if r['role'].startswith('code') else ('qa' if r['role']=='qa' else 'o'))
    x=a[story(r['desc'])][(f,role)]; x[0]+=1; x[1]+=r['lat']
tot=collections.Counter(); totn=collections.Counter()
for s in sorted(a):
    print(s,{f"{k[0]}/{k[1]}":f"{v[0]}x {v[1]:.0f}s" for k,v in sorted(a[s].items())})
    for k,v in a[s].items(): tot[k]+=v[1]; totn[k]+=v[0]
print({f"{k[0]}/{k[1]}":f"{totn[k]}x {tot[k]/60:.0f}min" for k in tot})
