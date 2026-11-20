#!/usr/bin/env python3 -I
"""Full-suite launches by role in s323 (and s322) from the finished bash corpus (hand-s323late/out/bash.jsonl) joined to MONO/spawns.jsonl.
A launch = a Bash row whose cmd STARTS (after env/cd prefix) a run: contains 'pytest-footprint-watchdog.py' or 'merge-review-shards.sh --record-run'
or a pytest invocation over a whole tree (rebalancer/tests|server/ with no -k and no ::), and does NOT begin with grep/cat/tail/ls/wc/sed/head (a mention).
Also totals: wall minutes of those rows (lat), wait-for-deliverable minutes per role, refusals ('REFUSED' + 'headroom' in the result text).
Controls: role zz-nope = 0 rows; a mention-only row (cmd 'grep -n pytest-footprint-watchdog x') must classify as NOT a launch (asserted below)."""
import json, re, collections, sys
SC = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/'
sp = int(sys.argv[1]) if len(sys.argv) > 1 else 323
spawn = {}
for l in open(SC + 'MONO/spawns.jsonl'):
    x = json.loads(l); spawn[x['unit']] = x
rows = [json.loads(l) for l in open(SC + 'hand-s323late/out/bash.jsonl')]
MENTION = re.compile(r'^\s*(grep|cat|tail|ls|wc|sed|head|echo|printf|test|\[)\b')
LAUNCH = re.compile(r'pytest-footprint-watchdog\.py|merge-review-shards\.sh\s+--record-run|(?:^|[;&|]\s*|\s)(?:\S*python3?\s+-m\s+)?pytest\s+(?:rebalancer/tests|server|scripts/tests)\b(?![^|;&]*(?:-k\s|::))')
def is_launch(cmd):
    parts = re.split(r'(?:&&|;|\|\|)', cmd)
    for p in parts:
        p = re.sub(r'^\s*(?:[A-Z_]+=\S+\s+)*', '', p)
        if MENTION.match(p): continue
        if LAUNCH.search(p): return True
    return False
assert not is_launch('grep -n pytest-footprint-watchdog x'), 'mention must not be a launch'
assert is_launch('AI_DLC_X=1 /v/bin/python3 scripts/pytest-footprint-watchdog.py --cwd /w -- rebalancer/tests -q'), 'launch must be a launch'
cnt = collections.defaultdict(lambda: [0, 0.0]); refused = collections.Counter(); wait = collections.defaultdict(float)
per_story = collections.defaultdict(collections.Counter)
for r in rows:
    if r['kind'] != 'sub' or r['sprint'] != sp or r['err']: continue
    s = spawn.get(r['unit'])
    if not s: continue
    ro = s['role']
    if 'wait-for-deliverable' in r['cmd']: wait[ro] += r['lat'] or 0
    if is_launch(r['cmd']):
        cnt[ro][0] += 1; cnt[ro][1] += r['lat'] or 0
        m = re.search(r'(\d+)[.-](\d+)', s['description'] or '')
        per_story[ro][m.group(0).replace('.', '-') if m else '?'] += 1
    if 'headroom' in (r.get('res') or '') and 'REFUS' in (r.get('res') or '').upper(): refused[ro] += 1
print(f's{sp} full-suite launches by role (n, bash minutes), refusals-on-headroom seen in result text, wait-for-deliverable minutes')
for ro in sorted(cnt): print(ro, cnt[ro][0], round(cnt[ro][1] / 60), 'refused', refused[ro], 'wait-min', round(wait[ro] / 60))
print('control zz-nope:', cnt['zz-nope'][0], '(must be 0)')
for ro in ('qa', 'code-reviewer', 'code-reviewer-escalated', 'dev', 'dev-escalated'):
    print(ro, 'per story', dict(sorted(per_story[ro].items())))
