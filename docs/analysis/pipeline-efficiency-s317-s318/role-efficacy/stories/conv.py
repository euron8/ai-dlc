import re, glob, os, collections
B='/Users/n8/' + 'git/graph/_bmad-output/planning-artifacts/'
GR=re.compile(r'\*\*(repaired wrongly|not repaired|partially repaired|repaired)\*\*',re.I)
for sp in ('s317','s318'):
    for p in ('stories-p1','stories-p2','stories-p3'):
        files=sorted(glob.glob(f'{B}{sp}/shards/{p}/*.md'))
        grades=collections.Counter(); maj=collections.Counter(); hdr=collections.Counter(); n=0
        for f in files:
            t=open(f,errors='replace').read(); n+=1
            for m in GR.finditer(t): grades[m.group(1).lower()]+=1
            # findings headings
            for m in re.finditer(r'^#+\s*F-?\d+\w*\s*[\[\(](MAJOR|CRITICAL|major|critical)[\]\)][^\n]*',t,re.M):
                h=m.group(0).lower()
                tag='repair-introduced' if 'repair-introduced' in h or 'introduced by' in h or 'repair introduced' in h else ('partial/not-repaired' if re.search(r'partial|not repaired|persist|carried|unrepaired|re-?found|still',h) else 'new/unlabelled')
                maj[tag]+=1
            for k in ('findings_major','findings_critical','findings_minor'):
                mm=re.search(rf'^{k}:\s*(\d+)',t,re.M)
                if mm: hdr[k]+=int(mm.group(1))
        print(sp,p,'files',n,'hdr',dict(hdr),'major-heading tags',dict(maj),'prior-grade',dict(grades))
# s317 has no heading severities? check finding headings sample
for f in sorted(glob.glob(B+'s317/shards/stories-p1/*.md'))[:30]:
    t=open(f,errors='replace').read()
    hs=re.findall(r'^#+\s*F-?\d+[^\n]{0,90}',t,re.M)
    if hs: print(os.path.basename(f),hs[:3]); break
