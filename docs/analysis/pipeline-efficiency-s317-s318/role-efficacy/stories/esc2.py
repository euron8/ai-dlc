import re, glob
B='/Users/n8/' + 'git/graph/_bmad-output/'
corp=glob.glob(B+'party-mode/s318/stories-*.md')+glob.glob(B+'planning-artifacts/s318/shards/stories-*/*.md')+[B+'planning-artifacts/s318/stories-elicitation.md',B+'planning-artifacts/s318/test-strategy-review-oneshot.md']
n=0
for f in corp:
    t=open(f,errors='replace').read(); n+=1
    a=len(re.findall(r'aurora|postgres',t,re.I)); b=len(re.findall(r'sqlite',t,re.I))
    d=len(re.findall(r'sweep_id.{0,100}(render|display|shown|never show|dashboard|UI\b)|(render|display|shown|dashboard).{0,100}sweep_id',t,re.I|re.S))
    if (a and b) or d: print(f.split('_bmad-output/')[1],'aurora',a,'sqlite',b,'sweep_id-ui',d)
print('corpus files',n)
# control: token known present
print('control sweep_id files',sum(1 for f in corp if 'sweep_id' in open(f,errors='replace').read()))
