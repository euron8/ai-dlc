import re,glob,os,collections
B="/Users/n8/git/graph/_bmad-output/"; PA=B+"planning-artifacts/s323/"
BT=re.compile(r'(?<!`)(`+)(?!`)([^\n]+?)(?<!`)\1(?!`)'); DQ=re.compile(r'"([^"\n]+)"')
def spans(s):
    out=[m.group(2) for m in BT.finditer(s) if len(m.group(2))>=12]
    s2=BT.sub(lambda m:' '*len(m.group(0)),s)
    return set(out+[m.group(1) for m in DQ.finditer(s2) if len(m.group(1))>=12])
def claims(files):
    t=''
    for f in files:
        if os.path.exists(PA+f): t+=open(PA+f).read()
    return ''.join(re.findall(r'^- claim now asserted:.*$',t,re.M))
claim={"party":claims(["stories-party-repair-p1.md","stories-party-serial-repair-p1.md"]),
       "elicit":claims(["stories-elicitation-repair-p1.md","stories-elicitation-serial-repair-p1.md"]),
       "p1":claims(["stories-repair-p1.md","stories-serial-repair-p1.md"])}
def findings(dirp,party=False):
    out=[]
    for f in sorted(glob.glob(dirp)):
        t=open(f).read()
        pat=r'^## F-\d+ \((critical|major)\)' if party else r'^### .*\b(CRITICAL|MAJOR)\b'
        parts=re.split(r'(?m)^(?=##+ )',t)
        for p in parts:
            if re.match(pat,p,re.M): out.append((os.path.basename(f),p))
    return out
def run(name,fs,prior):
    pc=''.join(claim[k] for k in prior)
    c=collections.Counter()
    for fn,p in fs:
        sp=spans(p)
        hit=[s for s in sp if s in pc]
        c['n']+=1
        if not sp: c['no-span']+=1
        elif hit: c['in-prior-repair-text']+=1
        else: c['no-overlap']+=1
    print(name,'C/M',dict(c))
run("elicit vs party-repair",findings(PA+"shards/stories-elicitation/*.md"),["party"])
run("p1 vs party+elicit repair",findings(PA+"shards/stories-p1/*.md"),["party","elicit"])
run("p2 vs party+elicit+p1 repair",findings(PA+"shards/stories-p2/*.md"),["party","elicit","p1"])
# control: impossible span never found; claim texts nonempty
print('control impossible:', 'QZXV-NO-SUCH-SPAN-90417' in ''.join(claim.values()), '| claim chars',{k:len(v) for k,v in claim.items()})
