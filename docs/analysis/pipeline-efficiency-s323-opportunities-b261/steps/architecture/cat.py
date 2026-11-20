import re,sys,collections
c=collections.Counter()
for l in open(sys.argv[1]):
    p=l.split(' ',2)
    if len(p)<3 or p[1]!='Bash': continue
    s=p[2]
    m=re.findall(r'([A-Za-z0-9_.-]+\.(?:sh|py|js))',s)
    k=m[0] if m else s.split()[0] if s.split() else '?'
    if not m:
        k='git' if s.startswith('git') else s.split()[0][:15]
    c[k]+=1
for k,v in c.most_common(30): print(v,k)
