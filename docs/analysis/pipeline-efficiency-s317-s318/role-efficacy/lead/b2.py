import json, os, glob, collections, re
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
segs=collections.defaultdict(list)
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    if r.get('kind')=='lead': segs[r['sess']].append((r['first'],r['last'],r['step']))
def stepat(s,ts):
    for a,b,st in segs[s]:
        if a<=ts<=b: return st
    return '?'
rows=[]  # per assistant msg: ts, sess, model, req, effort, step, is_preStep
for s in segs:
    for l in open(P+s+'.jsonl'):
        r=json.loads(l)
        if r.get('type')!='assistant' or r.get('isSidechain'): continue
        m=r['message'].get('model','')
        if m=='<synthetic>': continue
        rows.append((r['timestamp'][:19],s[:8],m,r.get('requestedModel'),r.get('effort'),stepat(s,r['timestamp'])))
rows.sort()
# change points in (requestedModel,effort) for pipeline steps vs pre-step separately
for cls in ['pipeline','pre-step']:
    prev=None; n=0; print('=== changepoints',cls)
    for ts,s,m,req,eff,st in rows:
        if (st=='pre-step')!=(cls=='pre-step'): continue
        key=(m.replace('claude-',''),req,eff)
        if key!=prev:
            print('  %s %s %-24s req=%s eff=%s step=%s (prev run n=%d)'%(ts,s,key[0],req,eff,st,n)); prev=key; n=0
        n+=1
    print('  final run n=%d'%n)
