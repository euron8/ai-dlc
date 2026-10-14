import json, os, glob, collections
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
f=glob.glob(P+'3dbc11fb*.jsonl')[0]
keys=collections.Counter(); ex={}
for l in open(f):
    r=json.loads(l)
    t=r.get('type')
    keys[t]+=1
    if t=='assistant' and 'a' not in ex:
        m=r['message']; ex['a']={k:(str(v)[:100]) for k,v in r.items() if k!='message'}; ex['am']={k:str(v)[:100] for k,v in m.items() if k!='content'}
    if t=='user' and 'u' not in ex and isinstance(r['message'].get('content'),list) and r['message']['content'] and r['message']['content'][0].get('type')=='tool_result':
        ex['u']={k:(str(v)[:150]) for k,v in r.items()}
print(keys);
for k,v in ex.items(): print(k,v)
print(len(glob.glob(P+'*.jsonl')))
