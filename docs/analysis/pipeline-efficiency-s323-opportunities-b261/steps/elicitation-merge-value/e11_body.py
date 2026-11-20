import re,sys
PA="/Users/n8/git/graph/_bmad-output/planning-artifacts/"
def body(path,fid,n=700):
    t=open(PA+path).read()
    for b in re.split(r'(?m)^(?=### )',t):
        if re.match(r'### (?:[A-Z]+ — )?'+fid+r'\b',b):
            x=re.sub(r'\s+',' ',b); print('##',path[-40:],x[:n]); return
    print('NOTFOUND',path,fid)
for a in sys.argv[1:]:
    p,f=a.split('#'); body(p,f)
