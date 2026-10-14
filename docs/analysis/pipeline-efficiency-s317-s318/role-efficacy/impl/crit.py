import re, sys
G = '/Users/n8/git/graph/docs/reviews/'
for f in sys.argv[1:]:
    L = open(G + f, encoding='utf-8', errors='replace').read().splitlines()
    out = []
    for i, l in enumerate(L):
        if re.match(r'^#{2,4}\s*(Critical|Blocking|Important)', l.strip()) or re.match(r'^#{2,4}\s*Shard verdicts', l.strip()):
            body = [x.strip() for x in L[i+1:i+14] if x.strip() and not x.startswith('|---')]
            out.append(l.strip()[:40] + ' :: ' + ' / '.join(b[:150] for b in body[:5]))
    print('=====', f)
    for o in out[:4]:
        print('  ', o[:700])
