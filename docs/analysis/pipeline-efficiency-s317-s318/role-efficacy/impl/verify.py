import json, os, re, glob
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
P = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
want = [('317', 'Finish story 3.1 dev work'), ('317', 'Story 4.3b dev dispatch'), ('317', 'Dev story 1.3 (wave 1)'), ('318', 'Dev story 2.4 tick_math precision'),
        ('318', 'Gate-1 review story 2.8'), ('317', '2.3 gate-3 shard 1/3'), ('318', 'Dev story 1.3 hodl route'), ('317', 'Gate-2 QA story 1.1')]
for sp, d in want:
    r = next((x for x in rows if str(x['sprint']) == sp and x['description'] == d), None)
    if not r: print('MISSING', sp, d); continue
    fs = glob.glob(P + r['sess'] + '*/subagents/' + r['unit'] + '.jsonl')
    if not fs: print('NO TRANSCRIPT', d); continue
    first = None; models = set()
    for line in open(fs[0], encoding='utf-8', errors='replace'):
        try: o = json.loads(line)
        except Exception: continue
        m = (o.get('message') or {})
        if isinstance(m, dict) and m.get('model'): models.add(m['model'])
        if first is None and o.get('type') == 'user':
            c = m.get('content')
            first = c if isinstance(c, str) else ' '.join(x.get('text', '') for x in c if isinstance(x, dict))
    sids = sorted(set(re.findall(r'(?:story[- ]|S3\d\d-)([1-4][.-][1-8][ab]?)', first or '', re.I)))
    print(sp, d[:40].ljust(40), 'joined=', r['story'], 'brief-ids=', sids[:5], 'models=', sorted(models))
