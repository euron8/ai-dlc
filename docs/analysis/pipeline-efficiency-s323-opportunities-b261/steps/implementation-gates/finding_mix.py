#!/usr/bin/env python3 -I
"""Critical+Important finding mix by gate, sprint, pass (first vs later) from reviews.tsv (story_gates.py output).
reviews.tsv columns: sp story kind pass sha verdict nfind classes file.  Findings counted are '#### ' headings under Critical/Important only.
A file with nfind>0 but no Class line gives class 'none' (older sprints carry no Class lines; s321+ all do).
Also passes per story: distinct (story-from-filename, kind, pass) and stories clean through both gates on pass 1.
Controls: total rows must equal the sum of the per-kind rows; kind 'zz' = 0."""
import collections, re, os
OUT = os.path.dirname(os.path.abspath(__file__))
rows = [l.rstrip('\n').split('\t') for l in open(f'{OUT}/reviews.tsv')]
def stem(fn):
    m = re.match(r'(.+?)-(code-review|qa-validation)', fn); return m.group(1)
agg = collections.defaultdict(collections.Counter)
passes = collections.defaultdict(lambda: collections.defaultdict(set))
for sp, story, kind, pas, sha, verdict, nf, cc, fn in rows:
    pas = int(pas)
    key = (sp, kind, 'p1' if pas == 1 else 'p2+')
    agg[key]['files'] += 1
    if verdict not in ('APPROVED', 'PASS'): agg[key]['rework'] += 1
    for kv in filter(None, cc.split(',')):
        k, v = kv.split('='); agg[key][k] += int(v)
    passes[sp][kind].add((stem(fn), pas))
print('control kind zz:', sum(1 for r in rows if r[2] == 'zz'), '(must be 0); total rows', len(rows), 'sum of agg files', sum(c['files'] for c in agg.values()))
print('sprint kind pass | files, rework verdicts, C/I findings by class')
for k in sorted(agg):
    c = agg[k]; print(k, 'files', c['files'], 'rework', c['rework'], {x: c[x] for x in ('CODE', 'TEST', 'EVIDENCE', 'BOOKKEEPING', 'none') if c[x]})
for sp in sorted(passes):
    sts = {s for k in passes[sp] for s, _ in passes[sp][k]}
    print('sprint', sp, 'review files-stories', len(sts))
    for kind in passes[sp]:
        mp = collections.defaultdict(int)
        for s, p in passes[sp][kind]: mp[s] = max(mp[s], p)
        print('  ', kind, 'stories', len(mp), 'passes', sum(mp.values()), 'per story', round(sum(mp.values()) / len(mp), 2))
