import json, glob, sys
G='/Users/n8/git/graph/_bmad-output/gate-adjudication/'
for pre in sys.argv[1:]:
    print('=====',pre)
    for f in sorted(glob.glob(G+pre+'*.jsonl'))+sorted(glob.glob(G+pre+'*.verdict.json')):
        txt=open(f).read()
        objs=[]
        if f.endswith('.jsonl'):
            for l in txt.splitlines():
                l=l.strip()
                if l:
                    try: objs.append(json.loads(l))
                    except Exception as e: print('bad line',f)
        else:
            objs=json.load(open(f))['verdicts']
        for o in objs:
            v=o.get('verdict')
            cid=o.get('check_id')
            ev=o.get('evidence','')
            if v!='PASS' or cid in ('5','21'):
                print(f.split('/')[-1][-20:], cid, v, (ev if isinstance(ev,str) else json.dumps(ev))[:int(sys.argv[0:1] and 900)])
