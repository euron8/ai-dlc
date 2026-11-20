import json,collections
o=json.load(open('readers.json')); n=json.load(open('readers_nsp.json'))
pat=collections.defaultdict(lambda:collections.defaultdict(int))
for k,v in o.items():
    sp,step,role=k.split('|')
    for kk,c in v.items():
        p,t=kk.split('|')
        if t=='SPAWNS_WITH': pat[p][(sp,step if step!='architecture' else 'ARCH', role)]+=c
for p in pat:
    print('==',p)
    agg=collections.defaultdict(int)
    for (sp,step,role),c in pat[p].items(): agg[(sp,step)]+=c
    print(' by sprint/step:',sorted(agg.items()))
