import json,re,collections
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/'
rows=[json.loads(l) for l in open(D+'out/spawns.jsonl')]
P=('carry-over-evaluation','requirements','architecture')
def phase(s):
    for p in P:
        if s==p or s==f'gate-validation[{p}]': return p
def stage(r):
    d=(r['description'] or '').lower(); role=r['role']
    if r['step'].startswith('gate-validation') or role=='gate-adjudicator' or 'gate' in d or 'check 17' in d or 'provenance' in d: return '9 gate'
    if role=='analyst' or 'context digest' in d or 'draft' in d and role=='analyst': return '0 author'
    if 'authoring' in d or 'author brief' in d or 'readiness' in d or 'render spec' in d: return '0 author'
    if role in('pm','architect','dev','tea','sm') and ('party' in d or 'seat' in d or 'spine review' in d): return '1 party'
    if role=='remediator' and ('party' in d or 'spine repair' in d or 'refused deriv' in d): return '2 party-repair'
    if role=='adversary' and 'elicitation' in d: return '3 elicit'
    if role=='remediator' and ('elicitation' in d or 'ad-10' in d or 'volatile wc' in d): return '4 elicit-repair'
    m=re.search(r'(?:pass|p)\s*-?(\d)',d)
    if role=='adversary':
        if 'verify pass' in d: return '5 adv-p3'
        if m: return '5 adv-p'+m.group(1)
        return '5 adv-p?'
    if role=='remediator':
        if 'pre-adversarial' in d or 'co-s318 pool' in d: return '4 elicit-repair'
        if 'residue' in d: return '6 repair-residue'
        if m: return '6 repair-p'+m.group(1)
        return '6 repair-?'
    if role=='pm-escalated': return '0 author'
    return '? '+role
agg=collections.defaultdict(lambda:[0,0.0,0.0,collections.Counter()])
for r in rows:
    p=phase(r['step'])
    if not p: continue
    k=(r['sprint'],p,stage(r)); a=agg[k]; a[0]+=1;a[1]+=r['usd'] or 0;a[2]+=r['minutes'] or 0;a[3][r['role']]+=1
tot=collections.defaultdict(float)
for k in sorted(agg):
    a=agg[k]; tot[k[:2]]+=a[1]
    print(k,a[0],round(a[1],2),round(a[2],1),dict(a[3]))
for k,v in sorted(tot.items()): print('TOTAL',k,round(v,2))
