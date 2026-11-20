import re,glob,os,collections
PA="/Users/n8/git/graph/_bmad-output/planning-artifacts/"; PM="/Users/n8/git/graph/_bmad-output/party-mode/"
names={"requirements":["requirements"],"architecture":["architecture","ARCHITECTURE-SPINE"],"coe":["coe"],"stories":["stories"]}
def cm(d):
    c=collections.Counter()
    for f in glob.glob(d+"/*.md"):
        for h in re.findall(r'(?m)^### .*$',open(f).read()):
            m=re.search(r'\b(CRITICAL|MAJOR)\b',h)
            if m: c[m.group(1)[0]]+=1
    return c
for st,ns in names.items():
  for s in ("s321","s322","s323"):
    out=[]
    for p in ("p1","p2","p3"):
        c=collections.Counter()
        for n in ns:
            for d in glob.glob(PA+f"{s}/shards/{n}-{p}")+glob.glob(PA+f"{s}/shards/{n}-adversarial-{p}"): c+=cm(d)
        out.append(f"{p}:C{c['C']}/M{c['M']}")
    # party seats
    pm={"requirements":"requirements","architecture":"architecture","coe":"carry-over-evaluation","stories":"stories"}[st]
    seats=glob.glob(PM+f"{s}/{pm}-*.md")
    cmp=0
    for f in seats: cmp+=len(re.findall(r'(?mi)^##+ F-\d+ \((critical|major)\)',open(f).read()))
    el=any(glob.glob(PA+f"{s}/shards/{n}-elicitation") for n in ns+(["coe"] if st=="coe" else []))
    print(st,s,'elic' if el else 'NOELIC',' '.join(out),'party seats',len(seats),'party C/M',cmp)
