#!/usr/bin/env python3 -I
"""Join each NEEDS_REWORK review (reviews.tsv) to the delta that followed it (plans.tsv chain; git diff via story_gates.py's classes).
Run story_gates.py first (writes plans.tsv, reviews.tsv). Output rework_delta.tsv:
 sp story kind pass verdict findings(class counts) next_plan n_code n_test n_rec code_files.
Control: a review with verdict APPROVED/PASS must never appear (must be 0 rows with those verdicts)."""
import os, re, subprocess, collections
OUT = os.path.dirname(os.path.abspath(__file__)); G = '/Users/n8/git/graph'
def git(*a): return subprocess.run(['git', '-C', G] + list(a), capture_output=True, text=True).stdout
def cls(p):
    if re.match(r'(docs|_bmad-output|test-results)/', p) or re.search(r'\.(md|txt|log|out)$', p): return 'rec'
    if re.search(r'(^|/)tests?/|(^|/)test_[^/]*$|\.(test|spec)\.|(^|/)conftest\.py$|_test\.py$', p): return 'test'
    return 'code'
plans = [l.rstrip('\n').split('\t') for l in open(f'{OUT}/plans.tsv')]
P = collections.defaultdict(list)
for sp, story, gate, pas, sha, t, route, nonce in plans: P[(sp, story)].append((int(t), gate, int(pas), sha))
for k in P: P[k].sort()
rows = []
for l in open(f'{OUT}/reviews.tsv'):
    sp, story, kind, pas, sha, verdict, nf, cc, fn = l.rstrip('\n').split('\t')
    if verdict in ('APPROVED', 'PASS') or not sha: continue
    chain = P.get((sp, story), [])
    idx = [i for i, c in enumerate(chain) if c[3].startswith(sha)]
    if not idx: rows.append((sp, story, kind, pas, verdict, cc, 'NOPLAN', '', '', '', '')); continue
    i = idx[0]
    # next plan with a different sha
    nxt = next((c for c in chain[i + 1:] if c[3] != chain[i][3]), None)
    if not nxt: rows.append((sp, story, kind, pas, verdict, cc, 'NONEXT', '', '', '', '')); continue
    nm = [x for x in git('diff', '--name-only', chain[i][3], nxt[3]).split('\n') if x]
    c = collections.Counter(cls(x) for x in nm)
    rows.append((sp, story, kind, pas, verdict, cc, f'g{nxt[1]}p{nxt[2]}', c['code'], c['test'], c['rec'], ';'.join(x for x in nm if cls(x) == 'code')[:120]))
with open(f'{OUT}/rework_delta.tsv', 'w') as o:
    for r in rows: o.write('\t'.join(map(str, r)) + '\n')
print('rows', len(rows), 'control APPROVED/PASS rows:', sum(1 for r in rows if r[4] in ('APPROVED', 'PASS')), '(must be 0)')
