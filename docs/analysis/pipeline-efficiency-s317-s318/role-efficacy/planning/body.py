import sys
f=sys.argv[1]; L=open(f,errors='replace').read().splitlines()
for a in sys.argv[2:]:
    s=int(a)
    print('=====',s)
    for i in range(s-1,min(s+16,len(L))):
        if i>s-1 and L[i].startswith('### '): break
        print(i+1,L[i][:330])
