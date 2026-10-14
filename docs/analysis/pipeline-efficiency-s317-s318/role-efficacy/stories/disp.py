import re, glob, collections
P='/Users/n8/' + 'git/graph/_bmad-output/planning-artifacts/'
for sp in ('s317','s318'):
    c=collections.defaultdict(collections.Counter); files=glob.glob(P+sp+'/shards/stories-party-repair-p1/*.md')
    for f in files:
        t=open(f,errors='replace').read()
        for s in re.split(r'^(?=### )',t,flags=re.M):
            h=s.split('\n',1)[0]
            m=re.match(r'### `?stories-([a-z]+)(?:-cross)?(?:-\d+)?\.md#F-\d+`?\s*[—-]+\s*(\w+)',h)
            if not m: continue
            d=re.search(r'disposition:\s*\**\s*([\w-]+)',s)
            c[(m.group(1),m.group(2).upper())][d.group(1).lower() if d else '?']+=1
    print('==',sp,'files',len(files))
    for k in sorted(c): print('  ',k,dict(c[k]))
