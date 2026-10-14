import os, re
GR = '/Users/n8/git/graph/_bmad-output/'
sp = GR + 'specs/s317/'
if os.path.isdir(sp):
    print('specs/s317:', sorted(os.listdir(sp)))
    for d in sorted(os.listdir(sp)):
        if 'ff' in d.lower():
            p = sp + d + '/SPEC.md'
            if os.path.exists(p):
                L = [l.strip() for l in open(p, encoding='utf-8', errors='replace') if l.strip()]
                print('=====', d, len(L))
                for l in L[:10]: print('   ', l[:260])
                hits = [l[:260] for l in L if re.search(r'(?i)(root cause|introduc|story|S317-\d|s31[0-7]-\d|regress|since)', l)]
                for h in hits[:10]: print('  *', h)
IA = GR + 'implementation-artifacts/s317/'
for f in ('ff1-capital-limit-dev-report.md', 'ff2-mint-resize-retry-dev-report-2.md', 'ff3-subscribe-after-first-chunk-dev-report.md'):
    L = [l.strip() for l in open(IA + f, encoding='utf-8', errors='replace') if l.strip()]
    hits = [l[:240] for l in L if re.search(r'(?i)(S\d{3}-\d|story|ADR-S317|incident|operator|why)', l)]
    print('=====', f)
    for h in hits[:10]: print('  *', h)
# s317 sprint-review spawns (escapes)
