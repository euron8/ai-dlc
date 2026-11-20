#!/usr/bin/env python3 -I
"""For each NEEDS_REWORK review: minutes from the reviewed commit to the next plan's frozen commit (= dev rework interval as committed),
grouped by tier (A/B/C as tiers.py). Uses plans.tsv commit times and git commit time of the reviewed sha. Sprint filter argv[1] (default all).
Control: intervals must be >= 0 (asserted count of negatives reported)."""
import os, sys, subprocess, collections, statistics as st
OUT = os.path.dirname(os.path.abspath(__file__)); G = '/Users/n8/git/graph'
sel = sys.argv[1] if len(sys.argv) > 1 else None
def ct(sha): return int(subprocess.run(['git', '-C', G, 'show', '-s', '--format=%ct', sha], capture_output=True, text=True).stdout.strip() or 0)
plans = collections.defaultdict(list)
for l in open(f'{OUT}/plans.tsv'):
    sp, story, gate, pas, sha, t, route, nonce = l.rstrip('\n').split('\t'); plans[(sp, story)].append((int(t), gate, int(pas), sha))
rev = {}
for l in open(f'{OUT}/reviews.tsv'):
    sp, story, kind, pas, sha, verdict, nf, cc, fn = l.rstrip('\n').split('\t'); rev[(sp, story, kind, pas)] = (sha, verdict)
res = collections.defaultdict(list); neg = 0
for l in open(f'{OUT}/rework_delta.tsv'):
    sp, story, kind, pas, verdict, cc, nxt, nc, nt, nr, files = l.rstrip('\n').split('\t')
    if sel and sp != sel: continue
    try: nc, nt = int(nc), int(nt)
    except ValueError: continue
    cls = {kv.split('=')[0] for kv in cc.split(',') if kv}
    tier = 'A' if ('CODE' in cls and nc) else 'B' if ('TEST' in cls and (nt or nc)) else 'C' if (not cls & {'CODE', 'TEST'} and not nc and not nt) else 'X'
    sha = [v for k, v in rev.items() if k[:4] == (sp, story, kind, pas)]
    if not sha: continue
    sha = sha[0][0]
    ch = plans.get((sp, story), [])
    i = next((i for i, c in enumerate(ch) if c[3].startswith(sha)), None)
    if i is None: continue
    nx = next((c for c in ch[i + 1:] if c[3] != ch[i][3]), None)
    if not nx: continue
    m = (nx[0] - ct(ch[i][3])) / 60
    if m < 0: neg += 1; continue
    res[tier].append(m)
for t in sorted(res): print('tier', t, 'n', len(res[t]), 'median min', round(st.median(res[t]), 1), 'mean', round(st.mean(res[t]), 1), 'sum h', round(sum(res[t]) / 60, 1))
print('negative intervals dropped:', neg)
