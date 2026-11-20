#!/usr/bin/env python3
"""Per-story timeline (UTC) for s323 build window. Sources: lead_calls.jsonl (Agent dispatches by description), dev spawn
transcripts (first SendMessage to main = report delivered), graph merge commits (git log first-parent, READ-ONLY).
Columns: disp = first dev dispatch; devdone = first dev SendMessage(to main) at/after disp; g1 = first code-reviewer dispatch
mentioning the story; qa = first qa dispatch; merge = 'Merge story X' commit time. All minutes from disp.
"""
import json,re,glob,subprocess,collections,csv
from datetime import datetime,timezone,timedelta
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/implementation-build/'
def T(s): return datetime.strptime(s[:19],'%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
rows=[json.loads(l) for l in open(D+'lead_calls.jsonl')]
st=collections.defaultdict(dict)
for r in rows:
    if r.get('name')!='Agent' or r.get('err'): continue
    m=re.search(r'(?<![\d.])(\d)[.-](\d)(?![\d.])',re.sub(r'\b323-','',r.get('desc') or ''))
    if not m: continue
    s=m.group(1)+'.'+m.group(2); sub=r['subtype']; t=T(r['ts'])
    k={'dev':'disp','dev-escalated':'disp','code-reviewer':'g1','code-reviewer-escalated':'g1','qa':'qa'}.get(sub)
    if k and k not in st[s]: st[s][k]=t
# dev report delivered: first SendMessage in the dev spawns
units=[]
for i,l in enumerate(open(D+'story_spawns.tsv')):
    f=l.rstrip('\n').split('\t')
    if i and f[2] in('dev','dev-escalated'): units.append((f[0],f[3],f[9]))
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/spawns.jsonl'
byk={}
for l in open(M):
    r=json.loads(l); byk[(r['start'],r['description'])]=r['unit']
for start,s,desc in units:
    u=byk.get((start,desc)); fs=glob.glob('/Users/n8/.claude/projects/-Users-n8-git-graph/*/subagents/'+str(u)+'.jsonl')
    if not fs: continue
    for l in open(fs[0]):
        if '"SendMessage"' in l:
            r=json.loads(l)
            for b in r['message'].get('content',[]) if r.get('type')=='assistant' else []:
                if b.get('type')=='tool_use' and b['name']=='SendMessage' and (b['input'].get('to')=='main'):
                    t=T(r['timestamp'])
                    if 'devdone' not in st[s] and t>=T(start) : st[s]['devdone']=t
                    break
            if 'devdone' in st[s]: break
out=subprocess.run(['git','-C','/Users/n8/git/graph','log','ai-dlc/carry-over/s323-per-chain-consolidation','--first-parent','--since=2026-11-18T12:00:00Z','--format=%aI %s'],capture_output=True,text=True).stdout
for l in out.splitlines():
    m=re.search(r'Merge story[- ](\d)[.-](\d)',l)
    if m:
        t=datetime.fromisoformat(l.split()[0]).astimezone(timezone.utc); st[m.group(1)+'.'+m.group(2)]['merge']=t
BASEMAP={'1.1':'ae63caf38','3.1':'ae63caf38','4.1':'ae63caf38','4.2':'ae63caf38','4.3':'ae63caf38','4.4':'ae63caf38','5.1':'ae63caf38','5.3':'ae63caf38','5.4':'ae63caf38','5.5':'e70a344c0','3.2':'5fe4b5ce7','1.2':'2fe36573c','1.3':'2fe36573c','1.4':'2fe36573c','5.2':'2fe36573c'}
for s_,b in BASEMAP.items():
    lg=subprocess.run(['git','-C','/Users/n8/git/graph','log','--no-merges','--format=%ct','%s..dev/sprint-323/story-%s'%(b,s_.replace('.','-'))],capture_output=True,text=True).stdout.split()
    ts=sorted(datetime.fromtimestamp(int(x),timezone.utc) for x in lg)
    g1=st[s_].get('g1'); d=st[s_].get('disp')
    st[s_]['firstcommit']=next((t for t in ts if d and t>=d),None)
    st[s_]['lastdev']=max([t for t in ts if g1 and d and d<=t<=g1],default=None)
    st[s_]['ncommit_pre_g1']=len([t for t in ts if g1 and d and d<=t<=g1])
def mins(a,b): return '' if (a is None or b is None) else str(round((b-a).total_seconds()/60))
print('story disp(UTC)  to_firstcommit  disp->lastdevcommit(pre-g1)  lastdev->g1(lead handoff)  g1->qa  qa->merge  disp->merge  ncommits')
for s in sorted(st):
    x=st[s]; d=x.get('disp')
    print(s.ljust(5),(d.strftime('%d %H:%M') if d else '-').ljust(12),mins(d,x.get('firstcommit')).rjust(5),mins(d,x.get('lastdev')).rjust(10),mins(x.get('lastdev'),x.get('g1')).rjust(14),mins(x.get('g1'),x.get('qa')).rjust(10),mins(x.get('qa'),x.get('merge')).rjust(9),mins(d,x.get('merge')).rjust(9),str(x.get('ncommit_pre_g1','')).rjust(6))
