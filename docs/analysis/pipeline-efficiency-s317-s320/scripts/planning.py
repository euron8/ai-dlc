import csv,collections,sys
exec(open(sys.argv[2]).read().split("rows=list")[0])
rows=list(csv.DictReader(open(sys.argv[1]+'/steps.csv')))
G={'carry-over-evaluation':'carry','requirements':'req','architecture':'arch','stories-test-strategy':'stories'}
A=collections.defaultdict(lambda: collections.defaultdict(float))
for r in rows:
    if r['bucket']!='pipeline': continue
    st=r['step']; b=st[16:-1] if st.startswith('gate-validation[') else st
    if b not in G: continue
    a=A[(int(r['sprint']),G[b])]
    a['machine']+=float(r['active_h'])+float(r['agent_wait_h']); a['op']+=float(r['op_wait_h'])
    a['$']+=usd(r,'lead')+usd(r,'sub'); a['subh']+=float(r['sub_active_h'])
    a['tok']+=sum(float(v or 0) for c,v in r.items() if c.endswith(('_in','_out','_cr','_cw')))
print("planning phase: machine h (active+agent wait) | operator-wait h | $ | subagent-h | tokens B")
for g in ['carry','req','arch','stories','ALL']:
    print(g.ljust(8),end='')
    for n in (317,318,319,320):
        keys=[g] if g!='ALL' else list(G.values())
        m=sum(A[(n,k)]['machine'] for k in keys);o=sum(A[(n,k)]['op'] for k in keys);d=sum(A[(n,k)]['$'] for k in keys);h=sum(A[(n,k)]['subh'] for k in keys);t=sum(A[(n,k)]['tok'] for k in keys)
        print(f"| s{n} {m:5.1f} {o:5.1f} ${d:5.0f} {h:4.0f} {t/1e9:4.2f} ",end='')
    print()
