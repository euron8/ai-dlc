import json, os, glob, collections, re, datetime
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
# lead sessions and step map from segs
segs=collections.defaultdict(list); spr={}
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    if r.get('kind')!='lead': continue
    segs[r['sess']].append((r['first'],r['last'],r['step'])); spr[r['sess']]=r['sprint']
def stepat(s,ts):
    for a,b,st in segs[s]:
        if a<=ts<=b: return st
    return '?'
def ts2(t): return datetime.datetime.fromisoformat(t.replace('Z','+00:00'))
cats=[('cap','concurren|at most \\d+ (agents|subagents)|too many (agents|subagents)|limit of \\d+'),
('handoff_guard','HANDOFF_GUARD'),('ack_denied','ACK_DENIED'),('backoff','BACKOFF'),
('nonce','nonce'),('waiver','waiver'),('blocked','BLOCKED'),('denied','[Dd]enied|deny'),('hook','hook')]
calls=collections.Counter(); hours=collections.Counter(); err=collections.Counter(); errcat=collections.Counter()
examples=collections.defaultdict(list); effort=collections.Counter(); agentdesc=collections.defaultdict(list)
for s in segs:
    fs=glob.glob(P+s+'.jsonl')
    if not fs: print('MISSING',s); continue
    model=None; last=None; idmodel={}
    for l in open(fs[0]):
        r=json.loads(l)
        if r.get('isSidechain'): continue
        t=r.get('type'); ts=r.get('timestamp')
        if t=='assistant':
            m=r['message'].get('model','?');
            if m=='<synthetic>': continue
            model=m.replace('claude-','').replace('-5-5','').replace('-mlx','')
            st=stepat(s,ts); key=(spr[s],st,model)
            calls[(spr[s],model)]+=1
            effort[(model,r.get('effort'))]+=1
            for c in r['message'].get('content',[]):
                if c.get('type')=='tool_use':
                    idmodel[c['id']]=(model,st,ts)
                    if c['name'] in ('Agent','Task'):
                        agentdesc[s].append((ts,model,st,c['input'].get('description',''),c['input'].get('subagent_type',''),c['id']))
            if last:
                dt=(ts2(ts)-ts2(last)).total_seconds()
                if dt<600: hours[(spr[s],model)]+=dt/3600
            last=ts
        elif t=='user':
            cs=r['message'].get('content')
            if not isinstance(cs,list): continue
            for c in cs:
                if c.get('type')!='tool_result': continue
                mm=idmodel.get(c.get('tool_use_id'))
                if not mm: continue
                txt=c.get('content'); txt=txt if isinstance(txt,str) else json.dumps(txt)
                if c.get('is_error'):
                    err[(spr[s],mm[0])]+=1
                    cat='other'
                    for n,rx in cats:
                        if re.search(rx,txt[:3000]): cat=n;break
                    errcat[(spr[s],mm[0],cat)]+=1
                    if len(examples[(mm[0],cat)])<4: examples[(mm[0],cat)].append((s[:8],mm[1],mm[2][:16],txt[:220].replace('\n',' ')))
print('calls/hours/errors per (sprint,model)')
for k in sorted(calls): print(k,calls[k],round(hours[k],1),err[k], round(100*err[k]/calls[k],1))
print('effort',effort)
for k in sorted(errcat): print(k,errcat[k])
for k,v in examples.items():
    print('==',k)
    for e in v: print('   ',e)
json.dump({s:v for s,v in agentdesc.items()},open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/lead/agentdesc.json','w'))
