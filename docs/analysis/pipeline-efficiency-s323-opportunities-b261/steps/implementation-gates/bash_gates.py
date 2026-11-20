#!/usr/bin/env python3 -I
"""Bash calls of the gate seats and the lead's gate-transition.sh calls, s321-s323.
Input: the other hand's finished corpus hand-s323late/out/bash.jsonl (read only; fields kind,unit,sprint,name,lat,err,cmd) joined to
MONO/spawns.jsonl (unit -> role, step, description). Not paired-by-id here (corpus already holds paired rows with err flag): rows with err=True are dropped.
Controls: role 'zz-nope' must give 0 rows; the gate-transition count per gate must sum to the all-gate total."""
import json, re, collections, sys
SC = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/'
spawn = {}
for l in open(SC + 'MONO/spawns.jsonl'):
    r = json.loads(l); spawn[r['unit']] = r
rows = [json.loads(l) for l in open(SC + 'hand-s323late/out/bash.jsonl')]
print('bash rows', len(rows), 'kinds', collections.Counter(r['kind'] for r in rows))
# 1. lead gate-transition calls
gt = collections.defaultdict(lambda: [0, 0.0, 0])
tot = 0
for r in rows:
    if r['kind'] != 'lead' or r['sprint'] not in (321, 322, 323) or 'gate-transition.sh' not in r['cmd']: continue
    m = re.search(r'gate-transition\.sh\s+(\S+)\s+(1|2|3|close)\b', r['cmd'])
    g = m.group(2) if m else 'other'
    k = (r['sprint'], g)
    if r['err']: gt[k][2] += 1; continue
    gt[k][0] += 1; gt[k][1] += r['lat'] or 0; tot += 1
print('lead gate-transition.sh calls (ok) per sprint/gate: n, mean s, total min, errored')
for k in sorted(gt): print(k, gt[k][0], round(gt[k][1] / max(gt[k][0], 1), 1), round(gt[k][1] / 60, 1), gt[k][2])
print('sum ok', tot, 'check', sum(v[0] for v in gt.values()))
# 2. seat bash: full-suite runs by role
FULL = re.compile(r'pytest-footprint-watchdog|pytest[^|;&]*(rebalancer/tests|server/|tests)\b|vitest run|npm (run )?test|ci-local\.sh|--record-run')
seat = collections.defaultdict(lambda: [0, 0.0, 0])
for r in rows:
    if r['kind'] != 'sub' or r['sprint'] not in (321, 322, 323) or r['err']: continue
    sp = spawn.get(r['unit'])
    if not sp: continue
    role = sp['role']
    k = (r['sprint'], role)
    seat[k][0] += 1; seat[k][1] += r['lat'] or 0
    if FULL.search(r['cmd']): seat[k] = [seat[k][0], seat[k][1], seat[k][2] + 1]
print('\nseat bash calls (ok): sprint role n_calls bash_min full-suite-ish calls (watchdog|pytest dirs|vitest|ci-local|--record-run)')
for k in sorted(seat):
    if k[1] in ('code-reviewer', 'code-reviewer-escalated', 'qa', 'gate-adjudicator', 'dev', 'dev-escalated'):
        print(k, seat[k][0], round(seat[k][1] / 60, 1), seat[k][2])
print('control zz-nope rows:', sum(1 for r in rows if r['kind'] == 'sub' and (spawn.get(r['unit']) or {}).get('role') == 'zz-nope'), '(must be 0)')
