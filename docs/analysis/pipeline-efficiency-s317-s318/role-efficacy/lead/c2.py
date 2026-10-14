import json, os, glob, datetime
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
sp=[json.loads(l) for l in open(D+'spawns.jsonl')]
an=[s for s in sp if s['role']=='analyst']
full={os.path.basename(f)[:8]:os.path.basename(f)[:-6] for f in glob.glob(P+'*.jsonl')}
def tools(path,after=None,before=None):
    rd=set(); wr=set()
    for l in open(path):
        r=json.loads(l)
        if r.get('type')!='assistant': continue
        if 'subagents' not in path and r.get('isSidechain'): continue
        ts=r['timestamp']
        if after and ts<after: continue
        if before and ts>before: continue
        for c in r['message'].get('content',[]):
            if c.get('type')!='tool_use': continue
            fp=c['input'].get('file_path','').replace('/Users/n8/git/graph/','')
            if not fp or fp.startswith('.claude/') or 'pipeline-snapshot' in fp: continue
            if c['name']=='Read': rd.add(fp)
            elif c['name'] in ('Write','Edit','MultiEdit'): wr.add(fp)
    return rd,wr
W=Wu=R=Rr=0
for s in an:
    sess=full.get(s['sess'][:8]); sub=glob.glob(P+sess+'/subagents/'+s['unit']+'.jsonl') if sess else []
    if not sub: continue
    ard,awr=tools(sub[0])
    lim=(datetime.datetime.fromisoformat(s['end'][:19])+datetime.timedelta(hours=3)).isoformat()+'Z'
    lrd,_=tools(P+sess+'.jsonl',s['end'],lim)
    ro=ard-awr
    W+=len(awr); Wu+=len(awr&lrd); R+=len(ro); Rr+=len(ro&lrd)
    print(s['sess'][:8],s['step'][:20],s['description'][:36],'wrote',len(awr),'lead-read-of-written',len(awr&lrd),'readonly',len(ro),'lead-reread',len(ro&lrd),sorted(ro&lrd)[:3])
print('TOTAL analyst-written',W,'lead Read of them',Wu,'| analyst read-only',R,'lead re-Read',Rr)
