import os, re
IA = '/Users/n8/git/graph/_bmad-output/implementation-artifacts/'
def g(f, pat, n):
    L = open(f, encoding='utf-8', errors='replace').read().splitlines()
    hits = [(i + 1, l.strip()[:240]) for i, l in enumerate(L) if re.search(pat, l)]
    print('--- %s  /%s/  %d hits of %d lines' % (f.replace(IA, ''), pat, len(hits), len(L)))
    for i, l in hits[:n]:
        print('  %d: %s' % (i, l))
for f in ('s317/pipeline-continuation-log-archive-2.md', 's317/pipeline-continuation-log-archive.md'):
    g(IA + f, r'(?i)\bff[123]\b.*(incident|root|introduc|story|caus|regress)', 10)
d = IA + 's317/gate-adjudication'
print('adjudication dir:', sorted(os.listdir(d))[:60])
g(IA + 's317/gate-log-archive.md', r'(?i)(nonce|fail-closed|discard|overturn|re-dispatch|re-run)', 25)
g(IA + 'gate-log.md', r'(?i)(nonce|fail-closed|discard|overturn|re-dispatch|re-run)', 25)
