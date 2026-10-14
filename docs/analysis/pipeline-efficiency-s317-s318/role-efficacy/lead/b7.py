import json, os, glob, collections, re, bisect, datetime
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
G='/Users/n8/git/graph/_bmad-output/'
segs=collections.defaultdict(list)
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    if r.get('kind')=='lead': segs[r['sess']].append((r['first'],r['last'],r['step']))
def T(s): return datetime.datetime.fromisoformat(s[:19]+'+00:00')
def regime(m,eff,req,st):
    m=m.replace('claude-','').replace('-5-5','').replace('-mlx','')
    if st=='pre-step': return 'pre-step/'+m
    return '%s/%s%s'%(m,eff,'' if m=='qwen38flash' else ('/1m' if req else '/plain'))
tl=[]; calls=collections.Counter(); hrs=collections.Counter(); errs=collections.Counter(); cap=collections.Counter(); grep_rev=[]
for s in segs:
    last=None; idr={}
    for l in open(P+s+'.jsonl'):
        r=json.loads(l)
        if r.get('isSidechain'): continue
        if r.get('type')=='assistant':
            m=r['message'].get('model','')
            if m=='<synthetic>': continue
            st='?'
            for a,b,x in segs[s]:
                if a<=r['timestamp']<=b: st=x
            g=regime(m,r.get('effort'),r.get('requestedModel'),st)
            tl.append((r['timestamp'][:19],g)); calls[g]+=1
            if last and (T(r['timestamp'])-T(last)).total_seconds()<600: hrs[g]+=(T(r['timestamp'])-T(last)).total_seconds()/3600
            last=r['timestamp']
            for c in r['message'].get('content',[]):
                if c.get('type')=='tool_use':
                    idr[c['id']]=g
                    if c['name']=='Bash' and re.search(r'gh pr (create|merge)|git revert',c['input'].get('command','')) and '2026-10-06T23'<=r['timestamp']<='2026-10-07T06':
                        grep_rev.append((r['timestamp'][:16],s[:8],m,c['input']['command'][:120].replace('\n',' ')))
        elif r.get('type')=='user' and isinstance(r['message'].get('content'),list):
            for c in r['message']['content']:
                if c.get('type')=='tool_result' and c.get('is_error') and c.get('tool_use_id') in idr:
                    t=c.get('content'); t=t if isinstance(t,str) else json.dumps(t)
                    g=idr[c['tool_use_id']]; errs[g]+=1
                    if 'Concurrent subagent limit' in t: cap[g]+=1
tl.sort(); ks=[t[0] for t in tl]
def at(ts):
    i=bisect.bisect_right(ks,ts)-1; return tl[i][1] if i>=0 else 'none'
ev=collections.Counter()
files=[G+'pipeline-continuation-log.md']+glob.glob(G+'implementation-artifacts/s317/pipeline-continuation-log-archive*.md')
for f in files:
    for m in re.finditer(r'\n## (2026-10-\d\dT\d\d:\d\d:\d\d)Z -- (HANDOFF_GUARD_BLOCK|BLOCKED|BACKOFF|ACK_DENIED|PAUSE_QUESTION_IN_PROSE|ESCALATION_UNDELIVERED)',open(f,errors='replace').read()):
        if '2026-10-05T14'<=m.group(1)<='2026-10-14T15': ev[(at(m.group(1)),m.group(2))]+=1
nonces=['2026-10-09T12:45:24','2026-10-09T19:28:41','2026-10-10T23:02:57','2026-10-11T08:30:48','2026-10-12T23:21:08','2026-10-13T21:25:00','2026-10-14T01:08:37','2026-10-14T01:15:34','2026-10-14T10:50:54']
nd=collections.Counter(at(n) for n in nonces)
regs=sorted(calls)
print('regime | calls | active_h | tool_err/100 | cap_rej | HGB | BLOCKED | ACK_DENIED | BACKOFF | PQIP | ESC_UNDEL | nonces_discarded | guard/h')
for g in regs:
    gb=sum(ev[(g,k)] for k in ['HANDOFF_GUARD_BLOCK','BLOCKED','ACK_DENIED','BACKOFF'])
    print(g,'|',calls[g],'|',round(hrs[g],1),'|',round(100*errs[g]/calls[g],2),'|',cap[g],'|',ev[(g,'HANDOFF_GUARD_BLOCK')],'|',ev[(g,'BLOCKED')],'|',ev[(g,'ACK_DENIED')],'|',ev[(g,'BACKOFF')],'|',ev[(g,'PAUSE_QUESTION_IN_PROSE')],'|',ev[(g,'ESCALATION_UNDELIVERED')],'|',nd[g],'|',round(gb/hrs[g],2) if hrs[g] else '-')
print('unattributed events',{k:v for k,v in ev.items() if k[0] not in calls})
print('CONTROL event total',sum(ev.values()))
for x in grep_rev: print('REV',x)
# distinct adjudicator spend in discarded windows
sp=[json.loads(l) for l in open(D+'spawns.jsonl')]
ga=[s for s in sp if s['role']=='gate-adjudicator']
seen={}
for n in nonces:
    for s in ga:
        dt=(T(s['start'])-T(n)).total_seconds()
        if 0<=dt<1200: seen[s['unit']]=s
print('adjudicator spawns in discarded-nonce windows (distinct)',len(seen),'usd',round(sum(float(s['usd'] or 0) for s in seen.values()),2),'agent-min',round(sum(float(s['minutes'] or 0) for s in seen.values()),1),'of total adjudicator usd',round(sum(float(s['usd'] or 0) for s in ga),2))
