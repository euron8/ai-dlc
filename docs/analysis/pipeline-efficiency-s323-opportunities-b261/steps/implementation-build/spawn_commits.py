#!/usr/bin/env python3
"""Per dev/dev-escalated spawn: commits (non-merge, story branch, base..tip) whose committer time lies in [spawn start, spawn end+120 s];
added lines by class (code/tests vs records) -> 'record-only' (no code/tests lines) vs 'code-bearing' spawn. READ-ONLY git. Stories 2.x, 3.x excluded when no base known (listed)."""
import subprocess,re,csv,collections
from datetime import datetime,timezone
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/implementation-build/'
exec(open(D+'story_diffs2.py').read().split("sp = collections")[0].split("def git")[0].replace("import subprocess, re, collections, csv",""))
BASE={'1-1':'ae63caf38','3-1':'ae63caf38','4-1':'ae63caf38','4-2':'ae63caf38','4-3':'ae63caf38','4-4':'ae63caf38','5-1':'ae63caf38','5-3':'ae63caf38','5-4':'ae63caf38','5-5':'e70a344c0','3-2':'5fe4b5ce7','1-2':'2fe36573c','1-3':'2fe36573c','1-4':'2fe36573c','5-2':'2fe36573c'}
def pcls(p):
    if re.search(r'(^|/)(tests?|__tests__|e2e)/|(^|/)test_[^/]*$|\.(test|spec)\.[jt]sx?$|conftest\.py$',p): return 'tests'
    if re.search(r'^_bmad-output/|^docs/|test-results/|\.(txt|log|out)$|sprint-status|carry-over',p): return 'rec'
    return 'code'
def T(s): return datetime.strptime(s[:19],'%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc).timestamp()
cache={}
def commits(st):
    if st in cache: return cache[st]
    out=subprocess.run(['git','-C','/Users/n8/git/graph','log','--no-merges','--format=@@%ct','--numstat',BASE[st]+'..dev/sprint-323/story-'+st],capture_output=True,text=True).stdout
    cs=[];cur=None
    for l in out.splitlines():
        if l.startswith('@@'): cur=[int(l[2:]),collections.Counter()]; cs.append(cur)
        elif l.strip():
            a,d,p=l.split('\t',2); cur[1][pcls(p)]+=0 if a=='-' else int(a)
    cache[st]=cs; return cs
rows=[]
for i,r in enumerate(csv.reader(open(D+'story_spawns.tsv'),delimiter='\t')):
    if i==0 or r[2] not in('dev','dev-escalated'): continue
    st=r[3].replace('.','-')
    if st not in BASE: rows.append((r[3],r[2],r[9],float(r[4]),float(r[6]),None,None)); continue
    a,b=T(r[0]),T(r[1])+120
    c=collections.Counter()
    n=0
    for ct,k in commits(st):
        if a<=ct<=b: c+=k; n+=1
    rows.append((r[3],r[2],r[9],float(r[4]),float(r[6]),n,dict(c)))
tot=collections.defaultdict(lambda:[0,0.0,0.0])
for st,role,desc,m,usd,n,c in rows:
    kind='unknown' if c is None else ('no-commit' if n==0 else ('code-bearing' if (c.get('code',0)+c.get('tests',0))>0 else 'record-only'))
    first=not re.search(r'rework|fix|re-?dispatch|verif|record',desc,re.I)
    key=('first' if first else 'rework/fix',kind); tot[key][0]+=1; tot[key][1]+=m; tot[key][2]+=usd
    print(st.ljust(4),role[:8].ljust(9),desc[:38].ljust(38),str(m).rjust(6),'$%5.1f'%usd,'commits',n,c)
print()
for k,v in sorted(tot.items()): print(k,'spawns',v[0],'wall min',round(v[1]),'usd',round(v[2],1))
