# per elicitation C/M finding: party-repair-written text (A), party seat same span, p1 re-raise (B), repaired, shipped
import re,glob,os,subprocess,json,sys,collections
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
def blocks(t):
    return re.split(r'(?m)^(?=### )',t)
def claims(t): return "".join(re.findall(r'(?m)^- claim now asserted:.*$',t))
_corp={}
def corpus(s):
    if s in _corp: return _corp[s]
    c=COMMIT[s]
    names=subprocess.run(["git","-C",G,"ls-tree","-r","--name-only",c,"--","_bmad-output/planning-artifacts"],capture_output=True,text=True).stdout.split("\n")
    bad=re.compile(r'/(shards|rounds|archive)/|repair|adversarial|party|elicitation|changelog|chain|lint|worklist|return|\.json$|-p[0-9]|/s3\d\d/(coe|requirements|stories|architecture)-')
    keep=[n for n in names if n.endswith(".md") and not bad.search(n)]
    # keep stories/ dir and top-level files; drop old sprints' dirs
    keep=[n for n in keep if (("/"+s+"/") in n or n.count("/")==2 or "/architecture/" in n)]
    txt="".join(subprocess.run(["git","-C",G,"show",f"{c}:{n}"],capture_output=True,text=True).stdout for n in keep)
    _corp[s]=(txt,len(keep)); return _corp[s]
def shardkey(src):
    m=re.search(r'#part\s+(\S+)\s+([FE])-(\d+)',src)
    if m: return (m.group(1).lstrip('0') or '0',m.group(2)+m.group(3))
    m=re.search(r'([A-Za-z0-9]+)\.md#([FE])-(\d+)',src)
    if m: return (m.group(1).lstrip('0') or '0',m.group(2)+m.group(3))
    return None
rows=[]
for s in ("s321","s322","s323"):
  for st,(ed,pm,p1k) in STEPS.items():
    fs=sorted(glob.glob(PA+f"{s}/shards/{ed}/*.md"))
    if not fs: continue
    par=[f for f in glob.glob(PA+f"{s}/*.md") if os.path.basename(f).startswith((pm+"-party",)) and "repair" in f]
    if st=="coe": par=[f for f in glob.glob(PA+f"{s}/carry-over-evaluation-party*repair*.md")]
    if st in("spine",): par=[f for f in glob.glob(PA+f"{s}/architecture-party*repair*.md")]
    parclaim="".join(claims(rd(f)) for f in par)
    erecs=[f for f in glob.glob(PA+f"{s}/*elicitation*repair*.md") if os.path.basename(f).startswith(ed.split("-elicitation")[0]) or (st=="spine" and "SPINE" in f) or (st=="architecture" and os.path.basename(f).startswith("architecture-elic"))]
    if st=="coe": erecs=glob.glob(PA+f"{s}/coe-elicitation-repair*.md")
    emap={}
    for f in erecs:
        for b in blocks(rd(f)):
            for src in re.findall(r'(?m)^- source:(.*)$',b):
                k=shardkey(src)
                if k:
                    disp=re.search(r'(?m)^- disposition:\s*(\S+)',b); 
                    emap.setdefault(k,[]).append((disp.group(1) if disp else '?',claims(b),os.path.basename(f)))
    eclaim="".join(c for v in emap.values() for _,c,_ in v)
    seats="".join(rd(f) for f in glob.glob(PM+f"{s}/{pm}-*.md"))
    p1txt=""
    for d in glob.glob(PA+f"{s}/shards/*-p1"):
        b=os.path.basename(d)
        if re.match(rf'^{re.escape(p1k)}(-adversarial)?-p1$',b) or (st=="spine" and b in("architecture-p1","architecture-adversarial-p1")) or (st=="architecture" and b in("architecture-p1","architecture-adversarial-p1")):
            for f in glob.glob(d+"/*.md"):
                for bl in blocks(rd(f)):
                    if bl.startswith("### F") or re.match(r'### .*(CRITICAL|MAJOR|MINOR)',bl): p1txt+=bl
    ctext,nf=corpus(s)
    for f in fs:
        key=os.path.basename(f)[:-3].lstrip('0') or '0'
        for b in blocks(rd(f)):
            h=b.split("\n")[0]
            m=re.match(r'### (F-\d+)',h); sv=re.search(r'\b(CRITICAL|MAJOR)\b',h)
            if not (m and sv): continue
            n=int(m.group(1)[2:]); sp=spans(b)
            rec=emap.get((key,n),[])
            disp=rec[0][0] if rec else 'no-record'
            cl="".join(c for _,c,_ in rec); csp=spans(cl)
            shipped=[x for x in csp if x in ctext]
            r=dict(sprint=s,step=st,shard=key,f=n,sev=sv.group(1),title=h[:110],nspan=len(sp),
              in_party_repair=sum(1 for x in sp if x in parclaim),
              in_party_seat=sum(1 for x in sp if x in seats),
              in_p1=sum(1 for x in sp if x in p1txt),
              in_p1_not_eclaim=sum(1 for x in sp if x in p1txt and x not in eclaim),
              disp=disp,nclaimspans=len(csp),nshipped=len(shipped),corpus_files=nf)
            rows.append(r)
json.dump(rows,open("e2_rows.json","w"),indent=0)
c=collections.Counter()
for r in rows:
    c[(r['sprint'],r['step'],'n')]+=1
    c[(r['sprint'],r['step'],'partyrepair>=1')]+= r['in_party_repair']>0
    c[(r['sprint'],r['step'],'seat>=1')]+= r['in_party_seat']>0
    c[(r['sprint'],r['step'],'p1>=1')]+= r['in_p1']>0
    c[(r['sprint'],r['step'],'repaired')]+= r['disp']=='repaired'
    c[(r['sprint'],r['step'],'norecord')]+= r['disp']=='no-record'
    c[(r['sprint'],r['step'],'nospan')]+= r['nspan']==0
    c[(r['sprint'],r['step'],'shipped')]+= r['nshipped']>0
ks=sorted({(a,b) for a,b,_ in c})
for a,b in ks: print(a,b,{k:c[(a,b,k)] for k in ('n','nospan','partyrepair>=1','seat>=1','p1>=1','repaired','norecord','shipped')})
print("corpus files",{r['sprint']:r['corpus_files'] for r in rows})
