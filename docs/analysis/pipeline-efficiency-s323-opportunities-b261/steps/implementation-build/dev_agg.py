#!/usr/bin/env python3
"""Aggregate dev_activity.tsv: by activity across dev+dev-escalated (pre-reviewer separate); per-spawn wall/standby."""
import csv, collections
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/implementation-build/'
rows=list(csv.DictReader(open(D+'dev_activity.tsv'),delimiter='\t'))
sp={}
for r in rows: sp[r['unit']]=(r['role'],r['story'],float(r['usd']),float(r['wall_min']),float(r['standby_min']),r['desc'])
print('per spawn: role story usd wall standby active(wall-standby)')
for u,(ro,st,usd,w,s,d) in sorted(sp.items(),key=lambda kv:-kv[1][3]):
    print(ro[:9].ljust(10),st.ljust(4),('$%.1f'%usd).rjust(7),str(round(w)).rjust(5),str(round(s)).rjust(5),str(round(w-s)).rjust(5),d[:40])
tw=sum(v[3] for v in sp.values() if v[0]!='pre-reviewer'); ts=sum(v[4] for v in sp.values() if v[0]!='pre-reviewer')
print('dev+esc wall min',round(tw),'standby(>300s gaps)',round(ts),'= %.0f%%'%(100*ts/tw))
for grp in (('dev','dev-escalated'),):
    agg=collections.defaultdict(lambda:[0,0.0,0.0,0.0,0.0,0.0])
    for r in rows:
        if r['role'] in grp:
            a=agg[r['activity']]; a[0]+=int(r['n']);a[1]+=float(r['think_min']);a[2]+=float(r['tool_min']);a[3]+=float(r['out_tok']);a[4]+=float(r['cw_tok']);a[5]+=float(r['cr_tok'])
    T=sum(a[1]+a[2] for a in agg.values()); O=sum(a[3] for a in agg.values()); CW=sum(a[4] for a in agg.values()); CR=sum(a[5] for a in agg.values())
    print('\nactivity'.ljust(26),'calls think+tool_min  %time  out_tok  %out  cacheW_M  cacheR_M')
    for k,a in sorted(agg.items(),key=lambda kv:-(kv[1][1]+kv[1][2])):
        print(k.ljust(26),str(a[0]).rjust(5),str(round(a[1]+a[2])).rjust(7),('%.0f%%'%(100*(a[1]+a[2])/T)).rjust(6),str(int(a[3])).rjust(8),('%.0f%%'%(100*a[3]/O)).rjust(5),('%.1f'%(a[4]/1e6)).rjust(8),('%.0f'%(a[5]/1e6)).rjust(8))
    print('TOTAL active min',round(T),'out tok',int(O),'cacheW M',round(CW/1e6,1),'cacheR M',round(CR/1e6))
