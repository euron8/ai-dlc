"""BL-913: lead gate-script calls and the gate-script class of lead active time, s320 against s322.

Usage (stdlib only, read only):
  OUT=<scratch>; EXTRACT_WIN_END=2026-11-12T12:32:58Z python3 -I docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py $OUT
  python3 -I docs/analysis/pipeline-efficiency-s317-s318/scripts/analyze.py $OUT
  python3 -I docs/analysis/step-value-b257/bl913/gate_calls.py $OUT [$OUT_FILING]

$OUT_FILING (optional) is an extraction by the FILING-ERA extractor, used only to trace the filed 15.8 h:
  git show 9d0bca846:docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py > <s>/extract.py
  git show 9d0bca846:docs/analysis/pipeline-efficiency-s317-s318/scripts/analyze.py > <s>/analyze.py
  EXTRACT_WIN_END=2026-10-29T23:20:00Z python3 -I <s>/extract.py $OUT_FILING && python3 -I <s>/analyze.py $OUT_FILING
(2026-10-29T23:20Z is the s320 edge the filing commit d44b83ca7 names.)

Reads ~/.claude/projects/-Users-n8-git-graph (graph lead transcripts; a lead record is isSidechain false) and
lists graph's gate-transition plans at the pinned ref with `git ls-tree` (read only). s322 window end:
2026-11-12T12:32:58Z, graph f7e60625b "chore(s322): finalize snapshot -- sprint 322 closed".

CONTROLS FIRST. The script reproduces every b256 figure BL-913 recorded (batch b256 paragraph) and exits 2 on
any mismatch BEFORE printing a new figure. The grammar is b256's: an occurrence is a match of
(?<![\\w-])<script name> in a lead Bash tool_use command.
"""
import collections, glob, json, os, re, subprocess, sys
from datetime import datetime

D = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph')
GRAPH = os.path.expanduser('~/git/graph')
REF = 'f7e60625b'
WIN_END = '2026-11-12T12:32:58Z'
NINE = ['verdict.sh', 'validate-handoff-evidence.sh', 'gate-checkpoint.sh', 'partition-review-diff.sh',
        'validate-gate-adjudication.sh', 'validate-artifact-derivations.sh', 'validate-adversarial-convergence.sh',
        'validate-escalation-resolution.sh', 'merge-review-shards.sh']
GT = 'gate-transition.sh'
ABSENT = 'zqxj-never-913.sh'
FILED = dict(zip(NINE, [262, 209, 185, 101, 77, 70, 54, 50, 44]))   # the filing's per-script counts (sum 1,052)
RX = {s: re.compile(r'(?<![\w-])' + re.escape(s)) for s in NINE + [GT, ABSENT]}
S320 = ('04c0da6d-d554-4c21-b2c3-521fd3c8ffc9 0de9fe4e-fe7f-43b5-a6d8-9ea9e85054fc ca14f3b7-73fb-4ba6-a36b-ae3a92cea7c8 '
        '517a5b03-27fd-4634-ba0d-d40ff8b578b5 77ef0c7b-efd8-4e21-9a5a-fd5dfc6f9041 81ea73ea-9390-4d14-9f08-3b869f4321d6 '
        'dd2df1d7-3a14-461e-b000-2b8943cffa6c').split()
S320_EARLY = ['719a49a0', 'd71fcbce', 'd22c7889']          # the 3 further sprint_id-320 transcripts (b256)
S322 = ('6c14d949-03a3-4d5c-bc77-49f657ea692e 80c96d42-f732-4310-8f0e-1c058dd7a0b3 9a646a3b-668c-4da5-991f-e1e21c46f617 '
        'fdc4249a-b74e-4dc5-a86b-71cf8db29def 70fd1d6d-3a65-4a22-8c34-e87ccb36bbd8 6249c621-d716-4f5c-a3f7-f70c97d6cf89 '
        'e444bf13-0caa-4c51-8740-f3367f670c13').split()
IMPL320 = ('2026-10-27T06:20:41Z', '2026-10-29T13:25:18Z')   # b256: first steps/implementation.md ref .. first steps/sprint-review.md ref
IMPL322 = ('2026-11-10T18:47:12Z', '2026-11-12T03:35:48Z')
SPRINT320_FILED = ('2026-10-23T09:53:00Z', '2026-10-29T23:20:00Z')   # extractor s319->s320 edge .. the filing's s320 edge
SPRINT320_NOW = ('2026-10-23T09:53:00Z', '2026-10-30T00:10:03Z')     # the current extractor's s320 edges
SPRINT322 = ('2026-11-09T00:00:00Z', WIN_END)                         # the current extractor's s322 start .. F-B1 end
STORIES = {320: 13, 322: 8}
S323_FIRST = '0ef7ba46'
SID = {n: re.compile(r'sprint_id[^0-9a-zA-Z]{1,6}%d([^0-9]|$)' % n) for n in (320, 322)}

def pt(s): return datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
fails = []
def want(name, got, exp):
    ok = got == exp
    print(f'CONTROL {"MATCH" if ok else "MISMATCH"} {name}: {got} (recorded {exp})')
    if not ok: fails.append(name)

# ---- one pass over every graph transcript: lead records only ----
bash = []        # (ts, file8, tool_use id, command)
results = {}     # tool_use id -> result text
dispatch = []    # (ts, file8, prompt)
implrefs = []    # (ts, file8, tool name, snippet) for tool inputs naming steps/implementation.md
srrefs = []      # same for steps/sprint-review.md (the re-entry check's present control)
recs_by_file = {}  # file -> [(ts, uuid, record)] for the 14 named files (active-hours heuristic)
sid_files = {320: set(), 322: set()}
first_ts = {}
NAMED = set(S320 + S322)
for p in sorted(glob.glob(D + '/*.jsonl')):
    fid = os.path.basename(p)[:-6]; f8 = fid[:8]
    keep = fid in NAMED
    for line in open(p, errors='replace'):
        for n, rx in SID.items():
            if rx.search(line): sid_files[n].add(f8)
        try: r = json.loads(line)
        except Exception: continue
        if r.get('isSidechain') is not False: continue
        ts = r.get('timestamp')
        if ts and (f8 not in first_ts or ts < first_ts[f8]): first_ts[f8] = ts
        if keep: recs_by_file.setdefault(fid, []).append((ts, r.get('uuid'), r))
        cont = (r.get('message') or {}).get('content')
        if not isinstance(cont, list): continue
        for it in cont:
            if not isinstance(it, dict): continue
            if it.get('type') == 'tool_use' and r.get('type') == 'assistant':
                inp = it.get('input') or {}
                if it.get('name') == 'Bash': bash.append((ts, f8, it.get('id'), inp.get('command') or ''))
                if it.get('name') in ('Agent', 'Task'): dispatch.append((ts, f8, inp.get('prompt') or '', inp.get('description') or ''))
                s = json.dumps(inp)
                if 'steps/implementation.md' in s: implrefs.append((ts, f8, it.get('name'), s[:110]))
                if 'steps/sprint-review.md' in s: srrefs.append((ts, f8, it.get('name'), s[:110]))
            elif it.get('type') == 'tool_result':
                results[it.get('tool_use_id')] = json.dumps(it.get('content'))

def occ_of(cmds, names=NINE):
    c = collections.Counter()
    for ts, f8, i, cmd in cmds:
        for s in names: c[s] += len(RX[s].findall(cmd))
    return c
def by_files(f8s): return [b for b in bash if b[1] in f8s]
def in_win(cmds, w): return [b for b in cmds if b[0] and w[0] <= b[0] < w[1]]
def dedup(cmds):
    seen = set(); out = []
    for b in cmds:
        if b[2] in seen: continue
        seen.add(b[2]); out.append(b)
    return out

# ---- active-hours heuristic (b256's active.py, unchanged semantics) ----
def active(files, w0s, w1s):
    w0, w1 = pt(w0s), pt(w1s)
    recs = []; seen = set()
    for f in files:
        for ts, u, r in recs_by_file.get(f, []):
            if not ts or u in seen: continue
            seen.add(u); recs.append((pt(ts), r))
    recs.sort(key=lambda x: x[0])
    act = collections.Counter(); cur = 'none'; occ = collections.Counter(); cmds_gate = 0; gt_only = 0; nbash = 0
    for i, (t, r) in enumerate(recs):
        if not (w0 <= t < w1): continue
        cont = (r.get('message') or {}).get('content')
        if r.get('type') == 'assistant' and isinstance(cont, list):
            for it in cont:
                if not isinstance(it, dict) or it.get('type') != 'tool_use': continue
                nm = it.get('name'); inp = it.get('input') or {}
                if nm == 'Bash':
                    cmd = inp.get('command') or ''; nbash += 1
                    names = [s for s in NINE + [GT] if RX[s].search(cmd)]
                    if names: cur = 'gate'; cmds_gate += 1; gt_only += (names == [GT])
                    elif re.search(r'\bsleep\b|wait-for-deliverable', cmd): cur = 'wait'
                    else: cur = 'bash-other'
                    for s in NINE + [GT, ABSENT]: occ[s] += len(RX[s].findall(cmd))
                elif nm in ('Agent', 'Task'): cur = 'agent'
                else: cur = 'tool-' + str(nm)
        if i + 1 < len(recs):
            g = recs[i + 1][0] - t
            if g <= 300 and recs[i + 1][0] < w1: act[cur] += g
    return act, occ, cmds_gate, gt_only, nbash

h = lambda x: round(x / 3600, 2)

# ================= CONTROLS (b256) =================
print('== controls: the b256 BL-913 figures, reproduced before any new figure')
c7 = occ_of(by_files({f[:8] for f in S320}))
want('s320 7 files, nine-script occurrences (the 898)', sum(c7[s] for s in NINE), 898)
a, o, cg, _, _ = active(S320, '2000-01-01T00:00:00Z', '2100-01-01T00:00:00Z')
want('s320 7 files, lead commands naming a gate script (the 529)', cg, 529)
ten = {f[:8] for f in S320} | set(S320_EARLY)
c10 = occ_of(by_files(ten))
want('s320 10 sprint_id files, nine-script occurrences (the 1,031)', sum(c10[s] for s in NINE), 1031)
for s, e in (('verdict.sh', 262), ('gate-checkpoint.sh', 185), ('validate-escalation-resolution.sh', 50)):
    want(f'  10 files, {s}', c10[s], e)
a20, o20, cg20, _, _ = active(S320, *IMPL320)
want('s320 implementation window, occurrences', sum(o20[s] for s in NINE), 735)
want('s320 implementation window, commands', cg20, 394)
want('s320 implementation window, gate-class h', h(a20['gate']), 2.71)
want('s320 implementation window, lead active h', h(sum(a20.values())), 13.56)
a22, o22, cg22, gto22, nb22 = active(S322, *IMPL322)
want('s322 implementation window, nine-script occurrences', sum(o22[s] for s in NINE), 242)
want('s322 implementation window, gate-transition.sh occurrences', o22[GT], 92)
want('s322 implementation window, commands', cg22, 237)
want('s322 implementation window, commands naming only gate-transition.sh', gto22, 85)
want('s322 implementation window, gate-class h', h(a22['gate']), 0.98)
want('s322 implementation window, lead active h', h(sum(a22.values())), 12.36)
PAIRS = {'validate-handoff-evidence.sh': (194, 7), 'partition-review-diff.sh': (99, 2), 'verdict.sh': (165, 31),
         'gate-checkpoint.sh': (140, 102), 'validate-gate-adjudication.sh': (62, 24),
         'validate-escalation-resolution.sh': (24, 2), 'validate-artifact-derivations.sh': (7, 2),
         'validate-adversarial-convergence.sh': (3, 0), 'merge-review-shards.sh': (41, 72)}
for s, (x, y) in PAIRS.items():
    want(f'  per script s320 -> s322 window, {s}', (o20[s], o22[s]), (x, y))
absent = sum(len(RX[ABSENT].findall(b[3])) for b in bash)
want('impossible token zqxj-never-913.sh, every lead Bash command of every graph transcript', absent, 0)
print(f'   present-token control beside it: lead Bash commands scanned {len(bash)}, of them naming verdict.sh '
      f'{sum(1 for b in bash if RX["verdict.sh"].search(b[3]))}')
if fails:
    print('CONTROLS FAILED:', fails); sys.exit(2)

# ================= F-B1 window control =================
print('\n== window control (F-B1)')
s323 = first_ts.get(S323_FIRST)
print(f'first lead record of {S323_FIRST} (the s323 session) {s323}; window end {WIN_END}; after the window: {bool(s323 and s323 > WIN_END)}')
if not (s323 and s323 > WIN_END): print('WINDOW CONTROL FAILED'); sys.exit(2)

# ================= item: the 21-call residual =================
print('\n== the filed 1,052 and the 21-call residual')
lead320 = dedup(in_win(bash, SPRINT320_FILED))
cf = occ_of(lead320)
print(f'every graph lead transcript, Bash commands timestamped in [{SPRINT320_FILED[0]}, {SPRINT320_FILED[1]}), deduped on tool_use id: '
      f'{sum(cf[s] for s in NINE)} occurrences')
print('   per script against the filing: ' + ', '.join(f'{s} {cf[s]} ({cf[s] - FILED[s]:+d})' for s in NINE))
print(f'   same invocation, b256 rule (10 sprint_id-320 files, whole): {sum(c10[s] for s in NINE)}')
perfile_in = collections.Counter(); perfile_all = collections.Counter()
for b in lead320: perfile_in[b[1]] += sum(len(RX[s].findall(b[3])) for s in NINE)
for b in by_files(ten): perfile_all[b[1]] += sum(len(RX[s].findall(b[3])) for s in NINE)
outside = {f: perfile_all[f] - perfile_in[f] for f in sorted(ten)}
extra = {f: n for f, n in perfile_in.items() if f not in ten and n}
A = sum(extra.values()); B = sum(outside.values())
print(f'   occurrences in-window from transcripts carrying no sprint_id 320: {A} {dict(sorted(extra.items()))}')
print(f'   occurrences in the 10 sprint_id-320 files OUTSIDE that window: {B} {dict((k, v) for k, v in outside.items() if v)}')
print(f'   identity: 1,031 - {B} + {A} = {1031 - B + A}')
seven = {f[:8] for f in S320}
in7 = sum(perfile_in[f] for f in seven); in3 = sum(perfile_in[f] for f in S320_EARLY)
out7 = sum(outside[f] for f in seven)
print(f'   the 154 (1,052 - 898): 3 earlier sprint_id-320 files in-window {in3} + no-sprint_id files {A} - 7 files outside the window {out7} = {in3 + A - out7}')

# ================= item: the 15.8 h =================
def segsum(O):
    act = collections.defaultdict(float); last = {}
    for l in open(os.path.join(O, 'segs.jsonl')):
        s = json.loads(l)
        if s['kind'] != 'lead' or s['step'] not in ('implementation', 'gate-validation[implementation]'): continue
        act[(s['sprint'], s['step'])] += s['active']
        last[(s['sprint'], s['step'])] = max(last.get((s['sprint'], s['step']), ''), s['last'])
    return act, last
print('\n== the filed 15.8 h (s320 implementation step total)')
act, last = segsum(sys.argv[1])
t20 = act[(320, 'implementation')] + act[(320, 'gate-validation[implementation]')]
print(f'current extractor ($OUT, EXTRACT_WIN_END={WIN_END}): s320 lead active implementation {act[(320, "implementation")]/3600:.3f} h + '
      f'gate-validation[implementation] {act[(320, "gate-validation[implementation]")]/3600:.3f} h = {t20/3600:.3f} h')
if len(sys.argv) > 2:
    actf, _ = segsum(sys.argv[2])
    tf = actf[(320, 'implementation')] + actf[(320, 'gate-validation[implementation]')]
    print(f'filing-era extractor 9d0bca846 at 2026-10-29T23:20:00Z ($OUT_FILING): {actf[(320, "implementation")]/3600:.3f} h + '
          f'{actf[(320, "gate-validation[implementation]")]/3600:.3f} h = {tf/3600:.3f} h')
print('   15.8 h reproduced by neither: UNRESOLVED')
for sp in (320, 322):
    ti = act[(sp, 'implementation')]; tg = act[(sp, 'gate-validation[implementation]')]
    print(f'current extractor, s{sp} lead active implementation + gate-validation[implementation]: {(ti + tg)/3600:.3f} h, '
          f'per story ({STORIES[sp]}) {(ti + tg)/3600/STORIES[sp]:.2f} h')

# ================= item: no later resume re-enters implementation =================
print('\n== re-entry after the s322 implementation window (03:35:48Z .. window end)')
for k in ((322, 'implementation'), (322, 'gate-validation[implementation]')):
    print(f'extractor: last s322 lead segment record of {k[1]}: {last.get(k)}')
after = (IMPL322[1], WIN_END); before = IMPL322
def gt_runs(w):
    # one run per deduped command, the same rule as the refusal count below
    c = collections.Counter()
    for ts, f8, i, cmd in dedup(in_win(bash, w)):
        m = re.search(r'gate-transition\.sh\s+\S+\s+(1|2|3|close)\b', cmd)
        if m: c[m.group(1)] += 1
    return dict(sorted(c.items()))
def disp(w):
    plan = sum(1 for ts, f8, p, d in dispatch if ts and w[0] <= ts < w[1] and re.search(r'(?m)^\s*gate-plan:', p))
    sh = [(p, d) for ts, f8, p, d in dispatch if ts and w[0] <= ts < w[1] and not re.search(r'(?m)^\s*gate-plan:', p) and re.search(r'(?m)^\s*shard:', p)]
    return plan, sh
for name, w in (('before (control)', before), ('after', after)):
    pl, sh = disp(w)
    ir = [x for x in implrefs if x[0] and w[0] <= x[0] < w[1]]
    sr = [x for x in srrefs if x[0] and w[0] <= x[0] < w[1]]
    print(f'{name} [{w[0]}, {w[1]}): gate-transition runs by gate {gt_runs(w)}; dispatches with gate-plan: {pl}, '
          f'shard: without gate-plan: {len(sh)}; tool inputs naming steps/implementation.md {len(ir)}; naming steps/sprint-review.md {len(sr)}')
    if name == 'after':
        for x in ir: print('   implementation.md ref:', x[0], x[1], x[2], x[3])
        cls = collections.Counter(('retro' if 'retro' in (re.search(r'(?m)^\s*shard:\s*(.*)$', p).group(1) + ' ' + d).lower() else 'other: ' + d[:40]) for p, d in sh)
        print(f'   shard: dispatches without gate-plan, by shard value or description: {dict(cls)}')

# ================= item: whole-sprint count =================
print('\n== whole-sprint lead gate-script calls, one rule both sides (every graph lead transcript, timestamp-bounded, deduped on tool_use id)')
def whole(w, label, n, sidset):
    cmds = dedup(in_win(bash, w)); c = occ_of(cmds, NINE + [GT])
    nine = sum(c[s] for s in NINE)
    ncmd = sum(1 for b in cmds if any(RX[s].search(b[3]) for s in NINE + [GT]))
    sid = occ_of([b for b in cmds if b[1] in sidset], NINE + [GT])
    print(f'{label} [{w[0]}, {w[1]}): nine {nine}, gate-transition.sh {c[GT]}, together {nine + c[GT]} over {ncmd} commands; '
          f'per story ({n}) nine {nine / n:.1f}, together {(nine + c[GT]) / n:.1f}; '
          f'sprint_id files only: nine {sum(sid[s] for s in NINE)}, gate-transition.sh {sid[GT]}')
    print('   per script: ' + ', '.join(f'{s} {c[s]}' for s in NINE + [GT]))
    return nine, c[GT]
whole(SPRINT320_FILED, 's320 (filing edge)', STORIES[320], sid_files[320])
whole(SPRINT320_NOW, 's320 (current extractor edge)', STORIES[320], sid_files[320])
n22, g22 = whole(SPRINT322, 's322', STORIES[322], sid_files[322])
print(f'   s322 sprint_id-322 files: {sorted(sid_files[322])}')

# ================= plans at the pinned ref; gate passes =================
print(f'\n== gate-transition plans at graph {REF}')
ls = subprocess.run(['git', '-C', GRAPH, 'ls-tree', '-r', '--name-only', REF, '--',
                     '_bmad-output/implementation-artifacts/s322/gate-transition'], capture_output=True, text=True).stdout.split()
plans = [os.path.basename(x) for x in ls if x.endswith('.plan')]
caps = [x for x in ls if x.endswith('.captures')]
kinds = collections.Counter(re.search(r'-g(1|2|3|close)-p', p).group(1) for p in plans)
miss = subprocess.run(['git', '-C', GRAPH, 'ls-tree', '-r', '--name-only', REF, '--',
                       '_bmad-output/implementation-artifacts/s322/gate-transition-zqxj'], capture_output=True, text=True).stdout.split()
passes = kinds['1'] + kinds['2'] + kinds['3']
print(f'.plan {len(plans)}, .captures {len(caps)}, by gate {dict(sorted(kinds.items()))}; gate passes (g1+g2+g3) {passes}; '
      f'must-miss path entries {len(miss)}')
print(f'whole-sprint s322 per gate pass: nine {n22 / passes:.1f}, together {(n22 + g22) / passes:.1f}')

# ================= gate-transition refusals, s322 =================
print('\n== gate-transition.sh refusals by id, s322 whole sprint')
ref = collections.Counter(); runs = 0
for ts, f8, i, cmd in dedup(in_win(bash, SPRINT322)):
    if not re.search(r'gate-transition\.sh\s+\S+\s+(1|2|3|close)\b', cmd): continue
    runs += 1
    for k in re.findall(r'gate-transition: REFUSED ([a-z0-9-]+)', results.get(i, '')): ref[k] += 1
print(f'runs {runs}; refusal lines by id {dict(sorted(ref.items()))}; dar-fold {ref.get("dar-fold", 0)}')

# ================= s321: the first graph sprint that runs the program (b257 verifier) =================
# Sprint edges are the CURRENT extractor's EDGES for every sprint, so the calls and the seat figures share one
# population rule: s320 [2026-10-23T09:53:00Z, 2026-10-30T00:10:03Z), s321 [.., 2026-11-09T00:00:00Z), s322 [.., WIN_END).
SPRINT321 = ('2026-10-30T00:10:03Z', '2026-11-09T00:00:00Z')
STORIES[321] = 25
EDGE = {320: SPRINT320_NOW, 321: SPRINT321, 322: SPRINT322}
print('\n== s321 against s320 and s322, one edge rule (the current extractor\'s sprint edges) for every side')
gtr = [(ts, f8, i, cmd) for ts, f8, i, cmd in dedup(bash) if ts and re.search(r'gate-transition\.sh\s+\S+\s+(1|2|3|close)\b', cmd)]
gtr.sort()
print(f'first lead gate-transition.sh run on any graph transcript: {gtr[0][0] if gtr else None} ({gtr[0][1] if gtr else ""})')
REVRX = re.compile(r'^[0-9]+-[0-9]+-(code-review|qa-validation)(-p[0-9]+)?\.md$')
def g12_passes(n):
    out = subprocess.run(['git', '-C', GRAPH, 'ls-tree', '--name-only', REF + ':docs/reviews/s%d' % n], capture_output=True, text=True).stdout.split()
    c = collections.Counter(REVRX.match(x).group(1) for x in out if REVRX.match(x))
    return c, len(out)
for n in (320, 321, 322):
    cmds = dedup(in_win(bash, EDGE[n])); c = occ_of(cmds, NINE + [GT]); nine = sum(c[s] for s in NINE)
    runs_n = sum(1 for b in cmds if re.search(r'gate-transition\.sh\s+\S+\s+(1|2|3|close)\b', b[3]))
    rv, nfiles = g12_passes(n); p12 = rv['code-review'] + rv['qa-validation']
    refs_n = collections.Counter()
    darf = []
    for ts, f8, i, cmd in cmds:
        m = re.search(r'gate-transition\.sh\s+(\S+)\s+(1|2|3|close)\b', cmd)
        if not m: continue
        for k in re.findall(r'gate-transition: REFUSED ([a-z0-9-]+)', results.get(i, '')):
            refs_n[k] += 1
            if k == 'dar-fold': darf.append((ts, m.group(1)))
    print(f's{n} [{EDGE[n][0]}, {EDGE[n][1]}): nine {nine}, gate-transition.sh occurrences {c[GT]}, together {nine + c[GT]}; '
          f'per story ({STORIES[n]}) {(nine + c[GT]) / STORIES[n]:.1f}; story review files at {REF} matching '
          f'<e>-<s>-code-review|qa-validation[-pM].md: code-review {rv["code-review"]}, qa-validation {rv["qa-validation"]}, '
          f'of {nfiles} entries (NOT a gate-pass count: the naming differs per sprint); gate-transition.sh runs {runs_n}; '
          f'dar-fold refusals {len(darf)} over {len(set(s for _, s in darf))} story indexes {sorted(set(s for _, s in darf))}')
    print('   per script: ' + ', '.join(f'{s} {c[s]}' for s in NINE + [GT]))
miss = subprocess.run(['git', '-C', GRAPH, 'ls-tree', '--name-only', REF + ':docs/reviews/s999'], capture_output=True, text=True).stdout.split()
print(f'   must-miss review directory s999 entries: {len(miss)}')

# ---- seat figures for the step group, by roll.py's own seat_sum/seat_line (imported, unchanged) ----
import importlib.util
_rp = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'pipeline-efficiency-s317-s320', 'scripts', 'roll.py')
_sp = importlib.util.spec_from_file_location('roll', _rp); roll = importlib.util.module_from_spec(_sp); _sp.loader.exec_module(roll)
import csv
rows = list(csv.DictReader(open(os.path.join(sys.argv[1], 'steps.csv'))))
HM = {seat: roll.hosted_mix(rows, seat) for seat in ('lead', 'sub')}
print('\n== seat figures per story, roll.py seat_sum/seat_line on $OUT (pipeline bucket)')
ctl = roll.seat_line(roll.seat_sum(rows, HM, 'pipeline', {'stories-test-strategy'}, {321}), roll.STORIES[321])
want('roll.py seat_line, s321 stories-test-strategy (BL-811 outcome row)', ctl.split(';')[0],
     '0.79 h gap-inclusive (gap 0.42 h), token-equivalent $26.9 (API $26.1), 47.5M tokens')
if fails: print('CONTROLS FAILED:', fails); sys.exit(2)
for label, steps in (('implementation', {'implementation'}), ('gate-validation[implementation]', {'gate[implementation]'}),
                     ('implementation plus gate-validation[implementation]', {'implementation', 'gate[implementation]'})):
    for n in (320, 321, 322):
        print(f'{label} s{n} ({roll.STORIES[n]} stories): ' + roll.seat_line(roll.seat_sum(rows, HM, 'pipeline', steps, {n}), roll.STORIES[n]))
