import re,glob,os,json,collections
PA="/Users/n8/git/graph/_bmad-output/planning-artifacts/"
ED={"requirements":"requirements-elicitation","architecture":"architecture-elicitation","spine":"ARCHITECTURE-SPINE-elicitation","coe":"coe-elicitation","stories":"stories-elicitation"}
pat=re.compile(r'(party[- ](?:serial[- ])?(?:repair|round|fold|edit|amend)\w*|(?:serial|fan-?in|readiness|elicitation)[- ]repair|the repair|a repair|repair R-\d+|\bR-\d+\b|folded|fold\b|operator answer|after the (?:repair|fold)|added by|introduced by|wrote|rewrote)',re.I)
out=collections.defaultdict(lambda:collections.Counter()); ex={}
for s in ("s321","s322","s323"):
  for st,d in ED.items():
    for f in sorted(glob.glob(PA+f"{s}/shards/{d}/*.md")):
      t=open(f).read()
      for b in re.split(r'(?m)^(?=### )',t):
        h=b.split("\n")[0]
        if not (re.match(r'### ',h) and re.search(r'\b(CRITICAL|MAJOR)\b',h) and re.search(r'\b[FE]-\d+',h)): continue
        body="\n".join(b.split("\n")[1:])
        m=re.search(r'party[- ](?:serial[- ])?(?:repair|round|fold|edit|amend)\w*|the party\b|party repair',body,re.I)
        m2=pat.search(body)
        k=(s,st); out[k]['n']+=1
        if m: out[k]['party_named']+=1
        if m2: out[k]['any_repair_word']+=1
for k,v in sorted(out.items()): print(*k,dict(v))
