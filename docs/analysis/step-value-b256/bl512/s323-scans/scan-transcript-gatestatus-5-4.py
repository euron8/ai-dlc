# Row 1 (implementation-20261118T170930Z, story 5-4, Check 1): did any round name 5-4's missing
# Gate-status line before the FAIL? Result recorded: {'54_pre': 0, '54_adjwin': 196, '51_pre_poscontrol': 128, 'neg': 0}
# Re-run once (batch 271 cluster H, 2026-11-27T23:53Z, `python3 -I` on this file), printed:
#   {'54_pre': 0, '54_adjwin': 196, '51_pre_poscontrol': 128, 'neg': 0}
# 54_pre is the absence query, 54_adjwin and 51_pre_poscontrol the positive controls, neg the negative token.
import glob,json,re
base='/Users/n8/.claude/projects/-Users-n8-git-graph'
files=sorted(set(glob.glob(base+'/*.jsonl')+glob.glob(base+'/*/subagents/*.jsonl')))
gs=re.compile(r'Gate-status|Gate status|gate.status',re.I)
cnt={'54_pre':0,'54_adjwin':0,'51_pre_poscontrol':0,'neg':0}
ex=[]
for f in files:
    for line in open(f,errors='replace'):
        neg='zq9xx-no-such-token-h271' in line
        if not (gs.search(line) or neg): continue
        try:o=json.loads(line)
        except: continue
        ts=o.get('timestamp','')
        if ts>'2026-11-20T04:20': continue
        if neg: cnt['neg']+=1
        for m in gs.finditer(line):
            w=line[max(0,m.start()-200):m.end()+200]
            if re.search(r'5-4|5\.4|5x4',w):
                if '2026-11-18T00:00'<=ts<'2026-11-18T17:09:30': cnt['54_pre']+=1; ex.append((ts,f[-45:],w[:300]))
                elif '2026-11-18T17:09:30'<=ts<'2026-11-18T17:25': cnt['54_adjwin']+=1
            if re.search(r'5-1|5\.1|5x1',w) and '2026-11-18T00:00'<=ts<'2026-11-18T17:09:30': cnt['51_pre_poscontrol']+=1
print(cnt)
for e in ex[:10]: print(e)
