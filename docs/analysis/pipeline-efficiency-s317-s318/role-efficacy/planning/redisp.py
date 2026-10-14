import json,re
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/'
rows=[json.loads(l) for l in open(D+'out/spawns.jsonl')]
P=('carry-over-evaluation','requirements','architecture')
pl=[r for r in rows if any(r['step']==p or r['step']==f'gate-validation[{p}]' for p in P)]
rx=re.compile(r'(?i)re-?dispatch|re-?run on current|finish ')
print('planning spawns',len(pl))
for r in pl:
    if rx.search(r['description'] or ''):
        print('REDISP',r['sprint'],r['step'],r['role'],r['model_ran'],r['effort_bound'],round(r['usd'],2),round(r['minutes'],1),r['description'])
# empty final text = possible abandoned
for r in pl:
    if not (r['final_text'] or '').strip():
        print('EMPTY-FINAL',r['sprint'],r['step'],r['role'],r['effort_bound'],round(r['usd'],2),round(r['minutes'],1),r['description'])
# control: count of non-empty
print('nonempty',sum(1 for r in pl if (r['final_text'] or '').strip()))
# long runners by role/effort
import collections
c=collections.defaultdict(list)
for r in pl: c[(r['role'],r['model_ran'],str(r['effort_bound']))].append(r['minutes'] or 0)
for k,v in sorted(c.items()):
    v=sorted(v); print('MIN',k,'n',len(v),'median',round(v[len(v)//2],1),'max',round(v[-1],1))
# gate log tokens
for f in ['/Users/n8/git/graph/_bmad-output/implementation-artifacts/s317/gate-log-archive.md','/Users/n8/git/graph/_bmad-output/implementation-artifacts/gate-log.md']:
    t=open(f,errors='replace').read()
    # only planning sections
    segs=re.split(r'\n(?=- Gate: )',t)
    plan=[s for s in segs if s.startswith('- Gate: planning')]
    j='\n'.join(plan)
    print(f[-30:],'planning entries',len(plan),'overturn',len(re.findall(r'(?i)overturn',j)),'FAILED once',len(re.findall(r'FAILED once',j)),'superseded/re-mint',len(re.findall(r'(?i)supersedes|re-minted|stale nonce',j)),'control PASSED',len(re.findall(r'PASSED',j)))
