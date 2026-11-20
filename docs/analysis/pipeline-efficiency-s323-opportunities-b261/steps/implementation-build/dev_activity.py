#!/usr/bin/env python3
"""Per-spawn activity breakdown for dev / dev-escalated / pre-reviewer seats of s323 (from story_spawns.tsv units).
For each spawn: load subagents/<unit>.jsonl of lead session 53b4296a (or 64926214), pair tool_use with tool_result by id,
classify each call, and book:
  tool = rts - ts (tool latency), think = ts - previous result ts (model generation + harness) with gaps > 300 s booked
  as 'standby' (agent idle, waiting for SendMessage / re-dispatch), also first-call gap booked as 'startup'.
Also tokens: per assistant message usage (out tokens, cache_read, cache_creation, input) booked to the activity of the
tool_use(s) of that message (split evenly when parallel), 'text-only' messages to 'final/text'.
Output: dev_activity.tsv (one row per spawn x activity) and dev_activity.out summary.
Usage: python3 -I dev_activity.py
"""
import json, re, glob, os, collections, bisect
from datetime import datetime
D = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/implementation-build/'
M = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
H = '/Users/n8/.claude/projects/-Users-n8-git-graph/'

def T(s): return datetime.strptime(s[:23], '%Y-%m-%dT%H:%M:%S.%f').timestamp()

RECORD = re.compile(r'(story-\d[-.]\d[^/]*\.md$|sprint-status|docs/reviews|test-results/|/captures?/|\.(txt|log|out)$|dev-report|gate-log|pipeline-snapshot|carry-over-backlog|escalations/|implementation-artifacts/)')
def classify(name, inp):
    if name in ('Edit', 'Write', 'NotebookEdit'):
        p = inp.get('file_path', '')
        return 'write:record' if RECORD.search(p) else 'write:code/tests'
    if name == 'Read':
        p = inp.get('file_path', '')
        if re.search(r'team-roles|\.claude/|postcompact|SKILL\.md', p): return 'read:role/engine-text'
        if re.search(r'story-\d|planning-artifacts|coding-conventions|architecture|sprint-status', p): return 'read:story/arch/conv'
        if RECORD.search(p): return 'read:records'
        return 'read:code'
    if name in ('Grep', 'Glob'): return 'search:code'
    if name == 'Agent': return 'spawn:' + str(inp.get('subagent_type'))
    if name == 'SendMessage': return 'sendmessage'
    if name in ('advisor', 'mcp__advisor__consult'): return 'advisor'
    if name.startswith('mcp__plugin_context-mode'): return 'ctx-tool'
    if name == 'Bash':
        c0 = inp.get('command', '')
        c = c0
        while True:  # strip leading `cd <dir> &&` / `cd <dir>;` and env prefixes (worktree-cd standing line)
            m = re.match(r'\s*cd\s+\S+\s*(&&|;)\s*', c)
            if not m: break
            c = c[m.end():]
        c = c.strip()
        if 'wait-for-deliverable' in c0: return 'bash:wait-own-job'
        if re.search(r'validate-mutation-red', c0): return 'evidence:mutation-red'
        if re.search(r'validate-handoff-evidence|render-dar|validate-artifact-derivations|validate-provenance|sprint-status\.sh|derive-stories|scripts/ai-dlc/validate-', c0): return 'evidence:validators'
        if re.search(r'pytest|vitest|jest|npm (run )?test|\bnpx\b|\.venv[^ ]*/bin/(python|pytest)|ruff|mypy|eslint|tsc\b|make |ci-local', c0): return 'run:tests/lint'
        if re.match(r'git (-C \S+ )?(commit|add)\b', c) or re.search(r'git (-C \S+ )?commit\b', c0): return 'git:commit/add'
        if re.match(r'git\b', c): return 'git:read'
        if re.match(r'(ls|cat|sed|grep|head|tail|wc|find|stat|test|echo|rg|awk|printf|date|pwd|diff|cmp|\[|file|sort|uniq|cut)\b', c): return 'shell:inspect(read)'
        if re.match(r'(python3?|node)\b', c): return 'python/node:inline'
        if re.search(r'>\s*\S+\s*<<|cat\s*>', c): return 'shell:write-heredoc'
        return 'bash:other'
    return 'other:' + name

def load_units():
    out = []
    for i, l in enumerate(open(D + 'story_spawns.tsv')):
        if i == 0: continue
        f = l.rstrip('\n').split('\t')
        if f[2] in ('dev', 'dev-escalated', 'pre-reviewer', 'protected-path-editor'):
            out.append(dict(start=f[0], end=f[1], role=f[2], story=f[3], desc=f[9], usd=float(f[6])))
    return out

def unit_id(u):
    for l in open(M + 'spawns.jsonl'):
        if u['start'] in l and u['desc'] in l and u['role'] in l:
            r = json.loads(l)
            if r['start'] == u['start'] and r['description'] == u['desc']: return r['unit'], r['sess']
    return None, None

def analyze(unit):
    fs = glob.glob(H + '*/subagents/' + unit + '.jsonl')
    if not fs: return None
    uses = {}
    calls = []
    msgs = {}  # message id -> [ts, out, cr, cw, in, kinds]  (one API message is logged once per content block; usage is repeated: dedupe by id)
    first = last = None
    with open(fs[0]) as f:
        for l in f:
            try: r = json.loads(l)
            except Exception: continue
            ts = r.get('timestamp'); t = r.get('type')
            if not ts: continue
            first = first or ts; last = ts
            if t == 'assistant':
                m = r.get('message', {}); u = m.get('usage', {}) or {}
                cont = m.get('content') if isinstance(m.get('content'), list) else []
                kinds = []
                for b in cont:
                    if b.get('type') == 'tool_use':
                        inp = b.get('input') or {}
                        uses[b['id']] = dict(ts=ts, name=b['name'], inp=inp, cls=classify(b['name'], inp))
                        kinds.append(uses[b['id']]['cls'])
                mid = m.get('id') or ts
                e = msgs.setdefault(mid, [ts, 0, 0, 0, 0, []])
                e[1] = max(e[1], u.get('output_tokens') or 0); e[2] = max(e[2], u.get('cache_read_input_tokens') or 0)
                e[3] = max(e[3], u.get('cache_creation_input_tokens') or 0); e[4] = max(e[4], u.get('input_tokens') or 0)
                e[5].extend(kinds)
            elif t == 'user':
                c = (r.get('message') or {}).get('content')
                if isinstance(c, list):
                    for b in c:
                        if b.get('type') == 'tool_result' and b.get('tool_use_id') in uses:
                            u = uses[b['tool_use_id']]; u['rts'] = ts; u['err'] = bool(b.get('is_error'))
                            calls.append(u)
    calls.sort(key=lambda c: c['ts'])
    res = sorted(T(c['rts']) for c in calls)
    t0 = T(first) if first else 0
    act = collections.defaultdict(lambda: dict(n=0, think=0.0, tool=0.0, out=0, cw=0, cr=0, inp=0))
    standby = 0.0
    for c in calls:
        ts, rts = T(c['ts']), T(c['rts'])
        k = bisect.bisect_left(res, ts)
        prev = res[k - 1] if k else t0
        th = max(0.0, ts - prev)
        a = act[c['cls']]
        a['n'] += 1; a['tool'] += max(0.0, rts - ts)
        if th > 300: standby += th
        else: a['think'] += th
    for ts, o, cr, cw, i, kinds in msgs.values():
        kinds = kinds or ['text/final']
        for kd in kinds:
            a = act[kd]; a['out'] += o / len(kinds); a['cr'] += cr / len(kinds); a['cw'] += cw / len(kinds); a['inp'] += i / len(kinds)
    return dict(first=first, last=last, wall=(T(last) - T(first)) if first else 0, standby=standby, act=act, ncalls=len(calls))

if __name__ == '__main__':
    rows = []
    for u in load_units():
        uid, sess = unit_id(u)
        if not uid: print('NOUNIT', u['desc']); continue
        a = analyze(uid)
        if not a: print('NOFILE', uid, u['desc']); continue
        rows.append((u, uid, a))
    with open(D + 'dev_activity.tsv', 'w') as o:
        o.write('unit\trole\tstory\tdesc\tusd\twall_min\tstandby_min\tactivity\tn\tthink_min\ttool_min\tout_tok\tcw_tok\tcr_tok\n')
        for u, uid, a in rows:
            for k, v in sorted(a['act'].items()):
                o.write('\t'.join(map(str, [uid, u['role'], u['story'], u['desc'], u['usd'], round(a['wall'] / 60, 1), round(a['standby'] / 60, 1), k, v['n'], round(v['think'] / 60, 2), round(v['tool'] / 60, 2), int(v['out']), int(v['cw']), int(v['cr'])])) + '\n')
    print('spawns analysed', len(rows))
