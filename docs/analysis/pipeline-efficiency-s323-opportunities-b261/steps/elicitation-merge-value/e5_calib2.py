import re,glob,os,json,collections
exec(open("e3_classify.py").read().split("rows=[]")[0])
doc=open("/Users/n8/git/ai-dlc/docs/analysis/step-value-stories-elicitation-s321.md").read().split("## Per-finding classification")[1]
lab={}
for l in doc.split("\n"):
    c=[x.strip() for x in l.split("|")]
    if len(c)>6 and re.match(r'\S+\.md$',c[2].strip('`')): lab[(c[2].strip('`')[:-3].lstrip('0') or '0',c[3].replace('-',''))]=c[5]
s="s321"
p1b=[]
for d in glob.glob(PA+f"{s}/shards/stories-p[123]"):
    for f in glob.glob(d+"/*.md"):
        for bl in blocks(rd(f)):
            if bl.startswith("### ") : p1b.append((d.split('/')[-1],bl))
print(len(p1b))
res=collections.defaultdict(list)
for f in sorted(glob.glob(PA+f"{s}/shards/stories-elicitation/*.md")):
    key=os.path.basename(f)[:-3].lstrip('0') or '0'
    for b in blocks(rd(f)):
        h=b.split("\n")[0]
        m=re.match(r'### (?:(?:CRITICAL|MAJOR|MINOR|NIT) — )?([FE])-(\d+)|### ([FE])-(\d+)',h); sv=re.search(r'\b(CRITICAL|MAJOR)\b',h)
        if not (m and sv): continue
        fid=(m.group(1) or m.group(3))+(m.group(2) or m.group(4)); sp=spans(b)
        mx=max([len([x for x in sp if x in t]) for _,t in p1b] or [0])
        mxr=max([len([x for x in sp if x in t])/max(1,len(sp)) for _,t in p1b] or [0])
        res[lab.get((key,fid))].append((mx,round(mxr,2)))
for k,v in res.items(): print(k and k[:18],len(v),sorted(x[0] for x in v))
