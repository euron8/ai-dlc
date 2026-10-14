import sys, re
G = '/Users/n8/git/graph/docs/reviews/'
for f in sys.argv[1:]:
    L = open(G + f, encoding='utf-8', errors='replace').read().splitlines()
    for i, l in enumerate(L):
        if re.match(r'(?i)^(#+\s*)?\**verdict', l.strip()):
            print('==', f, '::', ' / '.join(x.strip()[:160] for x in L[i:i+4] if x.strip()))
            break
