import json,re,collections
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10/'
R=json.load(open(D+'calls323.json'))
print('agent bash git push',sum(1 for r in R if r['tool']=='Bash' and re.search(r'git\s+push',r['cmd'])),'control: git commit',sum(1 for r in R if r['tool']=='Bash' and re.search(r'git\s+commit',r['cmd'])))
import sys
sys.path.insert(0,D)
from lead import run,P,T
rows=run(P+'53b4296a-8c03-4e97-8dc8-43106688cb6e.jsonl',T('2026-11-18T12:45:29Z'),T('2026-11-19T03:09:29Z'))
print('lead git push',sum(1 for f,th,tl,n,i,e in rows if n=='Bash' and re.search(r'git\s+push',i.get('command',''))),'lead git commit',sum(1 for f,th,tl,n,i,e in rows if n=='Bash' and re.search(r'git\s+commit',i.get('command',''))),'merge',sum(1 for f,th,tl,n,i,e in rows if n=='Bash' and re.search(r'git\s+merge',i.get('command',''))))
# gate-transition detail
c=collections.Counter(); t=collections.defaultdict(float)
for f,th,tl,n,i,e in rows:
    if f=='Bash:gate-transition':
        m=re.search(r'gate-transition\.sh\s+(\S+)\s+(\S+)',i['command']); k=(m.group(2) if m else '?'); c[k]+=1; t[k]+=tl
print({k:(c[k],round(t[k]/c[k],1)) for k in c})
# per-story bookkeeping distribution of lead calls: by story token in command
st=collections.Counter()
for f,th,tl,n,i,e in rows:
    s=json.dumps(i)
    m=re.findall(r'story-(\d)-(\d)|s323-(\d)-(\d)|\b(\d)\.(\d)\b',s)
    ids={a+'.'+b for a,b,c_,d,e_,f_ in m for a,b in [((a or c_ or e_),(b or d or f_))] if a}
    st[len(ids)]+=1
print('lead calls by #distinct story ids mentioned',sorted(st.items()))
