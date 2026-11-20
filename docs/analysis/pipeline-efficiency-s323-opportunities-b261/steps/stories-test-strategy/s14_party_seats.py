import re,collections,sys
G="/Users/n8/git/graph/_bmad-output/planning-artifacts/s323/"
t=open(G+"stories-party-repair-p1.md").read()+open(G+"stories-party-serial-repair-p1.md").read()
blocks=re.split(r'^### ',t,flags=re.M)[1:]
nse=collections.Counter(); uniq=collections.Counter(); tot=collections.Counter(); sevc=collections.Counter()
rows=0
for b in blocks:
    h=b.split('\n')[0]
    sev=re.search(r'\b(CRITICAL|MAJOR|MINOR)\b',h)
    if not sev or sev.group(1)=='MINOR': continue
    m=re.search(r'^- source:(.*)$',b,re.M)
    if not m: continue
    seats=set(re.findall(r'stories-(sm|dev|architect|tea|[a-z]+)-(?:\d+|cross)\.md',m.group(1)))
    if not seats: continue
    rows+=1; nse[len(seats)]+=1
    for s in seats: tot[s]+=1
    if len(seats)==1: uniq[next(iter(seats))]+=1
print('C/M repair blocks with seat sources',rows,'by #distinct seats naming it',dict(nse))
print('blocks naming seat',dict(tot)); print('blocks ONLY that seat names',dict(uniq))
# survival of sole-source blocks
import subprocess,glob,os
FIN="a9b015557";PA="_bmad-output/planning-artifacts/s323/"
def show(c,p):
    r=subprocess.run(["git","-C","/Users/n8/git/graph","show",f"{c}:{p}"],capture_output=True,text=True); return r.stdout
allst=" ".join(show(FIN,PA+"stories/"+os.path.basename(f)) for f in glob.glob("/Users/n8/git/graph/"+PA+"stories/*.md"))
BT=re.compile(r'(?<!`)(`+)(?!`)([^\n]+?)(?<!`)\1(?!`)')
res=collections.Counter()
for b in blocks:
    h=b.split('\n')[0]; sev=re.search(r'\b(CRITICAL|MAJOR|MINOR)\b',h)
    if not sev or sev.group(1)=='MINOR': continue
    m=re.search(r'^- source:(.*)$',b,re.M)
    if not m: continue
    seats=set(re.findall(r'stories-(sm|dev|architect|tea|[a-z]+)-(?:\d+|cross)\.md',m.group(1)))
    if len(seats)!=1: continue
    s=next(iter(seats))
    d=re.search(r'^- disposition:\s*(\S+)',b,re.M); d=d.group(1) if d else '?'
    cl=re.search(r'^- claim now asserted:(.*)$',b,re.M)
    sp=[x.group(2) for x in BT.finditer(cl.group(1)) if len(x.group(2))>=8] if cl else []
    st='not-repaired' if d!='repaired' else ('shipped' if sp and any(x in allst for x in sp) else ('nospan' if not sp else 'gone'))
    res[(s,st)]+=1
print(sorted(res.items()))
