import json, os, glob, collections, re, datetime, bisect
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
G='/Users/n8/git/graph/_bmad-output/'
def T(s): return datetime.datetime.fromisoformat(s[:19]+'+00:00')
# (3) version around req boundary
for s in ['562ac82a','913d04cc','7af3bf9c','79ff7d55']:
    f=glob.glob(P+s+'*.jsonl')[0]; vs=collections.Counter()
    for l in open(f):
        r=json.loads(l)
        if r.get('type')=='assistant' and not r.get('isSidechain'): vs[(r.get('version'),bool(r.get('requestedModel')))]+=1
    print('VER',s,dict(vs))
# (1) split discarded nonce adjudicators: abandoned = start between nonce and superseding nonce
pairs=[('124524Z waiver no-exception','2026-10-09T12:45:24','2026-10-09T12:53:58','lead'),
('192841Z check1 form','2026-10-09T19:28:41','2026-10-09T19:43:24','inferred'),
('230257Z lead waiver paperwork','2026-10-10T23:02:57',None,'lead'),
('083048Z stray hyphen','2026-10-11T08:30:48','2026-10-11T08:30:54','lead'),
('232108Z window lapsed','2026-10-12T23:21:08','2026-10-12T23:22:33','lead'),
('212500Z AC drift','2026-10-13T21:25:00','2026-10-13T21:35:03','inferred'),
('010837Z stale story copies','2026-10-14T01:08:37','2026-10-14T01:15:34','lead'),
('011534Z check22 waiver','2026-10-14T01:15:34','2026-10-14T01:26:08','lead'),
('105054Z coverage brief','2026-10-14T10:50:54','2026-10-14T14:28:05','lead')]
sp=[json.loads(l) for l in open(D+'spawns.jsonl')]
ga=[s for s in sp if s['role']=='gate-adjudicator']
tot=collections.Counter()
for lab,a,b,cls in pairs:
    if b is None:
        # 230257Z: first three shards after nonce, before re-dispatch at 23:26 per dup output
        b='2026-10-10T23:20:00'
    hits=[s for s in ga if T(a)<=T(s['start'])<T(b)]
    u=sum(float(s['usd'] or 0) for s in hits); m=sum(float(s['minutes'] or 0) for s in hits)
    tot[(cls,'n')]+=len(hits); tot[(cls,'usd')]+=u; tot[(cls,'min')]+=m
    print('NONCE',lab,cls,len(hits),round(u,2),round(m,1))
print({k:round(v,2) for k,v in tot.items()})
# (5) sonnet test edits disclosure
gl=open(G+'implementation-artifacts/gate-log.md',errors='replace').read()
print('test_s259_1 mentions in s318 gate-log',gl.count('test_s259_1'),'control "nonce"',gl.count('nonce'))
for m in re.finditer(r'[^\n]{0,200}test_s259_1[^\n]{0,200}',gl): print('  S259',m.group(0)[:400]); break
# overturn grep with control
for f in [G+'implementation-artifacts/gate-log.md',G+'implementation-artifacts/s317/gate-log-archive.md']:
    t=open(f,errors='replace').read()
    print('OVERTURN',f.split('/')[-1],len(re.findall(r'overturn',t,re.I)),'control PASSED',t.count('PASSED'))
    for m in re.finditer(r'[^\n]{0,160}overturn[^\n]{0,200}',t,re.I): print('   ',m.group(0)[:360])
# (2)/(7) regime recompute clipped to >=10-05T14:00, with sonnet/1m split at 10-12T06:03
segs=collections.defaultdict(list)
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    if r.get('kind')=='lead': segs[r['sess']].append((r['first'],r['last'],r['step']))
lm={}
for row in open(D+'leadmodel.csv').read().split('\n')[1:]:
    pass
def reg(m,eff,req,st,ts):
    m=m.replace('claude-','').replace('-5-5','').replace('-mlx','')
    if st=='pre-step': return 'pre-step/'+m
    if m=='sonnet': return 'sonnet/med/'+('plain<10-09' if not req else ('1m<10-12T06' if ts<'2026-10-12T06:03' else '1m>=10-12T06'))
    if m=='qwen38flash': return 'qwen/'+eff
    return m+'/'+eff
tl=[]; calls=collections.Counter(); hrs=collections.Counter(); errs=collections.Counter(); cap=collections.Counter(); steps=collections.defaultdict(collections.Counter)
for s in segs:
    last=None; idr={}
    for l in open(P+s+'.jsonl'):
        r=json.loads(l)
        if r.get('isSidechain') or r.get('timestamp','')<'2026-10-05T14:00': continue
        if r.get('type')=='assistant':
            m=r['message'].get('model','')
            if m=='<synthetic>': continue
            st='?'
            for a,b,x in segs[s]:
                if a<=r['timestamp']<=b: st=x
            g=reg(m,r.get('effort'),r.get('requestedModel'),st,r['timestamp'])
            tl.append((r['timestamp'][:19],g)); calls[g]+=1; steps[g][st.split('[')[0]]+=1
            if last and (T(r['timestamp'])-T(last)).total_seconds()<600: hrs[g]+=(T(r['timestamp'])-T(last)).total_seconds()/3600
            last=r['timestamp']
            for c in r['message'].get('content',[]):
                if c.get('type')=='tool_use': idr[c['id']]=g
        elif r.get('type')=='user' and isinstance(r['message'].get('content'),list):
            for c in r['message']['content']:
                if c.get('type')=='tool_result' and c.get('is_error') and c.get('tool_use_id') in idr:
                    t=c.get('content'); t=t if isinstance(t,str) else json.dumps(t)
                    errs[idr[c['tool_use_id']]]+=1
                    if 'Concurrent subagent limit' in t: cap[idr[c['tool_use_id']]]+=1
tl.sort(); ks=[t[0] for t in tl]
def at(ts):
    i=bisect.bisect_right(ks,ts)-1; return tl[i][1] if i>=0 else 'none'
ev=collections.Counter()
for f in [G+'pipeline-continuation-log.md']+glob.glob(G+'implementation-artifacts/s317/pipeline-continuation-log-archive*.md'):
    for m in re.finditer(r'\n## (2026-10-\d\dT\d\d:\d\d:\d\d)Z -- (HANDOFF_GUARD_BLOCK|BLOCKED|BACKOFF|ACK_DENIED|PAUSE_QUESTION_IN_PROSE|ESCALATION_UNDELIVERED)',open(f,errors='replace').read()):
        if '2026-10-05T14'<=m.group(1)<='2026-10-14T15': ev[(at(m.group(1)),m.group(2))]+=1
nd=collections.Counter(at(a) for lab,a,b,cls in pairs if cls=='lead')
print('regime|calls|act_h|err/100|cap|HGB|BLK|ACK|BACKOFF|PQIP|nonce_lead|costbearing/h|top steps')
for g in sorted(calls):
    cb=ev[(g,'HANDOFF_GUARD_BLOCK')]+ev[(g,'ACK_DENIED')]+cap[g]
    print(g,calls[g],round(hrs[g],1),round(100*errs[g]/calls[g],2),cap[g],ev[(g,'HANDOFF_GUARD_BLOCK')],ev[(g,'BLOCKED')],ev[(g,'ACK_DENIED')],ev[(g,'BACKOFF')],ev[(g,'PAUSE_QUESTION_IN_PROSE')],nd[g],round(cb/hrs[g],2) if hrs[g]>0.5 else '-',steps[g].most_common(4),sep=' | ')
print('CONTROL events',sum(ev.values()))
