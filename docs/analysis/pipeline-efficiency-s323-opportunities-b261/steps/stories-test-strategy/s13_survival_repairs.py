import re,subprocess,glob,os,collections,json,sys
G="/Users/n8/git/graph";PA="_bmad-output/planning-artifacts/s323/"
GATE,FIN="ae63caf38","a9b015557"
def show(c,p):
    r=subprocess.run(["git","-C",G,"show",f"{c}:{p}"],capture_output=True,text=True); return r.stdout if r.returncode==0 else ""
cache={}
def tgt(c,p):
    k=(c,p)
    if k not in cache: cache[k]=show(c,p)
    return cache[k]
BT=re.compile(r'(?<!`)(`+)(?!`)([^\n]+?)(?<!`)\1(?!`)'); DQ=re.compile(r'"([^"\n]+)"')
def spans(s):
    out=[m.group(2) for m in BT.finditer(s) if len(m.group(2))>=12]
    s2=BT.sub(lambda m:' '*len(m.group(0)),s)
    out+=[m.group(1) for m in DQ.finditer(s2) if len(m.group(1))>=12]
    return out
recs={"party":["stories-party-repair-p1.md","stories-party-serial-repair-p1.md"],"elicit":["stories-elicitation-repair-p1.md","stories-elicitation-serial-repair-p1.md"],"p1":["stories-repair-p1.md","stories-serial-repair-p1.md"],"p2":["stories-repair-p2.md","stories-serial-repair-p2.md"],"ts":["test-strategy-repair-p1.md","test-strategy-serial-repair-p1.md"]}
allst=" ".join(tgt(FIN,PA+"stories/"+os.path.basename(f)) for f in glob.glob(G+"/"+PA+"stories/*.md"))
allgate=" ".join(tgt(GATE,PA+"stories/"+os.path.basename(f)) for f in glob.glob(G+"/"+PA+"stories/*.md"))
ts_fin=tgt(FIN,PA+"test-strategy.md")
IMP="QZXV-NO-SUCH-SPAN-90417"
print("control impossible span in stories:",IMP in allst,"| control real heading in stories:", "Acceptance Criteria" in allst)
for r,fs in recs.items():
    c=collections.Counter(); cm=collections.Counter()
    for f in fs:
        t=show("HEAD",PA+f) if False else open(G+"/"+PA+f).read() if os.path.exists(G+"/"+PA+f) else ""
        blocks=re.split(r'^### ',t,flags=re.M)[1:]
        for b in blocks:
            h=b.split('\n')[0]
            sev=re.search(r'\b(CRITICAL|MAJOR|MINOR)\b',h)
            sev=sev.group(1) if sev else 'OTHER'
            disp=re.search(r'^- disposition:\s*(\S+)',b,re.M); disp=disp.group(1) if disp else '?'
            cl=re.search(r'^- claim now asserted:(.*)$',b,re.M); sp=spans(cl.group(1)) if cl else []
            haystack=ts_fin if r=="ts" else allst
            hg=ts_fin if r=="ts" else allgate
            if disp!='repaired': cls='not-repaired'
            elif not sp: cls='no-span'
            elif any(s in haystack for s in sp): cls='span-shipped'
            else: cls='span-gone'
            c[(sev,cls)]+=1; cm[sev]+=1
    print(r,dict(cm)); 
    for sev in ('CRITICAL','MAJOR','MINOR'):
        row={k[1]:v for k,v in c.items() if k[0]==sev}
        if row: print('   ',sev,row)
