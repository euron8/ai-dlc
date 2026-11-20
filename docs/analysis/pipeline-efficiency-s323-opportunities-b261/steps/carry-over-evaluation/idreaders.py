#!/usr/bin/env python3 -I
# idreaders.py: which CO- ids named only in the cluster/aged sections (lines 912-2135) of the shipped s323 evaluation appear in downstream artifacts?
import re,glob,os
G='/Users/n8/git/graph/_bmad-output/'
D=open(G+'planning-artifacts/s323/carry-over-evaluation.md').read().split('\n')
ID=re.compile(r'CO-S\d+[A-Z0-9-]*[A-Z0-9]')
head=set(ID.findall('\n'.join(D[:911]))); tail=set(ID.findall('\n'.join(D[911:2135])))
only_tail=tail-head
files=[]
for pat in ['planning-artifacts/s323/stories/*.md','planning-artifacts/s323/requirements*.md','planning-artifacts/s323/locked-requirements.md','planning-artifacts/s323/architecture*.md','specs/s323/**/*.md','planning-artifacts/prd.md','planning-artifacts/product-brief.md','implementation-artifacts/s323/**/*.md','retro-artifacts/s323/*.md']:
    files+=glob.glob(G+pat,recursive=True)
files=[f for f in files if '/shards/' not in f and 'coe-' not in f and 'carry-over-evaluation' not in os.path.basename(f)]
corp=''
for f in files: corp+=open(f,errors='replace').read()+'\n'
print('downstream files',len(files),'bytes',len(corp))
print('ids in head (lines1-911):',len(head),' ids only in cluster/aged lines:',len(tail-head),' all ids in tail:',len(tail))
hit_head=[i for i in head if i in corp]; hit_tail=[i for i in only_tail if i in corp]
print('POSITIVE CONTROL head ids found downstream:',len(hit_head),'of',len(head))
print('cluster-only ids found downstream:',len(hit_tail),'of',len(only_tail))
print('NEGATIVE CONTROL absent token found:', 'CO-S999-ZZ-NEVER' in corp)
print(sorted(hit_tail)[:25])
import collections
cat=collections.Counter()
for i in hit_tail:
    fs=set()
    for f in files:
        if i in open(f,errors='replace').read(): fs.add(f.replace(G,'').split('/')[0]+'/'+('stories' if '/stories/' in f else ('specs' if f.startswith(G+'specs') else os.path.basename(f)[:40])))
    for x in fs: cat[x]+=1
print(cat.most_common(14))
