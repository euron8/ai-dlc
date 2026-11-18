# Regroups the `open` (sub-class, target family) line of out/lead_other_split.s322.txt into the groups the
# batch 259 decision uses. Run from docs/analysis/pipeline-efficiency-s317-s322/. Control: the 69 cells sum to
# 288.9 against the line's stated 289.5 (one-decimal rounding), printed first.
import re,collections
L=open('out/lead_other_split.s322.txt').read().split('\n')
line=[l for l in L if l.startswith('-- s322 `open` calls per story')][0]
body=line.split('all 289.5:')[1]
items=re.findall(r'([a-z-]+)/([a-z]+) ([0-9.]+)',body)
tot=sum(float(v) for _,_,v in items)
print('n',len(items),'sum',round(tot,1))
G={'edit':['edit'],'git':['git'],'read-search':['shell-read','read','ctx-search','ctx-exec','inline-interp'],
   'plumbing':['harness','mcp-other','operator','sleep','shell-builtin','bash-other','test-build','script','shell-write']}
sub=collections.Counter()
for s,f,v in items:
    for g,m in G.items():
        if s in m: sub[g]+=float(v)
print({k:round(v,1) for k,v in sub.items()},'sum',round(sum(sub.values()),1))
e=collections.Counter()
for s,f,v in items:
    if s=='edit': e[f]+=float(v)
print('edit by fam',{k:round(v,1) for k,v in e.items()})
r=collections.Counter()
for s,f,v in items:
    if s in G['read-search']: r[f]+=float(v)
print('read by fam',{k:round(v,1) for k,v in r.items()})
p=collections.Counter()
for s,f,v in items:
    if s in G['plumbing']: p[s]+=float(v)
print('plumbing',{k:round(v,1) for k,v in p.items()})
