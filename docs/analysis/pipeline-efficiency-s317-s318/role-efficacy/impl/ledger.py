import re
G = '/Users/n8/' + 'git/graph/_bmad-output/planning-artifacts/'
for f, rx in (('s317/sprint-review-findings-ledger.md', r'W\d{1,2}'), ('s317/sprint-review-s3-dispatch-plan.md', r'W\d{1,2}')):
    L = open(G + f, encoding='utf-8', errors='replace').read().splitlines()
    print('=====', f, len(L))
    for l in L:
        s = l.strip()
        if re.match(r'^(\|\s*)?\**(' + rx + r')\b', s) or re.match(r'^#+\s*' + rx + r'\b', s) or re.match(r'^- \**' + rx + r'\b', s):
            print('  ', s[:280])
