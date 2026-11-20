import re
root='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
for s in ('s320','s322','s323'):
  for p in (2,3):
    L=open(root+f'{s}/coe-adversarial-p{p}.md').read().split('\n')
    shard='?'; i=0
    while i<len(L):
      l=L[i]
      if l.startswith('## Shard'): shard=l[9:30]
      m=re.match(r'#{2,4}\s*(F-?\d+)\s*(—|--)\s*(MAJOR|CRITICAL)',l)
      if m:
        j=i+1
        while j<len(L) and not re.match(r'#{1,4} ',L[j]): j+=1
        body=' '.join(x.strip() for x in L[i:j] if x.strip())
        print(f'@@ {s} p{p} [{shard}] L{i+1}: {body[:1500]}\n')
        i=j; continue
      i+=1
