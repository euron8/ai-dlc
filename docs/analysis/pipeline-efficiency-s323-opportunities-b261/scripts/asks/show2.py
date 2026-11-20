import json,sys
from ans import kind
sp=int(sys.argv[1]); lo=int(sys.argv[2]); hi=int(sys.argv[3]); qlen=int(sys.argv[4]) if len(sys.argv)>4 else 200
rows=[json.loads(l) for l in open("events.jsonl")]
rows=[r for r in rows if r["sprint"]==sp and r["kind"]=="ask"]
for i,r in enumerate(rows):
    if not lo<=i<hi: continue
    print(f"#{i} {r['start'][5:16]}Z w={r['wait']/60:.0f}m {r['step']} s={r['sess']}{' ERR' if r['err'] else ''}")
    for q in r["qs"]:
        k,c=kind(q,r["ans"])
        print(f"  [{q.get('header')}] {(q.get('question') or '')[:qlen]!r}")
        print(f"     opts={[ (o.get('label') or '')[:40] for o in q.get('options') or []]} -> {k}: {(c or r['ans'][-200:])[:100]!r}")
