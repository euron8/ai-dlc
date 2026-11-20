import sys; sys.path.insert(0, '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/c10-tokens')
from lib import *
from datetime import datetime
s = int(sys.argv[1]) if len(sys.argv) > 1 else 323
R = load(s)
def ts(x): return datetime.fromisoformat(x.replace('Z', '+00:00')).timestamp()
def groups(gap=120):
    by = collections.defaultdict(list)
    for r in R: by[r['role']].append(r)
    G = []
    for role, v in by.items():
        v = sorted(v, key=lambda r: ts(r['start'])); cur = []
        for r in v:
            if cur and (ts(r['start']) - ts(cur[-1]['start']) > gap or r['step'] != cur[-1]['step']): G.append(cur); cur = []
            cur.append(r)
        if cur: G.append(cur)
    return G
G = [g for g in groups() if len(g) >= 2]
print('sprint', s, 'sibling groups (same role+step, starts chained within 120 s), size>=2:', len(G), 'spawns in them', sum(len(g) for g in G))
# (a) first-request sharing upper bound
tot = collections.defaultdict(float); n_later = collections.Counter(); alld = 0
for g in G:
    for i, r in enumerate(g):
        if i == 0 or not r['calls']: continue
        c = r['calls'][0]
        a, b, crp, cwp = r['p']
        brief = 0
        tl = r['comp'].get('tail') or []
        if tl: brief = tl[0][1][-1] / 2.5 if tl[0][0] == 'user' else 0
        # share what is cache-written beyond what already hits; brief itself stays fresh
        shareable = max(0, c[2] - brief)
        sav = shareable * (cwp - crp) / 1e6
        tot[r['role']] += sav; n_later[r['role']] += 1; alld += sav
print('(a) FIRST-REQUEST: later siblings if brief were byte-identical and prefix cached: $ upper bound per role')
for k, v in sorted(tot.items(), key=lambda kv: -kv[1]): print(f'   {k:24s} later members {n_later[k]:4d}  ${v:6.1f}')
print('   total $', round(alld, 1))
# (b) shared reads among siblings
dupd = collections.defaultdict(lambda: [0, 0, 0.0]); allb = [0, 0, 0.0]
for g in G:
    seen = {}
    for i, r in enumerate(sorted(g, key=lambda r: r['start'])):
        local = set()
        for t in r['tools']:
            nm, fp, off, lim, ln, er, ci = t
            if nm != 'Read' or ln is None or er: continue
            key = (fp, off, lim)
            if key in local: continue
            local.add(key)
            if key in seen:
                c = classify(fp); x = dupd[c]; d = readcost(r, ln / BPT, ci)
                x[0] += 1; x[1] += ln; x[2] += d
                allb[0] += 1; allb[1] += ln; allb[2] += d
            seen[key] = 1
print('(b) READS repeated by a later sibling of the same group (same path+offset+limit): class: n, MB, $')
for c, v in sorted(dupd.items(), key=lambda kv: -kv[1][2]): print(f'   {c:22s}{v[0]:6d} {v[1]/1e6:6.1f}MB ${v[2]:6.1f}')
print('   total', allb[0], round(allb[1] / 1e6, 1), 'MB $', round(allb[2], 1))
# by role of (b)
rr = collections.defaultdict(float)
for g in G:
    seen = {}
    for i, r in enumerate(sorted(g, key=lambda r: r['start'])):
        local = set()
        for t in r['tools']:
            nm, fp, off, lim, ln, er, ci = t
            if nm != 'Read' or ln is None or er: continue
            key = (fp, off, lim)
            if key in local: continue
            local.add(key)
            if key in seen: rr[r['role']] += readcost(r, ln / BPT, ci)
            seen[key] = 1
print('   by role', {k: round(v, 1) for k, v in sorted(rr.items(), key=lambda kv: -kv[1])[:8]})
# (c) per-group: common reads by ALL members
common_b = 0; common_d = 0.0
for g in G:
    if len(g) < 3: continue
    sets = []
    for r in g:
        sets.append({(t[1], t[2], t[3]) for t in r['tools'] if t[0] == 'Read' and t[4] and not t[5]})
    inter = set.intersection(*sets)
    sizes = {}
    for r in g:
        for t in r['tools']:
            if t[0] == 'Read' and t[4]: sizes[(t[1], t[2], t[3])] = t[4]
    b = sum(sizes[k] for k in inter)
    common_b += b * (len(g))
print('(c) bytes read by EVERY member of groups >=3 (summed over members): %.1f MB' % (common_b / 1e6))
