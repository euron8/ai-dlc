#!/usr/bin/env python3
"""BL-975 after-side method: scan.sh DEATH rows -> lead's first action on the same seat/shard.
usage: first_action.py SCAN_OUT PROJECT_DIR
death  = scan 'last send' column if present, else scan 'notice' column (the cut).
action = earliest, after the death, of: lead Agent call whose description key (first two words,
         lowercased) matches the dead agent's description; lead SendMessage naming the agent id;
         scan 'reported' and 'resumed' columns.
description = the Agent tool_use whose tool_result mentions the agent id."""
import json, sys, os, re, statistics, datetime as dt
scan, proj = sys.argv[1], sys.argv[2]
def T(s): return dt.datetime.strptime(s, '%Y-%m-%dT%H:%M:%S.%fZ')
rows = []
for l in open(scan):
    f = l.rstrip('\n').split('\t')
    if f[0] == 'DEATH':
        rows.append(dict(sid=f[1], agent=f[2], arms=f[3], send=f[4], notice=f[5], rep=f[6], res=f[8]))
cache = {}
def lead(sid):
    if sid in cache: return cache[sid]
    recs = []
    for l in open(os.path.join(proj, sid + '.jsonl')):
        if l.startswith('{'):
            try: recs.append(json.loads(l))
            except Exception: pass
    use = {}; launches = []; sends = []; desc = {}
    for r in recs:
        c = r.get('message', {}).get('content'); t = r.get('timestamp') or ''
        if not isinstance(c, list): continue
        for b in c:
            if b.get('type') == 'tool_use':
                if b['name'] == 'Agent':
                    d = b['input'].get('description', ''); use[b['id']] = d; launches.append((t, d))
                if b['name'] == 'SendMessage': sends.append((t, json.dumps(b['input'])))
            if b.get('type') == 'tool_result':
                m = re.search(r'agentId: (a\w+)', json.dumps(b.get('content')))
                if m and b['tool_use_id'] in use: desc[m.group(1)] = use[b['tool_use_id']]
    for r in recs:  # fallback: failed-notice summary
        s = json.dumps(r.get('message', r))
        for m in re.finditer(r'task-id>(a\w+?)<.*?Agent \\+"([^"\\]+)\\+" failed', s):
            desc.setdefault(m.group(1), m.group(2))
    cache[sid] = (launches, sends, desc)
    return cache[sid]
def key(d):
    m = re.match(r'(\w+)\s+(\w+)', d or '')
    return (m.group(1).lower(), m.group(2).lower()) if m else None
out = []
for r in rows:
    launches, sends, desc = lead(r['sid'])
    death = r['send'] if r['send'] != '-' else r['notice']
    d = desc.get(r['agent'], '')
    cands = []
    for t, dd in launches:
        if t > death and ((key(dd) == key(d) and key(d)) or (dd == d and d)): cands.append((t, 'relaunch'))
    for t, x in sends:
        if t > death and r['agent'] in x: cands.append((t, 'sendmessage'))
        pn = re.search(r'part (\d+)', d or '', re.I)
        if t > death and pn and re.search(r'resume[^"]{0,60}part ' + pn.group(1) + r'\b', x, re.I): cands.append((t, 'sendmessage-part'))
    for col, nm in (('rep', 'report'), ('res', 'resume')):
        if r[col] != '-' and r[col] > death: cands.append((r[col], nm))
    cands.sort()
    lat = (T(cands[0][0]) - T(death)).total_seconds() if cands else None
    out.append((r['agent'], r['arms'], d, death, cands[0] if cands else None, lat))
for o in out: print('\t'.join(str(x) for x in (o[0], o[1], o[2], o[3], o[4][1] if o[4] else '-', '%.1f' % o[5] if o[5] is not None else 'NONE')))
for name, sel in (('A-only', lambda o: o[1] == 'A'), ('all', lambda o: True)):
    v = sorted(o[5] for o in out if sel(o) and o[5] is not None)
    n = sum(1 for o in out if sel(o))
    if v: print('SUMMARY', name, 'deaths', n, 'with action', len(v), 'none', n - len(v), 'min %.1f median %.1f max %.1f' % (v[0], statistics.median(v), v[-1]))
