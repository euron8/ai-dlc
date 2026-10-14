import os,re,glob
G='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
H=re.compile(r'^#{2,5}\s.*\b(CRITICAL|MAJOR|MINOR)\b')
K=re.compile(r'^\s*(findings_[a-z_]+|verdict|pass_verdict|exit_condition)\s*[:=]\s*(.+)$',re.I)
V=re.compile(r'\bEXIT_CONDITION_(NOT_)?MET\b')
names=['coe-adversarial-p1','coe-adversarial-p2','carry-over-evaluation-elicitation',
 'requirements-elicitation','requirements-adversarial-p1','requirements-adversarial-p2','requirements-adversarial-p3',
 'architecture-elicitation','architecture-adversarial-p1','architecture-adversarial-p2','architecture-adversarial-p3']
for sp in ('s317','s318'):
  for n in names:
    f=G+sp+'/'+n+'.md'
    if not os.path.exists(f): continue
    L=open(f,errors='replace').read().splitlines()
    c={'CRITICAL':0,'MAJOR':0,'MINOR':0}
    for l in L:
      m=H.match(l)
      if m:
        # take first severity token in heading
        s=re.search(r'\b(CRITICAL|MAJOR|MINOR)\b',l).group(1); c[s]+=1
    kv=[]
    for l in L[-80:]:
      m=K.match(l)
      if m: kv.append(m.group(1)+'='+m.group(2).strip()[:40])
    vs=[v.group(0) for l in L for v in V.finditer(l)]
    print(sp,n,'headings',c,'| tail-kv',kv[:12],'| verdict tokens MET/NOT',vs.count('EXIT_CONDITION_MET'),vs.count('EXIT_CONDITION_NOT_MET'))
