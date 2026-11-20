import json,collections,sys
SP=int(sys.argv[1])
keep=set()
for l in open('x/units.jsonl'):
    r=json.loads(l)
    if any(k.split('|',1)[0]!='pre-step' for k in r['tok']): keep.add(r['unit'])
H=collections.defaultdict(lambda:[0,0.0,0,0.0])
for l in open('x/hooks.jsonl'):
    r=json.loads(l)
    if r['sprint']!=SP or r['kind']!='lead' or r['unit'] not in keep: continue
    k=(r['event'],r['hook'],r['att'])
    h=H[k]; h[0]+=1; h[1]+=r['ms']; h[2]+=r['bytes']; h[3]=max(h[3],r['ms'])
tot=sum(v[1] for v in H.values())/3600e3; n=sum(v[0] for v in H.values()); b=sum(v[2] for v in H.values())
print("s%d lead hook records %d, sum of durationMs %.2f h (sequential upper bound), injected bytes %.1f MB"%(SP,n,tot,b/1e6))
for k,v in sorted(H.items(), key=lambda kv:-(kv[1][2] if len(sys.argv)>3 else kv[1][1]))[:int(sys.argv[2])]:
    print("  %-18s %-40s %-24s n%6d  sum %6.2f h  mean %6.0f ms max %6.0f ms  bytes %6.2f MB"%(k[0][:18],str(k[1])[:40],k[2][:24],v[0],v[1]/3600e3,v[1]/v[0],v[3],v[2]/1e6))
