import re,glob,os,json,collections
R='/Users/n8/git/graph/docs/reviews/s323/'
out=[]
for f in sorted(glob.glob(R+'[1-5]-[1-5]-*.md')):
    b=os.path.basename(f)
    if not re.match(r'\d-\d-(code-review|qa-validation)',b): continue
    t=open(f).read()
    vm=re.search(r'##\s*Verdict\s*\n+\s*\**\s*([A-Z_ ]+?)\**[\s\n.:—-]',t)
    verdict=vm.group(1).strip() if vm else '?'
    sec=None; items=[]
    for line in t.split('\n'):
        h=re.match(r'###\s*(Critical|Important|Suggestions|Blocking|Major|Minor)',line,re.I)
        if h: sec=h.group(1).lower(); continue
        if re.match(r'##\s',line): sec=None
        if sec in('critical','important','blocking','major') and re.match(r'\s*(\d+\.|-|\*)\s',line) and len(line)>40:
            items.append((sec,line.strip()[:260]))
    out.append((b,verdict,items))
tot=collections.Counter()
for b,v,it in out:
    print(b,v,len(it))
json.dump(out,open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10/findings.json','w'))
