import json,re,collections
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
F=json.load(open(M.replace("MONO/","")+"steps/stories-test-strategy/out_findings_per_story.json"))
stories=['1.1','1.2','1.3','1.4','2.1','2.2','2.3','3.1','3.2','4.1','4.2','4.3','4.4','5.1','5.2','5.3','5.4','5.5']
esc={'1.1','1.2','1.3','1.4','2.3','3.2','5.2'}
sp=[json.loads(l) for l in open(M+"spawns.jsonl")]
sp=[s for s in sp if s['sprint']==323 and s['step'] in('implementation','gate-validation[implementation]','sprint-review')]
rx=re.compile(r'(?:[Ss]tory|S323-|\bs?)\s*(\d)[.\-](\d)\b')
per=collections.defaultdict(lambda:collections.defaultdict(lambda:[0,0.0,0.0]))
unmatched=[0,0.0]
for s in sp:
    m=rx.search(s['description'])
    if not m: unmatched[0]+=1; unmatched[1]+=s['usd']; continue
    k=m.group(1)+'.'+m.group(2)
    r=s['role']; st='I' if s['step']=='implementation' else ('G' if s['step'].startswith('gate') else 'R')
    e=per[k][(st,r)]; e[0]+=1;e[1]+=s['usd'];e[2]+=s['minutes']
print('unmatched impl/gate/SR spawns',unmatched)
def fnd(r,i):
    d=F[r].get('%02d'%i) or F[r].get(str(i)) or {}
    return d.get('CRITICAL',0)+d.get('MAJOR',0)
print("story tag | plan C/M: party elic p1 p2 | impl: dev  rev  qa  | gate: rev qa adj | SR:dev tea pm arch | $impl $gate $SR | min dev")
for i,k in enumerate(stories,1):
    d=per[k]
    def n(st,roles): return sum(d[(st,r)][0] for (s2,r) in list(d) if s2==st and r in roles)
    def usd(st): return sum(v[1] for (s2,r),v in d.items() if s2==st)
    devm=sum(v[2] for (s2,r),v in d.items() if s2=='I' and r.startswith('dev'))
    party=sum(fnd('party',i) for _ in [0]) # placeholder
    print(k,'E' if k in esc else '-', '|',fnd('elicit',i),fnd('p1',i),fnd('p2',i),'|', n('I',('dev','dev-escalated')),n('I',('code-reviewer','code-reviewer-escalated','pre-reviewer')),n('I',('qa',)),'|',n('G',('code-reviewer','code-reviewer-escalated')),n('G',('qa',)),n('G',('gate-adjudicator',)),'|',n('R',('dev','dev-escalated')),n('R',('tea',)),n('R',('pm',)),n('R',('architect',)),'|',round(usd('I')),round(usd('G')),round(usd('R')),'|',round(devm))
