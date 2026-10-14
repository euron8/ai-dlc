import re, glob, os, collections, subprocess
B='/Users/n8/' + 'git/graph/_bmad-output/'
P=B+'planning-artifacts/'
# 1. s318 p1 repair-introduced: what does attribution name
c=collections.Counter()
for f in sorted(glob.glob(P+'s318/shards/stories-p1/*.md')):
    t=open(f,errors='replace').read()
    for m in re.finditer(r'^#+\s*F-?\d+\w*\s*\[(MAJOR|CRITICAL)\][^\n]*repair-introduced[^\n]*\n(.{0,600})',t,re.M|re.S):
        body=m.group(2)
        src=re.findall(r'(party[- ]repair|elicitation[- ]repair|stories-party-repair|stories-elicitation-repair|repair record [`\w./-]+)',body,re.I)
        c[tuple(sorted(set(s.lower() for s in src)))]+=1
print('s318 p1 repair-introduced attribution',dict(c))
# 2. who authored stories in s317 (briefs)
for f in sorted(glob.glob(P+'s317/shards/stories-author-*.md'))[:1]:
    print(f[-22:], open(f).read()[:400].replace('\n',' | '))
# 3. greps for escaped defects in stories-phase shards/seats
pats={'C-03 checklist SQLite':r'validation_checklist|fetch_incomplete_states|SQLite',
      'C-18 sweep_id UI':r'sweep_id',
      'C-07 2.1 backlog rewrite':r'backlog rewrite|carry-over-backlog',
      'C-04 ADR-S317-6 paragraph':r'ADR-S317-6'}
corp={'adv':glob.glob(P+'s318/shards/stories-p*/*.md'),'party':glob.glob(B+'party-mode/s318/stories-*.md'),'elicit':[P+'s318/stories-elicitation.md']}
for k,pat in pats.items():
    row=[]
    for cn,fs in corp.items():
        n=sum(1 for f in fs if re.search(pat,open(f,errors='replace').read()))
        row.append(f'{cn}:{n}/{len(fs)}')
    print(k,row)
# control token
print('control Strategy', sum(1 for f in corp['party'] if 'story' in open(f,errors='replace').read()))
