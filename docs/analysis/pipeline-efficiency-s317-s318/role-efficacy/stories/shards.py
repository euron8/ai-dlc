import os, re, glob, collections
B='/Users/n8/git/graph/_bmad-output/planning-artifacts'
for sp in ('s317','s318'):
    for d in sorted(glob.glob(f'{B}/{sp}/shards/stories-*')):
        if not os.path.isdir(d): continue
        files=sorted(glob.glob(d+'/*.md'))
        tot=collections.Counter(); hdr=collections.Counter(); origin=collections.Counter(); verdicts=collections.Counter()
        for f in files:
            t=open(f,errors='replace').read()
            for k in ('findings_major','findings_minor','findings_critical','findings_major_underived','findings_critical_prior_scope'):
                m=re.search(rf'^{k}:\s*(\d+)',t,re.M)
                if m: hdr[k]+=int(m.group(1))
            for m in re.finditer(r'^#+\s*F-?\d+\s*\[(\w+)\]',t,re.M): tot[m.group(1).upper()]+=1
            for m in re.finditer(r'\[(MAJOR|MINOR|CRITICAL)\]',t): pass
            for m in re.finditer(r'(repair-introduced|re-found|refound|carried|new in this pass|persist\w*|still open|not repaired|partially repaired)',t,re.I): origin[m.group(1).lower()]+=1
            for m in re.finditer(r'EXIT_CONDITION_(MET|NOT_MET)|\b(NOT_MET)\b',t): verdicts[m.group(0)]+=1
        print(sp, os.path.basename(d), 'files',len(files),'hdr',dict(hdr),'headings',dict(tot),'origin',dict(origin),'verd',dict(verdicts))
