"""BL-808's joint figures (implementation plus gate-validation[implementation], per story), old against fixed extractor.

usage: python3 -I joint_impl.py OUT_OLD OUT_NEW

Each OUT is an extract built the same way, differing only in the extract.py that built it:
    EXTRACT_WIN_END=<iso> python3 -I <extract.py> $OUT 2> $OUT/extract.stderr
    python3 -I docs/analysis/pipeline-efficiency-s317-s318/scripts/spawns.py $OUT
    python3 -I docs/analysis/pipeline-efficiency-s317-s318/scripts/analyze.py $OUT
OUT_OLD's extract.py is `git show e3cb7710f:docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py`
(the parent of 0.1100.0, the commit that added the gate terminator, BL-1003 item 1); OUT_NEW's is the tree's.

Per population and per OUT it prints:
  SEATS  roll.py's own seat_line over the step group {implementation, gate[implementation]} (seat_sum, hosted_mix
         and STORIES imported from roll.py, nothing restated): gap-inclusive h, gap h, token-equivalent and API $,
         tokens, lead active h and $, subagent active h and $.
  SPAWNS spawns.jsonl rows whose step is implementation or gate-validation[implementation]: spawns per story and
         subagent $ per story (decompose.py's `impl` phase, which is the same two labels).
  PASSES impl_passes.py's row set re-read from its own implrows.json logic: gate-1 code-review shards per pass and
         review spend on pass 2 and later per story (impl_passes.py is run as a subprocess on the OUT).
then a SAME or DIFFER verdict per line, and each OUT's `gate-terminator` stderr lines (the fixed extractor prints
them; the old one prints none). A figure may differ only in a sprint whose fixed-extractor LEFT count is above 0.
The controls are the b255 figures recorded in docs/backlog.md BL-808, checked against OUT_OLD: a control that fails
exits 1.
"""
import collections, decimal, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROLL_DIR = os.path.join(HERE, '..', '..', 'pipeline-efficiency-s317-s320', 'scripts')
sys.path.insert(0, ROLL_DIR)
import roll  # noqa: E402  (runs nothing on import: its main block is guarded)
import csv  # noqa: E402

GROUP_STEPS = {'implementation', 'gate[implementation]'}
LABELS = {'implementation', 'gate-validation[implementation]'}
POPS = [('s317', (317,)), ('s318', (318,)), ('s317+s318', (317, 318)), ('s319', (319,)), ('s320', (320,)), ('s321', (321,))]

def seats(out):
    rows = list(csv.DictReader(open(os.path.join(out, 'steps.csv'))))
    HM = {seat: roll.hosted_mix(rows, seat) for seat in ('lead', 'sub')}
    res = {}
    for pl, ns in POPS:
        sn = sum(roll.STORIES[n] for n in ns)
        T = roll.seat_sum(rows, HM, 'pipeline', GROUP_STEPS, set(ns))
        res[pl] = (T, sn, roll.seat_line(T, sn))
    return res

def spawns(out):
    A = collections.defaultdict(lambda: [0, 0.0])
    for l in open(os.path.join(out, 'spawns.jsonl')):
        s = json.loads(l)
        if s['step'] in LABELS:
            A[s['sprint']][0] += 1; A[s['sprint']][1] += s['usd']
    res = {}
    for pl, ns in POPS:
        sn = sum(roll.STORIES[n] for n in ns)
        n_ = sum(A[n][0] for n in ns); u = sum(A[n][1] for n in ns)
        res[pl] = f"{n_ / sn:.1f} spawns per story, subagent spawn ${u / sn:.1f} per story ({n_} spawns)"
    return res

def passes(out):
    sprints = '317,318,319,320,321'
    subprocess.run([sys.executable, '-I', os.path.join(ROLL_DIR, 'impl_passes.py'), out, sprints],
                   check=True, stdout=subprocess.DEVNULL)
    rows = json.load(open(os.path.join(out, 'implrows.json')))
    res = {}
    for pl, ns in POPS:
        sn = sum(roll.STORIES[n] for n in ns)
        R = [r for r in rows if r['sp'] in ns]
        passes_, shards = collections.defaultdict(set), collections.Counter()
        for r in R:
            k = (r['sp'], r['story'], r['gate'], r['kind'] == 'qa')
            passes_[k].add(r['ps']); shards[(k, r['ps'])] += 1
        cr = [k for k in passes_ if not k[3] and k[2] == '1']
        sh = [shards[(k, p)] for k in cr for p in passes_[k]]
        # impl_passes.py prints `$ by pass#` per sprint with each pass's dollars rounded to whole dollars; the recorded
        # pass-2-and-later figures sum those printed values, so the same rounding is applied here.
        bypass = collections.Counter()
        for r in R:
            bypass[(r['sp'], r['ps'])] += r['usd']
        late = sum(round(v) for (sp, p), v in bypass.items() if p >= 2)
        # whole dollars over a story count, rounded half up as the recorded figures were (329/20 = 16.45 -> 16.5)
        per = (decimal.Decimal(late) / sn).quantize(decimal.Decimal('0.1'), rounding=decimal.ROUND_HALF_UP)
        res[pl] = (f"gate-1 code-review shards per pass {sum(sh) / max(1, len(sh)):.1f} over {len(sh)} passes; "
                   f"pass-2-and-later review spend ${per} per story (${late} whole-dollar sum)")
    return res

def terminator(out):
    p = os.path.join(out, 'extract.stderr')
    return [l.strip() for l in open(p)] if os.path.exists(p) else []

def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    old, new = sys.argv[1], sys.argv[2]
    S = {k: seats(k) for k in (old, new)}
    P = {k: spawns(k) for k in (old, new)}
    Q = {k: passes(k) for k in (old, new)}
    ndiff = 0
    for pl, _ in POPS:
        for kind, D in (('SEATS', {k: S[k][pl][2] for k in S}), ('SPAWNS', P), ('PASSES', Q)):
            o = D[old] if kind == 'SEATS' else D[old][pl]
            n = D[new] if kind == 'SEATS' else D[new][pl]
            same = o == n
            ndiff += not same
            print(f"{pl} {kind} old: {o}")
            if same:
                print(f"{pl} {kind} new: SAME")
            else:
                print(f"{pl} {kind} new: {n}  <- DIFFER")
    for k, tag in ((old, 'old'), (new, 'new')):
        g = [l for l in terminator(k) if l.startswith('gate-terminator ')]
        print(f"{tag} gate-terminator lines: {len(g)}")
        for l in g:
            print(f"   {l}")
    print(f"DIFFER lines: {ndiff}")
    # Controls: the b255 figures recorded in BL-808 (docs/backlog.md), read off OUT_OLD's own lines.
    want = [
        ('s319', 'SEATS', '2.09 h gap-inclusive (gap 0.77 h), token-equivalent $41.3 (API $41.3)'),
        ('s319', 'SEATS', 'lead active 1.31 h, lead $10.6, subagent active 3.51 h, subagent $30.7'),
        ('s321', 'SEATS', '1.13 h gap-inclusive (gap 0.28 h), token-equivalent $25.5 (API $25.5)'),
        ('s321', 'SEATS', 'lead active 0.85 h, lead $7.6, subagent active 1.48 h, subagent $17.9'),
        ('s320', 'SEATS', '1.94 h gap-inclusive'),
        ('s320', 'SEATS', 'token-equivalent $20.7'),
        ('s317', 'SPAWNS', '14.1 spawns per story, subagent spawn $24.3 per story'),
        ('s319', 'SPAWNS', '31.5 spawns per story'),
        ('s321', 'SPAWNS', '11.2 spawns per story'),
        ('s319', 'PASSES', 'shards per pass 5.5'),
        ('s320', 'PASSES', 'shards per pass 1.9'),
        ('s321', 'PASSES', 'shards per pass 1.4'),
        ('s319', 'PASSES', 'spend $16.5 per story'),
        ('s320', 'PASSES', 'spend $1.5 per story'),
    ]
    bad = 0
    for pl, kind, frag in want:
        line = S[old][pl][2] if kind == 'SEATS' else (P if kind == 'SPAWNS' else Q)[old][pl]
        ok = frag in line
        bad += not ok
        print(f"CONTROL {'OK' if ok else 'FAIL'}: {pl} {kind} old carries '{frag}'")
    sys.exit(1 if bad else 0)

if __name__ == '__main__':
    main()
