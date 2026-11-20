#!/usr/bin/env python3
"""Per-story branch diff composition, READ-ONLY git on /Users/n8/git/graph.
For every dev/sprint-323/story-X branch with a known dispatch base, list non-merge commits in base..tip, attribute each to
'dev' if its committer time lies inside any dev/dev-escalated spawn interval of that story (story_spawns.tsv), else 'gate/lead'.
Path classes: code = non-test source; tests = tests/ or test_*; record = story file, sprint-status, docs/reviews,
_bmad-output, test-results, capture .txt/.log/.out, docs/escalations, backlog, CHANGELOG-like; other.
Output: story_diffs2.tsv (story, who, class, files, added, deleted) + story_diffs.out summary.
"""
import subprocess, re, collections, csv
from datetime import datetime, timezone
D = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/implementation-build/'
G = '/Users/n8/git/graph'
BASE = {'1-1': 'ae63caf38', '3-1': 'ae63caf38', '4-1': 'ae63caf38', '4-2': 'ae63caf38', '4-3': 'ae63caf38', '4-4': 'ae63caf38',
        '5-1': 'ae63caf38', '5-3': 'ae63caf38', '5-4': 'ae63caf38', '5-5': 'e70a344c0', '3-2': '5fe4b5ce7',
        '1-2': '2fe36573c', '1-3': '2fe36573c', '1-4': '2fe36573c', '5-2': '2fe36573c'}
def git(*a): return subprocess.run(['git', '-C', G, *a], capture_output=True, text=True).stdout
def pcls(p):
    if re.search(r'(^|/)(tests?|__tests__|e2e)/|(^|/)test_[^/]*$|\.(test|spec)\.[jt]sx?$|conftest\.py$', p): return 'tests'
    if re.search(r'sprint-status', p): return 'rec:sprint-status'
    if re.search(r'planning-artifacts/.*/stories/story-', p): return 'rec:story-file'
    if re.search(r'\.(txt|log|out)$', p): return 'rec:capture-txt'
    if re.search(r'docs/reviews', p): return 'rec:docs-reviews'
    if re.search(r'test-results/', p): return 'rec:test-results'
    if re.search(r'^_bmad-output/|^docs/(escalations|backlog|retro)|carry-over', p): return 'rec:other-bmad/escal'
    if re.search(r'\.(md)$', p): return 'docs-md'
    return 'code'
def T(s): return datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc).timestamp()
sp = collections.defaultdict(list)
for i, row in enumerate(csv.reader(open(D + 'story_spawns.tsv'), delimiter='\t')):
    if i and row[2] in ('dev', 'dev-escalated'): sp[row[3].replace('.', '-')].append((T(row[0]), T(row[1]) + 120))
out = collections.defaultdict(lambda: [0, 0, 0])
nco = collections.Counter()
for st, base in BASE.items():
    br = 'dev/sprint-323/story-' + st
    log = git('log', '--no-merges', '--format=@@%H %ct %s', '--numstat', base + '..' + br)
    cur = None
    for line in log.splitlines():
        if line.startswith('@@'):
            h, ct, subj = line[2:].split(' ', 2)
            who = 'dev' if any(a <= int(ct) <= b for a, b in sp[st]) else 'gate/lead'
            nco[(st, who)] += 1; cur = who
        elif line.strip():
            a, d, p = line.split('\t', 2)
            if a == '-': a = d = 0
            k = (st, cur, pcls(p)); out[k][0] += 1; out[k][1] += int(a); out[k][2] += int(d)
with open(D + 'story_diffs2.tsv', 'w') as o:
    o.write('story\twho\tclass\tfile_touches\tadded\tdeleted\n')
    for k, v in sorted(out.items()): o.write('\t'.join(map(str, [*k, *v])) + '\n')
# summary
tot = collections.defaultdict(lambda: [0, 0, 0])
for (st, who, c), v in out.items():
    for i in range(3): tot[(who, c)][i] += v[i]
print('commits:', {f'{k[0]}:{k[1]}': v for k, v in nco.items()} if False else sum(v for k, v in nco.items() if k[1] == 'dev'), 'dev-window,', sum(v for k, v in nco.items() if k[1] != 'dev'), 'other')
for who in ('dev', 'gate/lead'):
    T_ = sum(v[1] for (w, c), v in tot.items() if w == who)
    print(who, 'total added lines', T_)
    for (w, c), v in sorted(tot.items()):
        if w == who: print('   ', c.ljust(8), 'touches', str(v[0]).rjust(5), 'added', str(v[1]).rjust(6), ('%.0f%%' % (100 * v[1] / T_)).rjust(5), 'deleted', v[2])
print('per story (dev commits): code/tests/record/docs added')
for st in BASE:
    r = {c: out[(st, 'dev', c)][1] for c in ('code', 'tests', 'rec:', 'docs-md')}
    print(st, r, 'commits dev', nco[(st, 'dev')], 'other', nco[(st, 'gate/lead')])
