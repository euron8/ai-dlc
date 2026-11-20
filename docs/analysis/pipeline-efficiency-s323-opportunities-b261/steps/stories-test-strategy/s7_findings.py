import re,glob,os,collections,json
B="/Users/n8/git/graph/_bmad-output/"
D="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/stories-test-strategy"
HP=re.compile(r'^##\s+F-\d+\s+\((critical|major|minor|blocker|note)\)',re.M)
H=re.compile(r'^###\s.*?\b(CRITICAL|MAJOR|MINOR|NOTE|SUGGESTION)\b',re.M)
rounds={"party":[B+"party-mode/s323/stories-%s-%s.md"%(s,n) for s in("sm","dev","architect","tea") for n in list(range(1,19))+["cross"]],
 "elicit":glob.glob(B+"planning-artifacts/s323/shards/stories-elicitation/*.md"),
 "p1":glob.glob(B+"planning-artifacts/s323/shards/stories-p1/*.md"),
 "p2":glob.glob(B+"planning-artifacts/s323/shards/stories-p2/*.md"),
 "ts-p1":glob.glob(B+"planning-artifacts/s323/shards/test-strategy-p1/*.md")}
tab={};per=collections.defaultdict(lambda:collections.defaultdict(collections.Counter))
for r,fs in rounds.items():
    c=collections.Counter(); n=0; miss=0
    for f in fs:
        if not os.path.exists(f): miss+=1; continue
        n+=1; t=open(f).read()
        sev=H.findall(t) if r!='party' else [x.upper() for x in HP.findall(t)]; c.update(sev)
        m=re.search(r'(\d+|cross)\.md$',f); k=m.group(1) if m else '?'
        per[r][k].update(sev)
    tab[r]=(n,miss,dict(c))
    print(r,'files',n,'missing',miss,dict(c))
json.dump({r:{k:dict(v) for k,v in d.items()} for r,d in per.items()},open(D+"/out_findings_per_story.json","w"))
