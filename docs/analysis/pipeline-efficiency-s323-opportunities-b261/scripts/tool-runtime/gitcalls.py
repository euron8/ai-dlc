import re,collections,sys
sys.path.insert(0,'/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10')
from lead import run,P,T
rows=run(P+'53b4296a-8c03-4e97-8dc8-43106688cb6e.jsonl',T('2026-11-18T12:45:29Z'),T('2026-11-19T03:09:29Z'))
c=collections.Counter(); tm=collections.defaultdict(float)
for f,th,tl,n,i,e in rows:
    if f=='Bash:git other':
        m=re.search(r'\bgit\b(?:\s+-C\s+\S+)?\s+(\S+)',i['command']); k=m.group(1) if m else '?'
        c[k]+=1; tm[k]+=tl
print(sum(c.values()),[(k,v,round(tm[k]/v,1)) for k,v in c.most_common(10)])
# single-call multi-command? count calls with >=3 chained commands (&&, ;)
ch=sum(1 for f,th,tl,n,i,e in rows if n=='Bash' and len(re.findall(r'&&|;',i['command']))>=3)
print('bash calls',sum(1 for r in rows if r[3]=='Bash'),'chained>=3',ch)
agent=[(r[4].get('description','')[:40],r[4].get('run_in_background')) for r in rows if r[3]=='Agent']
print('Agent calls',len(agent),'background',sum(1 for a in agent if a[1]))
# dispatches rejected / errored
print('errored calls',sum(1 for r in rows if r[5]),'by fam',collections.Counter(r[0] for r in rows if r[5]).most_common(5))
