#!/usr/bin/env python3 -I
"""Gate 3 (implementation gate adjudication): per-check verdict table over graph s321-s323.
Reads graph's committed verdict files (working tree of /Users/n8/git/graph, read only).
Usage: python3 -I g3_checks.py   -> prints per-sprint pass counts, per-check PASS/FAIL, FAIL list with series id.
Control: a gate_type that cannot exist (NOPE) must give 0 files."""
import json, glob, os, collections, re
G = '/Users/n8/git/graph/_bmad-output/implementation-artifacts'
def load(sprint, gtype):
    out = []
    for p in sorted(glob.glob(f'{G}/s{sprint}/gate-adjudication/*.verdict.json')):
        try: d = json.load(open(p))
        except Exception as e: print('BAD', p, e); continue
        if d.get('gate_type') == gtype: out.append((p, d))
    return out
print('control NOPE files:', len(load(323, 'NOPE')), '(must be 0)')
tot = collections.defaultdict(lambda: collections.Counter())
fails = []
for sp in (321, 322, 323):
    files = load(sp, 'implementation')
    nchk = sum(len(d['verdicts']) for _, d in files)
    nfail = sum(1 for _, d in files for v in d['verdicts'] if v['verdict'] != 'PASS')
    wfail = sum(1 for _, d in files if any(v['verdict'] != 'PASS' for v in d['verdicts']))
    print(f's{sp}: implementation verdict files {len(files)}, checks {nchk}, non-PASS checks {nfail}, files with a non-PASS {wfail}')
    for p, d in files:
        for v in d['verdicts']:
            tot[sp][(v['check_id'], v['verdict'])] += 1
            if v['verdict'] != 'PASS':
                fails.append((sp, os.path.basename(p), d['gate_series_id'], v['check_id'], v['verdict'], re.sub(r'\s+', ' ', v['evidence'])[:260]))
ids = sorted({k[0] for sp in tot for k in tot[sp]}, key=lambda x: (int(re.match(r'\d+', x).group()), x))
print('\ncheck | s321 P/F | s322 P/F | s323 P/F')
for i in ids:
    row = []
    for sp in (321, 322, 323):
        p = tot[sp][(i, 'PASS')]; f = sum(c for (cid, v), c in tot[sp].items() if cid == i and v != 'PASS')
        row.append(f'{p}/{f}')
    print(i, ' | '.join(row))
print('\nNON-PASS rows:')
for r in fails: print(r)
