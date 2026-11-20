import re,collections,subprocess,glob,os,json
G="/Users/n8/git/graph";PA="_bmad-output/planning-artifacts/s323/"
FIN="a9b015557"
def show(c,p): return subprocess.run(["git","-C",G,"show",f"{c}:{p}"],capture_output=True,text=True).stdout
stories=sorted(os.path.basename(f) for f in glob.glob(G+"/"+PA+"stories/*.md"))
txt={s:show(FIN,PA+"stories/"+s) for s in stories}
ESC={'1-1','1-2','1-3','1-4','2-3','3-2','5-2'}
def sid(s): return re.match(r'story-(\d-\d)',s).group(1)
BT=re.compile(r'(?<!`)(`+)(?!`)([^\n]+?)(?<!`)\1(?!`)'); DQ=re.compile(r'"([^"\n]+)"')
def spans(s):
    out=[m.group(2) for m in BT.finditer(s) if len(m.group(2))>=12]
    s2=BT.sub(lambda m:' '*len(m.group(0)),s)
    return out+[m.group(1) for m in DQ.finditer(s2) if len(m.group(1))>=12]
recs={"party":["stories-party-repair-p1.md","stories-party-serial-repair-p1.md"],"elicit":["stories-elicitation-repair-p1.md","stories-elicitation-serial-repair-p1.md"],"p1":["stories-repair-p1.md","stories-serial-repair-p1.md"],"p2":["stories-repair-p2.md","stories-serial-repair-p2.md"]}
res=collections.defaultdict(collections.Counter)   # (round,tag)->class
bystory=collections.defaultdict(collections.Counter)
for r,fs in recs.items():
    for f in fs:
        p=G+"/"+PA+f
        if not os.path.exists(p): continue
        t=open(p).read()
        for b in re.split(r'^### ',t,flags=re.M)[1:]:
            h=b.split('\n')[0]; sv=re.search(r'\b(CRITICAL|MAJOR)\b',h)
            if not sv: continue
            e=re.search(r'^- edit:\s*(\S+)',b,re.M); a=re.search(r'^- artifact:\s*(\S+)',b,re.M)
            path=(e.group(1) if e else '') or ''
            m=re.search(r'story-(\d-\d)-',path)
            if not m:
                # use artifact from shard header above
                m=re.search(r'story-(\d-\d)-',b)
            k=m.group(1) if m else None
            d=re.search(r'^- disposition:\s*(\S+)',b,re.M); d=d.group(1) if d else '?'
            cl=re.search(r'^- claim now asserted:(.*)$',b,re.M); sp=spans(cl.group(1)) if cl else []
            if k is None: cls='nostory'
            elif d!='repaired': cls='not-repaired'
            elif not sp: cls='nospan'
            else:
                tg=[x for x in stories if sid(x)==k]
                cls='shipped' if tg and any(s in txt[tg[0]] for s in sp) else 'gone'
            tag='E' if (k in ESC) else ('-' if k else '?')
            res[(r,tag)][cls]+=1
            if k: bystory[k][(r,cls)]+=1
for k,v in sorted(res.items()): print(k,dict(v))
print()
for k in sorted(bystory): print(k,'E' if k in ESC else '-',{f"{a}:{b}":n for (a,b),n in sorted(bystory[k].items()) if b=='shipped'})
