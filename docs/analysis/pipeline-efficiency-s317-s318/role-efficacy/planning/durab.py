import os,re,collections
G='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
H=re.compile(r'^#{2,5}\s.*\b(CRITICAL|MAJOR|MINOR)\b')
AUTH=re.compile(r'(?i)(repair that authored|text that repair|the (x-?\d+ |s-?\d+ )?repair (wrote|added|introduced|authored)|introduced by (the )?repair|leftover from repair|bound (that )?the repair wrote|new claim)')
RESID=re.compile(r'(?i)(residual of|partially repaired|still (open|present|unrepaired|false)|not repaired|left partially)')
NOINTRO=re.compile(r'(?i)(introduced no new|no defect introduced|added nothing that breaks|landed without adding)')
names=['coe-adversarial-p2','requirements-adversarial-p2','requirements-adversarial-p3','architecture-adversarial-p2','architecture-adversarial-p3']
for sp in ('s317','s318'):
  for n in names:
    f=G+sp+'/'+n+'.md'
    if not os.path.exists(f): continue
    t=open(f,errors='replace').read(); L=t.splitlines()
    # repair verification tokens (whole file) -- bold or table cell verdicts
    pr=len(re.findall(r'(?i)partially repaired',t))
    nr=len(re.findall(r'(?i)\bnot repaired\b',t))
    rep=len(re.findall(r'(?i)(?<!partially )(?<!not )\brepaired\b',t))
    ni=len(NOINTRO.findall(t))
    finds=[];cur=None
    for l in L:
      if H.match(l): cur=[l,[]];finds.append(cur);continue
      if l.startswith('## ') or l.startswith('# '): cur=None;continue
      if cur: cur[1].append(l)
    c=collections.Counter()
    for h,b in finds:
      s=re.search(r'\b(CRITICAL|MAJOR|MINOR)\b',h).group(1)
      if s=='MINOR': continue
      body=h+'\n'+'\n'.join(b)
      if re.search(r'(?i)\):\s*repaired|\. Repaired',h): c['verify-row(repaired)']+=1; continue
      a=bool(AUTH.search(body)); r=bool(RESID.search(body))
      c['repair-authored' if a else ('residual' if r else 'fresh-in-untouched-text')]+=1
    print(sp,n,'MAJOR-class',dict(c),'| tokens: repaired',rep,'partially',pr,'not',nr,'no-new-defect-stmts',ni)
