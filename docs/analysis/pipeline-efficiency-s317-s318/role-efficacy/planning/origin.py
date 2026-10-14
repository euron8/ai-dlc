import os,re,collections
G='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
H=re.compile(r'^#{2,5}\s.*\b(CRITICAL|MAJOR|MINOR)\b')
# origin cues inside a finding body
REP=re.compile(r'(?i)(repair that authored|authored by (the )?(repair|remediat)|introduced by (the )?(repair|remediat|pass)|repair[- ]introduced|regression from (the )?repair|the repair (added|introduced|wrote|created)|new claim from the repair|left by (the )?repair|leftover from repair|repair .{0,40}(did not land|not landed|partially)|partially repaired|still (open|present|unrepaired)|not repaired|reopen)')
PRIOR=re.compile(r'(?i)(pass[- ]?1 F|prior pass|earlier pass|previous pass|re-?raised|same as pass|carried from pass|was F-?\d+ in pass)')
names=['coe-adversarial-p1','coe-adversarial-p2','requirements-adversarial-p1','requirements-adversarial-p2','requirements-adversarial-p3','architecture-adversarial-p1','architecture-adversarial-p2','architecture-adversarial-p3']
for sp in ('s317','s318'):
  for n in names:
    f=G+sp+'/'+n+'.md'
    if not os.path.exists(f): continue
    L=open(f,errors='replace').read().splitlines()
    # split into findings
    finds=[];cur=None
    for l in L:
      if H.match(l):
        cur=[l,[]];finds.append(cur);continue
      if l.startswith('## ') or l.startswith('# '): cur=None;continue
      if cur: cur[1].append(l)
    c=collections.Counter()
    for h,b in finds:
      s=re.search(r'\b(CRITICAL|MAJOR|MINOR)\b',h).group(1)
      body=h+'\n'+'\n'.join(b)
      r=bool(REP.search(body)); p=bool(PRIOR.search(body))
      c[(s,'repair-origin' if r else ('prior-ref' if p else 'fresh'))]+=1
    print(sp,n,len(finds),dict(sorted(c.items())))
