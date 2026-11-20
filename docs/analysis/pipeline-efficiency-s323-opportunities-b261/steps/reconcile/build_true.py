"""B: record-level re-derivation from D/recs.jsonl (extract_dump.py output; control: its segs.jsonl == MONO segs, 0 diffs).
Stages (each stage's totals are printed by report_b.py):
  S0 old labels            == steps.csv (control)
  S1 relabel (B1)          only moves elapsed between steps (total unchanged)
  S2 operator wait (B2)    only moves time between classes (total unchanged)
  S3 fork dedupe (B3)      drops records whose uuid is already in an earlier-started session file
  S4 idle tail (B4)        gap>300 s after the last tool_use record of a session leaves the totals
Writes rows.pkl: list of dict per record: sess, t, sprint, old (base label), gate_old(bool), new (true step), gate_new(bool),
 cls_old (a/o/g), cls_new (model/tool/idle/wake/o/g/tail), gap, dup, tail, cs, calls info.
"""
import sys, json, re, pickle, collections, bisect
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from lib import *

ORDER = {'route': 0, 'carry-over-evaluation': 1, 'requirements': 2, 'architecture': 3, 'ui-direction': 3.5,
         'stories-test-strategy': 4, 'implementation': 5, 'sprint-review': 6, 'deploy-validate': 7, 'retro': 8, 'handoff': 9}
PLAN = ['carry-over-evaluation', 'requirements', 'architecture', 'stories-test-strategy']
SUCC = {'carry-over-evaluation': 'requirements', 'requirements': 'architecture', 'architecture': 'stories-test-strategy',
        'stories-test-strategy': 'implementation'}
NONCE_OVR = {'implementation', 'sprint-review', 'deploy-validate', 'retro'}
def idx(x): return ORDER.get(x)

def nonce_prefix(cmd):
    m = re.search(r'--nonce\s+["\']?([^\s"\']+)', cmd)
    if not m: return None
    n = m.group(1)
    if n.startswith('$'):
        m2 = re.search(r'NONCE=["\']?([a-z][a-z-]*?)-(?:\$|\d)', cmd)
        return m2.group(1) if m2 else None
    m3 = re.match(r'([a-z][a-z-]*?)-\d{8}T', n)
    return m3.group(1) if m3 else None

def gate_kind(cmd):
    """'open' / 'close' for a gate-checkpoint.sh invocation (first word match after the script name)."""
    i = cmd.find('gate-checkpoint.sh')
    if i < 0: return None
    seg = re.split(r'[;&|\n]', cmd[i:])[0]
    w = seg.split()
    if 'close' in w: return 'close'
    if 'open' in w: return 'open'
    return None

def relabel(rs, log):
    """returns list of (true step, gate flag, nonce-gate flag) per record, labels PRE-update as in extract.py."""
    tm = 'pre-step'; omn_prev = 'pre-step'; ahead = False; gp = None; gprefix = None; gateM = None; closed_n = set()
    out = []
    for k, r in enumerate(rs):
        step = gp if gp else tm
        out.append((step, r['st'].startswith('gate-validation') or gp is not None))
        omn = r['mn']
        if omn != omn_prev:
            X = omn
            if ahead and idx(X) is not None and idx(tm) is not None and idx(X) < idx(tm):
                pass
            else:
                tm = X; ahead = False
            omn_prev = omn
        if ahead and idx(omn_prev) is not None and idx(tm) is not None and idx(omn_prev) >= idx(tm): ahead = False
        for n, i, s in r['tu']:
            if n != 'Bash': continue
            m = re.search(r'--set\s+["\']?current_step_file["\']?\s+["\']?([\w.-]+?)(?:\.md)?["\'\s]', s + ' ')
            if m and m.group(1) in ORDER and m.group(1) != tm:
                if idx(m.group(1)) is not None:
                    log.append((r['s'], r['t'], 'SET', tm, m.group(1)))
                    tm = m.group(1); ahead = (idx(omn_prev) is not None and idx(omn_prev) < idx(tm)); gp = None
            gk = gate_kind(s)
            nn = re.search(r'--nonce\s+["\']?(\w[\w-]*\d{8}T\d{6}Z)', s)
            if nn and nn.group(1) in closed_n: gk = None if gk != 'close' else gk
            elif nn and gk is None and gp is None:
                pf = nonce_prefix(s)
                if pf == 'implementation' and idx(tm) is not None and idx(tm) > idx('implementation') and 'gate-checkpoint.sh' in s:
                    gp = pf; gprefix = pf; gateM = tm; log.append((r['s'], r['t'], 'NONCE-VERB', tm, gp))
            if gk == 'open':
                gateM = tm; gprefix = nonce_prefix(s)
                if gprefix in NONCE_OVR and gprefix != tm:
                    gp = gprefix; log.append((r['s'], r['t'], 'NONCE-OPEN', tm, gp))
                else: gp = None
            elif gk == 'close':
                if nn: closed_n.add(nn.group(1))
                if gp: log.append((r['s'], r['t'], 'NONCE-CLOSE', tm, gp))
                gp = None
                if gprefix == 'planning' and gateM in SUCC and idx(tm) is not None and idx(tm) < idx(SUCC[gateM]):
                    log.append((r['s'], r['t'], 'PLAN-CLOSE', tm, SUCC[gateM]))
                    tm = SUCC[gateM]; ahead = (idx(omn_prev) is not None and idx(omn_prev) < idx(tm))
                gprefix = None
    return out

def running_union():
    iv = []
    for l in open(MONO + 'spawns.jsonl'):
        s = json.loads(l)
        iv.append((T(s['start']), T(s['end'])))
    iv.sort(); m = []
    for a, b in iv:
        if m and a <= m[-1][1]: m[-1][1] = max(m[-1][1], b)
        else: m.append([a, b])
    return m, [x[0] for x in m]
def overlap(m, starts, a, b):
    if b <= a: return 0.0
    i = max(0, bisect.bisect_right(starts, a) - 1); tot = 0.0
    while i < len(m) and m[i][0] < b:
        tot += max(0.0, min(b, m[i][1]) - max(a, m[i][0])); i += 1
    return tot

def main():
    bk = bucket(); S = by_session(); log = []
    firstt = {s: rs[0]['t'] for s, rs in S.items()}
    cnt = collections.Counter(r['u'] for rs in S.values() for r in rs if r['u'])
    owner_first = {}
    for s, rs in S.items():
        for r in rs:
            if r['u'] and cnt[r['u']] > 1:
                o = owner_first.get(r['u'])
                if o is None or firstt[s] < firstt[o]: owner_first[r['u']] = s
    m, starts = running_union()
    rows = []
    stats = collections.Counter()
    for s, rs in S.items():
        if bk.get(s) != 'pipeline': continue
        lab = relabel(rs, log)
        # operator spans: AskUserQuestion tool_use -> its tool_result; pause flag touch -> next human prompt
        isop = [False] * len(rs); isauq = [False] * len(rs)
        askid = {};
        for k, r in enumerate(rs):
            for n, i, c in r['tu']:
                if n == 'AskUserQuestion': askid[i] = k
                if n == 'Bash' and 'pipeline-paused.flag' in c and re.search(r'\btouch\b', c):
                    j = next((q for q in range(k + 1, len(rs)) if rs[q]['hp'] and not rs[q]['cs']), None)
                    if j is not None:
                        for q in range(k + 1, j + 1): isop[q] = True
            for tid, err in r['tr']:
                if tid in askid:
                    for q in range(askid[tid] + 1, k + 1): isop[q] = True; isauq[q] = True
        lt = max((k for k, r in enumerate(rs) if r['tu']), default=-1)
        prev_t = None
        pend_tool = {}
        prevtype = None
        for k, r in enumerate(rs):
            tt = T(r['t'])
            gap = r['gap']
            c = r['c']
            new = c
            sub = None
            if c == 'a':
                if r['ty'] == 'assistant': sub = 'model'
                elif r['tr']: sub = 'tool'
                else: sub = 'idle'
                # split idle/wake into running-agent wait vs own idle
                if sub == 'idle':
                    a0 = tt - gap
                    ov = overlap(m, starts, a0, tt)
                    sub = 'waitag' if ov >= gap / 2 else 'idle'
            if isop[k]: new = 'o'; sub = None
            elif c == 'o' and r['cs'] and r['hp']: new = 'g'; sub = None; stats['cs_as_human'] += gap
            tail = (k > lt and c != 'a' and not isauq[k])
            dup = bool(r['u'] and owner_first.get(r['u']) not in (None, s))
            rows.append(dict(s=s, t=r['t'], sp=sprint_of(r['t']), old=base(r['st']), g_old=r['st'].startswith('gate-validation'),
                             new=lab[k][0], g_new=lab[k][1], c_old=c, c_new=new, sub=sub, gap=gap, tail=tail, dup=dup,
                             cs=r['cs'], mid=r['mid'], mdl=r['mdl'], us=r['us'], tu=[(n, i) for n, i, _ in r['tu'] if n in ('Agent', 'Task')], hp=r['hp']))
    pickle.dump(rows, open(R + 'rows.pkl', 'wb'))
    json.dump(log, open(R + 'transitions.json', 'w'))
    print('compaction-summary gaps charged to the operator by the old rule (h):', {k: round(v/3600,2) for k, v in stats.items()})
    print('rows', len(rows), 'transition events', collections.Counter(x[2] for x in log))

if __name__ == '__main__':
    main()
