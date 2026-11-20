import re,glob,os,json,collections
exec(open("e13_title.py").read().split('if __name__')[0])
rows=json.load(open("e3_rows.json")); idx={(r['sprint'],r['step'],r['shard'],r['f']):r for r in rows}
SEATK={"requirements":"requirements","architecture":"architecture","spine":"architecture","coe":"carry-over-evaluation","stories":"stories"}
P1K={"requirements":["requirements"],"architecture":["architecture","architecture-adversarial"],"spine":["ARCHITECTURE-SPINE"],"coe":["coe"],"stories":["stories"]}
out=collections.defaultdict(collections.Counter)
for s in ("s321","s322","s323"):
  for st,(ed,pm,p1k) in STEPS.items():
    fs=sorted(glob.glob(PA+f"{s}/shards/{ed}/*.md"))
    if not fs: continue
    seat=[]
    for f in glob.glob(PM+f"{s}/{SEATK[st]}-*.md"):
        for bl in blocks(rd(f)):
            if re.match(r'##+ ',bl): seat.append(bl[:1800])
    later=[]
    for p in ("p1","p2","p3"):
        for k in P1K[st]:
            for f in glob.glob(PA+f"{s}/shards/{k}-{p}/*.md"):
                for bl in blocks(rd(f)):
                    if bl.startswith("### "): later.append((p,bl[:1500]))
    for f in fs:
        key=os.path.basename(f)[:-3].lstrip('0') or '0'
        for b in blocks(rd(f)):
            h=b.split("\n")[0]
            m=re.match(r'### (?:(?:CRITICAL|MAJOR|MINOR|NIT) — )?([FE])-(\d+)|### ([FE])-(\d+)',h); sv=re.search(r'\b(CRITICAL|MAJOR)\b',h)
            if not (m and sv): continue
            fid=(m.group(1) or m.group(3))+(m.group(2) or m.group(4)); tk=toks(h)
            r=idx.get((s,st,key,fid))
            ms=match(tk,seat,2); ml=match(tk,[t for _,t in later],2)
            if r is not None: r['t_seat']=bool(ms); r['t_later']=bool(ml); r['t_later_p']=later[ml[0]][0] if ml else ''
            k=(s,st); out[k]['n']+=1; out[k]['seat_title']+=bool(ms); out[k]['later_title']+=bool(ml)
json.dump(rows,open("e3_rows.json","w"))
for k,v in sorted(out.items()): print(*k,dict(v))
