import json,glob,os,re
A='/Users/n8/git/graph/_bmad-output/gate-adjudication/'
for n in ['planning-20261005T231118Z','planning-20261006T074556Z','planning-20261007T032358Z','planning-20261012T082837Z','planning-20261012T184956Z','planning-20261012T232233Z']:
    f=A+n+'.verdict.json'
    if not os.path.exists(f):
        parts=glob.glob(A+n+'*'); print(n,'NO verdict.json; parts',len(parts)); continue
    d=json.load(open(f))
    summ={}
    for k,v in d.items():
        if isinstance(v,list):
            st=[x.get('status') or x.get('verdict') for x in v if isinstance(x,dict)]
            summ[k]=(len(v),{s:st.count(s) for s in set(st)})
        elif isinstance(v,dict): summ[k]='dict'+str(len(v))
        else: summ[k]=str(v)[:40]
    print(n,summ)
