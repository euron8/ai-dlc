import csv,collections,sys
P={'opus':(4,20,0.2,8),'sonnet':(2,10,0.2,4),'haiku':(.1,.5,.01,.2),'fable':(10,50,.25,20)}
def usd(r,pre):
    t=0
    for f,(i,o,cr,cw) in P.items():
        g=lambda k: float(r.get(f"{pre}_{f}_{k}",0) or 0)
        t+=(g('in')*i+g('out')*o+g('cr')*cr+g('cw')*cw)/1e6
    return t
rows=list(csv.DictReader(open(sys.argv[1]+'/steps.csv')))
A=collections.defaultdict(lambda: collections.defaultdict(float))
for r in rows:
    if r['bucket']!='pipeline': continue
    st=r['step']; base=st.split('[')[0] if not st.startswith('gate-validation') else 'gate['+st[16:-1]+']'
    k=(int(r['sprint']),base)
    a=A[k]
    a['el']+=float(r['elapsed_h']); a['act']+=float(r['active_h']); a['aw']+=float(r['agent_wait_h']); a['op']+=float(r['op_wait_h'])
    a['lead$']+=usd(r,'lead'); a['sub$']+=usd(r,'sub'); a['subh']+=float(r['sub_active_h']); a['comp']+=float(r['compactions'])
    a['tok']+=sum(float(v or 0) for c,v in r.items() if c.endswith(('_in','_out','_cr','_cw')))
steps=sorted({k[1] for k in A})
order=['pre-step','carry-over-evaluation','requirements','gate[requirements]','architecture','gate[architecture]','stories-test-strategy','gate[stories-test-strategy]','implementation','gate[implementation]','sprint-review','gate[sprint-review]','deploy-validate','retro']
steps=[s for s in order if s in steps]+[s for s in steps if s not in order]
print(f"{'step':32}"+''.join(f"| s{n} el/act h  $(lead+sub)  ".ljust(30) for n in (317,318,319,320)))
for s in steps:
    line=f"{s:32}"
    for n in (317,318,319,320):
        a=A.get((n,s))
        line+=(f"| {a['el']:5.1f}/{a['act']:4.1f}  ${a['lead$']+a['sub$']:7.0f}".ljust(30) if a else "| -".ljust(30))
    print(line)
for n in (317,318,319,320):
    T=collections.defaultdict(float)
    for (m,s),a in A.items():
        if m==n:
            for k,v in a.items(): T[k]+=v
    print(f"s{n} TOTAL elapsed {T['el']:.1f}h active {T['act']:.1f}h agentwait {T['aw']:.1f}h opwait {T['op']:.1f}h lead$ {T['lead$']:.0f} sub$ {T['sub$']:.0f} subagent-h {T['subh']:.0f} tokens {T['tok']/1e9:.2f}B compactions {T['comp']:.0f}")
