import glob,re,sys,os
B="/Users/n8/git/graph/_bmad-output/"
def ctx(tok,globs,n=3,w=110):
    k=0
    for g in globs:
        for f in sorted(glob.glob(B+g)):
            t=open(f).read()
            for m in re.finditer(re.escape(tok),t):
                s=t[max(0,m.start()-w):m.end()+w].replace("\n"," ")
                print("  ",os.path.relpath(f,B)[-52:],"::",s); k+=1
                if k>=n: return
                break
for tok,globs in [(":15453",["planning-artifacts/s323/shards/stories-p[12]/*.md","party-mode/s323/stories-*.md"]),
 ("BIGINT",["planning-artifacts/s323/shards/stories-p[12]/*.md"]),
 ("signs without `gasPrice`",["planning-artifacts/s323/shards/ARCHITECTURE-SPINE-p[12]/*.md","party-mode/s323/architecture-*.md"]),
 ("temp `.env`",["planning-artifacts/s323/shards/requirements-p[12]/*.md","party-mode/s323/requirements-*.md"])]:
    print("==",tok); ctx(tok,globs)
