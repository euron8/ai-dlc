# Row 3a (implementation-20261118T213543Z, story 5-5, Check 1): did any round run
# validate-carried-findings on 5-5 code-review p2->p3, or flag 'carried: none owed', before the gate?
# Result recorded: A n= 0 (unused here), B n= 108; earliest validator run on the pair = adjudicator
# agent-a8693d5644716fe54 at 2026-11-18T21:41:45Z; reviewer agent-a8ec27fa1de6a4c3e wrote the line 21:07:49Z.
# Negative control (zq9xx-no-such-token-h271) run in the companion scan: 0.
# Batch 271 cluster H added the NEG count below, so the negative control is in the same invocation, and
# re-ran this file once (2026-11-27T23:53Z, `python3 -I`). It printed `A n= 0`, `NEG n= 0`, `B n= 108`;
# read in time order, the earliest validate-carried-findings run on the p2 -> p3 pair is the adjudicator
# agent-a8693d5644716fe54 at 2026-11-18T21:41:45Z, and the reviewer agent-a8ec27fa1de6a4c3e wrote
# "carried: none owed." at 21:07:49Z.
import glob,json,os,re
base='/Users/n8/.claude/projects/-Users-n8-git-graph'
files=sorted(set(glob.glob(base+'/*.jsonl')+glob.glob(base+'/*/subagents/*.jsonl')))
gs=re.compile(r'Gate-status|Gate status|gate.status',re.I)
near=re.compile(r'5-4|5\.4|5x4')
cn=re.compile(r'carried: none owed|carried:.{0,40}(resolved|open)|validate-carried-findings[^\n]{0,80}5-5-code-review-p2')
NEG='zq9xx-no-such-token-h271'
neg=0
out=[];out2=[]
for f in files:
    for line in open(f,errors='replace'):
        if NEG in line: neg+=1
        if 'Gate' not in line and 'gate' not in line and 'carried' not in line: continue
        try:o=json.loads(line)
        except: continue
        ts=o.get('timestamp','')
        if '2026-11-18T12:00'<=ts<'2026-11-18T17:09:30':
            for m in gs.finditer(line):
                w=line[max(0,m.start()-200):m.end()+200]
                if near.search(w): out.append((ts,f[-50:],o.get('type'),w.replace('\\n',' ')))
        if '2026-11-18T20:30'<=ts<'2026-11-18T21:46:08':
            for m in cn.finditer(line):
                w=line[max(0,m.start()-150):m.end()+150]
                if '5-5' in line: out2.append((ts,f[-50:],o.get('type'),w.replace('\\n',' ')))
seen=set()
print('A n=',len(out))
for x in sorted(out):
    k=x[3][150:260]
    if k in seen: continue
    seen.add(k); print(x[0],x[1],x[2],'|',x[3][:420]);print()
print('NEG n=',neg)
print('B n=',len(out2)); seen=set()
for x in sorted(out2):
    k=x[3][100:200]
    if k in seen: continue
    seen.add(k); print(x[0],x[1],x[2],'|',x[3][:350]);print()
