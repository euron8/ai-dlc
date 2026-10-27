"""Per-sprint, per-step roll-up of steps.csv. Usage: roll.py <OUT> [--seats]

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
LOCAL = 'qwen38flash-mlx'
HOSTED = ('opus', 'sonnet', 'haiku', 'fable')
# A sprint with local calls and no hosted calls on that seat has nothing to derive a price from. graph's own
# configuration at s314's start (git show 6a4469196:.claude/settings.json) names no lead model: it has no
# top-level "model" key, and aiDlcModels only maps role names to ids. So s314 is priced at the NEAREST sprint's
# hosted lead mix (s315) and labelled a fallback wherever printed.
FALLBACK = {314: 315}
STORIES = {317: 21, 318: 13, 319: 20, 320: 13}   # graph sprint-status.yaml at each close

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
            return None if float(r.get(f"{pre}_{LOCAL}_calls", 0) or 0) else t
        i, o, cr, cw = (sum(mix.get(f, 0) * P[f][k] for f in HOSTED) / n for k in range(4))
        g = lambda k: float(r.get(f"{pre}_{LOCAL}_{k}", 0) or 0)
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
POPS = [('before s317+s318 pooled', (317, 318)), ('s317', (317,)), ('s318', (318,)), ('s319', (319,)), ('s320', (320,))]

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
                    if c == f"{seat}_{LOCAL}_calls": T[seat + 'local'] += float(v or 0)
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

if __name__ == '__main__':
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
                if float(r.get(f"{seat}_{LOCAL}_calls", 0) or 0): FB.add(n)
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
