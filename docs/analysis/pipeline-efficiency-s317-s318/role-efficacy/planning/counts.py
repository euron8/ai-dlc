import os,re,sys,glob
G='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
pat=re.compile(r'(findings_(critical|major|minor)\s*[:=]\s*(\d+))|(verdict\s*[:=]\s*\**\s*([A-Z_]+))|(exit_condition\s*[:=]\s*([A-Z_]+))',re.I)
for sp in ('s317','s318'):
    files=sorted(glob.glob(G+sp+'/*.md'))+sorted(glob.glob(G+sp+'/shards/**/*.md',recursive=True))
    for f in files:
        b=os.path.basename(f); rel=f[len(G):]
        if not re.search(r'(coe|carry-over|requirements|architecture|gate-planning)',rel): continue
        if 'stories' in rel or 'sprint-review' in rel: continue
        t=open(f,errors='replace').read()
        head=t[:6000]
        c={};v=set()
        for m in pat.finditer(head):
            if m.group(2): c.setdefault(m.group(2).lower(),m.group(3))
            if m.group(5): v.add(m.group(5))
            if m.group(7): v.add(m.group(7))
        # count finding headings in whole file
        hs=len(re.findall(r'^#{2,4}\s*(\*\*)?\[?(F|M|C|N|A|R|E)[-\w]*\d+\b',t,re.M))
        sev=re.findall(r'\b(CRITICAL|MAJOR|MINOR)\b',t)
        print(rel, len(t), c, sorted(v)[:3], 'hdr',hs, 'sevtok',{k:sev.count(k) for k in ('CRITICAL','MAJOR','MINOR')})
