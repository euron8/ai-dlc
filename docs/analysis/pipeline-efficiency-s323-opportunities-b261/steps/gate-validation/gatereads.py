
import json,collections,re,sys
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
P='/Users/n8/.claude/projects/-Users-n8-git-graph/'
wins=[]
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    if r['kind']=='lead' and r['sprint'] in (321,322,323) and r['step'].startswith('gate-validation['):
        wins.append((r['sprint'],r['step'][16:-1],r['unit'],r['first'],r['last']))
PAT=re.compile(r'(gate-validation\.md|_gate-procedures\.md|extensions/checks/[^/]+\.md)$')
out=collections.defaultdict(lambda:collections.defaultdict(lambda:[0,0]))
comp=collections.Counter()
for sp,step,unit,a,b in wins:
    uses={}
    try: fh=open(P+unit+'.jsonl')
    except: continue
    for l in fh:
        try:r=json.loads(l)
        except: continue
        ts=r.get('timestamp','')
        if not(a<=ts<=b): continue
        if r.get('isCompactSummary'): comp[(sp,step)]+=1
        m=r.get('message') or {}
        c=m.get('content')
        if not isinstance(c,list): continue
        for x in c:
            if x.get('type')=='tool_use' and x['name']=='Read':
                fp=x['input'].get('file_path','')
                mm=PAT.search(fp)
                if mm: uses[x['id']]=mm.group(1).split('/')[-1]
            elif x.get('type')=='tool_result' and x.get('tool_use_id') in uses:
                cc=x.get('content'); 
                n=len(cc) if isinstance(cc,str) else sum(len(y.get('text','')) for y in cc if isinstance(y,dict))
                err=x.get('is_error')
                k=uses[x['tool_use_id']]+('(err)' if err else '')
                o=out[(sp,step)][k];o[0]+=1;o[1]+=n
for k in sorted(out): print(k,{f:(v[0],v[1]//1000) for f,v in out[k].items()},'compact',comp.get(k,0))
tot=collections.defaultdict(lambda:[0,0])
for k in out:
    for f,v in out[k].items():
        if 'implementation' in k[1]: continue
        tot[(k[0],f)][0]+=v[0];tot[(k[0],f)][1]+=v[1]
for k in sorted(tot): print('nonimpl',k,tot[k][0],'reads',tot[k][1]//1000,'KB')
