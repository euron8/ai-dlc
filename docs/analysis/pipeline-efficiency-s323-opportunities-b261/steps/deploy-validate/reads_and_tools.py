#!/usr/bin/env python3
# reads_and_tools.py SESSION A B -> (1) Read/ctx file reads in window (path, count); (2) tool_use counts by name,
# paired with tool_result by id, errored/denied dropped; (3) Bash latency top by command stem via timestamps
import json, sys, os, collections
from datetime import datetime
sess, a, b = sys.argv[1:4]
p = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/%s.jsonl' % sess)
def ts(s): return datetime.strptime(s[:23], '%Y-%m-%dT%H:%M:%S.%f') if '.' in s[:24] else datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S')
uses = {}; results = {}
for l in open(p):
    try: d = json.loads(l)
    except Exception: continue
    t = d.get('timestamp'); c = d.get('message', {}).get('content')
    if not t or not isinstance(c, list): continue
    for x in c:
        if x.get('type') == 'tool_use' and a <= t <= b: uses[x['id']] = (t, x['name'], x.get('input', {}))
        if x.get('type') == 'tool_result': results[x['tool_use_id']] = (t, bool(x.get('is_error')), x.get('content'))
cnt = collections.Counter(); err = collections.Counter(); reads = collections.Counter(); readbytes = collections.Counter()
lat = collections.defaultdict(list)
for i, (t, n, inp) in uses.items():
    r = results.get(i)
    if not r: cnt['__noresult__'] += 1; continue
    if r[1]: err[n] += 1; continue
    cnt[n] += 1
    if n == 'Read':
        reads[os.path.basename(inp.get('file_path', ''))] += 1
        cc = r[2]
        if isinstance(cc, list): cc = ' '.join(y.get('text', '') for y in cc if isinstance(y, dict))
        readbytes[os.path.basename(inp.get('file_path', ''))] += len(str(cc))
    dt = (ts(r[0]) - ts(t)).total_seconds()
    key = n
    if n == 'Bash':
        cmd = (inp.get('command') or '').strip().split()
        key = 'Bash:' + ' '.join(cmd[:2])[:40]
    lat[key].append(dt)
print('TOOL COUNTS (ok only):', dict(cnt.most_common(14)))
print('ERRORED:', dict(err))
print('READS (file: n, result chars):')
for f, n in reads.most_common(25): print('  ', f, n, readbytes[f])
print('LATENCY top by total seconds (key, n, total_s, max_s):')
for k, v in sorted(lat.items(), key=lambda kv: -sum(kv[1]))[:18]: print('  ', k, len(v), round(sum(v)), round(max(v)))
