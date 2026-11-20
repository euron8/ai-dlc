import json,sys
# usage: evlog.py transcript startISO endISO out
f,a,b,out=sys.argv[1:5]
o=open(out,'w')
res={}
rows=[]
for l in open(f):
    try: r=json.loads(l)
    except: continue
    ts=r.get('timestamp','')
    if not(a<=ts<=b): continue
    m=r.get('message',{})
    c=m.get('content')
    if r.get('type')=='assistant' and isinstance(c,list):
        for x in c:
            if x.get('type')=='tool_use':
                i=x['input']
                s=i.get('command') or i.get('file_path') or i.get('prompt') or i.get('description') or json.dumps(i)[:200]
                if x['name']=='Agent': s=(i.get('description','')+' | '+str(i.get('subagent_type'))+' | '+i.get('prompt','')[:150])
                rows.append((ts,x['name'],x['id'],' '.join(str(s).split())[:230]))
            elif x.get('type')=='text' and x['text'].strip():
                rows.append((ts,'TEXT','',' '.join(x['text'].split())[:230]))
    elif r.get('type')=='user':
        if isinstance(c,str):
            rows.append((ts,'USER','',' '.join(c.split())[:300]))
        elif isinstance(c,list):
            for x in c:
                if x.get('type')=='text': rows.append((ts,'USER','',' '.join(x['text'].split())[:300]))
for ts,n,i,s in rows: o.write(f"{ts[11:19]} {n} {s}\n")
print(len(rows))
