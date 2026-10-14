import os, re
IA = '/Users/n8/git/graph/_bmad-output/implementation-artifacts/s317/'
for f in ['ff1-capital-limit-dev-report.md', 'ff2-mint-resize-retry-dev-report.md', 'ff2-mint-resize-retry-dev-report-2.md', 'ff3-subscribe-after-first-chunk-dev-report.md']:
    t = open(IA + f, encoding='utf-8', errors='replace').read()
    L = [l.strip() for l in t.splitlines() if l.strip()]
    print('=====', f, len(t))
    for l in L[:14]:
        print('   ', l[:230])
    st = sorted(set(re.findall(r'\b(?:S317-)?([1-4]\.[1-7][ab]?)\b', t)))
    print('   story-ids mentioned:', st)
    print('   lines w/ story|regress|introduc|root cause:', [l[:200] for l in L if re.search(r'(?i)root cause|introduc|regress|story [1-4]\.\d', l)][:6])
