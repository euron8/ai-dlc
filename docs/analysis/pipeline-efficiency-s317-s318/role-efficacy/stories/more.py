import re, glob, os, json, collections
B='/Users/n8/' + 'git/graph/_bmad-output/'
P=B+'planning-artifacts/'
# s317 shard finding headings
for p in ('stories-p1','stories-p2','stories-p3'):
    tags=collections.Counter(); ex=None
    for f in sorted(glob.glob(P+'s317/shards/'+p+'/*.md')):
        t=open(f,errors='replace').read()
        for m in re.finditer(r'^#{2,4}\s*(?:F-?\d+|Finding)[^\n]*',t,re.M):
            h=m.group(0).lower()
            if 'major' not in h and 'critical' not in h:
                # severity may be on next line
                nxt=t[m.end():m.end()+300].lower()
                if not re.search(r'severity:?\**\s*(major|critical)',nxt): continue
            ex=ex or h[:120]
            tags['repair-introduced' if 'repair' in h and 'introduc' in h else ('carried/partial' if re.search(r'partial|not repaired|persist|carried|still|wrongly',h) else 'new/unlabelled')]+=1
    print('s317',p,dict(tags),ex)
rows=[json.loads(l) for l in open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/spawns.jsonl')]
for r in rows:
    if re.search(r'author|stories and epics|epics and stories|test strategy and trace|TEA sprint|traceability',r['description'] or '',re.I) and r['sprint'] in (317,318):
        print(r['sprint'],r['step'],r['role'],r['model_ran'],r['effort_bound'],r['description'][:60],'$%.2f'%r['usd'],'%.0fmin'%r['minutes'])
# s317 sprint-review dev effort split
for r in sorted([r for r in rows if r['sprint']==317 and r['step']=='sprint-review' and r['role']=='dev'],key=lambda r:r['start']):
    pass
c=collections.Counter((('seat' if re.search(r'seat \d|cross g',r['description']) else 'fix'),r['effort_bound']) for r in rows if r['sprint']==317 and r['step']=='sprint-review' and r['role']=='dev')
print('s317 SR dev',c)
med=[r['start'][5:16] for r in rows if r['sprint']==317 and r['step']=='sprint-review' and r['role']=='dev' and r['effort_bound']=='medium']
print('medium dev starts',min(med),max(med))
# one-shot review finding counts
for f in (P+'s317/test-strategy-oneshot-review.md',P+'s318/test-strategy-review-oneshot.md'):
    t=open(f).read()
    hs=re.findall(r'^(#{2,4}[^\n]*|\|\s*\w*-?\d+\s*\|[^\n]*|\d+\.\s\*\*[^\n]*)',t,re.M)
    sev=collections.Counter(re.findall(r'(?:severity|\[|\()\s*\**(CRITICAL|MAJOR|MINOR|critical|major|minor)',t))
    print(os.path.basename(f),'sev-tagged',dict(sev),'headings',len(hs))
