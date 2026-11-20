import sys; sys.path.insert(0, '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/c10-tokens')
from lib import *
s = int(sys.argv[1]) if len(sys.argv) > 1 else 323
R = load(s)
print('sprint', s, 'spawns', len(R), '$', round(sum(r['c'] for r in R), 1))
by = collections.defaultdict(list)
for r in R: by[r['role']].append(r)
tot_fixed = 0
print('\nITEM 2: fixed first-request charge. fixed$ = F0 x (cw + (n-1) x cr)')
print('role n  medF0  totF0M  fixed$  role$  share  | nonbrief-bytes: tools sys skills+env projblk')
rows = []
for role, v in sorted(by.items(), key=lambda kv: -sum(r['c'] for r in kv[1])):
    f0s = []; fixed = 0; fcw = 0; fcr = 0
    for r in v:
        if not r['calls']: continue
        c0 = r['calls'][0]; F = c0[1] + c0[2] + c0[3]; f0s.append(F)
        a, b, cr_, cw_ = r['p'][0], r['p'][1], r['p'][2], r['p'][3]
        n = len(r['calls'])
        fixed += F * (cw_ + (n - 1) * cr_) / 1e6
    rc = sum(r['c'] for r in v)
    tot_fixed += fixed
    cm = [r['comp'] for r in v if r['comp'].get('sys')]
    proj = statistics.median([c['tail'][0][1][0] if c.get('tail') and c['tail'][0][1][0] > 20000 else 0 for c in cm]) if cm else 0
    print(f"{role:24s}{len(v):4d} {statistics.median(f0s):7.0f} {sum(f0s)/1e6:6.1f}M ${fixed:7.1f} ${rc:7.1f} {100*fixed/rc:4.0f}%  tools {statistics.median([c['tools_bytes'] for c in cm]):6.0f} sys {statistics.median([sum(c['sys']) for c in cm]):5.0f} projblk {proj:6.0f}")
print('total fixed $', round(tot_fixed, 1))
