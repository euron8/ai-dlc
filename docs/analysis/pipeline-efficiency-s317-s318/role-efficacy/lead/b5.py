import json, os, glob, collections, re, datetime
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
sp=[json.loads(l) for l in open(D+'spawns.jsonl')]
an=[s for s in sp if s['role']=='analyst']
full={os.path.basename(f)[:8]:os.path.basename(f)[:-6] for f in glob.glob(P+'*.jsonl')}
PR=re.compile(r'(?:_bmad-output|docs|src|tests|scripts|infra|lambdas?)/[A-Za-z0-9_./-]+\.(?:md|ya?ml|json|jsonl|py|ts|sh|txt)')
def paths(path, after=None, before=None):
    out=set()
    for l in open(path):
        r=json.loads(l)
        if r.get('type')!='assistant' or r.get('isSidechain') and 'subagents' not in path: continue
        ts=r['timestamp']
        if after and ts<after: continue
        if before and ts>before: continue
        for c in r['message'].get('content',[]):
            if c.get('type')!='tool_use': continue
            s=json.dumps(c['input'])
            for m in PR.findall(s.replace('/Users/n8/git/graph/','')): out.add(m)
    return out
mach=lambda p: 'pipeline-snapshot' in p or p.startswith('scripts/ai-dlc') or 'continuation-log' in p or 'gate-log' in p or 'spawn-ledger' in p
A=L=O=C=0
for s in an:
    sess=full.get(s['sess'][:8]); sub=glob.glob(P+sess+'/subagents/'+s['unit']+'.jsonl') if sess else []
    if not sub: continue
    ap={p for p in paths(sub[0]) if not mach(p)}
    e=datetime.datetime.fromisoformat(s['end'].replace('Z','+00:00'))
    st=datetime.datetime.fromisoformat(s['start'].replace('Z','+00:00'))
    lim=(e+datetime.timedelta(hours=3)).isoformat().replace('+00:00','Z')
    lp={p for p in paths(P+sess+'.jsonl', s['end'], lim) if not mach(p)}
    # control: lead's paths in the 3h BEFORE the analyst started vs after (lead re-touching its own files)
    pre=(st-datetime.timedelta(hours=3)).isoformat().replace('+00:00','Z')
    lpre={p for p in paths(P+sess+'.jsonl', pre, s['start']) if not mach(p)}
    ov=ap&lp; ctl=lpre&lp
    A+=len(ap); L+=len(lp); O+=len(ov); C+=len(ctl)
    print(s['sess'][:8],s['sprint'],s['step'][:22],s['description'][:38],'analyst',len(ap),'lead_after',len(lp),'overlap',len(ov),'ctl(lead before&after)',len(ctl),sorted(ov)[:4])
print('TOTAL analyst',A,'lead_after',L,'overlap',O,'control',C)
