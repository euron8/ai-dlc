"""asks.py -- every AskUserQuestion in update sessions (dump_sessions.py output): wait (Q->QA), options, answer kind.
usage: python3 -I asks.py SESSDIR > asks.out ; also writes asks.json beside it.
answer kind: took-rec (option labelled Recommended), chose-other, first (unbadged first option), free-text, declined."""
import glob, os, sys, re, json, ast, datetime, collections
D = sys.argv[1]
def ts(s): return datetime.datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S').timestamp()
asks = []
for f in sorted(glob.glob(D + '/3*.tsv')):
    rows = [l.rstrip('\n').split('\t') for l in open(f)]; rows = [r for r in rows if len(r) >= 3]
    i = 0
    while i < len(rows):
        if rows[i][1] == 'Q':
            j = i; qs = []
            while j < len(rows) and rows[j][1] == 'Q': qs.append(rows[j][2]); j += 1
            wait = None; ans = ''
            if j < len(rows) and rows[j][1] == 'QA': wait = ts(rows[j][0]) - ts(rows[i][0]); ans = rows[j][2]
            asks.append([os.path.basename(f)[:19], rows[i][0][11:19], len(qs), wait, qs, ans]); i = j
        else: i += 1
json.dump(asks, open((sys.argv[2] if len(sys.argv) > 2 else 'asks.json'), 'w'))
res = collections.Counter(); det = []
for a in asks:
    ans = a[5]; sp = a[0][:3]
    if not ans.startswith('Your questions'):
        for q in a[4]: res[(sp, 'declined')] += 1; det.append((sp, q[:30], 'DECLINED', ans[100:300]))
        continue
    pieces = ans.split('"="')[1:]
    anss = [re.split(r'", "|"\. You can|"$', p)[0] for p in pieces]
    for qi, q in enumerate(a[4]):
        h, rest = q.split(' | ', 1)
        opts = ast.literal_eval(rest.split(' | opts=')[1])
        got = anss[qi] if qi < len(anss) else ''
        rec = [o for o in opts if 'recommend' in o.lower()]
        if got in opts: k = ('took-rec' if rec and got == rec[0] else 'chose-other' if rec else ('first' if got == opts[0] else 'other'))
        else: k = 'free-text'
        res[(sp, k)] += 1
        det.append((sp, h[:28], k, got[:160]))
for k, v in sorted(res.items()): print(k, v)
for d in det:
    if d[2] not in ('took-rec',): print(d)
