import os, re, json
G = '/Users/n8/git/graph/docs/reviews/'
VR = re.compile(r'(APPROVED_WITH_CONDITIONS|APPROVED|NEEDS_REWORK|CHANGES_REQUESTED|REJECTED|CONDITIONAL|PASS|FAIL|BLOCKED|INCONCLUSIVE)')
res = {}
for s in ('s317', 's318'):
    for f in sorted(os.listdir(G + s)):
        if not f.endswith('.md'):
            continue
        L = open(G + s + '/' + f, encoding='utf-8', errors='replace').read().splitlines()
        v = None
        for i, l in enumerate(L):
            ls = l.strip()
            m = re.match(r'(?i)^(#+\s*)?\**verdict\**\s*:?\s*(.*)$', ls)
            if m:
                tail = m.group(2)
                if VR.search(tail):
                    v = VR.search(tail).group(1); break
                for l2 in L[i+1:i+6]:
                    if VR.search(l2):
                        v = VR.search(l2).group(1); break
                if v: break
        sc = [l for l in L if 'findings=' in l and ('seat-complete' in l)]
        fn = re.search(r'findings=(\d+)', sc[-1]).group(1) if sc else '?'
        res[s + '/' + f] = (v, fn)
        print(s, f, v, 'findings=' + fn)
json.dump(res, open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/verdicts.json', 'w'))
