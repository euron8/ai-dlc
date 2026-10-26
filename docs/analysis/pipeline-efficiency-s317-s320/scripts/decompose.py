import json,glob,os,collections,sys
S=sys.argv[1]
STORIES={317:21,318:13,319:20,320:13}
sp=[json.loads(l) for l in open(S+"/spawns.jsonl")]
# first-call context per subagent
ROOT=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
first={}
for p in glob.glob(ROOT+"/*/subagents/*.jsonl"):
    u=os.path.basename(p)[:-6]
    try:
        for line in open(p,errors="replace"):
            r=json.loads(line)
            if r.get("type")=="assistant" and r.get("message",{}).get("usage"):
                us=r["message"]["usage"]; first[u]=us.get("cache_creation_input_tokens",0)+us.get("cache_read_input_tokens",0)+us.get("input_tokens",0); break
    except Exception: pass
def ph(st):
    st=st[16:-1] if st.startswith('gate-validation[') else st
    if st in('carry-over-evaluation','requirements','architecture','stories-test-strategy'): return 'planning'
    if st in('implementation',): return 'impl'
    if st in('sprint-review','deploy-validate','retro'): return 'close'
    return 'other'
A=collections.defaultdict(lambda: collections.defaultdict(float))
for s in sp:
    n=s['sprint']
    if n not in STORIES: continue
    for k in (ph(s['step']),'ALL'):
        a=A[(n,k)]; a['n']+=1; a['usd']+=s['usd']; a['min']+=s['minutes']; a['calls']+=s['calls']; a['tok']+=s['tok']
        if s['unit'] in first: a['ctx']+=first[s['unit']]; a['nctx']+=1
print("subagents: spawns/story | $/spawn | calls/spawn | agent-min/spawn | first-call context tokens | $/story")
for k in ('planning','impl','close','ALL'):
    print(k)
    for n in (317,318,319,320):
        a=A[(n,k)]
        if not a['n']: continue
        print(f"  s{n}: {a['n']/STORIES[n]:5.1f} | ${a['usd']/a['n']:.2f} | {a['calls']/a['n']:5.1f} | {a['min']/a['n']:5.1f} | {a['ctx']/max(1,a['nctx']):7.0f} | ${a['usd']/STORIES[n]:6.1f}")
