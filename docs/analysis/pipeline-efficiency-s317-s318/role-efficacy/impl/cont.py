import json, glob, os, re
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
P = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
# count non-tool-result user turns (SendMessage continuations) in dev transcripts
for r in rows:
    if r['impl'] and r['role'] in ('dev', 'dev-escalated', 'protected-path-editor'):
        fs = glob.glob(P + r['sess'] + '*/subagents/' + r['unit'] + '.jsonl')
        if not fs: print('NOFILE', r['description']); continue
        n = 0; snippets = []
        for line in open(fs[0], encoding='utf-8', errors='replace'):
            try: o = json.loads(line)
            except Exception: continue
            if o.get('type') != 'user': continue
            c = (o.get('message') or {}).get('content')
            if isinstance(c, str): txt = c
            else:
                if any(isinstance(x, dict) and x.get('type') == 'tool_result' for x in (c or [])): continue
                txt = ' '.join(x.get('text', '') for x in (c or []) if isinstance(x, dict))
            n += 1
            if n > 1: snippets.append(txt.strip().replace('\n', ' ')[:110])
        if n > 1:
            print(r['sprint'], r['story'], r['role'], r['model_ran'], round(r['minutes']), 'user_turns=%d' % n, '|', ' || '.join(snippets[:3]))
G = '/Users/n8/' + 'git/graph/docs/reviews/'
for f in ('s317/1-4-qa-validation.md',):
    L = open(G + f, encoding='utf-8', errors='replace').read().splitlines()
    print('=====', f)
    for l in L:
        if re.match(r'^#{2,4}\s', l) or re.match(r'(?i)^verdict', l.strip()): print('   ', l.strip()[:200])
