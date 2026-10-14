import os, re, sys
G = '/Users/n8/git/graph/docs/reviews/'
for s in ('s317', 's318'):
    for f in sorted(os.listdir(G + s)):
        if not f.endswith('.md'):
            continue
        t = open(G + s + '/' + f, encoding='utf-8', errors='replace').read().splitlines()
        hits = [l.strip()[:150] for l in t if re.search(r'(?i)(^\**verdict|^#+.*verdict|^status:|gate.?[123] (result|verdict)|\*\*verdict)', l.strip())]
        print(s, f, '||', ' ## '.join(hits[:3]))
