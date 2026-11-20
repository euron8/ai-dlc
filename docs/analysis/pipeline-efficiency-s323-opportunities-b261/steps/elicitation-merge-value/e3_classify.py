# Per elicitation C/M finding. Strong match = >=2 shared spans with ONE target block/line, or 1 shared span of >=40 chars.
import re,glob,os,subprocess,json,collections
G="/Users/n8/git/graph"; PA=G+"/_bmad-output/planning-artifacts/"; PM=G+"/_bmad-output/party-mode/"
COMMIT={"s321":"fb6f198e7","s322":"e0ebaf019","s323":"eabdc576e"}
STEPS={"requirements":("requirements-elicitation","requirements","requirements"),
 "architecture":("architecture-elicitation","architecture","architecture"),
 "spine":("ARCHITECTURE-SPINE-elicitation","architecture","ARCHITECTURE-SPINE"),
 "coe":("coe-elicitation","carry-over-evaluation","coe"),
 "stories":("stories-elicitation","stories","stories")}
BT=re.compile(r'(?<!`)(`+)(?!`)([^\n]+?)(?<!`)\1(?!`)'); DQ=re.compile(r'"([^"\n]+)"')
def spans(s):
    out=[m.group(2) for m in BT.finditer(s) if len(m.group(2))>=12]
    s2=BT.sub(lambda m:' '*len(m.group(0)),s)
    out+=[m.group(1) for m in DQ.finditer(s2) if len(m.group(1))>=12]
    return set(out)
def rd(p):
    try: return open(p).read()
    except: return ""
def blocks(t): return re.split(r'(?m)^(?=##+ )',t)
def claimlines(t): return re.findall(r'(?m)^- claim now asserted:.*$',t)
def strong(S,texts):
    """best strong match among texts: returns (idx, matched spans) or None"""
    best=None
    for i,t in enumerate(texts):
        m=[x for x in S if x in t]
        if len(m)>=2 or (len(m)==1 and len(m[0])>=40):
            if best is None or len(m)>len(best[1]): best=(i,m)
    return best
_corp={}
def corpus(s):
    if s in _corp: return _corp[s]
    c=COMMIT[s]
    names=subprocess.run(["git","-C",G,"ls-tree","-r","--name-only",c,"--","_bmad-output/planning-artifacts"],capture_output=True,text=True).stdout.split("\n")
    bad=re.compile(r'/(shards|rounds|archive)/|repair|adversarial|party|elicitation|changelog|chain|lint|worklist|return|\.json$|-p[0-9]')
    keep=[n for n in names if n.endswith(".md") and not bad.search(n) and (("/"+s+"/") in n or n.count("/")==2 or "/architecture/" in n)]
    keep=[n for n in keep if not re.search(r'/s3\d\d/[a-z-]+-(context|subject|chain|impact)',n)]
    txt="".join(subprocess.run(["git","-C",G,"show",f"{c}:{n}"],capture_output=True,text=True).stdout for n in keep)
    _corp[s]=(txt,keep); return _corp[s]
def shardkey(src):
    m=re.search(r'#part\s+(\S+)\s+([FE])-(\d+)',src) or re.search(r'([A-Za-z0-9]+)\.md#([FE])-(\d+)',src)
    return (m.group(1).lstrip('0') or '0',m.group(2)+m.group(3)) if m else None
rows=[]
for s in ("s321","s322","s323"):
  for st,(ed,pm,p1k) in STEPS.items():
    fs=sorted(glob.glob(PA+f"{s}/shards/{ed}/*.md"))
    if not fs: continue
    if st=="coe": par=glob.glob(PA+f"{s}/carry-over-evaluation-party*repair*.md")
    elif st=="spine": par=glob.glob(PA+f"{s}/architecture-party*repair*.md")
    else: par=[f for f in glob.glob(PA+f"{s}/{pm}-party*repair*.md")]
    pcl=[l for f in par for l in claimlines(rd(f))]
    pshard=[f for d in glob.glob(PA+f"{s}/shards/{pm if st!='coe' else 'carry-over-evaluation'}-party*repair*") if os.path.isdir(d) for f in glob.glob(d+"/*.md")]
    pcl+= [l for f in pshard for l in claimlines(rd(f))]
    ebase=ed.split("-elicitation")[0]
    edirs=[d for d in glob.glob(PA+f"{s}/shards/{ebase}-elicitation*repair*") if os.path.isdir(d)]
    efiles=[f for d in edirs for f in glob.glob(d+"/*.md")]+[f for f in glob.glob(PA+f"{s}/{ebase}-elicitation*repair*.md")]
    emap={}
    for f in efiles:
        for b in blocks(rd(f)):
            hh=b.split("\n")[0]; mh=re.match(r'### (?:(?:CRITICAL|MAJOR|MINOR|NIT) — )?([FE])-(\d+)|### ([FE])-(\d+)',hh)
            if mh and os.path.isdir(os.path.dirname(f)) and "/shards/" in f and not re.findall(r'(?m)^- source:(.*)$',b):
                k=(os.path.basename(f)[:-3].lstrip('0') or '0',(mh.group(1) or mh.group(3))+(mh.group(2) or mh.group(4)))
                disp=re.search(r'(?m)^- disposition:\s*(\S+)',b)
                emap.setdefault(k,[]).append((disp.group(1) if disp else '?',"".join(claimlines(b)),os.path.basename(os.path.dirname(f))+"/"+os.path.basename(f)))
            for src in re.findall(r'(?m)^- source:(.*)$',b):
                k=shardkey(src)
                if k:
                    disp=re.search(r'(?m)^- disposition:\s*(\S+)',b)
                    emap.setdefault(k,[]).append((disp.group(1) if disp else '?',"".join(claimlines(b)),os.path.basename(os.path.dirname(f))+"/"+os.path.basename(f)))
    eclaim="".join(c for v in emap.values() for _,c,_ in v)
    seatb=[]
    for f in glob.glob(PM+f"{s}/{pm}-*.md"):
        for b in blocks(rd(f)):
            if re.match(r'##+ (F|E)-?\d+',b) or re.match(r'##+ .*(critical|major|minor|CRITICAL|MAJOR)',b): seatb.append((os.path.basename(f),b))
    p1b=[]
    for d in glob.glob(PA+f"{s}/shards/*-p1"):
        b0=os.path.basename(d)
        if re.match(rf'^{re.escape(p1k)}(-adversarial)?-p1$',b0) or (st in("spine","architecture") and b0 in("architecture-p1","architecture-adversarial-p1")):
            for f in glob.glob(d+"/*.md"):
                for bl in blocks(rd(f)):
                    if re.match(r'### ',bl) and re.search(r'\b(F|E)-\d+|CRITICAL|MAJOR|MINOR',bl.split("\n")[0]): p1b.append((os.path.basename(f),bl))
    ctext,keep=corpus(s)
    for f in fs:
        key=os.path.basename(f)[:-3].lstrip('0') or '0'
        for b in blocks(rd(f)):
            h=b.split("\n")[0]
            m=re.match(r'### (?:(?:CRITICAL|MAJOR|MINOR|NIT) — )?([FE])-(\d+)|### ([FE])-(\d+)',h); sv=re.search(r'\b(CRITICAL|MAJOR)\b',h)
            if not (m and sv): continue
            fid=(m.group(1) or m.group(3))+(m.group(2) or m.group(4))
            sp=spans(b)
            rec=emap.get((key,fid),[])
            disp=rec[0][0] if rec else 'no-record'
            csp=spans("".join(c for _,c,_ in rec))
            shipped=[x for x in csp if x in ctext]
            pa=strong(sp,pcl)
            ps=strong(sp,[x[1] for x in seatb])
            p1=strong(sp,[x[1] for x in p1b])
            p1_orig=None
            if p1 and any(x not in eclaim for x in p1[1]): p1_orig=p1
            rows.append(dict(sprint=s,step=st,shard=key,f=fid,sev=sv.group(1),title=h[:120],nspan=len(sp),
              A_party_repair=bool(pa),seat=bool(ps),seat_where=(seatb[ps[0]][0]+' '+seatb[ps[0]][1].split(chr(10))[0][:80]+' ['+str(len(ps[1]))+'sp]' if ps else ""),
              p1=bool(p1),p1_orig=bool(p1_orig),p1_where=(p1b[p1[0]][0]+' '+p1b[p1[0]][1].split(chr(10))[0][:90]+' ['+str(len(p1[1]))+'sp]' if p1 else ""),
              disp=disp,ncl=len(csp),nship=len(shipped),repairfile=(rec[0][2] if rec else "")))
json.dump(rows,open("e3_rows.json","w"),indent=0)
c=collections.Counter()
for r in rows:
    k=(r['sprint'],r['step'])
    c[k+('n',)]+=1; c[k+('A',)]+=r['A_party_repair']; c[k+('seat',)]+=r['seat']; c[k+('p1',)]+=r['p1']; c[k+('p1orig',)]+=r['p1_orig']
    c[k+('repaired',)]+=r['disp']=='repaired'; c[k+('norec',)]+=r['disp']=='no-record'; c[k+('ship',)]+=r['nship']>0; c[k+('nospan',)]+=r['nspan']==0
    c[k+('uniq',)]+= (not r['seat'] and not r['p1'] and not r['A_party_repair'] and r['nship']>0)
for k in sorted({x[:2] for x in c}): print(*k,{n:c[k+(n,)] for n in ('n','nospan','A','seat','p1','p1orig','repaired','norec','ship','uniq')})
