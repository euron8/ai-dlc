import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, collections, statistics as S
D=os.path.dirname(os.path.abspath(__file__))
calls, ivs, res, comps, *_x = pickle.load(open(D+"/lib.pkl","rb"))
def pct(a,p):
    a=sorted(a); return a[min(len(a)-1,int(p*len(a)))]
def solve(X,y):
    n=len(X[0]); A=[[sum(r[i]*r[j] for r in X) for j in range(n)] for i in range(n)]; b=[sum(r[i]*yy for r,yy in zip(X,y)) for i in range(n)]
    for i in range(n):
        p=max(range(i,n),key=lambda k:abs(A[k][i])); A[i],A[p]=A[p],A[i]; b[i],b[p]=b[p],b[i]
        for k in range(i+1,n):
            f=A[k][i]/A[i][i]
            for j in range(i,n): A[k][j]-=f*A[i][j]
            b[k]-=f*b[i]
    x=[0]*n
    for i in reversed(range(n)): x[i]=(b[i]-sum(A[i][j]*x[j] for j in range(i+1,n)))/A[i][i]
    return x
rows=collections.defaultdict(list)
for m,c in calls.items():
    if c["treq"] is None or c["s"] not in(321,322,323): continue
    lat=c["t1"]-c["treq"]; lat0=c["t0"]-c["treq"]
    if lat<0 or lat>3600: continue
    inn,cc,cr,out=c["uu"]
    if out==0 and inn+cc+cr==0: continue
    mod=c["model"] or "?"
    rows[(c["s"],mod)].append(dict(lat=lat,lat0=lat0,ctx=inn+cc+cr,unc=inn+cc,cr=cr,out=out,ntu=sum(1 for b in c["b"] if b[0]=="tu")))
BK=[0,40e3,80e3,120e3,160e3,200e3,1e9]
for k,v in sorted(rows.items()):
    if len(v)<200: continue
    L=[r["lat"] for r in v]
    print("== sprint %s model %s n=%d | lat median %.1fs p90 %.1fs mean %.1fs | ctx median %.0fk p90 %.0fk max %.0fk | out median %d p90 %d"%(k[0],k[1],len(v),S.median(L),pct(L,.9),S.mean(L),S.median(r["ctx"] for r in v)/1e3,pct([r["ctx"] for r in v],.9)/1e3,max(r["ctx"] for r in v)/1e3,S.median(r["out"] for r in v),pct([r["out"] for r in v],.9)))
    for i in range(len(BK)-1):
        w=[r for r in v if BK[i]<=r["ctx"]<BK[i+1]]
        if len(w)<30: continue
        L=[r["lat"] for r in w]; print("   ctx %3d-%3dk n%5d lat med %5.1f p90 %6.1f | out med %4d | uncached med %6.0f | lat/out-tok med %.3f"%(BK[i]/1e3,min(BK[i+1],999e3)/1e3,len(w),S.median(L),pct(L,.9),S.median(r["out"] for r in w),S.median(r["unc"] for r in w),S.median(r["lat"]/max(1,r["out"]) for r in w)))
    # regression lat ~ a + b*unc/1e3 + c*cr/1e3 + d*out/1e3
    X=[[1,r["unc"]/1e3,r["cr"]/1e3,r["out"]/1e3] for r in v]; y=[r["lat"] for r in v]
    try:
        b=solve(X,y); pred=[sum(bi*xi for bi,xi in zip(b,x)) for x in X]; ym=S.mean(y)
        r2=1-sum((a-p)**2 for a,p in zip(y,pred))/sum((a-ym)**2 for a in y)
        print("   OLS lat = %.1f + %.2f s/1k uncached + %.3f s/1k cache-read + %.1f s/1k out tok ; R2 %.2f"%(b[0],b[1],b[2],b[3],r2))
    except Exception as ex: print("   ols fail",ex)
    # out-token buckets
    for lo,hi in((0,50),(50,200),(200,1000),(1000,5000),(5000,10**9)):
        w=[r for r in v if lo<=r["out"]<hi]
        if len(w)>=30: print("   out %5d-%-9d n%5d lat med %5.1f p90 %6.1f | ctx med %.0fk"%(lo,hi,len(w),S.median(r["lat"] for r in w),pct([r["lat"] for r in w],.9),S.median(r["ctx"] for r in w)/1e3))
