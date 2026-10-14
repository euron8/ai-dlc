import os, re, collections
GR = '/Users/n8/git/graph/_bmad-output/'
cands = []
for base in (GR + 'planning-artifacts/s317/', GR + 'implementation-artifacts/s317/', GR + 'planning-artifacts/s318/', GR + 'implementation-artifacts/s318/'):
    if os.path.isdir(base):
        for f in os.listdir(base):
            if re.search(r'(?i)sprint-review', f) and f.endswith('.md'):
                cands.append(base + f)
print('\n'.join(c.replace(GR, '') for c in sorted(cands)))
# W-items (s317) and C-items (s318): map each item id to story ids co-occurring on its line
for sp, rx in (('s317', r'\bW(\d{1,2})\b'), ('s318', r'\bC-(\d{2})\b')):
    items = collections.defaultdict(set)
    for c in cands:
        if '/' + sp + '/' not in c: continue
        for l in open(c, encoding='utf-8', errors='replace'):
            ids = re.findall(rx, l)
            if not ids: continue
            st = set(re.findall(r'(?:S3\d\d-|[Ss]tory |\b)([1-4]\.[1-8][ab]?)\b', l))
            for i in ids:
                items[i] |= st
    print('==', sp, 'items', len(items))
    for k in sorted(items, key=lambda x: int(x)):
        print('  ', k, sorted(items[k]))
