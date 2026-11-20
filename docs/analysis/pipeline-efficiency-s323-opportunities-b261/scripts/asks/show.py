import json,sys,re
sp=int(sys.argv[1]); lo=int(sys.argv[2]); hi=int(sys.argv[3])
rows=[json.loads(l) for l in open("events.jsonl")]
rows=[r for r in rows if r["sprint"]==sp and r["kind"]=="ask"]
for i,r in enumerate(rows):
    if not lo<=i<hi: continue
    print(f"#{i} {r['start'][5:16]}Z wait={r['wait']/60:.0f}m step={r['step']} sess={r['sess']}")
    for q in r["qs"]:
        print("  Q["+str(q.get('header'))+"]", (q.get("question") or "")[:420].replace("\n"," "))
        for o in q.get("options") or []: print("    -", (o.get("label") or "")[:90], "|", (o.get("description") or "")[:110].replace("\n"," "))
    print("  ANS:", r["ans"][:330].replace("\n"," "))
