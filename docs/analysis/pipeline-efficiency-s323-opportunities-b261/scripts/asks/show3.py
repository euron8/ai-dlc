import json,sys,re
sys.path.insert(0,".")
from ans import kind
sp=int(sys.argv[1]); lo=int(sys.argv[2]); hi=int(sys.argv[3]); ql=int(sys.argv[4])
A=json.load(open("asks_enriched.json")); A=[r for r in A if r["sprint"]==sp]
for r in A:
    if not lo<=r["idx"]<hi: continue
    print(f"#{r['idx']} {r['et0']} w={r['wait']/60:.0f} {r['step'][:14]} g={None if r['gap'] is None else round(r['gap'])} run={r['nrun']} fin={r['nfin']}{' ERR' if r['err'] else ''}")
    for q in r["qs"]:
        k,c=kind(q,r["ans"])
        print(f"   [{q.get('header')}] {(q.get('question') or '')[:ql]!r} => {k}: {(c or '')[:50]!r}")
