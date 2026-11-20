#!/usr/bin/env python3 -I
"""Per-story gate timeline for graph s321-s323, read only (git plumbing against /Users/n8/git/graph).
Inputs: s32N/gate-transition/*.plan (story, gate, pass, sha, nonce) and docs/reviews/s32N/*-(code-review|qa-validation)[-pN].md
(non-shard files; verdict, reviewed-sha, findings with Class). Output: reviews.tsv (one row per review file),
plans.tsv (one row per plan with commit time), trans.tsv (delta between consecutive plan shas of the same story,
classified code/test/rec by path). Control: story 'ZZNOPE' must have 0 plans.
Path class: rec = under docs/ _bmad-output/ test-results/ or *.md/*.txt/*.log/*.out ; test = tests?/ dir or test_*/ *.test.* / *.spec.* ; code = rest."""
import re, os, glob, subprocess, collections, sys
G = '/Users/n8/git/graph'
OUT = os.path.dirname(os.path.abspath(__file__))
def git(*a):
    return subprocess.run(['git', '-C', G] + list(a), capture_output=True, text=True).stdout
def cls(p):
    if re.match(r'(docs|_bmad-output|test-results)/', p) or re.search(r'\.(md|txt|log|out)$', p): return 'rec'
    if re.search(r'(^|/)tests?/|(^|/)test_[^/]*$|\.(test|spec)\.|(^|/)conftest\.py$|_test\.py$', p): return 'test'
    return 'code'
def norm(s): return s.replace('.', '-')
plans = []
for sp in (321, 322, 323):
    for f in sorted(glob.glob(f'{G}/_bmad-output/implementation-artifacts/s{sp}/gate-transition/*.plan')):
        d = {}
        for l in open(f):
            m = re.match(r'(story|gate|pass|sha|route|nonce): ?(.*)', l)
            if m and m.group(1) not in d: d[m.group(1)] = m.group(2).strip()
        if 'sha' not in d: continue
        t = git('show', '-s', '--format=%ct', d['sha']).strip()
        plans.append(dict(sp=sp, story=norm(d.get('story', '?')), gate=d.get('gate'), pas=int(d.get('pass', 1)), sha=d['sha'], t=int(t or 0), route=d.get('route', '')[:40], nonce=d.get('nonce', ''), file=os.path.basename(f)))
print('control ZZNOPE plans:', sum(1 for p in plans if p['story'] == 'ZZNOPE'), '(must be 0)')
print('plans:', collections.Counter((p['sp'], p['gate']) for p in plans))
with open(f'{OUT}/plans.tsv', 'w') as o:
    for p in sorted(plans, key=lambda p: (p['sp'], p['story'], p['t'])): o.write('\t'.join(str(p[k]) for k in ('sp', 'story', 'gate', 'pas', 'sha', 't', 'route', 'nonce')) + '\n')
# reviews
rev = []
for sp in (321, 322, 323):
    for f in sorted(glob.glob(f'{G}/docs/reviews/s{sp}/*.md')):
        b = os.path.basename(f)
        m = re.match(r'(.+?)-(code-review|qa-validation)(?:-p(\d+))?\.md$', b)
        if not m: continue
        txt = open(f, errors='replace').read()
        sha = (re.search(r'^reviewed-sha:\s*([0-9a-f]{7,40})', txt, re.M) or [None, ''])[1]
        vm = re.search(r'^## Verdict\s*\n+\s*([A-Z_]+)', txt, re.M) or re.search(r'^Verdict:\s*([A-Z_]+)', txt, re.M)
        verdict = vm.group(1) if vm else '?'
        finds = []
        sev = None
        lines = txt.split('\n')
        for i, l in enumerate(lines):
            h = re.match(r'### (Critical|Important|Suggestions?)', l)
            if h: sev = h.group(1)[0]; continue
            if re.match(r'## ', l) and not re.match(r'## (Findings)', l): sev = None if not l.startswith('## Shard') else sev
            if l.startswith('#### ') and sev in ('C', 'I'):
                c = ''
                for j in range(i + 1, min(i + 4, len(lines))):
                    mm = re.match(r'Class:\s*(\w+)', lines[j])
                    if mm: c = mm.group(1); break
                finds.append((sev, c, l[5:90]))
        rev.append(dict(sp=sp, file=b, kind=m.group(2), pas=int(m.group(3) or 1), sha=sha, verdict=verdict, finds=finds, storyfn=m.group(1)))
by_prefix = lambda sha: [p for p in plans if sha and p['sha'].startswith(sha[:10])]
with open(f'{OUT}/reviews.tsv', 'w') as o:
    for r in rev:
        pm = by_prefix(r['sha'])
        r['story'] = pm[0]['story'] if pm else norm(r['storyfn'])
        r['plan'] = (pm[0]['gate'], pm[0]['pas']) if pm else ('?', 0)
        cc = collections.Counter(c for _, c, _ in r['finds'])
        o.write('\t'.join([str(r['sp']), r['story'], r['kind'], str(r['pas']), r['sha'][:10], r['verdict'], str(len(r['finds'])), ','.join(f'{k or "none"}={v}' for k, v in sorted(cc.items())), r['file']]) + '\n')
print('reviews:', len(rev), 'unmatched to a plan sha:', sum(1 for r in rev if r['plan'][0] == '?'))
# transitions per story
bystory = collections.defaultdict(list)
for p in plans: bystory[(p['sp'], p['story'])].append(p)
with open(f'{OUT}/trans.tsv', 'w') as o:
    o.write('sp\tstory\tfrom\tto\tn_code\tn_test\tn_rec\tcode_files\n')
    for k, ps in sorted(bystory.items()):
        ps.sort(key=lambda p: p['t'])
        for a, b in zip(ps, ps[1:]):
            if a['sha'] == b['sha']: nm = []
            else: nm = [x for x in git('diff', '--name-only', a['sha'], b['sha']).split('\n') if x]
            c = collections.Counter(cls(x) for x in nm)
            cf = [x for x in nm if cls(x) == 'code']
            o.write(f"{k[0]}\t{k[1]}\tg{a['gate']}p{a['pas']}\tg{b['gate']}p{b['pas']}\t{c['code']}\t{c['test']}\t{c['rec']}\t{';'.join(cf[:4])}\n")
print('stories with plans:', {sp: len({s for (x, s) in bystory if x == sp}) for sp in (321, 322, 323)})
