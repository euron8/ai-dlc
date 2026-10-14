import re, sys
f, pat, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
L = open(f, encoding='utf-8', errors='replace').read().splitlines()
c = 0
for i, l in enumerate(L):
    if re.search(pat, l):
        print('%d: %s' % (i + 1, l.strip()[:260]))
        c += 1
        if c >= n: break
print('TOTAL', sum(1 for l in L if re.search(pat, l)), 'of', len(L), 'lines')
