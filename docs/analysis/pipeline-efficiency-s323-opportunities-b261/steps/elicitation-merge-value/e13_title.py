import re,glob,os,json,collections
exec(open("e3_classify.py").read().split("rows=[]")[0])
def toks(h):
    t=set(re.findall(r'`([^`]{3,})`',h))
    t|=set(re.findall(r'\b[A-Z][A-Za-z]*-[A-Z0-9][A-Za-z0-9-]*\d\b',h))   # ids like FR-S323-9
    t|=set(re.findall(r'(?<![\w/])[:.]?\d{3,6}\b',h)) # line numbers
    t|=set(re.findall(r'\b[a-z_]+_[a-z_0-9]+\b',h))  # snake idents
    return {x.strip() for x in t if len(x.strip())>=4}
def match(tk,texts,need=2):
    best=None
    for i,t in enumerate(texts):
        m=[x for x in tk if x in t]
        if len(m)>=need and (best is None or len(m)>len(best[1])): best=(i,m)
    return best
if __name__=="__main__":
    doc=open("/Users/n8/git/ai-dlc/docs/analysis/step-value-stories-elicitation-s321.md").read().split("## Per-finding classification")[1]
    lab={}
    for l in doc.split("\n"):
        c=[x.strip() for x in l.split("|")]
        if len(c)>6 and re.match(r'\S+\.md$',c[2].strip('`')): lab[(c[2].strip('`')[:-3].lstrip('0') or '0',c[3].replace('-',''))]=c[5]
    s="s321"; tg=[]
    for d in glob.glob(PA+f"{s}/shards/stories-p[123]"):
        for f in glob.glob(d+"/*.md"):
            for bl in blocks(rd(f)):
                if bl.startswith("### "): tg.append(bl[:1500])
    res=collections.defaultdict(list)
    for f in sorted(glob.glob(PA+f"{s}/shards/stories-elicitation/*.md")):
        key=os.path.basename(f)[:-3].lstrip('0') or '0'
        for b in blocks(rd(f)):
            h=b.split("\n")[0]
            m=re.match(r'### (?:(?:CRITICAL|MAJOR|MINOR|NIT) — )?([FE])-(\d+)|### ([FE])-(\d+)',h); sv=re.search(r'\b(CRITICAL|MAJOR)\b',h)
            if not (m and sv): continue
            fid=(m.group(1) or m.group(3))+(m.group(2) or m.group(4))
            tk=toks(h); mm=match(tk,tg,2)
            res[(lab.get((key,fid)) or '?')[:16]].append(bool(mm))
    for k,v in res.items(): print(k,len(v),'matched',sum(v))
