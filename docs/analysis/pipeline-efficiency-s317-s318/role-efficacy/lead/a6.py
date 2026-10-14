import re, glob, collections
G='/Users/n8/git/graph/_bmad-output/'
files=[G+'pipeline-continuation-log.md']+glob.glob(G+'implementation-artifacts/s317/pipeline-continuation-log-archive*.md')
toks=['HANDOFF_GUARD_BLOCK','BLOCKED','BACKOFF','ESCALATION_UNDELIVERED','ACK_DENIED','PAUSE_QUESTION_IN_PROSE','ZZNEVERTOKEN']
ts_re=re.compile(r'20\d\d-\d\d-\d\dT\d\d:\d\d')
ev=collections.defaultdict(list)
for f in files:
    for line in open(f,errors='replace'):
        for t in toks:
            if t in line:
                m=ts_re.search(line); ev[t].append((m.group(0) if m else '?', f.split('/')[-1][:40], line.strip()[:200]))
for t in toks:
    inwin=[e for e in ev[t] if '2026-10-05T14'<=e[0]<='2026-10-14T15']
    print(t,'total',len(ev[t]),'in s317-318 window',len(inwin))
    for e in inwin[:14]: print('   ',e)
