"""bg_durations.py -- wall time of each BACKGROUND Bash command in update sessions, joined by tool_use id.
usage: python3 -I bg_durations.py [SPRINTS]   (population = MONO/units.jsonl lead units with skill ai-dlc-update)
A background command: its tool_use id appears in a later user <task-notification> ... <tool-use-id>ID</tool-use-id> row.
duration = notification timestamp - tool_use timestamp. Label = first reconcile/*.sh or known script name in the command.
Foreground Bash duration (tool_use -> tool_result) is printed per label too. Prints per sprint x label: n, total min, mean min."""
import json, os, sys, re, collections, datetime
MONO = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
ROOT = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph')
sprints = set(int(x) for x in (sys.argv[1] if len(sys.argv) > 1 else '321,322,323').split(','))
pop = [json.loads(l) for l in open(MONO + 'units.jsonl')]
pop = [u for u in pop if u['kind'] == 'lead' and 'ai-dlc-update' in (u.get('skills') or {}) and u['sprint'] in sprints]
KW = ['dist-clone', 'self-update-gate', 'self-update-fixtures', 'self-update-push', 'preclassify', 'emit-report', 'hard-blockers', 'layer-drift', 'unregistered-drift',
      'ledger-reverify', 'predicate-differential', 'derivation-differential', 'apply.sh', 'post-write-gates', 'push-drain', 'readopt-override', 'git push', 'gh pr merge', 'gh pr checks', 'retired-', 'relabel-extension', 'settings-merge', 'hermetic-run', 'run.sh']
def label(cmd):
    for k in KW:
        if k in cmd: return k
    return 'other'
def T(s): return datetime.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
bg = collections.defaultdict(list); fg = collections.defaultdict(list)
for u in pop:
    uses = {}; done = {}
    for l in open(ROOT + '/' + u['unit'] + '.jsonl', errors='replace'):
        try: d = json.loads(l)
        except Exception: continue
        ts = d.get('timestamp'); m = d.get('message') or {}; c = m.get('content')
        if not ts or not isinstance(c, list):
            if isinstance(c, str) and '<task-notification>' in c:
                for tid in re.findall(r'<tool-use-id>([^<]+)</tool-use-id>', c): done.setdefault(tid, ts)
            continue
        for b in c:
            if not isinstance(b, dict): continue
            if b.get('type') == 'tool_use' and b['name'] == 'Bash': uses[b['id']] = (ts, b.get('input', {}).get('command', ''), b.get('input', {}).get('run_in_background'))
            elif b.get('type') == 'tool_result' and b.get('tool_use_id') in uses and b['tool_use_id'] not in done and not uses[b['tool_use_id']][2]:
                t0 = uses[b['tool_use_id']]; fg[(u['sprint'], label(t0[1]))].append(T(ts) - T(t0[0]))
            elif b.get('type') == 'text' and '<task-notification>' in b.get('text', ''):
                for tid in re.findall(r'<tool-use-id>([^<]+)</tool-use-id>', b['text']): done.setdefault(tid, ts)
    for tid, t1 in done.items():
        if not t1: continue
        if tid in uses: bg[(u['sprint'], label(uses[tid][1]))].append(T(t1) - T(uses[tid][0]))
for name, dd in (('BACKGROUND', bg), ('FOREGROUND', fg)):
    print('==', name)
    for k in sorted(dd, key=lambda k: (k[0], -sum(dd[k]))):
        v = dd[k]
        print('%d %-24s n=%3d total=%6.1f min mean=%5.1f min max=%5.1f' % (k[0], k[1], len(v), sum(v) / 60, sum(v) / len(v) / 60, max(v) / 60))
