import os, re, sys
G = '/Users/n8/git/graph/docs/reviews/'
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
sys.path.insert(0, B)
files = sys.argv[1:]
for f in files:
    t = open(G + f, encoding='utf-8', errors='replace').read()
    L = t.splitlines()
    # verdict paragraph
    vi = next((i for i, l in enumerate(L) if re.match(r'(?i)^#+\s*verdict\s*$|^verdict:', l.strip())), None)
    para = ' '.join(x.strip() for x in L[vi+1:vi+5] if x.strip())[:500] if vi is not None else ''
    heads = [l.strip()[:140] for l in L if re.match(r'^#{3,4}\s', l) and re.search(r'(?i)(F-?\d|finding|\d\.|blocking|must)', l)]
    tier = [l.strip()[:80] for l in L if 'seat-complete' in l][-1:]
    print('=====', f, '|', tier)
    print('  V:', para)
    for h in heads[:9]:
        print('   -', h)
