import json,sys
F=sys.argv[1]; T0,T1=sys.argv[2],sys.argv[3]
calls={};res={}
rows=[]
for l in open(F):
    try:o=json.loads(l)
    except: continue
    ts=o.get('timestamp','')
    m=o.get('message') or {}
    c=m.get('content')
    if not isinstance(c,list): continue
    for b in c:
        if b.get('type')=='tool_use': calls[b['id']]=(ts,b['name'],b.get('input',{}))
        elif b.get('type')=='tool_result': res[b['tool_use_id']]=(ts,bool(b.get('is_error')),len(json.dumps(b.get('content',''))))
out=[]
for i,(ts,n,inp) in calls.items():
    if not(T0<=ts<=T1):continue
    r=res.get(i)
    if r is None: continue   # unpaired -> dropped (denied/never resulted)
    if r[1]: continue
    d=inp.get('command') or inp.get('file_path') or inp.get('description') or inp.get('prompt') or json.dumps(inp)
    out.append((ts,n,r[2],' '.join(str(d).split())[:150], inp.get('description','') if n in('Agent','Task') else ''))
out.sort()
for o in out: print(o[0][5:19],o[1],o[2],o[3],'|',o[4])
