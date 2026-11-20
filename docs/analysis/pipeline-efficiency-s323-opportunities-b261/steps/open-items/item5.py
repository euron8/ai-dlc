"""item 5: the lane's 61 unconsumed findings (lead's own derivation at 4b34031d 21:49:20, reproduced verbatim) vs the 41 SERIAL-REQUIRED
and the serial record's entries. Reads graph read-only. python3 -I item5.py
Control: TOTAL must be 122, CONSUMED 61, UNCONSUMED 61 (the lead's printed result)."""
import re,glob,os,collections
os.chdir('/Users/n8/git/graph')
seat={}
for f in sorted(glob.glob('_bmad-output/party-mode/s323/architecture-*.md')):
    t=open(f).read();base=os.path.basename(f)
    for m in re.finditer(r'(?m)^## (F-\d+)\b',t):
        fid=m.group(1);nxt=t.find('\n## ',m.end());body=t[m.end():nxt if nxt!=-1 else len(t)]
        sec=re.search(r'(?m)^sections:\s*(.+)$',body);sev=re.search(r'(?m)^severity:\s*(.+)$',body) or re.search(r'(?m)^\*\*severity:\*\*\s*(.+)$',body)
        seat[(base,fid)]=(sec.group(1).strip() if sec else '?',sev.group(1).strip() if sev else '?')
consumed=set()
for p in '1234':
    t=open(f'_bmad-output/planning-artifacts/s323/shards/architecture-party-repair-p1/{p}.md').read()
    for m in re.finditer(r'architecture-([\w-]+\.md)#(F-\d+)',t): consumed.add(('architecture-'+m.group(1),m.group(2)))
un={k:v for k,v in seat.items() if k not in consumed}
print('TOTAL',len(seat),'CONSUMED',len(consumed),'UNCONSUMED',len(un),'(lead printed 122/61/61)')
def ents(path):
    t=open(path).read();out=[]
    for p in re.split(r'\n(?=### )',t):
        if not p.startswith('### '):continue
        h=p.split('\n',1)[0];g=lambda k:(re.search(r'^- %s: (.*)$'%k,p,re.M) or [None,None])[1]
        sid=h.split()[1];sev=re.search(r'— (MAJOR|MINOR|CRITICAL)\s*$',h)
        out.append(dict(id=sid,disp=(g('disposition') or '?').split()[0],edit=(g('edit') or ''),src=(g('source') or ''),sev=sev.group(1) if sev else '?',txt=p))
    return out
sr=ents('_bmad-output/planning-artifacts/s323/architecture-party-serial-repair-p1.md')
def kind(e):
    k='SP-X' if e['id'].startswith('SP-X') else e['id'].split('-')[0]
    return k
cov=collections.defaultdict(list)
for e in sr:
    for m in re.finditer(r'(architecture-[\w-]+\.md)#(F-\d+)',e['src']): cov[(m.group(1),m.group(2))].append(e)
res=collections.Counter();rows=[]
for k in sorted(un):
    es=[e for e in cov.get(k,[]) if not e['id'].startswith('FI-')] or cov.get(k,[])
    if not es: res['not cited by any serial entry']+=1;rows.append((k,'NONE',un[k][1]));continue
    def real(e): return e['disp']=='repaired' and e['edit'] and not e['edit'].startswith('n/a')
    tag='edit' if any(real(e) and not e['id'].startswith('FI-') for e in es) else ('escalated' if any(e['disp']=='escalated' for e in es) else 'no-edit('+'/'.join(sorted({kind(e) for e in es}))+')')
    res[tag]+=1;rows.append((k,tag,un[k][1]))
for k,v in res.most_common():print(' ',k,v)
sevc=collections.defaultdict(collections.Counter)
for k,tag,sev in rows:sevc[tag.split('(')[0]][sev.lower().split()[0] if sev else '?']+=1
for k,v in sevc.items():print('  severity by outcome',k,dict(v))
print('rows NONE/no-edit:')
for r in rows:
    if r[1] in('NONE',) or r[1].startswith('no-edit'):print('   ',r)
