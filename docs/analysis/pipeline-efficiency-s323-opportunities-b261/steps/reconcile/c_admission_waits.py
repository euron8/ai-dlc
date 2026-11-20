"""C: every agent that hit a refused suite launch in s323 (refusals.jsonl, A1): story, first/last refusal, time to the next admitted
reading (or agent end), agent lifetime, and whether the story's merge was the latest of its dependency chain.
Chains: wave-dag.copy.md edges 3.1->3.2, 5.4->5.5, 1.1->1.2->1.3->1.4->2.1->2.2->2.3->5.2 (actual merges below: graph first-parent
'Merge story X' commits, EST -> UTC +5 h)."""
import json, re, os, glob, collections, sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from lib import *
H = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
MERGE = {  # UTC = commit time (-05:00) + 5 h
    '4.2': '2026-11-18T14:04:23', '4.3': '2026-11-18T14:33:58', '5.1': '2026-11-18T15:21:14', '4.1': '2026-11-18T16:44:30',
    '5.3': '2026-11-18T16:27:15', '4.4': '2026-11-18T17:07:15', '5.4': '2026-11-18T17:53:31', '3.1': '2026-11-18T20:13:27',
    '1.1': '2026-11-18T21:06:42', '5.5': '2026-11-18T22:57:18', '1.2': '2026-11-19T03:14:50', '1.3': '2026-11-19T03:34:09',
    '1.4': '2026-11-19T03:34:30', '5.2': '2026-11-19T03:34:38', '3.2': '2026-11-19T03:35:21', '2.1': '2026-11-19T14:06:50',
    '2.2': '2026-11-19T15:45:36', '2.3': '2026-11-19T15:45:37'}
CHAIN = {'3.1': 'C1', '3.2': 'C1', '5.4': 'C3', '5.5': 'C3', '1.1': 'C2', '1.2': 'C2', '1.3': 'C2', '1.4': 'C2', '5.2': 'C2'}
sp = {s['unit']: s for s in map(json.loads, open(MONO + 'spawns.jsonl'))}
ref = [json.loads(l) for l in open(R + 'refusals.jsonl')]
WS, WE = '2026-11-13T08:00:00Z', '2026-11-20T04:20:00Z'
ref = [r for r in ref if WS <= r['ts'] <= WE]
by = collections.defaultdict(list)
for r in ref: by[r['f']].append(r)
tot = 0.0; out = []
for f, L in by.items():
    ag = os.path.basename(f)[:-6]
    s = sp.get(ag)
    first = min(r['ts'] for r in L); last = max(r['ts'] for r in L)
    adm = []
    for l in open(f, errors='replace'):
        if 'GiB: ok' not in l and 'admission: ADMITTED' not in l: continue
        try: o = json.loads(l)
        except Exception: continue
        if o.get('timestamp') and o['timestamp'] > last:
            m = o.get('message') if isinstance(o.get('message'), dict) else {}
            if isinstance(m.get('content'), list) and any(isinstance(b, dict) and b.get('type') == 'tool_result' for b in m['content']): adm.append(o['timestamp'])
    end = s['end'] if s else last
    stop = min(adm) if adm else end
    wait = (T(stop) - T(first)) / 60
    desc = s['description'] if s else '(lead session)'
    m = re.search(r'(?<![\d.])([1-5])[.-]([1-9])(?![\d.])', desc)
    story = m.group(1) + '.' + m.group(2) if m else '-'
    life = s['minutes'] if s else None
    ch = CHAIN.get(story)
    latest = None
    tie = None
    if ch:
        mem = [k for k, v in CHAIN.items() if v == ch and k in MERGE]
        mx = max(MERGE[k] for k in mem); latest = (MERGE[story] == mx) or ('tie<=2min' if (T(mx + 'Z') - T(MERGE[story] + 'Z')) <= 120 else False)
    out.append((first, ag[:14], 'sub' if '/subagents/' in f else 'lead', s['role'] if s else '-', story, len(L), round((T(last) - T(first)) / 60, 1), round(wait, 1), life, bool(adm), ch, latest, desc[:34]))
out.sort()
print('first refusal | agent | kind | role | story | refused blocks | first->last refusal min | wait to next admitted/agent end min | agent life min | admitted later | chain | story is latest-merged of its chain | desc')
for o in out: print(' | '.join(str(x) for x in o))
subs = [o for o in out if o[2] == 'sub']
print('sub agents', len(subs), 'sum wait min', round(sum(o[7] for o in subs)), 'sum first->last refusal min', round(sum(o[6] for o in subs)), 'sum agent life min', round(sum(o[8] or 0 for o in subs)))
byst = collections.defaultdict(float)
for o in subs: byst[o[4]] += o[7]
print('wait min by story', {k: round(v) for k, v in sorted(byst.items(), key=lambda x: -x[1])})
