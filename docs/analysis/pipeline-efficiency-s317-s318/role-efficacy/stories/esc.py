import re, glob, collections
B='/Users/n8/' + 'git/graph/_bmad-output/'
P=B+'planning-artifacts/'
# attribution lines of repair-introduced majors s318 p1/p2
for p in ('stories-p1','stories-p2'):
    c=collections.Counter()
    for f in glob.glob(P+'s318/shards/'+p+'/*.md'):
        t=open(f,errors='replace').read()
        for s in re.split(r'^(?=#{2,4} )',t,flags=re.M):
            h=s.split('\n',1)[0]
            if not re.search(r'\b(MAJOR|CRITICAL)\b',h): continue
            if not re.search(r'repair[- ]introduced',s[:1500],re.I): continue
            src='party-repair' if re.search(r'party[- ]repair',s,re.I) else ('elicitation-repair' if re.search(r'elicitation[- ]repair',s,re.I) else ('adv-repair p1' if re.search(r'stories-repair-p1|repair record|repair p1|pass 1 repair',s,re.I) else 'unattributed'))
            c[src]+=1
    print('s318',p,'repair-introduced by source',dict(c))
# escape classification: finding headings (stories phase) mentioning the token
toks={'C-03 checklist/SQLite':r'validation_checklist|fetch_incomplete_states|checklist',
      'C-18 sweep_id':r'sweep_id',
      'C-16 HODL UI safety':r'hodl_wallet|confirm(ation)? (dialog|modal)|destination address'}
corp=glob.glob(P+'s318/shards/stories-p*/*.md')+glob.glob(B+'party-mode/s318/stories-*.md')+[P+'s318/stories-elicitation.md']
for k,pat in toks.items():
    hits=[]
    for f in corp:
        t=open(f,errors='replace').read()
        for s in re.split(r'^(?=#{2,4} )',t,flags=re.M):
            h=s.split('\n',1)[0]
            if re.match(r'#{2,4} .*(F-?\d|MAJOR|MINOR|CRITICAL|major|minor)',h) and re.search(pat,s[:2500]):
                hits.append((f.split('/')[-2][-10:]+'/'+f.split('/')[-1], h[:130]))
    print('==',k,len(hits))
    for x in hits[:8]: print('  ',x)
