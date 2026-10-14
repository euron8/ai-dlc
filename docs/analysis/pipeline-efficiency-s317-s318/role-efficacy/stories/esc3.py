import re
B='/Users/n8/'+'git/graph/_bmad-output/'
for f in ('party-mode/s318/stories-sm-05.md','planning-artifacts/s318/shards/stories-party-repair-p1/5.md','planning-artifacts/s318/shards/stories-p2/04.md'):
    t=open(B+f).read()
    for m in re.finditer(r'[^\n]{0,250}sweep_id[^\n]{0,250}',t):
        s=m.group(0)
        if re.search(r'render|display|shown|dashboard|UI',s,re.I): print(f,'::',s[:420]); break
