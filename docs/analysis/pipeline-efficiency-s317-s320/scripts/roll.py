"""Per-sprint, per-step roll-up of steps.csv. Usage: roll.py <OUT> [--seats | --classes]

--classes prints, per sprint, per step and per lead tool-call class (extract.py's classes.jsonl), per story: active h,
gap h, calls, tokens and lead $ (token-equivalent, API beside it), with the `other` share; it asserts the class-sum of
tokens equals segs.jsonl tok per (lead unit, step) and prints segs active minus class-sum active as the
"out-of-order overcount".

--seats prints, per story, the lead and subagent figures separately for the cited step groups (pooled s317+s318,
then each sprint) and for every step per sprint: lead active h, lead $, subagent active h, subagent $.

Hours are GAP-INCLUSIVE: elapsed = active + op_wait + agent_wait, where the two waits are the time between
consecutive records longer than 300 s. That time is recorded separately as `gap` (extract.py) and printed beside
the hours; gap == op_wait + agent_wait is asserted against segs.jsonl.

Dollars come in two bases, always printed together:
  API $        list price of every call; a local-model call (qwen38flash-mlx) costs $0.
  token-equiv  the same, with each local-model call priced at the model that replaced it on that seat.
               LOCAL_REPLACED_BY names it. On the lead seat the local model was replaced by sonnet (the lead
               seat is sonnet in every sprint that has no local calls); no subagent seat ever ran local.
"""
import csv, collections, json, os, sys
P = {'opus': (4, 20, 0.2, 8), 'sonnet': (2, 10, 0.2, 4), 'haiku': (.1, .5, .01, .2), 'fable': (10, 50, .25, 20)}
LOCAL = ('qwen38flash-mlx', 'qwen38flash', 'deepseek41')   # every local model family analyze.py has emitted

def lsum(r, pre, k):
    return sum(float(r.get(f"{pre}_{m}_{k}", 0) or 0) for m in LOCAL)
HOSTED = ('opus', 'sonnet', 'haiku', 'fable')
# A sprint with local calls and no hosted calls on that seat has nothing to derive a price from. graph's own
# configuration at s314's start (git show 6a4469196:.claude/settings.json) names no lead model: it has no
# top-level "model" key, and aiDlcModels only maps role names to ids. So s314 is priced at the NEAREST sprint's
# hosted lead mix (s315) and labelled a fallback wherever printed.
FALLBACK = {314: 315, 322: 321}   # s322's lead seat ran only local models (qwen38flash, deepseek41)
# graph sprint-status.yaml at each close; s321 is still open, so its 25 is the planned count from
# _bmad-output/planning-artifacts/s321/sprint-status.yaml@e32f9ce2f (written once, a6afc3eba "6 epics, 25 stories").
STORIES = {317: 21, 318: 13, 319: 20, 320: 13, 321: 25, 322: 8}   # s322 open: 8 planned (3 done at 2026-11-11T10:30Z)

def hosted_mix(rows, pre):
    """{sprint: {family: calls}} over the pipeline bucket: the HOSTED calls on one seat, per sprint."""
    m = collections.defaultdict(lambda: collections.defaultdict(float))
    for r in rows:
        if r['bucket'] != 'pipeline': continue
        for f in HOSTED:
            m[int(r['sprint'])][f] += float(r.get(f"{pre}_{f}_calls", 0) or 0)
    return m

def usd(r, pre, tokeq=False, mix=None):
    t = 0
    for f, (i, o, cr, cw) in P.items():
        g = lambda k: float(r.get(f"{pre}_{f}_{k}", 0) or 0)
        t += (g('in') * i + g('out') * o + g('cr') * cr + g('cw') * cw) / 1e6
    if tokeq:
        # Local calls are priced at the count-weighted price of THAT sprint's hosted calls on the same seat.
        # No hosted calls on the seat in that sprint: nothing to derive from, the figure is PENDING (returns None).
        n = sum((mix or {}).values())
        if n <= 0:
            return None if lsum(r, pre, "calls") else t
        i, o, cr, cw = (sum(mix.get(f, 0) * P[f][k] for f in HOSTED) / n for k in range(4))
        g = lambda k: lsum(r, pre, k)
        t += (g('in') * i + g('out') * o + g('cr') * cr + g('cw') * cw) / 1e6
    return t

def calls(r, pre):
    c = collections.Counter()
    for k, v in r.items():
        if k.startswith(pre + '_') and k.endswith('_calls') and float(v or 0):
            c[k[len(pre) + 1:-6]] += float(v)
    return c

def step_base(st):
    """roll.py's step grouping: gate-validation[x] rolls up as gate[x], any other [suffix] is dropped."""
    return st.split('[')[0] if not st.startswith('gate-validation') else 'gate[' + st[16:-1] + ']'

# Step groups the backlog's Outcome measured: lines cite. None = the whole bucket.
GROUPS = [
    ('stories-test-strategy', 'pipeline', {'stories-test-strategy'}),
    ('route plus artifact-consolidation plus pre-step', 'pipeline', {'route', 'artifact-consolidation', 'pre-step'}),
    ('the whole pipeline bucket', 'pipeline', None),
    ('architecture', 'pipeline', {'architecture'}),
    ('requirements', 'pipeline', {'requirements'}),
    ('sprint-review plus gate-validation[sprint-review]', 'pipeline', {'sprint-review', 'gate[sprint-review]'}),
    ('the ai-dlc-update bucket', 'ai-dlc-update', None),
]
POPS = [('before s317+s318 pooled', (317, 318)), ('s317', (317,)), ('s318', (318,)), ('s319', (319,)), ('s320', (320,)), ('s321', (321,)), ('s322', (322,))]

def seat_sum(rows, HM, bucket, steps, sprints):
    """Sums one population's steps.csv rows per seat. Hours are gap-inclusive lead-segment elapsed; lead active
    is active_h; subagent active is sub_active_h summed over subagents (it can exceed elapsed). Dollars use usd()
    with hosted_mix(), exactly as the main roll-up does, including the FALLBACK and PENDING handling."""
    T = collections.defaultdict(float)
    for r in rows:
        if r['bucket'] != bucket: continue
        n = int(r['sprint'])
        if n not in sprints: continue
        if steps is not None and step_base(r["step"]) not in steps: continue
        T['el'] += float(r['elapsed_h']); T['act'] += float(r['active_h'])
        T['gap'] += float(r['agent_wait_h']) + float(r['op_wait_h']); T['subh'] += float(r['sub_active_h'])
        for seat in ('lead', 'sub'):
            api = usd(r, seat); mix = HM[seat][n]
            if sum(mix.values()) <= 0 and n in FALLBACK: mix = HM[seat][FALLBACK[n]]
            te = usd(r, seat, True, mix)
            if te is None: T['pending'] += 1; te = api
            T[seat + '$'] += api; T[seat + '$e'] += te
            T[seat + 'tok'] += sum(float(v or 0) for c, v in r.items() if c.startswith(seat + '_') and c.endswith(('_in', '_out', '_cr', '_cw')))
            for c, v in r.items():
                if c.startswith(seat + '_') and c.endswith('_calls'):
                    T[seat + 'calls'] += float(v or 0)
                    if c in {f"{seat}_{m}_calls" for m in LOCAL}: T[seat + 'local'] += float(v or 0)
    return T

def money(te, api):
    return f"${te:.1f}" if f"{te:.1f}" == f"{api:.1f}" else f"${te:.1f} (API ${api:.1f})"

def seat_line(T, sn):
    te = T['lead$e'] + T['sub$e']; api = T['lead$'] + T['sub$']
    share = 100 * T['leadlocal'] / T['leadcalls'] if T['leadcalls'] else 0
    return (f"{T['el']/sn:.2f} h gap-inclusive (gap {T['gap']/sn:.2f} h), token-equivalent ${te/sn:.1f} (API ${api/sn:.1f}), "
            f"{(T['leadtok'] + T['subtok'])/sn/1e6:.1f}M tokens; lead active {T['act']/sn:.2f} h, lead {money(T['lead$e']/sn, T['lead$']/sn)}, "
            f"subagent active {T['subh']/sn:.2f} h, subagent {money(T['sub$e']/sn, T['sub$']/sn)}; "
            f"lead-seat local share {share:.0f}% of {T['leadcalls']:.0f} calls" + (f"; PENDING rows {T['pending']:.0f}" if T['pending'] else ""))

def seats(rows):
    HM = {seat: hosted_mix(rows, seat) for seat in ('lead', 'sub')}
    print(f"per story; STORIES = {STORIES}; $ token-equivalent, API beside it where it differs")
    print("== cited step groups")
    for label, bucket, steps in GROUPS:
        print(f"-- {label} [{bucket}]")
        for pl, ns in POPS:
            sn = sum(STORIES[n] for n in ns)
            print(f"   {pl} ({sn} stories): " + seat_line(seat_sum(rows, HM, bucket, steps, set(ns)), sn))
    print("== every step, per sprint")
    keys = sorted({(r["bucket"], step_base(r["step"])) for r in rows if int(r['sprint']) in STORIES})
    for bucket, st in keys:
        for n in sorted(STORIES):
            T = seat_sum(rows, HM, bucket, {st}, {n})
            if T['el'] or T['subh'] or T['leadcalls'] or T['subcalls']:
                print(f"   s{n} {bucket} {st} ({STORIES[n]} stories): " + seat_line(T, STORIES[n]))

def analyze_defs():
    """RELABEL and fam() exactly as the s317-s318 analyze.py defines them (read from its source, not restated)."""
    import ast
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'pipeline-efficiency-s317-s318', 'scripts', 'analyze.py')
    tree = ast.parse(open(p).read()); ns = {}
    for n in tree.body:
        if (isinstance(n, ast.Assign) and any(getattr(t, 'id', None) == 'RELABEL' for t in n.targets)) or \
           (isinstance(n, ast.FunctionDef) and n.name == 'fam'):
            exec(compile(ast.Module([n], []), p, 'exec'), ns)
    return ns['RELABEL'], ns['fam']

CLASS_ORDER = ('dispatch', 'merge', 'repair', 'gate-run', 'step-reread', 'compaction-recovery', 'snapshot', 'other')

def classes(out):
    """Per sprint, step and class (lead seat, pipeline bucket): active h, gap h, calls, lead $ per story. Asserts the
    class-sum of tokens equals segs tok per (lead unit, step) and prints the active-h difference against segs."""
    RELABEL, fam = analyze_defs()
    rows = list(csv.DictReader(open(out + '/steps.csv')))
    HM = hosted_mix(rows, 'lead')
    units = [json.loads(l) for l in open(os.path.join(out, 'units.jsonl'))]
    bucket = {}
    for u in units:
        if u['kind'] != 'lead': continue
        bucket[u['sess']] = 'pipeline' if any(k.split('|', 1)[0] != 'pre-step' for k in u['tok']) else 'not-pipeline'
    segs = {}; cls = collections.defaultdict(list)
    for l in open(os.path.join(out, 'segs.jsonl')):
        s = json.loads(l)
        if s['kind'] == 'lead': segs[(s['unit'], s['step'])] = s
    for l in open(os.path.join(out, 'classes.jsonl')):
        c = json.loads(l); cls[(c['unit'], c['step'])].append(c)
    def toks(tok): return {m: list(d) for m, d in (tok or {}).items()}
    bad = 0
    for k in set(segs) | set(cls):
        want = toks(segs[k].get('tok')) if k in segs else {}
        got = {}
        for c in cls.get(k, []):
            for m, d in c['tok'].items():
                g = got.setdefault(m, [0, 0, 0, 0, 0])
                for i in range(5): g[i] += d[i]
        if got != want: bad += 1
    print(f"class tokens == segs tok (in, cw, cr, out, calls per model) on {len(set(segs) | set(cls)) - bad} of {len(set(segs) | set(cls))} (lead unit, step) pairs")
    if bad: print("INVARIANT FAILED: class token sum differs from segs"); sys.exit(1)
    # (sprint, step_base) -> class -> sums; segs active per (sprint, step_base) for the overcount line.
    A = collections.defaultdict(lambda: collections.defaultdict(lambda: collections.defaultdict(float)))
    SA = collections.defaultdict(float)
    for (unit, st), s in segs.items():
        if bucket.get(s['sess']) != 'pipeline' or s['sprint'] not in STORIES: continue
        SA[(s['sprint'], step_base(RELABEL.get((s['sess'], st), st)))] += s['active']
        for c in cls.get((unit, st), []):
            a = A[(s['sprint'], step_base(RELABEL.get((s['sess'], st), st)))][c['cls']]
            a['act'] += c['active']; a['gap'] += c['gap']; a['calls'] += c['calls']
            for m, d in c['tok'].items():
                f = fam(m)
                for i, n in enumerate(('in', 'cw', 'cr', 'out', 'calls')): a[f"lead_{f}_{n}"] += d[i]
    print("per story, lead seat, pipeline bucket; h = transcript-timestamp hours on the monotone clock; "
          "lead $ token-equivalent and API; STORIES =", STORIES)
    for n in sorted(STORIES):
        sn = STORIES[n]; mix = HM[n]
        if sum(mix.values()) <= 0 and n in FALLBACK: mix = HM[FALLBACK[n]]
        tot = collections.defaultdict(lambda: collections.defaultdict(float))
        print(f"== s{n} ({sn} stories)")
        stps = sorted({st for (m, st) in A if m == n})
        for st in stps:
            C = A[(n, st)]
            ca = sum(c['act'] for c in C.values())
            print(f"  -- {st}: segs active {SA[(n, st)]/3600:.2f} h, class-sum active {ca/3600:.2f} h, "
                  f"out-of-order overcount {(SA[(n, st)] - ca)/3600:.2f} h")
            for k in CLASS_ORDER:
                if k not in C: continue
                c = C[k]; api = usd(c, 'lead'); te = usd(c, 'lead', True, mix)
                te = api if te is None else te
                c['api'] = api; c['te'] = te
                for x, v in c.items(): tot[k][x] += v
                tk = sum(v for x, v in c.items() if x.startswith('lead_') and x.endswith(('_in', '_cw', '_cr', '_out')))
                print(f"     {k:20} active {c['act']/3600/sn:6.3f} h  gap {c['gap']/3600/sn:6.3f} h  calls {c['calls']/sn:6.1f}  "
                      f"tok {tk/sn/1e6:6.2f}M  lead token-eq ${te/sn:.2f} API ${api/sn:.2f}")
            ta = sum(c['act'] for c in C.values()); tc = sum(c['calls'] for c in C.values())
            tt = sum(c['te'] for c in C.values())
            o = C.get('other', {})
            print(f"     other share: active {100*o.get('act', 0)/ta if ta else 0:.0f}%, calls {100*o.get('calls', 0)/tc if tc else 0:.0f}%, "
                  f"$ {100*o.get('te', 0)/tt if tt else 0:.0f}%")
        ta = sum(c['act'] for c in tot.values()); tc = sum(c['calls'] for c in tot.values()); tt = sum(c['te'] for c in tot.values())
        o = tot.get('other', {})
        print(f"  s{n} all steps: " + ', '.join(f"{k} {tot[k]['act']/3600/sn:.2f} h token-eq ${tot[k]['te']/sn:.1f} API ${tot[k]['api']/sn:.1f}" for k in CLASS_ORDER if k in tot))
        print(f"  s{n} other share: active {100*o.get('act', 0)/ta if ta else 0:.0f}%, calls {100*o.get('calls', 0)/tc if tc else 0:.0f}%, "
              f"$ {100*o.get('te', 0)/tt if tt else 0:.0f}%")

if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[2] == '--classes':
        classes(sys.argv[1]); sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[2] == '--seats':
        seats(list(csv.DictReader(open(sys.argv[1] + '/steps.csv')))); sys.exit(0)
    rows = list(csv.DictReader(open(sys.argv[1] + '/steps.csv')))
    HM = {seat: hosted_mix(rows, seat) for seat in ('lead', 'sub')}
    PENDING = set(); FB = set()
    A = collections.defaultdict(lambda: collections.defaultdict(float))
    MIX = collections.defaultdict(collections.Counter)
    for r in rows:
        if r['bucket'] != 'pipeline': continue
        st = r['step']; base = st.split('[')[0] if not st.startswith('gate-validation') else 'gate[' + st[16:-1] + ']'
        n = int(r['sprint'])
        a = A[(n, base)]
        a['el'] += float(r['elapsed_h']); a['act'] += float(r['active_h']); a['aw'] += float(r['agent_wait_h']); a['op'] += float(r['op_wait_h'])
        a['lead$'] += usd(r, 'lead'); a['sub$'] += usd(r, 'sub')
        for seat in ('lead', 'sub'):
            mix = HM[seat][n]
            if sum(mix.values()) <= 0 and n in FALLBACK:
                mix = HM[seat][FALLBACK[n]]
                if lsum(r, seat, "calls"): FB.add(n)
            v = usd(r, seat, True, mix)
            if v is None: PENDING.add(n); v = usd(r, seat)
            for pin in ('sonnet', 'opus'):   # bracket: every local call at one model's price
                a[seat + '$' + pin] += usd(r, seat, True, {pin: 1.0})
            a[seat + '$e'] += v
        a['subh'] += float(r['sub_active_h']); a['comp'] += float(r['compactions'])
        a['tok'] += sum(float(v or 0) for c, v in r.items() if c.endswith(('_in', '_out', '_cr', '_cw')))
        for seat in ('lead', 'sub'):
            for f, c in calls(r, seat).items(): MIX[(n, seat)][f] += c
    # extractor invariant: every segment's gap equals its op_wait + agent_wait
    bad = 0; nseg = 0
    for l in open(os.path.join(sys.argv[1], 'segs.jsonl')):
        sg = json.loads(l); nseg += 1
        if abs(sg.get('gap', -1) - sg['op_wait'] - sg['agent_wait']) > 1e-6: bad += 1
    print(f"extractor gap == op_wait + agent_wait on {nseg - bad} of {nseg} segments")
    sprints = sorted({k[0] for k in A})
    steps = sorted({k[1] for k in A})
    order = ['pre-step', 'carry-over-evaluation', 'requirements', 'gate[requirements]', 'architecture', 'gate[architecture]', 'stories-test-strategy', 'gate[stories-test-strategy]', 'implementation', 'gate[implementation]', 'sprint-review', 'gate[sprint-review]', 'deploy-validate', 'retro']
    steps = [s for s in order if s in steps] + [s for s in steps if s not in order]
    show = [n for n in sprints if n >= 317]
    print("hours are gap-inclusive (active + gaps over 300 s); $ = API list price, local calls $0; $e = token-equivalent")
    print(f"{'step':32}" + ''.join(f"| s{n} el/act h  $API/$e".ljust(34) for n in show))
    for s in steps:
        line = f"{s:32}"
        for n in show:
            a = A.get((n, s))
            line += (f"| {a['el']:5.1f}/{a['act']:4.1f}  ${a['lead$'] + a['sub$']:6.0f}/${a['lead$e'] + a['sub$e']:6.0f}".ljust(34) if a else "| -".ljust(34))
        print(line)
    print()
    print("lead-seat HOSTED calls per sprint (the price basis for that sprint's local calls):")
    for n in sprints:
        print(f"  s{n}: " + ', '.join(f"{f} {HM['lead'][n][f]:.0f}" for f in HOSTED))
    print()
    for n in sprints:
        T = collections.defaultdict(float)
        for (m, s), a in A.items():
            if m == n:
                for k, v in a.items(): T[k] += v
        api = T['lead$'] + T['sub$']; te = T['lead$e'] + T['sub$e']
        sn = STORIES.get(n)
        if n in PENDING:
            tes = "PENDING (no hosted lead calls to derive a price from)"; tep = "PENDING"
        else:
            bl = (T['lead$sonnet'] + T['sub$sonnet'], T['lead$opus'] + T['sub$opus'])
            tes = f"${te:.0f} (lead {T['lead$e']:.0f} sub {T['sub$e']:.0f})" + (f" [FALLBACK: s{FALLBACK[n]} hosted lead mix]" if n in FB else "") + f" bracket sonnet ${bl[0]:.0f} .. opus ${bl[1]:.0f}"
            tep = (f"${te/sn:.1f} (bracket {bl[0]/sn:.1f}..{bl[1]/sn:.1f})") if sn else ""
        per = f" | per story ({sn}): {T['el']/sn:.1f}h, API ${api/sn:.1f}, token-eq {tep}" if sn else ""
        print(f"s{n} TOTAL elapsed {T['el']:.1f}h gap-inclusive (active {T['act']:.1f}h + gap {T['aw'] + T['op']:.1f}h = agentwait {T['aw']:.1f}h + opwait {T['op']:.1f}h) "
              f"| API ${api:.0f} (lead {T['lead$']:.0f} sub {T['sub$']:.0f}) | token-eq {tes} "
              f"| subagent-h {T['subh']:.0f} tokens {T['tok']/1e9:.2f}B compactions {T['comp']:.0f}{per}")
        for seat in ('lead', 'sub'):
            c = MIX[(n, seat)]; tot = sum(c.values()) or 1
            print(f"     {seat} model mix (calls): " + ', '.join(f"{f} {v:.0f} ({100*v/tot:.0f}%)" for f, v in c.most_common()))
