#!/usr/bin/env python3 -I
"""Run graph's shipped validate-handoff-evidence.sh (byte-identical to core/scripts, cmp'd) over every g1/g2 plan of a sprint,
read only (git plumbing; TMPDIR in our dir), and classify each WARN line by whether any Critical/Important finding in the SAME story's
review files mentions it.  Usage: warn_fp.py <sprint>.  Output warn_fp.<sprint>.tsv (plan, class, key, matched, line) and summary.
Match key: head-tree/head-missing/placeholder -> capture basename; capture-unresolved -> token basename; section-empty -> the '## heading' text.
'Matched' = key appears in the text of a C/I finding block (heading + body up to next '####' or '###') of any non-shard review of the story.
Controls: (1) the WARN lines reproduced per plan must equal the plan's own gate-log WARN lines as a set (reported); (2) a bogus sha must give no WARN;
(3) impossible key never matches."""
import sys, os, re, glob, subprocess, collections, concurrent.futures as cf
sp = sys.argv[1]; G = '/Users/n8/git/graph'; OUT = os.path.dirname(os.path.abspath(__file__))
V = f'{G}/scripts/ai-dlc/validate-handoff-evidence.sh'
env = dict(os.environ, TMPDIR=f'{OUT}/tmp', PATH='/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin')
plans = sorted(glob.glob(f'{G}/_bmad-output/implementation-artifacts/s{sp}/gate-transition/*-g[12]-p*.plan'))
def field(t, k):
    m = re.search(rf'^{k}: ?(.*)$', t, re.M); return m.group(1).strip() if m else ''
def run(p):
    t = open(p).read(); g = re.search(r'-g([12])-p', p).group(1)
    sf, base, sha = field(t, 'story-file'), field(t, 'base'), field(t, 'sha')
    if not (sf and base and sha): return p, None, None, set()
    args = ['bash', V, '-C', G] + (['--gate2'] if g == '2' else []) + [sf, base, sha]
    r = subprocess.run(args, capture_output=True, text=True, env=env, timeout=300)
    planw = {l[len('gate-log: '):] for l in t.split('\n') if l.startswith('gate-log: WARN')}
    return p, r, sf, planw
res = []
with cf.ThreadPoolExecutor(4) as ex: res = list(ex.map(run, plans))
# bogus control
r = subprocess.run(['bash', V, '-C', G, '_bmad-output/x.md', 'deadbeef', 'deadbeef00'], capture_output=True, text=True, env=env)
print('control bogus sha WARN lines:', sum(1 for l in r.stdout.split('\n') if l.startswith('WARN')), '(must be 0); rc', r.returncode)
def findings_text(stem):
    out = []
    for f in glob.glob(f'{G}/docs/reviews/s{sp}/{stem}-*.md') + glob.glob(f'{G}/docs/reviews/s{sp}/{stem.replace("-", ".")}-*.md'):
        if not re.search(r'(code-review|qa-validation)', f): continue
        L = open(f, errors='replace').read().split('\n'); sev = None; cur = None
        for l in L:
            h = re.match(r'### (Critical|Important|Suggestions?)', l)
            if h: sev = h.group(1)[0]; cur = None; continue
            if re.match(r'## ', l): sev = None; cur = None; continue
            if l.startswith('#### ') and sev in ('C', 'I'): cur = [l]; out.append(cur); continue
            if l.startswith('####'): cur = None; continue
            if cur is not None: cur.append(l)
    return ['\n'.join(b) for b in out]
cache = {}
rows = []; match_ok = 0; mism = 0
for p, r, sf, planw in res:
    if r is None: continue
    stem = re.search(r'story-(\d+-\d+)', sf); stem = stem.group(1) if stem else '?'
    if stem not in cache: cache[stem] = findings_text(stem)
    blocks = cache[stem]; ft = '\n'.join(blocks)
    mine = {l for l in r.stdout.split('\n') if l.startswith('WARN')}
    if mine == planw: match_ok += 1
    else: mism += 1
    for l in sorted(mine):
        m = re.match(r'WARN ([a-z-]+) (.*)', l); cl, rest = m.group(1), m.group(2)
        if cl == 'section-empty': key = (re.search(r"'## ([^']+)'", rest) or [0, ''])[1]
        else: key = os.path.basename(rest.split(':')[0].split(' ')[0].strip('`'))
        matched = bool(key) and any(key in b and (cl == 'section-empty' or re.search(r'head|sha|stale|predate|frozen|names the|unresolved|placeholder|not committed|untracked|gitignored', b, re.I)) for b in blocks)
        rows.append((os.path.basename(p), stem, cl, key, matched, l[:230]))
with open(f'{OUT}/warn_fp.{sp}.tsv', 'w') as o:
    for r in rows: o.write('\t'.join(map(str, r)) + '\n')
print(f's{sp}: plans {len(plans)}, plans whose reproduced WARN set equals the plan gate-log WARN set: {match_ok}, differ: {mism}')
S = collections.defaultdict(lambda: [set(), set(), 0, 0, set()])
for pl, stem, cl, key, matched, l in rows:
    a = S[cl]; a[0].add(pl); a[2] += 1
    if matched: a[1].add(pl); a[3] += 1
    a[4].add(stem)
print('class: plans fired, lines, plans with a matched finding, lines matched, stories')
for cl, a in sorted(S.items()): print(cl, len(a[0]), a[2], len(a[1]), a[3], len(a[4]))
print('control impossible key matched:', sum(1 for r in rows if 'ZZNOPEQ' in '\n'.join(cache.get(r[1], []))), '(must be 0)')
