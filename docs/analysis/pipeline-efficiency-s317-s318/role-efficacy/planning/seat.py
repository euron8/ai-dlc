import os,re,collections
G='/Users/n8/git/graph/_bmad-output/planning-artifacts/'
recs={'s317':{'coe':'carry-over-evaluation-repair-p1.md','req':'requirements-repair-p1.md','arch':'architecture-spine-party-repair-p1.md'},
      's318':{'coe':'carry-over-evaluation-party-repair-p1.md','req':'requirements-party-repair.md','arch':'architecture-party-repair-p1.md'}}
SRC=re.compile(r'(?i)(?:carry-over-evaluation|requirements|architecture)-(architect|dev|tea|pm|sm)-(?:cross-?)?\w*?(?:\.md)?#?([A-Z]+-?\d+|F\d+)?')
for sp,d in recs.items():
  for ph,fn in d.items():
    f=G+sp+'/'+fn
    t=open(f,errors='replace').read(); L=t.splitlines()
    entries=[];cur=None
    for l in L:
      if re.match(r'^#{2,4}\s',l):
        cur={'h':l,'src':'','disp':''};entries.append(cur);continue
      if cur is None: continue
      m=re.match(r'(?i)^\s*[-*]*\s*\**(source|sources|finding|from)\**\s*[:]\s*(.*)',l)
      if m and not cur['src']: cur['src']=m.group(2)
      m=re.match(r'(?i)^\s*[-*]*\s*\**(disposition|status|outcome)\**\s*[:]\s*\**`?([A-Za-z_ -]+)',l)
      if m and not cur['disp']: cur['disp']=m.group(2).strip().lower()
    entries=[e for e in entries if e['disp'] or e['src']]
    disp=collections.Counter(e['disp'].split()[0] if e['disp'] else '?' for e in entries)
    seatcite=collections.Counter(); seatdisp=collections.defaultdict(collections.Counter); multi=0
    for e in entries:
      roles=set(r.lower() for r,_ in SRC.findall(e['src']))
      if not roles:
        m=re.search(r'(?i)(?:-|### )(architect|dev|tea|pm|sm)\b',e['h'])
        if m: roles={m.group(1).lower()}
      if len(SRC.findall(e['src']))>1: multi+=1
      for r in roles:
        seatcite[r]+=1; seatdisp[r][e['disp'].split()[0] if e['disp'] else '?']+=1
    print(sp,ph,fn,'entries',len(entries),'disp',dict(disp),'multi-source(dup-merged)',multi)
    for r in sorted(seatcite): print('    seat',r,seatcite[r],dict(seatdisp[r]))
