#!/usr/bin/env python3
"""Apportion each dev/dev-escalated spawn's recorded usd (spawns.jsonl) to activities by a token-price weight:
weight = in*1 + cw*1.25 + cr*0.1 + out*5 (Anthropic ratio in:cw:cr:out = 1:1.25:0.1:5 for all models). Calibration printed: sum of weights*price vs recorded usd
(price per unit weight fitted per spawn so each spawn's activities sum EXACTLY to its recorded usd; the fit factor spread shows how well the ratio explains the spawn).
"""
import importlib.util,collections,json
spec=importlib.util.spec_from_file_location('da','dev_activity.py'); da=importlib.util.module_from_spec(spec); spec.loader.exec_module(da)
cost=collections.defaultdict(float); tot=0; fit=[]
for u in da.load_units():
    if u['role']=='pre-reviewer': continue
    uid,_=da.unit_id(u); a=da.analyze(uid)
    w={k:v['inp']*1+v['cw']*1.25+v['cr']*0.1+v['out']*5 for k,v in a['act'].items()}
    W=sum(w.values()); 
    for k,x in w.items(): cost[k]+=u['usd']*x/W
    tot+=u['usd']; fit.append((u['usd']/W*1e6))
print('total usd apportioned',round(tot,1),' $/M weight-units min/median/max',round(min(fit),2),round(sorted(fit)[len(fit)//2],2),round(max(fit),2))
for k,v in sorted(cost.items(),key=lambda kv:-kv[1]): print(k.ljust(24),'$%.1f'%v,'%.0f%%'%(100*v/tot))
