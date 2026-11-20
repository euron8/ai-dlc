import re,sys
root='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
for s in ('s320','s322','s323'):
  for p in (1,2,3):
    f=root+f'{s}/coe-adversarial-p{p}.md'
    try: L=open(f).read().split('\n')
    except: continue
    shard='?'
    for i,l in enumerate(L,1):
      if l.startswith('## Shard'): shard=l[3:]
      m=re.match(r'#{2,4}\s*(F-?\d+|X-?\d+)\s*[—-]+\s*(CRITICAL|MAJOR)\s*[—-]+\s*(.*)',l)
      if m: print(s,'p%d'%p,shard[:22],'L%d'%i,m.group(1),m.group(2),m.group(3)[:150])
