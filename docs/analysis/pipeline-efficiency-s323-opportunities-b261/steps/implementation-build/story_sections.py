#!/usr/bin/env python3
"""Section sizes of each s323 story file at its branch tip (READ-ONLY git show): bytes per '## ' heading group; share of the file taken by dev-written evidence sections.
Story file = _bmad-output/planning-artifacts/s323/stories/story-<i>-<j>-*.md found via git ls-tree at the tip."""
import subprocess,re,collections
G='/Users/n8/git/graph'
def git(*a): return subprocess.run(['git','-C',G,*a],capture_output=True,text=True).stdout
tot=collections.Counter(); files=0; size=0; per={}
for st in ['1-1','1-2','1-3','1-4','3-1','3-2','4-1','4-2','4-3','4-4','5-1','5-2','5-3','5-4','5-5']:
    br='dev/sprint-323/story-'+st
    fs=[f for f in git('ls-tree','-r','--name-only',br,'_bmad-output/planning-artifacts/s323/stories/').split() if re.search(r'story-%s-'%st,f)]
    if not fs: continue
    txt=git('show',br+':'+fs[0]); files+=1; size+=len(txt)
    sec=None; d=collections.Counter()
    for line in txt.splitlines(keepends=True):
        m=re.match(r'##\s+(.*)',line)
        if m: sec=re.sub(r'\W+',' ',m.group(1)).strip()[:34]
        d[sec or 'frontmatter/preamble']+=len(line)
    per[st]=(len(txt),d)
    for k,v in d.items(): tot[k]+=v
print('story files',files,'total bytes',size)
for k,v in tot.most_common(16): print(k.ljust(36),v,'%.0f%%'%(100*v/size))
for st,(n,d) in per.items():
    dar=sum(v for k,v in d.items() if re.search(r'Dev Agent Record|Production Integrity|Smoke Test|Rename Verif|Scope Verif|Cross CI|Strategy Test|Canonical',k)); print(st,n,'evidence-ish %.0f%%'%(100*dar/n))
