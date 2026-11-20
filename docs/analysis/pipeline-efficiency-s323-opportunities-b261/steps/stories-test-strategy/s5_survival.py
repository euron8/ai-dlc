import subprocess,re,sys,difflib,json,hashlib
G="/Users/n8/git/graph"
P="_bmad-output/planning-artifacts/s323/stories"
C0,C1,CF=sys.argv[1],sys.argv[2],sys.argv[3]   # planning commit, story gate, final
def git(*a):
    return subprocess.run(["git","-C",G]+list(a),capture_output=True,text=True).stdout
def show(c,p):
    r=subprocess.run(["git","-C",G,"show",f"{c}:{p}"],capture_output=True,text=True)
    return r.stdout if r.returncode==0 else None
files=[l.split('/')[-1] for l in git("ls-tree","--name-only",CF,P+"/").split()]
files=[f for f in files if f.endswith('.md')]
ACRE=re.compile(r'^- \*\*(AC\d+[a-z]?)\b',re.M)
def acs(t):
    if t is None: return {}
    m=re.search(r'^## Acceptance Criteria\s*$(.*?)(?=^## )',t,re.M|re.S)
    if not m: return {}
    body=m.group(1)
    idx=[(x.start(),x.group(1)) for x in ACRE.finditer(body)]
    d={}
    for i,(s,k) in enumerate(idx):
        e=idx[i+1][0] if i+1<len(idx) else len(body)
        d[k]=body[s:e].strip()
    return d
def norm(s): return re.sub(r'\s+',' ',s)
def fm(t,key):
    m=re.search(r'^'+key+r':\s*(.*)$',t,re.M); return m.group(1).strip() if m else ''
tot={'ac0':0,'same_c1':0,'same_f':0,'amend':0,'chg':0,'gone':0,'bytes0':0,'bytes_same':0}
rows=[]
for f in files:
    p=f"{P}/{f}"
    t0,t1,tf=show(C0,p),show(C1,p),show(CF,p)
    a0,a1,af=acs(t0),acs(t1),acs(tf)
    if t0 is None: continue
    n=len(a0); s1=sum(1 for k in a0 if a1.get(k)==a0[k]); sf=sum(1 for k in a0 if af.get(k) and norm(af[k])==norm(a0[k]))
    am=sum(1 for k in a0 if k in af and norm(af[k])!=norm(a0[k]) and re.search(r'amendment|\[Sprint-review|\[Gate-|\[Amend',af[k]))
    gone=sum(1 for k in a0 if k not in af)
    chg=n-sf-am-gone
    b0=sum(len(v) for v in a0.values()); bs=sum(len(a0[k]) for k in a0 if af.get(k) and norm(af[k])==norm(a0[k]))
    # char similarity of changed
    sims=[]
    for k in a0:
        if k in af and norm(af[k])!=norm(a0[k]):
            sims.append(difflib.SequenceMatcher(None,norm(a0[k]),norm(af[k]),autojunk=False).quick_ratio())
    rows.append(dict(f=f[:40],n=n,nf=len(af),same_c1=s1,same_f=sf,amend=am,chg=chg,gone=gone,b0=b0,bs=bs,len0=len(t0),lenf=len(tf),esc=fm(t0,'escalate_model'),pp=fm(t0,'protected_path_editor'),status=fm(tf,'status'),sim=round(sum(sims)/len(sims),2) if sims else None))
print("story n ACs  same@gate  same@final amended(marker) changed-other gone | AC bytes0 same bytes | file bytes0->final | esc pp")
for r in rows: print(r['f'],r['n'],r['same_c1'],r['same_f'],r['amend'],r['chg'],r['gone'],r['b0'],r['bs'],r['len0'],r['lenf'],r['esc'],r['pp'],r['sim'])
for k in ('n','same_c1','same_f','amend','chg','gone','b0','bs','len0','lenf'):
    print(k,sum(r[k] for r in rows))
json.dump(rows,open(sys.argv[4],'w'))
