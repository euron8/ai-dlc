
import json,collections,re,sys
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
sp=[json.loads(l) for l in open(D+'spawns.jsonl')]
seatre=re.compile(r'^(pm|architect|dev|tea|qa)[ -](\d+|cross)( seat)?$')
def phase(s,partystart):
    d=s['description'];r=s['role']
    if s['sprint']==323 and re.search(r'story 2\.[123]|2\.[123] gate|2\.3',d) and 'merge' not in d.lower(): return 'story2x-build-in-step'
    if r=='adversary': return 'adversary-pass'
    if seatre.match(d) or re.match(r'^(pm|architect|dev|tea|qa)[ -](\d+|cross) seat',d):
        return 'party-seat-cross' if 'cross' in d else 'party-seat-story'
    if r=='general-purpose' or 'ispatch' in d: return 'party-dispatcher'
    if r=='analyst' or 'riage' in d: return 'party-triage'
    if r=='gate-adjudicator' or 'Gate' in d and 'remediator' in d.lower() or s['step'].startswith('gate'): return 'gate'
    if s['start']<partystart: return 'pre-party-fix/merge/review'
    return 'post-party-fix/review/qa'
res={}
for sprint in (321,322,323):
    S=[s for s in sp if s['sprint']==sprint and 'sprint-review' in s['step']]
    ps=min(s['start'] for s in S if re.match(r'^(pm|architect|tea) ',s['description']) or 'party' in s['description'].lower())
    c=collections.defaultdict(lambda:[0,0.0,0.0])
    for s in S:
        p=phase(s,ps);c[p][0]+=1;c[p][1]+=s['usd'];c[p][2]+=s['minutes']
    print('== s%d'%sprint,'party start',ps[5:16])
    for k,v in sorted(c.items()):print('  %-28s n=%3d  $%7.2f  agent-min %6.1f'%(k,v[0],v[1],v[2]))
    print('  TOTAL n=%d $%.2f min %.1f'%(len(S),sum(v[1] for v in c.values()),sum(v[2] for v in c.values())))
