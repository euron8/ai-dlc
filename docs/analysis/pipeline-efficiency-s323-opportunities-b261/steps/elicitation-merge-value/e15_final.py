import json,collections,re
rows=json.load(open("e3_rows.json"))
body=collections.defaultdict(dict)
c=collections.defaultdict(collections.Counter)
for r in rows:
    k=(r['sprint'],r['step']); r_=r
    sh=r['disp']=='repaired' and r['nship']>0
    c[k]['n']+=1; c[k]['crit']+=r['sev']=='CRITICAL'
    c[k]['rep+ship']+=sh
    c[k]['A_proxy']+=r['A_party_repair']
    c[k]['seat_t']+=r.get('t_seat',False); c[k]['later_t']+=r.get('t_later',False)
    u=sh and not r.get('t_seat',False) and not r.get('t_later',False)
    c[k]['uniq_ship_ub']+=u
    c[k]['uniq_ship_ub_and_notA']+=(u and not r['A_party_repair'])
    c[k]['uniq_ship_ub_critmaj_A']+=(u and r['A_party_repair'])
tot=collections.defaultdict(collections.Counter)
for k,v in sorted(c.items()):
    print(*k,dict(v))
    for a,b in v.items(): tot[k[1]][a]+=b
print()
for k,v in tot.items(): print('TOTAL',k,dict(v))
