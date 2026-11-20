
import re
f='/Users/n8/git/ai-dlc/core/skills/ai-dlc/steps/gate-validation.md'
L=open(f).read().split('\n')
heads=[(i+1,l) for i,l in enumerate(L) if l.startswith('## ') or l.startswith('### ')]
heads.append((len(L)+1,'END'))
tot=sum(len(l)+1 for l in L)
cb=sum(1 for l in L if l.startswith('```'))//2
print('bytes',tot,'lines',len(L),'codeblocks',cb)
for (a,h),(b,_) in zip(heads,heads[1:]):
    by=sum(len(l)+1 for l in L[a-1:b-1])
    print('%5d-%5d %7d B %s'%(a,b-1,by,h[:70]))
g='/Users/n8/git/ai-dlc/core/skills/ai-dlc/steps/_gate-procedures.md'
L=open(g).read().split('\n')
heads=[(i+1,l) for i,l in enumerate(L) if l.startswith('## ') or l.startswith('### ')]
heads.append((len(L)+1,'END'))
tot=sum(len(l)+1 for l in L)
cb=sum(1 for l in L if l.startswith('```'))//2
print('PROC bytes',tot,'lines',len(L),'codeblocks',cb)
for (a,h),(b,_) in zip(heads,heads[1:]):
    by=sum(len(l)+1 for l in L[a-1:b-1])
    print('%5d-%5d %7d B %s'%(a,b-1,by,h[:70]))
