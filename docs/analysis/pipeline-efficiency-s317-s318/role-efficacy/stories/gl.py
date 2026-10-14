import json, re, sys
rows=[json.loads(l) for l in open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/spawns.jsonl')]
for sp in (317,318):
  for st in ('stories-test-strategy','gate-validation[stories-test-strategy]','sprint-review','gate-validation[sprint-review]'):
    s=[r['start'] for r in rows if r['sprint']==sp and r['step']==st]
    print(sp,st,min(s),max(s))
B='/Users/n8/' + 'git/graph/_bmad-output/implementation-artifacts/'
for f in ('s317/gate-log-archive.md','gate-log.md'):
    t=open(B+f,errors='replace').read().splitlines()
    print('=====',f,len(t))
    for i,l in enumerate(t):
        if re.search(r'^#{1,3} ',l) or re.search(r'Check (5|21)\b',l) or re.search(r'gate_type|^gate:|result:|verdict:',l,re.I):
            print(i+1,l[:220])
