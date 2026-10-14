import re, glob, os, collections, json
B='/Users/n8/' + 'git/graph/_bmad-output/'
# seat findings per file
def seats(sp, phase):
    out={}
    for f in glob.glob(f'{B}party-mode/{sp}/{phase}-*.md'):
        t=open(f,errors='replace').read()
        sev=[m.group(1).lower() for m in re.finditer(r'^#+\s*F-?\d+\w*\s*\(([a-zA-Z]+)',t,re.M)]
        sev+= [m.group(1).lower() for m in re.finditer(r'^#+\s*F-?\d+\w*\s*\[([A-Za-z]+)\]',t,re.M)]
        m=re.search(r'seat-complete:.*findings=(\d+)',t)
        base=os.path.basename(f)
        role=re.sub(r'^'+phase+r'-','',base); role=re.sub(r'-?\d+[a-z]?\.md$','',role).replace('.md','')
        out[base]=(role,sev,int(m.group(1)) if m else None)
    return out
for sp,phase in (('s317','stories'),('s318','stories'),('s317','sprint-review'),('s318','sprint-review')):
    s=seats(sp,phase)
    agg=collections.defaultdict(lambda:[0,collections.Counter(),0,0])
    for b,(role,sev,decl) in s.items():
        a=agg[role]; a[0]+=1; a[1].update(sev); a[2]+=len(sev); a[3]+= (decl or 0)
    print('==',sp,phase,'files',len(s))
    for r,a in sorted(agg.items()): print('  ',r,'seats',a[0],'parsed',a[2],'declared',a[3],dict(a[1]))
# s318 sprint-review digest clusters
t=open(B+'implementation-artifacts/s318/sprint-review-party-digest.md').read()
cl=re.split(r'^### ',t,flags=re.M)[1:]
mem2cl={}; clinfo={}
for c in cl:
    h=c.splitlines()[0]; m=re.match(r'(C-\d+) \((\w+), ([\w-]+)\)',h)
    cid,sev,fc=m.groups()
    mm=re.search(r'Members \((\d+)\): (.*)',c)
    mems=re.findall(r'`([^`]+)`',mm.group(2))
    ver=re.search(r'Verification: (.*)',c).group(1)[:40]
    clinfo[cid]=(sev,fc,len(mems),ver)
    for x in mems: mem2cl[x]=cid
print('clusters',len(clinfo),'members',len(mem2cl), collections.Counter((v[0],v[1]) for v in clinfo.values()))
# per seat role: findings, clusters, unique-first, sole-member clusters
rep=open(B+'implementation-artifacts/s318/sprint-review-party-repair.md').read()
disp={}
for blk in re.split(r'^### ',rep,flags=re.M)[1:]:
    ids=re.findall(r'C-\d+',blk.splitlines()[0]); d=re.search(r'disposition: (\w+)',blk)
    for i in ids: disp.setdefault(i,set()).add(d.group(1) if d else '?')
print('repair-file dispositions', {k:sorted(v) for k,v in sorted(disp.items())})
byrole=collections.defaultdict(lambda:[0,set(),0])
for x,c in mem2cl.items():
    f=x.split('#')[0]; role=re.sub(r'^sprint-review-','',f); role=re.sub(r'-?\d+[a-z]?\.md$','',role)
    byrole[role][0]+=1; byrole[role][1].add(c)
for role,(n,cs) in [(k,(v[0],v[1])) for k,v in byrole.items()]:
    sole=[c for c in cs if all(re.sub(r'-?\d+[a-z]?\.md$','',re.sub(r'^sprint-review-','',y.split('#')[0]))==role for y,cc in mem2cl.items() if cc==c)]
    maj=[c for c in cs if clinfo[c][0] in('major','critical')]
    print('  role',role,'members',n,'clusters',len(cs),'major-clusters',len(maj),'sole-role clusters',len(sole), 'sole-major',[c for c in sole if clinfo[c][0] in ('major','critical')])
json.dump({k:list(v) for k,v in clinfo.items()},open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/stories/clinfo.json','w'))
