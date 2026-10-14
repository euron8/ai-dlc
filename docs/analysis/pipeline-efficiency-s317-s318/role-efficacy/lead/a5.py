import json, os, glob, collections, re
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
H='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/lead/'
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
ad=json.load(open(H+'agentdesc.json'))
# collect results of Agent calls: cap-rejected or not
res={}
for s in ad:
    for l in open(glob.glob(P+s+'.jsonl')[0]):
        r=json.loads(l)
        if r.get('type')!='user' or r.get('isSidechain'): continue
        cs=r['message'].get('content')
        if not isinstance(cs,list): continue
        for c in cs:
            if c.get('type')=='tool_result':
                txt=c.get('content'); txt=txt if isinstance(txt,str) else json.dumps(txt)
                res[c.get('tool_use_id')]=(c.get('is_error'),txt[:200])
tot=collections.Counter(); cap=collections.Counter(); otherr=collections.Counter(); resent=collections.Counter(); dupok=collections.Counter()
capbursts=collections.Counter(); dupex=[]
for s,lst in ad.items():
    okdesc=collections.Counter()
    capdesc=set()
    for ts,model,st,desc,typ,tid in lst:
        k=(model,st)
        tot[k]+=1
        e=res.get(tid,(None,''))
        if e[0] and 'Concurrent subagent limit' in e[1]:
            cap[k]+=1; capdesc.add(desc); capbursts[(s[:8],st,ts[:16])]+=1
        elif e[0]:
            otherr[k]+=1
        else:
            if desc in capdesc: resent[k]+=1
            okdesc[desc]+=1
            if okdesc[desc]==2:
                dupok[k]+=1
                if len(dupex)<25: dupex.append((s[:8],model,st,ts[:16],desc[:70],typ))
print('model,step: spawns, cap_rejected, other_err, resent_after_cap, same_desc_ok_twice')
for k in sorted(tot):
    if cap[k] or dupok[k] or otherr[k]: print(k,tot[k],cap[k],otherr[k],resent[k],dupok[k])
print('TOTAL',sum(tot.values()),sum(cap.values()),sum(otherr.values()),sum(resent.values()),sum(dupok.values()))
print('cap bursts (sess,step,minute):',len(capbursts));
for k,v in sorted(capbursts.items()): print('  ',k,v)
for d in dupex: print('DUP',d)
