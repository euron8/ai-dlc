#!/usr/bin/env python3 -I
"""Pass-1 verdict pairs (code-review p1, qa p1) per story, s321-s323, keyed on the review file's story stem (reviews.tsv col 9).
Counts: stories with both files; CR p1 APPROVED + QA p1 NR; CR NR + QA NR; both clean; plus 'stories with zero NEEDS_REWORK anywhere'.
Stems that are not stories (sprint-review-*, 'step3', 'fix') are excluded by requiring the stem to match ^\\d+([.-]\\d+)?$.  Control: stem 'zz' must be absent."""
import re, os, collections
OUT = os.path.dirname(os.path.abspath(__file__))
v = collections.defaultdict(dict); anyNR = collections.defaultdict(bool)
for l in open(f'{OUT}/reviews.tsv'):
    sp, story, kind, pas, sha, verdict, nf, cc, fn = l.rstrip('\n').split('\t')
    stem = re.match(r'(.+?)-(code-review|qa-validation)', fn).group(1).replace('.', '-')
    if not re.match(r'^\d+(-\d+)?$', stem): continue
    if verdict not in ('APPROVED', 'PASS'): anyNR[(sp, stem)] = True
    if int(pas) == 1: v[(sp, stem)][kind] = verdict
print('control zz:', sum(1 for k in v if k[1] == 'zz'), '(must be 0)')
for sp in ('321', '322', '323'):
    ks = [k for k in v if k[0] == sp]
    both = [k for k in ks if len(v[k]) == 2]
    ok = lambda x: x in ('APPROVED', 'PASS')
    a = [k for k in both if ok(v[k]['code-review']) and not ok(v[k]['qa-validation'])]
    b = [k for k in both if not ok(v[k]['code-review']) and not ok(v[k]['qa-validation'])]
    c = [k for k in both if ok(v[k]['code-review']) and ok(v[k]['qa-validation'])]
    d = [k for k in both if not ok(v[k]['code-review']) and ok(v[k]['qa-validation'])]
    print(f's{sp}: story stems {len(ks)}, with both p1 files {len(both)}: CR ok + QA NR {len(a)} {sorted(x[1] for x in a)}; both NR {len(b)}; both ok {len(c)}; CR NR + QA ok {len(d)}; stems with no NR anywhere {sum(1 for k in ks if not anyNR[k])}')
