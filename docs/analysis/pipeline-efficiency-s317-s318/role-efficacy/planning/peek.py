import sys,re
f=sys.argv[1]; n=int(sys.argv[2]) if len(sys.argv)>2 else 60
t=open(f,errors='replace').read().splitlines()
mode=sys.argv[3] if len(sys.argv)>3 else 'head'
if mode=='head':
    for i,l in enumerate(t[:n]): print(i+1,l[:220])
else:
    rx=re.compile(mode)
    for i,l in enumerate(t):
        if rx.search(l): print(i+1,l[:260])
