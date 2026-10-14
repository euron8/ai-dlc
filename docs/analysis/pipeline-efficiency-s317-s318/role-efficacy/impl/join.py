import json, re, collections, sys
P = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/spawns.jsonl'
rows = [json.loads(l) for l in open(P)]
STORIES = {317: ['1.1','1.2','1.3','1.4','1.5','1.6','1.7','2.1','2.2','2.3','2.4','2.5','2.6','2.7','3.1','3.2','4.1','4.2a','4.2b','4.3a','4.3b'],
           318: ['1.1','1.2','1.3','1.4','1.5','2.1','2.2','2.3','2.4','2.5','2.6','2.7','2.8']}
IMPL_ROLES = {'dev','dev-escalated','protected-path-editor','code-reviewer','code-reviewer-escalated','qa','gate-adjudicator','remediator','tea'}
rx = re.compile(r'(?<![\d.])([1-4])[.\-]([1-8])([ab])?(?![\d])')
def sid(r):
    d = r['description'] or ''
    m = rx.findall(d)
    c = [a+'.'+b+c for a,b,c in m if a+'.'+b+c in STORIES[r['sprint']]]
    return c[0] if c else None
implsteps = lambda s: s in ('implementation','deploy-validate') or s.startswith('gate-validation[impl')
out = []
for r in rows:
    r['story'] = sid(r)
    r['impl'] = implsteps(r['step'])
    out.append(r)
json.dump(out, open(sys.argv[1],'w'))
# join rate
for sp in (317,318):
    imp = [r for r in out if r['sprint']==sp and r['impl']]
    j = [r for r in imp if r['story']]
    print(sp, 'impl-step spawns', len(imp), 'joined', len(j), '%.0f%%' % (100*len(j)/len(imp)))
    byrole = collections.Counter((r['role'], bool(r['story'])) for r in imp)
    print('  ', sorted(byrole.items()))
    # dev spawns in NON-impl steps whose description names a story
    other = [r for r in out if r['sprint']==sp and not r['impl'] and r['role'] in ('dev','dev-escalated')]
    print('   non-impl-step dev spawns', len(other), collections.Counter(r['step'] for r in other))
    for r in other[:6]: print('     e.g.', r['step'], r['description'][:70])
