import re,glob,os,collections
PA="/Users/n8/git/graph/_bmad-output/planning-artifacts/"
R={"requirements":"requirements-elicitation","architecture":"architecture-elicitation","spine":"ARCHITECTURE-SPINE-elicitation","coe":"coe-elicitation","stories":"stories-elicitation"}
for s in ("s321","s322","s323"):
  for k,d in R.items():
    fs=sorted(glob.glob(PA+f"{s}/shards/{d}/*.md"))
    if not fs: continue
    c=collections.Counter(); ex=[]
    for f in fs:
      for h in re.findall(r'(?m)^###? .*$',open(f).read()):
        if h.startswith('### '):
          m=re.search(r'\b(CRITICAL|MAJOR|MINOR)\b',h)
          if m: c[m.group(1)]+=1
          elif len(ex)<2 and h.startswith('### F'): ex.append(h[:60])
    print(s,k,len(fs),dict(c),ex)
# control: impossible dir
print("control none:",len(glob.glob(PA+"s323/shards/no-such-elicitation/*.md")), "control s323 req >0:",len(glob.glob(PA+"s323/shards/requirements-elicitation/*.md")))
