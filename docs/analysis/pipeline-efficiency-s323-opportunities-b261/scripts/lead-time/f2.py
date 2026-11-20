import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle,collections,re
from fam import fam
calls, ivs, res, comps, flows, order = pickle.load(open("lib.pkl","rb"))
t=collections.defaultdict(float)
for u,s,st,d,cls,mid,sk,ty,det in ivs:
    if mid and d<=300: t[mid]+=d
SP=int(sys.argv[1])
A=collections.defaultdict(lambda:[0,0.0,0,0.0,0,0.0,0,0])  # n act exactrepeat act_rep same_size_rep act_same bytes_total_same
seen={}
for m,c in calls.items():
    if c["s"]!=SP: continue
    tus=[b for b in c["b"] if b[0]=="tu"]
    for b in tus:
        if b[1]!="Bash": continue
        f=fam({"b":[b]})[1]
        if not f.startswith("script:"): continue
        k=f[7:]; a=A[k]; w=t[m]/len(tus); a[0]+=1; a[1]+=w
        rb=res.get(b[2],{}).get("b")
        kk=(c["u"],c["step"],re.sub(r"\s+"," ",b[3]))
        if kk in seen:
            a[2]+=1; a[3]+=w
            if rb is not None and rb==seen[kk]: a[4]+=1; a[5]+=w
        seen[kk]=rb
print("s%d lead Bash script calls by script (n, active h; exact-repeat of the same command text in the same unit+step: n,h; of which result size identical: n,h)"%SP)
for k,a in sorted(A.items(), key=lambda kv:-kv[1][1])[:14]:
    print("  %-34s n%5d %.2fh | exact-repeat n%4d %.2fh | same-size n%4d %.2fh"%(k[:34],a[0],a[1]/3600,a[2],a[3]/3600,a[4],a[5]/3600))
# sleeps
n=0;h=0.0
for m,c in calls.items():
    if c["s"]!=SP: continue
    for b in c["b"]:
        if b[0]=="tu" and b[1]=="Bash" and re.search(r"(^|[;&|\s])sleep\s+\d",b[3]): n+=1; h+=t[m]/len([x for x in c["b"] if x[0]=="tu"])
print("  sleep-containing Bash blocks: n%d %.2fh"%(n,h/3600))
