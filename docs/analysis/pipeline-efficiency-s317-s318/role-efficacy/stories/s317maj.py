import re, glob, collections
P='/Users/n8/' + 'git/graph/_bmad-output/planning-artifacts/'
for sp in ('s317','s318'):
  for p in ('stories-p1','stories-p2','stories-p3'):
    c=collections.Counter(); n=0
    for f in sorted(glob.glob(P+sp+'/shards/'+p+'/*.md')):
        t=open(f,errors='replace').read()
        parts=re.split(r'^(?=#{2,4} )',t,flags=re.M)
        for s in parts:
            h=s.split('\n',1)[0]
            if not re.match(r'#{2,4} ',h): continue
            if not re.search(r'\b(MAJOR|CRITICAL)\b',h): continue
            n+=1
            body=s[:1500].lower()
            if re.search(r'repair[- ]introduced|introduced by (the|a) repair|the repair (added|introduced|created)|repair (added|introduced)',body): c['repair-introduced']+=1
            elif re.search(r'partial(ly)? repair|not repaired|repaired wrongly|persists|still (open|present)|carried from pass|re-?raised',body): c['carried/partial']+=1
            else: c['new']+=1
    print(sp,p,'major/critical headings',n,dict(c))
