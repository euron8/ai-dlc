import sys; sys.path.insert(0, '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/c10-tokens')
from lib import *
s = int(sys.argv[1]) if len(sys.argv) > 1 else 323
R = load(s)
BPT_ALL = 2.5
# component dollars of the fixed prefix
comp = {'tools(18.2KB)': 18224, 'system def(2.4KB)': 2350, 'env+skills list+advisor(34.7KB)': 34717, 'gitStatus+attribution(3.8KB)': 3800,
        'agent-listing+mcp instr (call 2 inject, 10.2KB)': 10195}
projdol = 0; compdol = collections.Counter(); nproj = 0
for r in R:
    n = len(r['calls'])
    if n == 0: continue
    a, b, cr_, cw_ = r['p']
    unit = (cw_ + (n - 1) * cr_) / 1e6
    for k, by in comp.items():
        if k.startswith('agent-listing') and n < 2: continue
        compdol[k] += by / BPT_ALL * (unit if not k.startswith('agent-listing') else (cw_ + (n - 2) * cr_) / 1e6)
    tl = r['comp'].get('tail') or []
    if tl and tl[0][1][0] > 20000:
        nproj += 1
        compdol['project block CLAUDE.md+rules+MEMORY.md (48.8KB; non-omit roles)'] += 48820 / BPT_ALL * unit
print('FIXED COMPONENT $ (s%d), bytes/token=%.1f assumed' % (s, BPT_ALL))
for k, v in compdol.most_common(): print(f'  {k:75s} ${v:7.1f}')
print('spawns with project block', nproj, 'of', len(R))

# role-file reads etc
print('\nITEM 3: Read results by class: n, MB, $ (cw + later cr)')
cls = collections.defaultdict(lambda: [0, 0, 0.0])
roleRead = collections.defaultdict(lambda: [0, 0, 0.0, 0])
dup = collections.defaultdict(lambda: [0, 0, 0.0])   # role -> [dup reads, dup bytes, dup $]
whole = collections.defaultdict(lambda: [0, 0, 0.0])
tool_by = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0, 0.0]))
for r in R:
    seen = {}
    for t in r['tools']:
        nm, fp, off, lim, ln, er, ci = t
        if ln is None: continue
        toks = ln / BPT
        d = readcost(r, toks, ci)
        x = tool_by[r['role']][nm]; x[0] += 1; x[1] += ln; x[2] += d
        if nm != 'Read': continue
        c = classify(fp); k = cls[c]; k[0] += 1; k[1] += ln; k[2] += d
        key = (fp, off, lim)
        if key in seen:
            y = dup[r['role']]; y[0] += 1; y[1] += ln; y[2] += d
        seen[key] = 1
        if off is None and lim is None and ln > 40000 and not er:
            w = whole[r['role']]; w[0] += 1; w[1] += ln; w[2] += d
for c, (n, b, d) in sorted(cls.items(), key=lambda kv: -kv[1][2]): print(f'  {c:22s}{n:6d} {b/1e6:7.1f}MB ${d:7.1f}')
print('\nTool-result bytes per role: top tools (n, MB, $)')
for role in sorted(tool_by, key=lambda ro: -sum(v[2] for v in tool_by[ro].values()))[:12]:
    tt = sorted(tool_by[role].items(), key=lambda kv: -kv[1][2])[:4]
    tot = sum(v[2] for v in tool_by[role].values())
    print(f'  {role:22s} tool-result $ {tot:6.1f} | ' + '; '.join(f'{k} n{v[0]} {v[1]/1e6:.1f}MB ${v[2]:.1f}' for k, v in tt))
print('\nDuplicate Read (same path+offset+limit twice in one spawn): role: dups, MB, $')
for role, v in sorted(dup.items(), key=lambda kv: -kv[1][2])[:8]: print(f'  {role:22s}{v[0]:5d} {v[1]/1e6:6.2f}MB ${v[2]:.1f}')
print('total dup', sum(v[0] for v in dup.values()), round(sum(v[2] for v in dup.values()), 1))
print('\nWhole-file Read (no offset/limit) of >40KB result: role: n, MB, $')
for role, v in sorted(whole.items(), key=lambda kv: -kv[1][2])[:8]: print(f'  {role:22s}{v[0]:5d} {v[1]/1e6:6.2f}MB ${v[2]:.1f}')
# role-file read: per role bytes and $
print('\nRole-file Read (mandatory first action): role: n spawns, median KB, $ per sprint')
for role in sorted({r['role'] for r in R}):
    v = []; dd = 0.0
    for r in R:
        if r['role'] != role: continue
        for t in r['tools']:
            if t[0] == 'Read' and '/team-roles/' in t[1] and t[4]:
                v.append(t[4]); dd += readcost(r, t[4] / BPT, t[6])
    if v: print(f'  {role:22s}{len(v):5d} {statistics.median(v)/1e3:6.1f}KB ${dd:7.1f}')
