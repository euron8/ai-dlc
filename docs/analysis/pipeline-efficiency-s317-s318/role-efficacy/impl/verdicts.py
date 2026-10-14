import os, re, collections
G = '/Users/n8/git/graph/docs/reviews/'
VR = re.compile(r'\b(APPROVED_WITH_CONDITIONS|APPROVED|NEEDS_REWORK|CHANGES_REQUESTED|REJECTED|PASS_WITH_CONDITIONS|CONDITIONAL_PASS|CONDITIONAL|PASS|FAIL|BLOCKED)\b')
for s in ('s317', 's318'):
    for f in sorted(os.listdir(G + s)):
        if not f.endswith('.md'):
            continue
        t = open(G + s + '/' + f, encoding='utf-8', errors='replace').read()
        lines = t.splitlines()
        # verdict line: first line containing 'verdict' (case-insens) with a token
        vl = [l for l in lines if re.search(r'verdict', l, re.I) and VR.search(l)]
        v = VR.findall(vl[0])[0] if vl else '-'
        vlast = VR.findall(vl[-1])[-1] if vl else '-'
        # findings count: lines starting with heading/list naming F-n or Finding
        nf = len(set(re.findall(r'\b(?:F|CR|QA)-?(\d{1,2})\b', t)))
        sev = collections.Counter(re.findall(r'\b(BLOCKER|HIGH|MAJOR|MEDIUM|MINOR|LOW|NIT)\b', t))
        sc = [l for l in lines if l.startswith('seat-complete')]
        print(s, f, 'first=%s last=%s' % (v, vlast), 'Fids=%d' % nf, 'bytes=%d' % len(t), dict(sev), sc[-1][-40:] if sc else '')
