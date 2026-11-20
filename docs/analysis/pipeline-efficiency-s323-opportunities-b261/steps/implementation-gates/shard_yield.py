#!/usr/bin/env python3 -I
"""Critical/Important findings by seat type inside merged review files, s321-s323.
A merged file holds '## Shard: part N' / '## Shard: cross' sections (fan-out) or none (serial). Findings = '#### ' headings under a
'### Critical' or '### Important' heading, class from the Class: line. Output: per sprint, gate, seat type (part|cross|serial) x class.
Gate = filename (code-review|qa-validation). Control: a heading text 'ZZNOPE' count must be 0; files with >=1 shard section vs none must sum to all files."""
import re, glob, os, collections
G = '/Users/n8/git/graph/docs/reviews'
T = collections.defaultdict(collections.Counter); nfan = collections.Counter(); nser = collections.Counter(); zz = 0
for sp in (321, 322, 323):
    for f in sorted(glob.glob(f'{G}/s{sp}/*.md')):
        b = os.path.basename(f); m = re.search(r'(code-review|qa-validation)', b)
        if not m or 'merge-resolution' in b: continue
        L = open(f, errors='replace').read().split('\n'); seat = 'serial'; sev = None; fan = False
        for i, l in enumerate(L):
            h = re.match(r'## Shard: (\w+)', l)
            if h: seat = 'part' if h.group(1).startswith('part') else h.group(1); fan = True; sev = None; continue
            h = re.match(r'### (Critical|Important|Suggestions?)', l)
            if h: sev = h.group(1)[0]; continue
            if re.match(r'## ', l): sev = None; continue
            if l.startswith('#### ') and sev in ('C', 'I'):
                c = 'none'
                for j in range(i + 1, min(i + 4, len(L))):
                    mm = re.match(r'Class:\s*(\w+)', L[j])
                    if mm: c = mm.group(1); break
                T[(sp, m.group(1), seat)][c] += 1
                if 'ZZNOPE' in l: zz += 1
        (nfan if fan else nser)[(sp, m.group(1))] += 1
print('control ZZNOPE headings:', zz, '(must be 0)')
for k in sorted(T): print(k, dict(T[k]), 'total', sum(T[k].values()))
print('files with shard sections:', dict(nfan)); print('serial files:', dict(nser))
