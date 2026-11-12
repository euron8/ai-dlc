"""BL-615 outcome: the four planning steps, per story, s319 (before) against s321 and s322 (after), with the seat split.

Usage:
  python3 -I step_value.py <OUT> --graph <graph clone> --ref <graph commit>
  python3 -I step_value.py <OUT> --stories 319=20,321=25,322=8        (no graph: counts given, not derived)
  python3 -I step_value.py --diff <OUT_A> <OUT_B>                      (window-stability control)

<OUT> is a directory produced by docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py, then
pipeline-efficiency-s317-s318/scripts/spawns.py and analyze.py (it must hold steps.csv and segs.jsonl).

Every money, hour and token figure comes from roll.py's own seat_sum(), usd() and hosted_mix(), loaded from
docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py (that file is a fixture input and is not edited).
Only STORIES is overridden, with counts derived from graph's sprint-status files: one per `story-<N>-<M>:`
key. s319 and s321 are controls (20 and 25); the run refuses if either differs. s322 is derived.

s322's lead seat ran local models only. roll.py prices it by FALLBACK {322: 321} (s321's hosted lead mix);
this script prints that figure and a bracket with every local call priced at sonnet and at opus.

Decision rule (BL-615, contract FOLD D4, fixed before any number was read):
  FELL iff BOTH s321 and s322 are below s319 per story on the four-step group's token-equivalent $ AND tokens
  AND the subagent seat's token-equivalent $. Otherwise DID NOT FALL. Where the lead ran local calls, a
  bracket check is printed beside the rule (not part of it): whether both ends sit on one side of s319.

The gate rows of the four steps (gate[<step>]) are outside the group and printed separately, because
extract.py's gate span can carry a later step's work under an earlier gate's label: in s322 the
requirements-adversarial-p1 round ran under the label gate-validation[carry-over-evaluation].
"""
import collections, csv, importlib.util, json, os, re, subprocess, sys

STEPS = ('carry-over-evaluation', 'requirements', 'architecture', 'stories-test-strategy')
MEMBER = 'requirements'
BEFORE, AFTER = 319, (321, 322)
CONTROLS = {319: 20, 321: 25}
FILES = {319: '_bmad-output/implementation-artifacts/s319/sprint-status.yaml',
         321: '_bmad-output/implementation-artifacts/s321/sprint-status.yaml',
         322: '_bmad-output/implementation-artifacts/sprint-status.yaml'}
KEY = re.compile(r'^\s*story-\d+-\d+:\s*$')


def repo_root():
    d = os.path.dirname(os.path.abspath(__file__))
    while True:
        if os.path.isfile(os.path.join(d, 'docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py')):
            return d
        up = os.path.dirname(d)
        if up == d:
            sys.exit('step_value: cannot find docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py above ' + __file__)
        d = up


def load_roll():
    p = os.path.join(repo_root(), 'docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py')
    spec = importlib.util.spec_from_file_location('roll', p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def derive_stories(graph, ref):
    out = {}
    for n, f in FILES.items():
        r = subprocess.run(['git', '-C', graph, 'show', '%s:%s' % (ref, f)], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit('step_value: git show %s:%s failed: %s' % (ref, f, r.stderr.strip()))
        lines = r.stdout.split('\n')
        sprint = [l for l in lines if l.startswith('sprint:')]
        keys = [i for i, l in enumerate(lines) if KEY.match(l)]
        done = 0
        for j, i in enumerate(keys):
            end = keys[j + 1] if j + 1 < len(keys) else len(lines)
            if any(re.match(r'^\s+status:\s*done\s*$', l) for l in lines[i + 1:end]):
                done += 1
        naive = sum(1 for l in lines if re.search(r'story-\d+-\d+', l))
        print('stories s%d: %d keys, %d done (%s, %s; lines naming a story id, the naive count: %d)'
              % (n, len(keys), done, f, sprint[0] if sprint else 'no sprint: line', naive))
        if n == 322 and (not sprint or sprint[0].split(':')[1].strip() != '322'):
            sys.exit('step_value: %s is not sprint 322 at %s' % (f, ref))
        out[n] = (len(keys), done)
    for n, want in CONTROLS.items():
        if out[n][0] != want:
            sys.exit('step_value: CONTROL FAILED, s%d reads %d keys, expected %d' % (n, out[n][0], want))
    print('controls: s319 20 and s321 25 reproduced')
    return out


def bracket(R, rows, steps, n):
    """Token-equivalent $ with every local call priced at one model, lead and subagent seats summed."""
    b = {}
    for pin in ('sonnet', 'opus'):
        t = 0.0
        for r in rows:
            if r['bucket'] != 'pipeline' or int(r['sprint']) != n or R.step_base(r['step']) not in steps:
                continue
            for seat in ('lead', 'sub'):
                t += R.usd(r, seat, True, {pin: 1.0})
        b[pin] = t
    return b


def figures(R, rows, HM, steps, n, sn):
    T = R.seat_sum(rows, HM, 'pipeline', set(steps), {n})
    te = T['lead$e'] + T['sub$e']
    tok = T['leadtok'] + T['subtok']
    return dict(T=T, sn=sn, h=T['el'] / sn, gap=T['gap'] / sn, te=te / sn, api=(T['lead$'] + T['sub$']) / sn,
                tok=tok / sn, lact=T['act'] / sn, le=T['lead$e'] / sn, la=T['lead$'] / sn,
                sact=T['subh'] / sn, se=T['sub$e'] / sn, sa=T['sub$'] / sn,
                local=T['leadlocal'], calls=T['leadcalls'], pending=T['pending'],
                br={k: v / sn for k, v in bracket(R, rows, set(steps), n).items()})


def line(f):
    s = ('%.2f h gap-inclusive (gap %.2f h), token-equivalent $%.1f (API $%.1f), %.1fM tokens; '
         'lead active %.2f h, lead $%.1f (API $%.1f); subagent active %.2f h, subagent $%.1f (API $%.1f); '
         'lead-seat local %d of %d calls'
         % (f['h'], f['gap'], f['te'], f['api'], f['tok'] / 1e6, f['lact'], f['le'], f['la'],
            f['sact'], f['se'], f['sa'], f['local'], f['calls']))
    if f['local']:
        s += '; bracket sonnet $%.1f .. opus $%.1f' % (f['br']['sonnet'], f['br']['opus'])
    if f['pending']:
        s += '; PENDING rows %d' % f['pending']
    return s


def main(argv):
    if argv[:1] == ['--diff']:
        a, b = argv[1], argv[2]
        bad = 0
        ra = {(r['sprint'], r['bucket'], r['step']): r for r in csv.DictReader(open(a + '/steps.csv'))}
        rb = {(r['sprint'], r['bucket'], r['step']): r for r in csv.DictReader(open(b + '/steps.csv'))}
        R = load_roll()
        for n in (319, 321, 322):
            ka = sorted(k for k in ra if k[0] == str(n) and k[1] == 'pipeline' and R.step_base(k[2]) in STEPS)
            kb = sorted(k for k in rb if k[0] == str(n) and k[1] == 'pipeline' and R.step_base(k[2]) in STEPS)
            diff = [k for k in set(ka) | set(kb) if ra.get(k) != rb.get(k)]
            print('s%d four-step rows: %d vs %d, %d differ %s' % (n, len(ka), len(kb), len(diff), sorted(diff)))
            bad += len(diff)
        # control: the same comparison over every pipeline row of s322 must be able to see a difference
        allk = [k for k in set(ra) | set(rb) if k[0] == '322']
        print('control: s322 rows of any step that differ: %d of %d' % (sum(1 for k in allk if ra.get(k) != rb.get(k)), len(allk)))
        return 1 if bad else 0
    out = argv[0]
    opts = dict(zip(argv[1::2], argv[2::2]))
    R = load_roll()
    if '--graph' in opts:
        derived = derive_stories(opts['--graph'], opts.get('--ref', 'HEAD'))
        stories = {n: v[0] for n, v in derived.items()}
        done = {n: v[1] for n, v in derived.items()}
    else:
        stories = {int(k): int(v) for k, v in (p.split('=') for p in opts['--stories'].split(','))}
        done = dict(stories)
    rows = list(csv.DictReader(open(out + '/steps.csv')))
    HM = {seat: R.hosted_mix(rows, seat) for seat in ('lead', 'sub')}
    sprints = sorted(n for n in stories if n in (BEFORE,) + AFTER)
    print('extract: %s (rows %d); roll.py FALLBACK %s' % (out, len(rows), R.FALLBACK))
    print()
    G = {}
    # like for like with s321, which ran no carry-over-evaluation: the group without that step
    for label, steps in [('four-step group', STEPS), ('three-step group, without carry-over-evaluation', STEPS[1:])] + [(s, (s,)) for s in STEPS]:
        print('== %s' % label)
        for n in sprints:
            for div, sn in ([('planned', stories[n])] + ([('done', done[n])] if done[n] != stories[n] else [])):
                if sn <= 0:
                    print('   s%d: no stories' % n); continue
                f = figures(R, rows, HM, steps, n, sn)
                G[(label, n, div)] = f
                print('   s%d (%d stories, %s): %s' % (n, sn, div, line(f)))
        print()
    print('== the four steps\' gate rows, OUTSIDE the group (per planned story)')
    for st in STEPS:
        for n in sprints:
            f = figures(R, rows, HM, ('gate[%s]' % st,), n, stories[n])
            if f['T']['el'] or f['T']['subh'] or f['calls']:
                print('   s%d gate[%s]: %s' % (n, st, line(f)))
    print()
    if not all(('four-step group', n, 'planned') in G for n in (BEFORE,) + AFTER):
        print('no decision: s319, s321 and s322 are not all present')
        return 0
    # planning completion in s322: the last lead record of the four steps
    last = None; lsub = None
    for l in open(out + '/segs.jsonl'):
        s = json.loads(l)
        if s.get('sprint') == 322 and R.step_base(s['step']) in STEPS + tuple('gate[%s]' % x for x in STEPS):
            if s['kind'] == 'lead' and (last is None or s['last'] > last[0]):
                last = (s['last'], s['step'], s['unit'][:8])
            if s['kind'] != 'lead' and (lsub is None or s['last'] > lsub[0]):
                lsub = (s['last'], s['step'], s['unit'])
    print('s322 planning complete: last lead record of the four steps and their gates at %s (%s, lead %s)' % last if last else 's322 planning: no lead segment')
    if lsub:
        print('   latest subagent record labelled with one of them: %s (%s, %s)' % lsub)
    print()
    # decision
    b = G[('four-step group', BEFORE, 'planned')]
    res = []
    for n in AFTER:
        a = G[('four-step group', n, 'planned')]
        te_ok = a['te'] < b['te']
        res.append((n, te_ok, a['tok'] < b['tok'], a['se'] < b['se']))
        print('rule s%d vs s319: token-equivalent %s (%.1f vs %.1f), tokens %s (%.1fM vs %.1fM), subagent seat %s ($%.1f vs $%.1f)'
              % (n, 'below' if te_ok else 'NOT below', a['te'], b['te'],
                 'below' if a['tok'] < b['tok'] else 'NOT below', a['tok'] / 1e6, b['tok'] / 1e6,
                 'below' if a['se'] < b['se'] else 'NOT below', a['se'], b['se']))
        if a['local']:
            # reported beside the rule, not part of it: does the FALLBACK price decide the token-equivalent leg?
            print('   bracket check s%d: sonnet $%.1f, opus $%.1f, both %s s319 $%.1f'
                  % (n, a['br']['sonnet'], a['br']['opus'],
                     'below' if a['br']['opus'] < b['te'] else ('above' if a['br']['sonnet'] >= b['te'] else 'NOT on one side of'), b['te']))
    fell = all(x[1] and x[2] and x[3] for x in res)
    print('DECISION: four-step group %s' % ('FELL' if fell else 'DID NOT FALL'))
    # BL-1003: s322's requirements-adversarial-p1 spawns carry gate-validation[carry-over-evaluation]. Split that
    # label's s322 spawns at BL-1003's boundary (spawn start 2026-11-09T14:00:00Z) and add the later ones back.
    # spawns.jsonl `usd` is list price; every subagent call is hosted, so it is also token-equivalent.
    sp = [json.loads(l) for l in open(out + '/spawns.jsonl')]
    lab = [s for s in sp if s['sprint'] == 322 and s['step'] == 'gate-validation[carry-over-evaluation]']
    gate = [s for s in lab if s['start'] < '2026-11-09T14:00:00Z']; req = [s for s in lab if s['start'] >= '2026-11-09T14:00:00Z']
    tot = lambda L: (len(L), sum(s['usd'] for s in L), sum(s['tok'] for s in L), sum(s['minutes'] for s in L) / 60)
    print('BL-1003 split, s322 spawns labelled gate-validation[carry-over-evaluation]: all %d, $%.2f, %.1fM tokens, %.2f agent-h; '
          'gate (start before 14:00Z) %d, $%.2f, %.2f agent-h; requirements (from 14:00Z) %d, $%.2f, %.1fM tokens, %.2f agent-h'
          % (tot(lab)[0], tot(lab)[1], tot(lab)[2] / 1e6, tot(lab)[3], tot(gate)[0], tot(gate)[1], tot(gate)[3],
             tot(req)[0], tot(req)[1], tot(req)[2] / 1e6, tot(req)[3]))
    gr = R.seat_sum(rows, HM, 'pipeline', {'gate[carry-over-evaluation]'}, {322})
    print('   reconcile: the gate row in steps.csv is subagent $%.2f (spawns basis) + lead seat token-equivalent $%.2f '
          '(FALLBACK, API $%.2f) = $%.2f, %.1fM tokens (lead %.1fM, subagent %.1fM)'
          % (gr['sub$e'], gr['lead$e'], gr['lead$'], gr['sub$e'] + gr['lead$e'], (gr['leadtok'] + gr['subtok']) / 1e6,
             gr['leadtok'] / 1e6, gr['subtok'] / 1e6))
    rn, ru, rt = len(req), sum(s['usd'] for s in req), sum(s['tok'] for s in req)
    sn = stories[322]
    # One method for every row: the UNROUNDED per-story figure plus the 61 spawns' unrounded sum over the planned
    # story count, rounded once at print.
    for label in ('four-step group', 'three-step group, without carry-over-evaluation', MEMBER):
        f = G[(label, 322, 'planned')]
        print('   s322 %s with the %d requirements spawns added back (spawns only; the gate row\'s lead seat is not split): '
              'token-equivalent $%.1f (API $%.1f; bracket opus $%.1f), %.1fM tokens, subagent $%.1f'
              % (label, rn, f['te'] + ru / sn, f['api'] + ru / sn, f['br']['opus'] + ru / sn, (f['tok'] + rt / sn) / 1e6, f['se'] + ru / sn))
    m = G[(MEMBER, BEFORE, 'planned')]
    for n in AFTER:
        a = G[(MEMBER, n, 'planned')]
        print('declared member %s s%d vs s319: token-equivalent $%.1f vs $%.1f (%s), tokens %.1fM vs %.1fM (%s), subagent $%.1f vs $%.1f (%s)'
              % (MEMBER, n, a['te'], m['te'], 'fell' if a['te'] < m['te'] else 'rose',
                 a['tok'] / 1e6, m['tok'] / 1e6, 'fell' if a['tok'] < m['tok'] else 'rose',
                 a['se'], m['se'], 'fell' if a['se'] < m['se'] else 'rose'))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
