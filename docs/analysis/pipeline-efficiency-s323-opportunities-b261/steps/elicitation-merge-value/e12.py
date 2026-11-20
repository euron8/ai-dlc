import glob,re,sys,os
B="/Users/n8/git/graph/_bmad-output/"
tok=sys.argv[1]
for g in sys.argv[2:]:
    for f in sorted(glob.glob(B+g))[:60]:
        t=open(f).read()
        m=re.search(tok,t)
        if m:
            print(os.path.relpath(f,B)[-46:],"::",re.sub(r'\s+',' ',t[max(0,m.start()-150):m.end()+150]))
