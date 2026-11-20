"""B tables. Reads rows.pkl (build_true.py), MONO/spawns.jsonl, units.jsonl, owner.json. Prints to stdout (redirect to B_tables.txt)."""
import sys, json, pickle, collections, bisect
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from lib import *
rows = pickle.load(open(R + 'rows.pkl', 'rb'))
SP = (321, 322, 323)
P = {'opus': (4, 20, 0.2, 8), 'sonnet': (2, 10, 0.2, 4), 'haiku': (.1, .5, .01, .2), 'fable': (10, 50, .25, 20)}
P5 = {f: (i, o, cr, 1.25 * i) for f, (i, o, cr, cw) in P.items()}
def fam(m):
    m = (m or '?').lower()
    for k in ('opus', 'sonnet', 'haiku', 'fable'):
        if k in m: return k
    return 'local'
def usd(tok, Pp):
    t = 0.0
    for k, d in tok.items():
        f = fam(k.split('|', 1)[1])
        if f == 'local': continue
        i, o, cr, cw = Pp[f]
        t += (d[0] * i + d[3] * o + d[2] * cr + d[1] * cw) / 1e6
    return t

# ---------- stage totals
def stage(sp):
    S0 = sum(r['gap'] for r in rows if r['sp'] == sp)
    dup = sum(r['gap'] for r in rows if r['sp'] == sp and r['dup'])
    tail = sum(r['gap'] for r in rows if r['sp'] == sp and r['tail'] and not r['dup'])
    return S0, dup, tail
print('== stage totals, pipeline bucket, h (S0 old == steps.csv elapsed; relabel and operator-wait moves leave it unchanged)')
for sp in SP:
    S0, dup, tail = stage(sp)
    print(f's{sp}: old {S0/3600:7.2f}  fork copies {dup/3600:5.2f}  idle tail {tail/3600:5.2f}  corrected {(S0-dup-tail)/3600:7.2f}')

# ---------- class split old vs new
def classes(sp, new):
    a = collections.Counter()
    for r in rows:
        if r['sp'] != sp: continue
        if new and (r['dup'] or r['tail']): continue
        c = r['c_new'] if new else r['c_old']
        if c == 'a' and new: c = 'a:' + (r['sub'] or '?')
        a[c] += r['gap']
    return a
print('\n== class hours: old (active / op / agent) and new (lead model, tool, idle, wait-on-agents, op, long agent)')
for sp in SP:
    o = classes(sp, False); n = classes(sp, True)
    print(f's{sp}: OLD active {o["a"]/3600:5.2f} op {o["o"]/3600:5.2f} agent {o["g"]/3600:5.2f} | NEW model {n["a:model"]/3600:5.2f} tool {n["a:tool"]/3600:5.2f} idle(no agent) {n["a:idle"]/3600:5.2f} wait-agent<300s {n["a:waitag"]/3600:5.2f} op {n["o"]/3600:5.2f} long-agent {n["g"]/3600:5.2f}')

# ---------- spawn mapping
units = {}
for l in open(MONO + 'units.jsonl'):
    u = json.loads(l); units[u['unit']] = u
owner = json.load(open(MONO + 'owner.json'))
sp_rows = [json.loads(l) for l in open(MONO + 'spawns.jsonl')]
tid2 = {}
bysess = collections.defaultdict(list)
for r in rows:
    for n, i in r['tu']: tid2[i] = (r['s'], r['new'], r['g_new'])
    bysess[r['s']].append((r['t'], r['new'], r['g_new']))
for s in bysess: bysess[s].sort()
def true_of_spawn(sp_):
    u = units.get(sp_['unit']); tid = ((u or {}).get('meta') or {}).get('toolUseId')
    if tid in tid2: return tid2[tid][1], tid2[tid][2], 'direct'
    o = owner.get(tid)
    if o and o[0] in bysess:
        L = bysess[o[0]]; i = bisect.bisect_right([x[0] for x in L], o[2]) - 1
        if i >= 0: return L[i][1], L[i][2], 'time'
    return None, False, 'none'
def step_row(st, gate):
    if st in ('route', 'handoff', 'pre-step'): return 'route/handoff/pre-step'
    if st == 'implementation': return 'implementation gates' if gate else 'implementation build'
    return st if st in ORDERED else 'other steps (bug-investigation etc.)'
def old_row(st, gate=False):
    b = base(st)
    if b in ('route', 'handoff', 'pre-step'): return 'route/handoff/pre-step'
    if b == 'implementation': return 'implementation gates' if gate else 'implementation build'
    return b if b in ORDERED else 'other steps (bug-investigation etc.)'
ORDERED = {'carry-over-evaluation','requirements','architecture','ui-direction','stories-test-strategy','sprint-review','deploy-validate','retro'}
ROWS = ['carry-over-evaluation', 'requirements', 'architecture', 'ui-direction', 'stories-test-strategy', 'implementation build',
        'implementation gates', 'sprint-review', 'deploy-validate', 'retro', 'route/handoff/pre-step', 'other steps (bug-investigation etc.)']
def groupkey(st, gate):  # table row, with gate merged into the step except implementation
    return step_row(st, gate)

spawn_new = collections.defaultdict(lambda: collections.Counter())
spawn_old = collections.defaultdict(lambda: collections.Counter())
how = collections.Counter(); chk = collections.Counter()
for s_ in sp_rows:
    if s_['sprint'] not in SP: continue
    u = units.get(s_['unit'])
    if not u: continue
    bu = None
    new, g, h = true_of_spawn(s_); how[h] += 1
    d1 = usd(u['tok'], P); d5 = usd(u['tok'], P5)
    chk[s_['sprint']] += d1
    ostep = base(s_['step'])
    og = s_['step'].startswith('gate-validation')
    ok = old_row(s_['step'], og)
    nk = groupkey(new, g) if new else old_row(s_['step'], og)
    for dd, key, tag in ((spawn_old, ok, 'old'), (spawn_new, nk, 'new')):
        dd[(s_['sprint'], key)]['n'] += 1; dd[(s_['sprint'], key)]['d1'] += d1; dd[(s_['sprint'], key)]['d5'] += d5
print('\nspawn owner resolution', dict(how))
print('control sub $ (hour-rate cw) from units vs spawns.jsonl usd, per sprint:', {sp: (round(chk[sp], 1), round(sum(x['usd'] for x in sp_rows if x['sprint'] == sp), 1)) for sp in SP})

# ---------- per-step tables
def table(sp, new):
    T = collections.defaultdict(lambda: collections.Counter())
    seen = set()
    for r in rows:
        if r['sp'] != sp: continue
        if new and (r['dup'] or r['tail']): continue
        key = groupkey(r['new'], r['g_new']) if new else old_row(r['old'], r['g_old'])
        t = T[key]
        c = (r['c_new'] if new else r['c_old'])
        if new:
            if c == 'a': c = 'a:' + (r['sub'] or '?')
        t['el'] += r['gap']; t[c] += r['gap']
        if r['mid'] and (r['s'], r['mid']) not in seen: seen.add((r['s'], r['mid'])); t['calls'] += 1
        if r['cs']: t['comp'] += 1
    return T
def pr(sp):
    To, Tn = table(sp, False), table(sp, True)
    print(f'\n##### s{sp}   (h; $ = subagent list-price, hour-rate cache write | five-minute cache write)')
    print('step                      | elapsed old -> new | lead-own(model+tool) | idle | lead wait<300s on agents | operator wait old -> new | long agent wait old -> new | spawns old->new | sub$ old -> new (hr | 5min) | lead calls old->new | compactions old->new')
    tot = collections.Counter(); toto = collections.Counter()
    for key in ROWS:
        o, n = To[key], Tn[key]
        so, sn = spawn_old[(sp, key)], spawn_new[(sp, key)]
        if not (o['el'] or n['el'] or so['n'] or sn['n']): continue
        print(f'{key:25} | {o["el"]/3600:5.1f} -> {n["el"]/3600:5.1f} | {(n["a:model"]+n["a:tool"])/3600:5.1f} | {n["a:idle"]/3600:4.1f} | {n["a:waitag"]/3600:5.1f} | {o["o"]/3600:5.1f} -> {n["o"]/3600:5.1f} | {o["g"]/3600:5.1f} -> {n["g"]/3600:5.1f} | {so["n"]:4d} -> {sn["n"]:4d} | {so["d1"]:6.1f} -> {sn["d1"]:6.1f} ({sn["d1"]:6.1f} | {sn["d5"]:6.1f}) | {o["calls"]:5d} -> {n["calls"]:5d} | {o["comp"]:3d} -> {n["comp"]:3d}')
        for k in ('el', 'a:model', 'a:tool', 'a:idle', 'a:waitag', 'o', 'g', 'calls', 'comp'): tot[k] += n[k]
        for k in ('el', 'o', 'g', 'calls', 'comp'): toto[k] += o[k]
        tot['n'] += sn['n']; toto['n'] += so['n']; tot['d1'] += sn['d1']; toto['d1'] += so['d1']; tot['d5'] += sn['d5']
    print(f'{"TOTAL":25} | {toto["el"]/3600:5.1f} -> {tot["el"]/3600:5.1f} | {(tot["a:model"]+tot["a:tool"])/3600:5.1f} | {tot["a:idle"]/3600:4.1f} | {tot["a:waitag"]/3600:5.1f} | {toto["o"]/3600:5.1f} -> {tot["o"]/3600:5.1f} | {toto["g"]/3600:5.1f} -> {tot["g"]/3600:5.1f} | {toto["n"]:4d} -> {tot["n"]:4d} | {toto["d1"]:6.1f} -> {tot["d1"]:6.1f} ({tot["d1"]:6.1f} | {tot["d5"]:6.1f}) | {toto["calls"]:5d} -> {tot["calls"]:5d} | {toto["comp"]:3d} -> {tot["comp"]:3d}')
for sp in SP: pr(sp)
