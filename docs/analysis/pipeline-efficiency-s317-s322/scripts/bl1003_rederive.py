"""BL-1003 item 3: every reading BL-1003 lists, re-derived old extractor against fixed extractor at its OWN window.

usage: python3 -I bl1003_rederive.py WORK [--build] [--graph <graph repo>] [--only members,w1,w2,w3]

WORK holds one extract per (side, window), named <side>-<window with ':' and '-' dropped>, e.g. old-20261111T103000Z.
--build makes any that are missing: EXTRACT_WIN_END=<window> python3 -I <extract.py> OUT (stderr kept as
OUT/extract.stderr), then the s317-s318 spawns.py and analyze.py. The OLD extract.py is
`git show e3cb7710f:docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py` (the parent of 0.1100.0, which
added the gate terminator); the NEW one is this tree's. Every other script is this tree's, on both sides.

Windows (each reading at the window it was recorded at):
  W1 2026-11-11T10:30:00Z  BL-808 b255, BL-397 b255 F4, BL-510 Outcome measured and its archived copy under BL-507,
                           BL-975, BL-972's per-ask step column (ask_split.py), out/ask_split.txt, out/poles.txt,
                           out/seats_adversary.txt
  W2 2026-11-09T00:00:00Z  BL-811's archived s319 cross counts (cross_spawns.py), the sprint-review/deploy-validate
                           s321 document (sr_dv_yield.py) and elicitation_yield.py
  W3 2026-11-12T18:53:06Z  item 2's table, and the LEFT-events list: every lead-side reading (segs, hooks, tools)
                           per (sprint, step) that differs between the two extractors
BL-812's readings (b255, b256, Projection (c)) are re-derived by their own unit, not here; the member list marks them.

Every section prints its control first; a failed control makes the exit status 1. No repo root is exit 2: the root is
$AI_DLC_PROJECT_ROOT when set (it must carry docs/backlog.md), else the nearest directory above this script carrying
.git and docs/backlog.md.
"""
import collections, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def no_root(msg):
    # Exit 2, not 1: "cannot run" must stay distinct from "a control failed".
    print('bl1003_rederive: ' + msg, file=sys.stderr)
    sys.exit(2)


def resolve_root(d):
    # AI_DLC_PROJECT_ROOT, when set, is the root, and it must carry docs/backlog.md. Otherwise walk UP for a
    # marker, never a fixed count of '..' hops (the rule ai_dlc_resolve_root() in
    # core/scripts/validate-provenance-block.sh applies): the nearest directory carrying both a
    # .git entry and docs/backlog.md is the repo root, in the main checkout and in a worktree alike.
    env = os.environ.get('AI_DLC_PROJECT_ROOT')
    if env:
        if os.path.isfile(os.path.join(env, 'docs', 'backlog.md')):
            return os.path.abspath(env)
        no_root('AI_DLC_PROJECT_ROOT=' + env + ' carries no docs/backlog.md')
    while d and d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, '.git')) and os.path.isfile(os.path.join(d, 'docs', 'backlog.md')):
            return d
        d = os.path.dirname(d)
    no_root('no repo root (.git and docs/backlog.md) above ' + HERE)


REPO = resolve_root(HERE)
B = os.path.join(REPO, 'docs/analysis/pipeline-efficiency-s317-s320/scripts')
A = os.path.join(REPO, 'docs/analysis/pipeline-efficiency-s317-s318/scripts')
C = HERE
OUTD = os.path.join(REPO, 'docs/analysis/pipeline-efficiency-s317-s322/out')
OLD_SHA = 'e3cb7710f'
W1, W2, W3 = '2026-11-11T10:30:00Z', '2026-11-09T00:00:00Z', '2026-11-12T18:53:06Z'
BAD = []

def tag(w):
    return w.replace(':', '').replace('-', '')

def out(work, side, w):
    return os.path.join(work, side + '-' + tag(w))

def build(work, side, w):
    o = out(work, side, w)
    if os.path.exists(os.path.join(o, 'steps.csv')):
        return
    os.makedirs(o, exist_ok=True)
    ex = os.path.join(B, 'extract.py')
    if side == 'old':
        ex = os.path.join(work, 'extract.old.py')
        if not os.path.exists(ex):
            src = subprocess.run(['git', '-C', REPO, 'show', OLD_SHA + ':docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py'],
                                 capture_output=True, text=True, check=True).stdout
            open(ex, 'w').write(src)
    env = dict(os.environ, EXTRACT_WIN_END=w)
    with open(os.path.join(o, 'extract.stderr'), 'w') as fe:
        subprocess.run([sys.executable, '-I', ex, o], env=env, check=True, stdout=subprocess.DEVNULL, stderr=fe)
    for s in ('spawns.py', 'analyze.py'):
        subprocess.run([sys.executable, '-I', os.path.join(A, s), o], check=True, stdout=subprocess.DEVNULL)

def run(script, args, w):
    env = dict(os.environ, EXTRACT_WIN_END=w)
    r = subprocess.run([sys.executable, '-I', script] + args, env=env, capture_output=True, text=True)
    return r.stdout + r.stderr

def control(ok, what):
    print(f"CONTROL {'OK' if ok else 'FAIL'}: {what}")
    if not ok:
        BAD.append(what)

def diff_lines(a, b):
    la, lb = a.splitlines(), b.splitlines()
    return [x for x in la if x not in set(lb)], [x for x in lb if x not in set(la)]

# ---------------------------------------------------------------- the member list
def members():
    t = open(os.path.join(REPO, 'docs/backlog.md')).read()
    i = t.index('## BL-1003 ')
    e = t.index('\n## ', i + 5)
    body = t[i:e]
    def bullets(start, stop):
        s = body.index(start); x = body.index(stop, s)
        return [l[2:] for l in body[s:x].splitlines() if l.startswith('- ')]
    sus = bullets('Suspect readings.', 'Not suspect')
    it3 = bullets('**Item 3, OPEN.**', 'Whether the 14:00Z')
    print(f"== members: {len(sus)} suspect-reading bullets, {len(it3)} item-3 bullets")
    for k, l in [('S', x) for x in sus] + [('I', x) for x in it3]:
        owner = 'U5 (BL-812)' if l.startswith('BL-812') else 'here'
        print(f"   {k} [{owner}] {l[:150]}")
    control(len(sus) > 0 and len(it3) > 0, f"the member list parses non-empty ({len(sus)} + {len(it3)})")

# ---------------------------------------------------------------- W1
def w1(work):
    o, n = out(work, 'old', W1), out(work, 'new', W1)
    print(f"== W1 {W1}")
    # implementation group (BL-808, BL-397, BL-510, BL-507's archived copy): joint_impl.py prints and controls it
    r = subprocess.run([sys.executable, '-I', os.path.join(C, 'joint_impl.py'), o, n], capture_output=True, text=True)
    for l in r.stdout.splitlines():
        if l.startswith(('s3', 'DIFFER', 'CONTROL')):
            print('   joint_impl: ' + l)
    control(r.returncode == 0, 'joint_impl.py reproduces the b255 figures on the old extract (exit 0)')
    roll_old = run(os.path.join(B, 'roll.py'), [o], W1)
    control(roll_old == open(os.path.join(OUTD, 'roll.txt')).read(), 'old roll.py output == committed out/roll.txt (BL-397, BL-510 cite it)')
    # BL-975: the 2026-11-09 17:50Z-18:00Z s322 dispatches and the four dead seats it names, by agent id
    dead = {'agent-ac4b451217711d991', 'agent-af5fbf05bbbf3f481', 'agent-a35c2f46ce6da29b6', 'agent-a4993bb965978e3cc'}
    so = {json.loads(l)['unit']: json.loads(l) for l in open(os.path.join(o, 'spawns.jsonl'))}
    sn = {json.loads(l)['unit']: json.loads(l) for l in open(os.path.join(n, 'spawns.jsonl'))}
    sel = sorted((u for u, s in so.items() if '2026-11-09T17:50' <= s['start'] < '2026-11-09T18:00'), key=lambda u: so[u]['start'])
    print(f"   BL-975: {len(sel)} spawns started 2026-11-09T17:50Z-18:00Z")
    for u in sel:
        print(f"   BL-975 {u} {so[u]['start'][:19]}Z {so[u]['role']} '{so[u]['description'][:40]}' old={so[u]['step']} new={sn.get(u, {}).get('step')}"
              + (' DEAD-SEAT' if u in dead else ''))
    control(dead <= set(sel), 'BL-975: all four dead-seat agent ids are in the selection')
    # every spawn label change at W1, all sprints (owner rows of spawns.jsonl)
    ch = collections.Counter((so[u]['sprint'], so[u]['step'], sn[u]['step']) for u in so if u in sn and so[u]['step'] != sn[u]['step'])
    print(f"   spawn label changes at W1: {sum(ch.values())} of {len(so)} spawns; old units {len(so)}, new units {len(sn)}")
    for (sp, a, b), c in sorted(ch.items()):
        print(f"      s{sp} {a} -> {b}: {c}")
    # ask_split.py (BL-972's per-ask step column and the committed out/ask_split.txt)
    ao, an = run(os.path.join(C, 'ask_split.py'), [o], W1), run(os.path.join(C, 'ask_split.py'), [n], W1)
    control(ao == open(os.path.join(OUTD, 'ask_split.txt')).read(), 'old ask_split.py output == committed out/ask_split.txt')
    def asks(txt):
        rows = {}
        hdr = None
        for l in txt.splitlines():
            f = l.split('\t')
            if f[0] == 'sprint':
                hdr = f; continue
            if hdr and len(f) == len(hdr) and re.match(r's3\d\d$', f[0]):
                rows[f[1]] = dict(zip(hdr, f))
        return rows
    ra, rb = asks(ao), asks(an)
    control(len(ra) > 0 and set(ra) == set(rb), f'ask rows parse on both sides ({len(ra)} old, {len(rb)} new)')
    moved = [k for k in ra if ra[k]['step'] != rb.get(k, {}).get('step')]
    print(f"   ask_split: {len(moved)} of {len(ra)} asks change step column")
    for k in moved:
        print(f"      {ra[k]['sprint']} {k} {ra[k]['step']} -> {rb[k]['step']} ({ra[k]['wait_min']} min, {ra[k]['bucket']})")
    other = sum(1 for k in ra if {c: v for c, v in ra[k].items() if c != 'step'} != {c: v for c, v in rb[k].items() if c != 'step'})
    print(f"   ask_split: {other} asks change any column other than step")
    da, db = diff_lines(ao, an)
    TAB = '\t'
    sa, sb = [x for x in da if TAB not in x], [x for x in db if TAB not in x]
    print(f"   ask_split summary lines: {len(sa)} old-only, {len(sb)} new-only")
    for x in sa: print('      old: ' + x[:220])
    for x in sb: print('      new: ' + x[:220])
    # poles.py and seats.py adversary (out/poles.txt, out/seats_adversary.txt)
    for name, script, args, f in (('poles', 'poles.py', [], 'poles.txt'), ('seats_adversary', 'seats.py', ['adversary', '318,319,320,321,322'], 'seats_adversary.txt')):
        po, pn = run(os.path.join(C, script), [o] + args, W1), run(os.path.join(C, script), [n] + args, W1)
        control(po == open(os.path.join(OUTD, f)).read(), f'old {script} output == committed out/{f}')
        da, db = diff_lines(po, pn)
        print(f"   {name}: {len(da)} old-only lines, {len(db)} new-only lines")
        for x in da: print('      old: ' + x[:200])
        for x in db: print('      new: ' + x[:200])

# ---------------------------------------------------------------- W2
def w2(work, graph):
    o, n = out(work, 'old', W2), out(work, 'new', W2)
    print(f"== W2 {W2}")
    for name, script, args in (('cross_spawns', 'cross_spawns.py', []), ('cross_spawns --broad', 'cross_spawns.py', ['--broad']),
                               ('sr_dv_yield', 'sr_dv_yield.py', [graph]), ('elicitation_yield', 'elicitation_yield.py', [graph])):
        po, pn = run(os.path.join(C, script), [o] + args, W2), run(os.path.join(C, script), [n] + args, W2)
        da, db = diff_lines(po, pn)
        print(f"   {name}: {len(po.splitlines())} lines; {len(da)} old-only, {len(db)} new-only")
        for x in da: print('      old: ' + x[:200])
        for x in db: print('      new: ' + x[:200])
        if name == 'cross_spawns':
            control('gate-validation[sprint-review]' in po and re.search(r'gate-validation\[sprint-review\]\D{0,6}30\b', po) is not None
                    and re.search(r'gate-validation\[stories-test-strategy\]\D{0,6}6\b', po) is not None,
                    "BL-811's s319 cross counts by step reproduce on the old extract (gate-validation[sprint-review] 30, gate-validation[stories-test-strategy] 6)")
            print('      ' + ' | '.join(l for l in po.splitlines() if 's319' in l)[:400])
        if name == 'sr_dv_yield':
            control('169' in po and '209.09' in po, 'sr_dv_yield old carries the document\'s 169 spawns and $209.09')
    so = {json.loads(l)['unit']: json.loads(l)['step'] for l in open(os.path.join(o, 'spawns.jsonl'))}
    sn = {json.loads(l)['unit']: json.loads(l)['step'] for l in open(os.path.join(n, 'spawns.jsonl'))}
    print(f"   spawn label changes at W2: {sum(1 for u in so if sn.get(u) != so[u])} of {len(so)}")

# ---------------------------------------------------------------- W3: the LEFT-events list
def w3(work):
    o, n = out(work, 'old', W3), out(work, 'new', W3)
    print(f"== W3 {W3}")
    want = {317: (27, 18, 9, 1), 318: (16, 10, 6, 2), 319: (23, 13, 10, 0), 320: (18, 15, 3, 0), 321: (40, 27, 13, 1), 322: (33, 20, 13, 3)}
    got = {}
    for l in open(os.path.join(n, 'extract.stderr')):
        m = re.match(r'gate-terminator sprint=(\d+) opens=(\d+) closed=(\d+) unclosed=(\d+) left=(\d+)', l)
        if m:
            got[int(m.group(1))] = tuple(int(x) for x in m.groups()[1:])
    control(got == want, "the fixed extractor's gate-terminator lines reproduce item 2's table exactly")
    left = sorted(s for s, v in got.items() if v[3] > 0)
    print(f"   sprints with LEFT > 0: {', '.join('s%d' % s for s in left)}")
    def agg(d, f):
        A = collections.defaultdict(lambda: collections.defaultdict(float))
        for l in open(os.path.join(d, f)):
            r = json.loads(l)
            if r.get('kind') != 'lead':
                continue
            a = A[(r['sprint'], r['step'])]
            a['rows'] += 1
            if f == 'segs.jsonl':
                a['active_h'] += r['active'] / 3600; a['gap_h'] += (r['op_wait'] + r['agent_wait']) / 3600; a['tok'] += sum(sum(v[:4]) for v in r.get('tok', {}).values())  # per model [in, cache-write, cache-read, out, calls] (extract.py)
            elif f == 'hooks.jsonl':
                a['bytes'] += r.get('bytes', 0)
            else:
                a['bytes'] += r.get('bytes', 0)
        return A
    events = collections.Counter()
    for f in ('segs.jsonl', 'hooks.jsonl', 'tools.jsonl'):
        Ao, An = agg(o, f), agg(n, f)
        keys = sorted(set(Ao) | set(An))
        dif = [k for k in keys if {x: round(v, 4) for x, v in Ao[k].items()} != {x: round(v, 4) for x, v in An[k].items()}]
        print(f"   {f}: {len(dif)} (sprint, step) rows differ")
        for k in dif:
            a, b = Ao[k], An[k]
            print(f"      s{k[0]} {k[1]}: " + ', '.join(f"{x} {a.get(x, 0):.2f} -> {b.get(x, 0):.2f}" if x != 'tok' else f"tok {a.get(x, 0) / 1e6:.2f}M -> {b.get(x, 0) / 1e6:.2f}M"
                                                    for x in sorted(set(a) | set(b)) if round(a.get(x, 0), 4) != round(b.get(x, 0), 4)))
            if f == 'segs.jsonl':
                events[k[0]] += 1
        sprints = {k[0] for k in dif}
        control(not (sprints & {s for s, v in got.items() if v[3] == 0}), f'{f}: no row differs in a sprint with left=0 (s319, s320)')
    # each LEFT event: a new-extract lead segment whose step is not a gate label, starting inside an old gate segment
    def segs(d):
        S = collections.defaultdict(list)
        for l in open(os.path.join(d, 'segs.jsonl')):
            r = json.loads(l)
            if r['kind'] == 'lead':
                S[r['unit']].append(r)
        return S
    So, Sn = segs(o), segs(n)
    ev = []
    for u, rows in Sn.items():
        for r in rows:
            if r['step'].startswith('gate-validation'):
                continue
            cov = [x for x in So.get(u, []) if x['first'] <= r['first'] <= x['last'] and x['step'] != r['step']]
            if cov and cov[0]['step'].startswith('gate-validation'):
                ev.append((r['sprint'], r['first'], u[:8], cov[0]['step'], r['step']))
    ev.sort()
    print(f"   lead segments relabelled out of a gate: {len(ev)}")
    for e in ev:
        print(f"      s{e[0]} {e[1][:19]}Z {e[2]} {e[3]} -> {e[4]}")
    per = collections.Counter(e[0] for e in ev)
    for s in sorted(got):
        print(f"      s{s}: left={got[s][3]}, relabelled segments {per.get(s, 0)}")
    control(all(per.get(s, 0) >= (1 if got[s][3] else 0) for s in got) and all(per.get(s, 0) == 0 for s in got if got[s][3] == 0),
            'every sprint with left > 0 has a relabelled segment, and no sprint with left = 0 has one')

def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    work = a[0]; graph = os.path.expanduser('~/git/graph')
    if '--graph' in a:
        graph = a[a.index('--graph') + 1]
    if '--build' in a:
        for w in (W1, W2, W3):
            for side in ('old', 'new'):
                build(work, side, w)
    only = a[a.index('--only') + 1].split(',') if '--only' in a else ['members', 'w1', 'w2', 'w3']
    if 'members' in only: members()
    if 'w1' in only: w1(work)
    if 'w2' in only: w2(work, graph)
    if 'w3' in only: w3(work)
    print(f"CONTROLS FAILED: {len(BAD)}")
    sys.exit(1 if BAD else 0)

if __name__ == '__main__':
    main()
