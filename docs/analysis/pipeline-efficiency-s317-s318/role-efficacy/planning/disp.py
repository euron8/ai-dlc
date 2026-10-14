import os,re,collections,glob
G='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
recs={'s317':['carry-over-evaluation-repair-p1.md','requirements-repair-p1.md','architecture-spine-party-repair-p1.md'],
      's318':['carry-over-evaluation-party-repair-p1.md','requirements-party-repair.md','architecture-party-repair-p1.md']}
ROLE=re.compile(r'(?i)\b(architect|dev|tea|pm|sm)[-_ ](?:cross[-_]?)?(\d+|cross)\b')
DISP=re.compile(r'(?i)\b(repaired|already[- ]repaired|not[- ]reproduced|escalated|rejected|duplicate|dismissed|skipped|carried|deferred|declined|out[- ]of[- ]scope|refuted|no[- ]change)\b')
for sp,fs in recs.items():
  for fn in fs:
    f=G+sp+'/'+fn
    if not os.path.exists(f): print(sp,fn,'MISSING'); continue
    t=open(f,errors='replace').read()
    L=t.splitlines()
    # status-like lines: "status: X" / "disposition: X" / "**Status:** X"
    st=collections.Counter()
    for l in L:
      m=re.match(r'(?i)^\s*[-*|]*\s*\**(status|disposition|outcome|verdict|result)\**\s*[:|]\**\s*`?([A-Za-z-_ ]{3,30})',l)
      if m: st[m.group(2).strip().lower()[:20]]+=1
    # summary lines with counts
    summ=re.findall(r'(?i)(repaired[:=]?\s*\d+[^\n]{0,80})',t)[:3]
    print(sp,fn,len(t),'status-fields',dict(st.most_common(8)),'| summ',summ)
