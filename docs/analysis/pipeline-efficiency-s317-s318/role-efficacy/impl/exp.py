import json, collections, statistics as S
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
st = json.load(open(B + 'stories.json'))
rows = json.load(open(B + 'joined.json'))
# hand classification of the verdict-flipping finding of each NEEDS_REWORK pass (from crit.py / nfind.py reads)
# S = substantive code/test defect, E = evidence/capture/record format, B = bookkeeping/status/headings
CLS = {
 (317,'1.2'): 'CR p1 E(no RED capture) p2 E(truncated capture) p3 E(capture no sha/cmd)',
 (317,'1.3'): 'CR p1 E(no committed RED capture)',
 (317,'1.7'): 'CR p1 S(runbook PUT envelope 400s)',
 (317,'2.3'): 'CR p1 S(AC6 assertion vacuous); QA p1 B(handoff evidence)',
 (317,'2.5'): 'CR p1 S(gated knob inert, control tests nothing)',
 (317,'2.6'): 'CR p1 S(second pin/dead code) p2 S(fix round deleted 1.5 span tests) p3 S(guard claimed no test provides) p4 S(repair deleted dotted assertion); QA p1 B(dev edited 1.5 artifacts)',
 (317,'4.3a'): 'CR p1 B(no Dev Agent Record, status not flipped)',
 (317,'1.4'): 'QA p1 B(empty evidence sections)',
 (317,'4.2a'): 'QA p1 B p2 B(handoff evidence)',
 (317,'4.3b'): 'QA p1 B(handoff evidence; QA: not a code defect)',
 (318,'1.1'): 'CR p1 S(tautological test; trailing-newline address bypass) p2 E(capture no cmd/sha) p3 E(captures gitignored)',
 (318,'1.2'): 'CR p1 S(LR-S318-2 no discriminating AC; wrong transfer passes 18 tests)',
 (318,'1.5'): 'CR p1 B(evidence headings demoted); QA p1 B(stale derived fences)',
 (318,'2.3'): 'CR p1 ?(cross-shard) p2 E(captures no cmd/sha)',
 (318,'2.4'): 'CR p1 E(no cmd/seed/sha; no RED artifact) p2 E(wrong sha label; D-7 record)',
 (318,'2.5'): 'QA p1 E(RED figure arithmetic)',
 (318,'2.6'): 'CR p1 E(pre-existing 49 db reds misreported) p2 E(rung no command) p3 B(recipe anchor line)',
 (318,'2.7'): 'QA p1 S(untested raise arms, guard tests loosened, AC3 node missing)',
}
def grp(s):
    return s['writer']
G = collections.defaultdict(list)
for s in st:
    G[grp(s)].append(s)
print('writer-binding | n | CR1st-A | QA1st-P | both1st | mean extra passes | stories w/ S-driven rework | $story mean | $dev mean')
for g, ss in sorted(G.items()):
    n = len(ss)
    cra = sum(1 for s in ss if s['cr'] and s['cr'][0][1] == 'APPROVED')
    qap = sum(1 for s in ss if s['qa'] and s['qa'][0][1] == 'PASS')
    both = sum(1 for s in ss if s['cr'] and s['cr'][0][1] == 'APPROVED' and s['qa'] and s['qa'][0][1] == 'PASS')
    extra = [len(s['cr']) - 1 + len(s['qa']) - 1 for s in ss]
    sdr = [s['story'] for s in ss if 'S(' in CLS.get((s['sprint'], s['story']), '')]
    print(g, n, cra, qap, both, round(S.mean(extra), 2), sdr, round(S.mean(s['usd'] for s in ss), 1), round(S.mean(s['dusd'] for s in ss), 2), [ (s['sprint'], s['story']) for s in ss])
# reviewer binding of FIRST CR pass
print('\nfirst-CR binding per story')
RB = collections.defaultdict(list)
for s in st:
    rs = sorted([r for r in rows if r['impl'] and r['sprint'] == s['sprint'] and r['story'] == s['story'] and r['role'].startswith('code-reviewer') and 'losing' not in r['description']], key=lambda r: r['start'])
    b = '%s/%s/%s' % (rs[0]['role'].replace('code-reviewer', 'CR'), rs[0]['model_ran'], rs[0]['effort_bound']) if rs else 'none-joined'
    RB[b].append(s)
for b, ss in sorted(RB.items()):
    nr = sum(1 for s in ss if s['cr'] and s['cr'][0][1] == 'NEEDS_REWORK')
    qaN = [s['story'] for s in ss if s['qa'] and s['qa'][0][1] != 'PASS']
    print(b, 'n=%d' % len(ss), 'CR1st NEEDS_REWORK=%d' % nr, 'later QA-1st-not-PASS=%s' % qaN, 'CR$ mean=%.1f' % S.mean(s['crusd'] for s in ss), [(s['sprint'], s['story'], ''.join(v[0] for p, v in s['cr'])) for s in ss])
# role $ in impl window by binding
print('\nimpl-window $ and n by role/binding')
C = collections.defaultdict(lambda: [0, 0.0, 0.0])
for r in rows:
    if r['impl']:
        role = r['role']
        if role == 'code-reviewer' and 'losing' in (r['description'] or '').lower(): role = 'closing-writer'
        k = (role, r['model_ran'], r['effort_bound'])
        C[k][0] += 1; C[k][1] += r['usd'] or 0; C[k][2] += r['minutes'] or 0
for k, v in sorted(C.items()):
    print('  %-40s n=%3d $%7.1f  mean$%.2f  mean min %.1f' % (str(k), v[0], v[1], v[1] / v[0], v[2] / v[0]))
