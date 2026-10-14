import json, os, glob, collections, re, bisect, datetime
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
G='/Users/n8/git/graph/_bmad-output/'
# arm-log
print('== arm-log lead_model rows in window')
c=collections.Counter(); keys=collections.Counter()
for l in open(G+'arm-log.jsonl'):
    try: r=json.loads(l)
    except: continue
    for k in r: keys[k]+=1
    ts=str(r.get('ts') or r.get('timestamp') or '')
    if '2026-10-04'<=ts[:10]<='2026-10-14' and 'lead_model' in r:
        c[(ts[:10],r.get('sprint'),r.get('lead_model'),r.get('lead_effort'))]+=1
print([k for k in keys if 'lead' in k or 'model' in k][:20])
for k in sorted(c): print('  ',k,c[k])
# discarded nonces -> lead model at that moment
segs=collections.defaultdict(list)
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    if r.get('kind')=='lead': segs[r['sess']].append((r['first'],r['last'],r['step']))
tl=[]
for s in segs:
    for l in open(P+s+'.jsonl'):
        r=json.loads(l)
        if r.get('type')=='assistant' and not r.get('isSidechain') and r['message'].get('model')!='<synthetic>':
            tl.append((r['timestamp'][:19],s[:8],r['message'].get('model'),r.get('effort')))
tl.sort(); ks=[t[0] for t in tl]
for lab,t in [('s317 impl 124524Z','2026-10-09T12:45:24'),('s317 impl 192841Z','2026-10-09T19:28:41'),('s317 impl 230257Z','2026-10-10T23:02:57'),('s317 impl 083048Z','2026-10-11T08:30:48'),('s318 plan 232108Z','2026-10-12T23:21:08'),('s318 story 212500Z','2026-10-13T21:25:00'),('s318 impl 010837Z','2026-10-14T01:08:37'),('s318 impl 011534Z','2026-10-14T01:15:34'),('s318 SR 105054Z','2026-10-14T10:50:54'),('lead-ff1-inline?','2026-10-11T19:00:00')]:
    i=bisect.bisect_right(ks,t)-1; print('NONCE',lab,tl[i])
