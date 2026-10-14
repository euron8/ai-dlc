import json, os, glob, collections, re
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
sp=[json.loads(l) for l in open(D+'spawns.jsonl')]
an=[s for s in sp if s['role']=='analyst']
fullsess={os.path.basename(f)[:8]:os.path.basename(f)[:-6] for f in glob.glob(P+'*.jsonl')}
def reads(path, after=None, before=None):
    out=set()
    for l in open(path):
        r=json.loads(l)
        if r.get('type')!='assistant': continue
        ts=r['timestamp']
        if after and ts<after: continue
        if before and ts>before: continue
        for c in r['message'].get('content',[]):
            if c.get('type')=='tool_use' and c['name']=='Read':
                p=c['input'].get('file_path','')
                out.add(p.replace('/Users/n8/git/graph/',''))
    return out
tot_a=tot_ov=tot_l=0; rows=[]
for s in an:
    sess=fullsess.get(s['sess'][:8])
    sub=glob.glob(P+sess+'/subagents/'+s['unit']+'.jsonl') if sess else []
    if not sub: rows.append((s['sess'][:8],s['step'],s['description'][:40],'NO TRANSCRIPT')); continue
    ar=reads(sub[0])
    # lead reads after analyst end within 3h, same session
    lr=reads(P+sess+'.jsonl', after=s['end'], before=None)
    # restrict to next 3 hours
    import datetime
    e=datetime.datetime.fromisoformat(s['end'].replace('Z','+00:00'))
    lim=(e+datetime.timedelta(hours=3)).isoformat().replace('+00:00','Z')
    lr=reads(P+sess+'.jsonl', after=s['end'], before=lim)
    # exclude ai-dlc machinery files (step files, snapshot) from overlap
    mach=lambda p: p.startswith('.claude/') or 'pipeline-snapshot' in p
    ov={p for p in ar&lr if not mach(p)}
    arn={p for p in ar if not mach(p)}
    tot_a+=len(arn); tot_ov+=len(ov); tot_l+=len({p for p in lr if not mach(p)})
    rows.append((s['sess'][:8],s['sprint'],s['step'],s['description'][:45],len(arn),len({p for p in lr if not mach(p)}),len(ov),sorted(ov)[:3]))
for r in rows: print(r)
print('TOTAL analyst non-machinery reads',tot_a,'lead reads next 3h',tot_l,'overlap',tot_ov)
