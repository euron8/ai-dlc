#!/usr/bin/env python3 -I
"""Tier each NEEDS_REWORK review (rework_delta.tsv) by what the finding classes were and what the next delta changed.
Tier A: any CODE-class finding AND next delta has >=1 code path.  Tier B: any TEST-class (no A) AND next delta has >=1 test or code path.
Tier C: only EVIDENCE/BOOKKEEPING/none findings and next delta has 0 code, 0 test paths (records only).  Tier X: everything else
(class said code/test but the next delta shows none, or a mixed case) - listed. Control: rows with verdict APPROVED/PASS must be absent (asserted)."""
import os, collections
OUT = os.path.dirname(os.path.abspath(__file__))
T = collections.defaultdict(collections.Counter); X = []
for l in open(f'{OUT}/rework_delta.tsv'):
    sp, story, kind, pas, verdict, cc, nxt, nc, nt, nr, files = l.rstrip('\n').split('\t')
    assert verdict not in ('APPROVED', 'PASS')
    cls = {kv.split('=')[0] for kv in cc.split(',') if kv}
    try: nc, nt = int(nc), int(nt)
    except ValueError: T[(sp, kind[:2])]['no-next'] += 1; continue
    if 'CODE' in cls and nc: t = 'A-code-changed'
    elif 'TEST' in cls and (nt or nc): t = 'B-test-changed'
    elif not (cls & {'CODE', 'TEST'}) and nc == 0 and nt == 0: t = 'C-records-only'
    else: t = 'X-other'; X.append((sp, story, kind[:2], pas, cc, nxt, nc, nt))
    T[(sp, kind[:2])][t] += 1
for k in sorted(T): print(k, dict(T[k]))
tot = collections.Counter()
for k in T: tot.update(T[k])
print('TOTAL s321-s323', dict(tot))
print('X rows:'); [print(' ', x) for x in X]
