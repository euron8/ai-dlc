import json, glob, os, re
P = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
r = next(x for x in rows if x['description'] == 'Dev-escalated story 1.3 hodl route')
f = glob.glob(P + r['sess'] + '*/subagents/' + r['unit'] + '.jsonl')[0]
for line in open(f, encoding='utf-8', errors='replace'):
    o = json.loads(line)
    if o.get('type') == 'user':
        c = (o.get('message') or {}).get('content')
        t = c if isinstance(c, str) else ' '.join(x.get('text', '') for x in c if isinstance(x, dict))
        i = t.find('UNCOMMITTED')
        print('BRIEF-PRE:', t[max(0, i - 900):i + 300].replace('\n', ' '))
        break
# lead session around 04:00-04:06 for reason
lf = glob.glob(P + r['sess'] + '*.jsonl')
for fp in lf:
    if '/subagents/' in fp: continue
    for line in open(fp, encoding='utf-8', errors='replace'):
        if '"2026-10-14T0' not in line: continue
        try: o = json.loads(line)
        except Exception: continue
        ts = o.get('timestamp', '')
        if not ('2026-10-14T03:55' <= ts <= '2026-10-14T04:06'): continue
        m = o.get('message') or {}
        for c in (m.get('content') or []) if isinstance(m.get('content'), list) else []:
            if isinstance(c, dict) and c.get('type') == 'text' and re.search(r'(?i)(1\.3|escalat|haiku)', c.get('text', '')):
                print('LEAD', ts[11:19], c['text'][:500].replace('\n', ' '))
L = open('/Users/n8/' + 'git/graph/_bmad-output/implementation-artifacts/gate-log.md', encoding='utf-8', errors='replace').read().splitlines()
print('GATELOG 271-275:', ' || '.join(l[:700] for l in L[270:274]))
