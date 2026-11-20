import json,re,collections,sys
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
sprint=int(sys.argv[1])
sp=[json.loads(l) for l in open(M+"spawns.jsonl")]
sp=[s for s in sp if s['sprint']==sprint and s['step'] in('stories-test-strategy','gate-validation[stories-test-strategy]')]
sp.sort(key=lambda s:s['start'])
def key(s):
    d=re.sub(r'\d+','N',s['description'])[:60]
    return (s['step'][:4],s['role'],d)
g=collections.OrderedDict()
for s in sp:
    k=key(s); e=g.setdefault(k,[0,0,0,s['start'],s['end']])
    e[0]+=1;e[1]+=s['minutes'];e[2]+=s['usd'];e[4]=max(e[4],s['end'])
for k,e in g.items(): print(e[3][5:16],e[4][5:16],e[0],round(e[1],1),round(e[2],1),k)
print(len(sp),sum(s['usd'] for s in sp),sum(s['minutes'] for s in sp))
