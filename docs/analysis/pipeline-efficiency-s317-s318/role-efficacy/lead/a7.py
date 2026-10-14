import re, glob, collections, json, os, bisect
G='/Users/n8/git/graph/_bmad-output/'
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
# timeline of (ts, sess, model, step)
segs=collections.defaultdict(list); spr={}
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    if r.get('kind')!='lead': continue
    segs[r['sess']].append((r['first'],r['last'],r['step'])); spr[r['sess']]=r['sprint']
tl=[]
for s in segs:
    for l in open(P+s+'.jsonl'):
        r=json.loads(l)
        if r.get('type')=='assistant' and not r.get('isSidechain'):
            m=r['message'].get('model','')
            if m=='<synthetic>': continue
            st='?'
            for a,b,x in segs[s]:
                if a<=r['timestamp']<=b: st=x
            tl.append((r['timestamp'][:19],s[:8],m.replace('claude-','').replace('-5-5','').replace('-mlx',''),st))
tl.sort(); keys=[t[0] for t in tl]
def at(ts):
    i=bisect.bisect_right(keys,ts)-1
    return tl[i] if i>=0 else None
files=[G+'pipeline-continuation-log.md']+glob.glob(G+'implementation-artifacts/s317/pipeline-continuation-log-archive*.md')
toks=['HANDOFF_GUARD_BLOCK','BLOCKED','BACKOFF','ESCALATION_UNDELIVERED','ACK_DENIED','PAUSE_QUESTION_IN_PROSE']
agg=collections.Counter(); bodies=collections.defaultdict(list)
for f in files:
    txt=open(f,errors='replace').read()
    parts=re.split(r'\n(?=## 20\d\d-)',txt)
    for p in parts:
        m=re.match(r'## (20\d\d-\d\d-\d\dT\d\d:\d\d:\d\d)Z -- (\S+)',p)
        if not m: continue
        ts,ev=m.group(1),m.group(2)
        if ev not in toks or not ('2026-10-05T14'<=ts<='2026-10-14T15'): continue
        a=at(ts)
        model=a[2] if a and a[0]>=ts[:13] else 'none'
        # gap between event and nearest lead msg
        sp='318' if ts>='2026-10-12T03' else '317'
        agg[(ev,sp,model)]+=1
        if len(bodies[ev])<3: bodies[ev].append((ts,a,p[:500].replace('\n',' | ')))
for k in sorted(agg): print(k,agg[k])
for ev,v in bodies.items():
    print('=====',ev)
    for b in v: print('  ',b[0],b[1]); print('     ',b[2])
