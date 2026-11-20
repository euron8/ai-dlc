"""stage_time.py -- attribute each gap in dump_sessions.py output to an update stage and a wait kind.
usage: python3 -I stage_time.py SESSDIR   (SESSDIR = output of dump_sessions.py)
Rule: stage = last stage keyword seen in a Bash/tool row (priority list below); stage persists until the next keyword row.
gap i->i+1 is: 'ask' if row i is Q; 'script' if row i+1 is an H that starts with <task-notification>; 'operator' if row i+1 is any other H;
'lead' otherwise (model + tool time). Gaps > 6 h are dropped (session pause). Prints per-sprint stage x kind hours and tool-call counts."""
import glob, os, sys, re, collections
D = sys.argv[1]
STAGES = [
 ('dist-clone', 'fetch'),
 ('self-update-gate', 'selfupdate-gate'), ('self-update-fixtures', 'selfupdate-gate'), ('self-update-push', 'selfupdate-gate'),
 ('preclassify', 'classify'), ('derivation-differential', 'classify'), ('layer-drift', 'classify'), ('ledger-reverify', 'classify'),
 ('unregistered-drift', 'classify'), ('register-drift', 'classify'), ('predicate-differential', 'classify'), ('setup-site-drift', 'classify'),
 ('retired-', 'classify'), ('audit-layer-debt', 'classify'), ('audit-upstream', 'classify'),
 ('emit-report', 'report'), ('hard-blockers', 'report'), ('list-adjudications', 'report'), ('_bmad-output/ai-dlc-update', 'report'), ('dossier', 'report'),
 ('readopt-override', 'overrides'), ('adopt-extension', 'overrides'), ('relabel-extension', 'overrides'),
 ('apply.sh', 'apply'), ('post-write-gates', 'apply'), ('settings-merge', 'apply'),
 ('push-drain', 'push'), ('gh pr', 'pr'), ('git push', 'push'), ('git merge', 'pr'), ('git commit', 'pr'),
]
def stage_of(kind, text):
    if kind not in ('T',): return None
    for kw, st in STAGES:
        if kw in text: return st
    return None
def ts(s):
    import datetime
    return datetime.datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S').timestamp() + float('0.' + s[20:23] if len(s) > 23 else 0)
tot = collections.defaultdict(lambda: collections.defaultdict(float))
calls = collections.defaultdict(lambda: collections.defaultdict(int))
persess = []
for f in sorted(glob.glob(D + '/32*.tsv')):
    sp = os.path.basename(f)[:3]
    rows = [l.rstrip('\n').split('\t') for l in open(f)]
    rows = [r for r in rows if len(r) >= 3]
    st = 'start'; sess = collections.defaultdict(float)
    for i, r in enumerate(rows):
        s2 = stage_of(r[1], r[2])
        if s2: st = s2
        if r[1] == 'T': calls[sp][st] += 1
        if i + 1 >= len(rows): continue
        dt = ts(rows[i + 1][0]) - ts(r[0])
        if dt < 0 or dt > 6 * 3600: continue
        n = rows[i + 1]
        if r[1] == 'Q': k = 'ask'
        elif n[1] == 'H' and n[2].startswith('<task-notification>'): k = 'script'
        elif n[1] == 'H': k = 'operator'
        elif r[1] == 'QA' : k = 'lead'
        else: k = 'lead'
        tot[sp][(st, k)] += dt; sess[k] += dt
    persess.append((os.path.basename(f), {k: round(v / 3600, 2) for k, v in sess.items()}))
for sp in sorted(tot):
    print('== sprint', sp)
    stages = sorted(set(s for s, _ in tot[sp]), key=lambda s: -sum(v for (a, _), v in tot[sp].items() if a == s))
    print('%-16s %7s %7s %7s %7s %6s' % ('stage', 'lead_h', 'script_h', 'ask_h', 'oper_h', 'Tcalls'))
    for s in stages:
        g = lambda k: tot[sp].get((s, k), 0) / 3600
        print('%-16s %7.2f %7.2f %7.2f %7.2f %6d' % (s, g('lead'), g('script'), g('ask'), g('operator'), calls[sp][s]))
    print('%-16s %7.2f %7.2f %7.2f %7.2f %6d' % ('TOTAL', *[sum(v for (a, k), v in tot[sp].items() if k == kk) / 3600 for kk in ('lead', 'script', 'ask', 'operator')], sum(calls[sp].values())))
if len(sys.argv) > 2:
    for p in persess: print(p)
