import os,re
G='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
H=re.compile(r'^#{2,5}\s.*\b(CRITICAL|MAJOR)\b')
names=['coe-adversarial-p2','requirements-adversarial-p2','requirements-adversarial-p3','architecture-adversarial-p2']
for sp in ('s317','s318'):
  for n in names:
    f=G+sp+'/'+n+'.md'
    if not os.path.exists(f): continue
    L=open(f,errors='replace').read().splitlines()
    for i,l in enumerate(L):
      if H.match(l):
        body=' '.join(L[i+1:i+14])
        m=re.search(r'(?i)(repair[^.]{0,160}\.)',body)
        print(sp,n,i+1,'|',l[:150],'|| origin:',(m.group(1)[:200] if m else '-'))
