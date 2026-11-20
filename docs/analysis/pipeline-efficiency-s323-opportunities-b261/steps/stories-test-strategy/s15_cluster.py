import json,re,collections
D="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/stories-test-strategy/"
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
F=json.load(open(D+"out_findings_per_story.json"))
S=json.load(open(D+"out_survival.json"))
stories=['1.1','1.2','1.3','1.4','2.1','2.2','2.3','3.1','3.2','4.1','4.2','4.3','4.4','5.1','5.2','5.3','5.4','5.5']
def cm(r,i):
    d=F[r].get(str(i)) or F[r].get('%02d'%i) or {}
    return d.get('CRITICAL',0)+d.get('MAJOR',0)
# commits by story: rework / NEEDS_REWORK mentions
com=open(D+"out_s323_commits.txt").read().split('\n')
rw=collections.Counter(); cc=collections.Counter()
for l in com:
    m=re.search(r's323[-(]?(\d)[.\-](\d)',l) or re.search(r'story (\d)\.(\d)',l)
    if not m: continue
    k=m.group(1)+'.'+m.group(2); cc[k]+=1
    if re.search(r'rework|rehandoff|NEEDS_REWORK|remediat',l,re.I): rw[k]+=1
rx=re.compile(r'(\d)[.\-](\d)\b')
sp=[json.loads(l) for l in open(M+"spawns.jsonl")]
sp=[s for s in sp if s['sprint']==323 and s['step'] in('implementation','gate-validation[implementation]')]
usd=collections.Counter(); n=collections.Counter(); mins=collections.Counter()
for s in sp:
    m=rx.search(s['description'])
    if m:
        k=m.group(1)+'.'+m.group(2); usd[k]+=s['usd']; n[k]+=1
print("story tag acs ACkB | party elic p1 p2 (C/M) | impl+gate spawns $ | commits rework")
tot=collections.Counter()
for i,k in enumerate(stories,1):
    r=S[i-1]
    pt=cm('party',i) # note party keyed per ordinal pooled across seats
    print(k,'E' if r['esc']=='true' else '-',r['n'],round(r['b0']/1000,1),'|',pt,cm('elicit',i),cm('p1',i),cm('p2',i),'|',n[k],round(usd[k]),'|',cc[k],rw[k])
