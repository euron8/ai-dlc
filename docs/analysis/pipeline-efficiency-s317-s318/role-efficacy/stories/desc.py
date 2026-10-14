import json, collections, re, sys
P='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/spawns.jsonl'
rows=[json.loads(l) for l in open(P)]
steps={'stories-test-strategy','ui-direction','sprint-review','gate-validation[stories-test-strategy]','gate-validation[sprint-review]'}
sel=[r for r in rows if r['step'] in steps]
def norm(d):
    d=re.sub(r'\d+(\.\d+)*','#',d or '')
    return d[:60]
c=collections.Counter((r['sprint'],r['step'],r['role'],norm(r['description'])) for r in sel)
for k in sorted(c,key=str): print(k,c[k])
