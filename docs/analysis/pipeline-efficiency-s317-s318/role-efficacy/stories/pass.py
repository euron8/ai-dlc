import json, re, collections
rows=[json.loads(l) for l in open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/spawns.jsonl')]
G={317:'2026-10-09T05:48',318:'2026-10-13T21:13'}
a=collections.defaultdict(lambda:[0,0.0])
for r in rows:
    if r['step']!='stories-test-strategy' or r['start']>=G[r['sprint']]: continue
    if r['role'] not in ('adversary','remediator'): continue
    d=r['description']
    m=re.search(r'\bp(\d)\b|[Pp]ass (\d)',d)
    if re.search(r'party',d,re.I): k='party-repair'
    elif re.search(r'elicit',d,re.I): k='elicit'
    elif re.search(r'one-shot|test strategy|test-strategy',d,re.I): k='strategy-oneshot'
    elif m: k='pass'+(m.group(1) or m.group(2))
    elif r['role']=='remediator' and re.search(r'Repair story|Repair shard|Adv repair',d): k='adv-repair(unnumbered)'
    else: k='other:'+re.sub(r'\d','#',d)[:30]
    a[(r['sprint'],r['role'],k)][0]+=1; a[(r['sprint'],r['role'],k)][1]+=r['usd']
for k in sorted(a,key=str): print(k,a[k][0],round(a[k][1],2))
