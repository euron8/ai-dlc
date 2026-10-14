import json, glob, os, re, sys
G='/Users/n8/git/graph/_bmad-output/gate-adjudication/'
for f in sys.argv[1:]:
    p=G+f
    j=json.load(open(p))
    print('==',f, {k:(v if not isinstance(v,(list,dict)) else type(v).__name__+str(len(v))) for k,v in j.items()})
    items=None
    for k in ('checks','verdicts','results','rows'):
        if isinstance(j.get(k),list): items=j[k]; break
    if items is None and isinstance(j.get('checks'),dict): items=[dict(id=k,**v) if isinstance(v,dict) else {'id':k,'v':v} for k,v in j['checks'].items()]
    if items:
        print('  item keys',list(items[0].keys()))
        for it in items:
            s=json.dumps(it)
            v=it.get('verdict') or it.get('status') or it.get('result')
            if v and str(v).upper() not in ('PASS','N/A','NA','SKIP'):
                print('  ',it.get('id') or it.get('check'),v,s[:400])
