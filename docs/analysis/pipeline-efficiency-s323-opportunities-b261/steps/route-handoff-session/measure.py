#!/usr/bin/env python3 -I
"""Read-only measurements for the route/handoff/session-overhead step (s321-s323).
Usage: python3 -I measure.py <handoff|stophook|compaction|advisor|snapshot|startup>
Inputs: MONO/segs.jsonl (extraction, read only) and graph lead transcripts (read only).
Population: lead sessions whose segs sprint is 321/322/323 (includes non-pipeline operator sessions in s323
pre-step; compaction counts therefore read 149 for s323 against the roll's 134)."""
import json, re, sys, glob, collections, statistics
from datetime import datetime
SP = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/'
M = SP + 'MONO/'
R = '/Users/n8/.claude/projects/-Users-n8-git-graph/'
T = lambda s: datetime.fromisoformat(s.replace('Z', '+00:00'))
segs = [json.loads(l) for l in open(M + 'segs.jsonl')]
SESS = {}
for s in segs:
    if s['kind'] == 'lead' and s['sprint'] in (321, 322, 323):
        SESS.setdefault(s['sess'], s['sprint'])

def rows_of(sid):
    for l in open(R + sid + '.jsonl'):
        try:
            yield json.loads(l)
        except Exception:
            pass

def blocks(r):
    m = r.get('message', {})
    c = m.get('content') if isinstance(m, dict) else None
    return c if isinstance(c, list) else []

def handoff():
    # in-session handoff = first handoff.md Read .. `touch .driver/handoff`; push window = first git push .. touch
    out = []
    for s in segs:
        if s['kind'] != 'lead' or s['step'] != 'handoff' or s['sprint'] not in (321, 322, 323):
            continue
        t0, t1 = T(s['first']), T(s['last']); push = touch = None
        for r in rows_of(s['sess']):
            ts = r.get('timestamp')
            if not ts: continue
            t = T(ts)
            if t < t0 or t > t1: continue
            for b in blocks(r):
                if b.get('type') == 'tool_use' and b['name'] == 'Bash':
                    cmd = json.dumps(b['input'])
                    if 'git push' in cmd and push is None: push = t
                    if '.driver/handoff' in cmd and 'touch' in cmd: touch = t
        out.append((s['sprint'], s['sess'][:8], round((t1 - t0).total_seconds() / 60, 1),
                    round((touch - t0).total_seconds() / 60, 1) if touch else None,
                    round((touch - push).total_seconds() / 60, 1) if touch and push else None))
    for o in sorted(out): print(o)
    for sp in (321, 322, 323):
        print(sp, 'seg elapsed min', round(sum(o[2] for o in out if o[0] == sp), 1),
              'in-session min', round(sum(o[3] for o in out if o[0] == sp and o[3]), 1),
              'push window min', round(sum(o[4] for o in out if o[0] == sp and o[4]), 1))

def stophook():
    cnt = collections.Counter()
    for sid, sp in SESS.items():
        for r in rows_of(sid):
            m = r.get('message', {}); c = m.get('content') if isinstance(m, dict) else None
            if r.get('type') == 'user' and isinstance(c, str) and c.startswith('Stop hook feedback:'):
                k = 'handoff-guard' if 'HANDOFF GUARD' in c[:60] else 'pipeline-active' if 'Pipeline is active' in c[:60] else 'other'
                cnt[(sp, k)] += 1
    print(sorted(cnt.items()))

def compaction():
    for sp in (321, 322, 323):
        post = []
        for sid, s2 in SESS.items():
            if s2 != sp: continue
            for r in rows_of(sid):
                if r.get('subtype') == 'compact_boundary':
                    post.append(r['compactMetadata']['postTokens'])
        print(sp, 'n', len(post), 'post tokens median', statistics.median(post), 'mean', round(statistics.mean(post)))

def advisor():
    res = collections.defaultdict(lambda: [0, []])
    for sid, sp in SESS.items():
        pend = {}
        for r in rows_of(sid):
            if not r.get('timestamp'): continue
            for b in blocks(r):
                t = b.get('type')
                if (t == 'server_tool_use' and b.get('name') == 'advisor') or (t == 'tool_use' and b.get('name') == 'mcp__advisor__consult'):
                    res[sp][0] += 1; pend[b['id']] = T(r['timestamp'])
                if t in ('advisor_tool_result', 'tool_result') and b.get('tool_use_id') in pend:
                    res[sp][1].append((T(r['timestamp']) - pend.pop(b['tool_use_id'])).total_seconds())
    for sp in (321, 322, 323):
        n, l = res[sp]; print(sp, 'attempts', n, 'paired', len(l), 'median s', statistics.median(l), 'total h', round(sum(l) / 3600, 2))

def snapshot():
    cat = collections.defaultdict(collections.Counter)
    for sid, sp in SESS.items():
        for r in rows_of(sid):
            for b in blocks(r):
                if b.get('type') == 'tool_use' and b['name'] == 'Bash':
                    cmd = b['input'].get('command', '')
                    if 'snapshot-update.sh' not in cmd: continue
                    k = 'help' if re.search(r'snapshot-update.sh[^|;&]*--help', cmd) else 'trim' if '--move-to-history' in cmd else 'row' if '--row-' in cmd else 'activity' if '--activity' in cmd else 'set/line/open' if re.search(r'--(set|line|open-item|section)', cmd) else 'other'
                    cat[sp][k] += 1
    for sp in (321, 322, 323): print(sp, dict(cat[sp]), 'total', sum(cat[sp].values()))

def startup():
    for p in ('0ef7ba46', '4b34031d', '53b4296a', '64926214', '68cf8de7'):
        f = glob.glob(R + p + '*.jsonl')[0]; t0 = None; ev = {}
        for l in open(f):
            r = json.loads(l)
            if not r.get('timestamp'): continue
            t = T(r['timestamp']); t0 = t0 or t
            for b in blocks(r):
                if b.get('type') != 'tool_use': continue
                el = (t - t0).total_seconds() / 60; fp = b['input'].get('file_path', '')
                if b['name'] == 'Read' and fp.endswith('steps/route.md'): ev.setdefault('first route.md read', round(el, 1))
                if b['name'] == 'Read' and '/steps/' in fp and not fp.endswith('route.md'): ev.setdefault('first step file read', round(el, 1))
                if b['name'] == 'Agent': ev.setdefault('first Agent', round(el, 1))
            if 'first Agent' in ev: break
        print(p, ev)

if __name__ == '__main__':
    {'handoff': handoff, 'stophook': stophook, 'compaction': compaction, 'advisor': advisor, 'snapshot': snapshot, 'startup': startup}[sys.argv[1]]()
