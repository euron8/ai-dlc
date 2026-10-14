import os,re,glob,collections
B='/Users/n8/git/graph/_bmad-output/party-mode/'
SC=re.compile(r'seat-complete:.*findings=(\d+)')
H=re.compile(r'^#{2,5}\s.*\b(CRITICAL|MAJOR|MINOR)\b')
out=collections.OrderedDict()
for sp in ('s317','s318'):
  for ph in ('carry-over-evaluation','requirements','architecture'):
    for f in sorted(glob.glob(B+sp+'/'+ph+'-*.md')):
      b=os.path.basename(f)[len(ph)+1:-3]
      role=b.split('-')[0]
      if role not in ('pm','architect','dev','tea','sm','analyst'): continue
      t=open(f,errors='replace').read()
      m=SC.findall(t); sc=int(m[-1]) if m else None
      sev=collections.Counter()
      for l in t.splitlines():
        if H.match(l): sev[re.search(r'\b(CRITICAL|MAJOR|MINOR)\b',l).group(1)]+=1
      k=(sp,ph,role); a=out.setdefault(k,[0,0,0,collections.Counter(),0])
      a[0]+=1; a[1]+= sc or 0; a[2]+= (1 if sc is None else 0); a[3].update(sev); a[4]+=len(t)
for k,a in out.items(): print(k,'files',a[0],'seat-complete-findings',a[1],'no-sc-line',a[2],'heading-sev',dict(a[3]),'bytes',a[4])
