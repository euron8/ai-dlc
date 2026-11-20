import sys,os; sys.path.insert(0,'.')
import json,collections,pickle,re
calls, ivs, res, comps, flows, order = pickle.load(open("lib.pkl","rb"))
keep=set()
for l in open('x/units.jsonl'):
    r=json.loads(l)
    if any(k.split('|',1)[0]!='pre-step' for k in r['tok']): keep.add(r['unit'])
t=collections.defaultdict(float)
for u,s,st,d,cls,mid,sk,ty,det in ivs:
    if mid and d<=300: t[mid]+=d
up=collections.defaultdict(lambda:[0,0]); stop=[]; 
units=collections.OrderedDict()
for l in open('x/rec.jsonl'):
    e=json.loads(l)
    if e['u0'] in keep and e['s']==323: units.setdefault(e['u0'],[]).append(e)
for u,evs in units.items():
    ci=0; 
    for i,e in enumerate(evs):
        if e['ty']=='attachment' and e.get('hev')=='UserPromptSubmit' and e.get('hb'):
            h=e.get('hh','')
            k="ai-dlc-pause provenance" if "hook=ai-dlc-pause" in h else "context_mode_recall" if "context_mode_recall" in h else "other:"+h[:30]
            up[k][0]+=1; up[k][1]+=e['hb']
        if e['ty']=='user' and (e.get('tx') or '').startswith('Stop hook feedback'):
            # next assistant mid after this record
            nxt=None
            for x in evs[i+1:i+40]:
                if x['ty']=='assistant' and x.get('mid'): nxt=x['mid']; break
            stop.append((u,e['sz'],nxt, e['tx'][20:60]))
print("UserPromptSubmit injections s323 (pipeline bucket):",{k:(v[0],round(v[1]/1e6,2)) for k,v in up.items()})
print("Stop-hook feedback injections:",len(stop),"bytes %.2f MB"%(sum(s[1] for s in stop)/1e6))
nm=[s[2] for s in stop if s[2]]
print(" following call: active %.2fh, out tokens %.2fM, classes %s"%(sum(t[m] for m in nm)/3600,sum(calls[m]['uu'][3] for m in nm)/1e6,collections.Counter(calls[m]['cls'] for m in nm).most_common(4)))
print(" kinds:",collections.Counter(s[3][:22] for s in stop).most_common(4))
