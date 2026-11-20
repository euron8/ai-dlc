#!/usr/bin/env python3 -I
"""Who reads the requirements-step documents. Population: every subagent spawn of sprints 321-323 (spawns.jsonl) plus
lead segments of those sprints (segs.jsonl, step by time window). A hit = tool_use (Read/Grep/Bash/ctx_*) whose input names
the document AND whose tool_result exists and is not is_error. Output: readers.jsonl, one row per (unit, doc) with call count."""
import json,glob,os,re,sys,collections
from multiprocessing import Pool
R=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
OUT=os.path.dirname(os.path.abspath(__file__))+'/readers.jsonl'
DOCS={
 'prd':re.compile(r'(?<![\w-])prd\.md'),
 'brief':re.compile(r'(?<![\w-])product-brief\.md'),
 'spec':re.compile(r'(?<![\w-])SPEC\.md'),
 'locked':re.compile(r'locked-requirements\.md'),
 'archimpact':re.compile(r'architecture-impact\.md'),
 'reqctx':re.compile(r'requirements-context\.md'),
 'reqchangelog':re.compile(r'changelog-requirements\.md'),
 'reqadv':re.compile(r'requirements-(adversarial|party|elicitation)'),
 'prdhist':re.compile(r'prd-history\.md|product-brief-history\.md'),
}
TOOLS=('Read','Grep','Bash','Glob')
def scan(job):
    path,meta,win=job
    cnt=collections.Counter(); pend={}
    try: fh=open(path,errors='replace')
    except Exception as e: return (meta,None,str(e))
    for l in fh:
        if not any(k in l for k in ('prd','brief','SPEC','locked-req','architecture-impact','requirements-')):
            # still need results to close pend? results carry no names; skip
            if '"tool_result"' not in l: continue
        try:o=json.loads(l)
        except: continue
        c=(o.get('message') or {}).get('content')
        if not isinstance(c,list): continue
        t=o.get('timestamp') or ''
        for x in c:
            if x.get('type')=='tool_use' and (x['name'] in TOOLS or x['name'].startswith('mcp__plugin_context-mode')):
                s=json.dumps(x['input'])
                hits=[d for d,rx in DOCS.items() if rx.search(s)]
                if hits:
                    step=meta['step']
                    if win:
                        step=None
                        for (a,b,st) in win:
                            if a<=t<=b: step=st;break
                        if step is None: continue
                    pend[x['id']]=(hits,x['name'],step)
            elif x.get('type')=='tool_result' and x.get('tool_use_id') in pend:
                hits,nm,step=pend.pop(x['tool_use_id'])
                if x.get('is_error'): continue
                for h in hits: cnt[(step,h,nm)]+=1
    return (meta,cnt,None)
def main():
    sp=[json.loads(l) for l in open(M+'spawns.jsonl')]
    segs=[json.loads(l) for l in open(M+'segs.jsonl')]
    jobs=[]
    full={}
    for d in glob.glob(R+'*/'):
        full[os.path.basename(d.rstrip('/'))[:8]]=d
    for s in sp:
        if s['sprint'] not in (321,322,323): continue
        d=full.get(s['sess'])
        if not d: continue
        p=d+'subagents/'+s['unit']+'.jsonl'
        if os.path.exists(p): jobs.append((p,{'kind':'sub','sprint':s['sprint'],'step':s['step'],'role':s['role'],'unit':s['unit'],'desc':s['description'][:60]},None))
    lead=collections.defaultdict(list)
    for s in segs:
        if s['sprint'] in (321,322,323) and s['kind']=='lead':
            lead[s['unit']].append((s['first'],s['last'],s['step'],s['sprint']))
    for u,w in lead.items():
        p=R+u+'.jsonl'
        if os.path.exists(p): jobs.append((p,{'kind':'lead','sprint':w[0][3],'step':'*','role':'lead','unit':u,'desc':''},[(a,b,st) for a,b,st,_ in w]))
    print('jobs',len(jobs),file=sys.stderr)
    with Pool(8) as pool, open(OUT,'w') as out:
        n=0
        for meta,cnt,err in pool.imap_unordered(scan,jobs,chunksize=4):
            n+=1
            if err: print('ERR',meta['unit'],err,file=sys.stderr);continue
            for (step,h,nm),k in cnt.items():
                out.write(json.dumps(dict(meta,rstep=step,doc=h,tool=nm,n=k))+'\n')
            out.write(json.dumps(dict(meta,rstep=meta['step'],doc='_scanned',tool='',n=1))+'\n')
    print('done',n,file=sys.stderr)
if __name__=='__main__':
    main()
