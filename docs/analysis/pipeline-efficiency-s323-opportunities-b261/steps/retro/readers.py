#!/usr/bin/env python3 -I
"""readers.py SESS START END : in the next sprint's first lead session, which tool calls touch
the previous retro's outputs. Pairs tool_use with tool_result (drops is_error / unmatched).
Prints per-pattern count of executed calls with the first 3 examples (tool, ts, 110 chars)."""
import sys, json, glob, os, re
from datetime import datetime
sess, t0, t1 = sys.argv[1:4]
f = glob.glob(os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/") + sess + "*.jsonl")[0]
P = lambda s: datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
a, b = P(t0), P(t1)
PATS = [("retro doc docs/retro/s", r"docs/retro/s\d+"), ("next-inputs / retro-artifacts", r"next-inputs|retro-artifacts"),
        ("push-candidate-ledger", r"push-candidate-ledger"), ("audit-anchors", r"audit-anchors"),
        ("party-mode-transcripts", r"party-mode-transcripts"), ("gate-log archive", r"gate-log-archive"),
        ("continuation-log archive", r"pipeline-continuation-log"), ("compaction-log", r"compaction-log"),
        ("gate-adjudication archive", r"gate-adjudication"), ("carry-over-backlog", r"carry-over-backlog"),
        ("escalations pending", r"escalations/pending"), ("snapshot", r"pipeline-snapshot"),
        ("sprint-status", r"sprint-status")]
uses = {}; res = {}
for l in open(f):
    try: d = json.loads(l)
    except Exception: continue
    ts = d.get('timestamp')
    if not ts: continue
    t = P(ts)
    c = (d.get('message') or {}).get('content')
    if not isinstance(c, list): continue
    for x in c:
        if not isinstance(x, dict): continue
        if x.get('type') == 'tool_use' and a <= t <= b: uses[x['id']] = (t, x['name'], json.dumps(x.get('input', {}))[:600])
        elif x.get('type') == 'tool_result': res[x['tool_use_id']] = bool(x.get('is_error'))
ok = {i: v for i, v in uses.items() if i in res and not res[i]}
print("session", sess, "window", t0, t1, "executed calls", len(ok), "of", len(uses))
for name, rx in PATS:
    hit = [(v[0], v[1], v[2]) for v in ok.values() if re.search(rx, v[2])]
    rd = [h for h in hit if h[1] == 'Read']
    print("%-30s calls %3d  (Read %2d)" % (name, len(hit), len(rd)))
    for t, n, s in sorted(hit)[:2]:
        print("     ", datetime.utcfromtimestamp(t).strftime('%H:%M:%S'), n, s[:130])
