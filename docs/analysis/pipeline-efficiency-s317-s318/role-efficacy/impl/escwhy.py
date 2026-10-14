import json, glob, os, re
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
P = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
for r in rows:
    if r['role'] == 'dev-escalated' and r['impl']:
        fs = glob.glob(P + r['sess'] + '*/subagents/' + r['unit'] + '.jsonl')
        brief = ''
        if fs:
            for line in open(fs[0], encoding='utf-8', errors='replace'):
                try: o = json.loads(line)
                except Exception: continue
                if o.get('type') == 'user':
                    c = (o.get('message') or {}).get('content')
                    brief = c if isinstance(c, str) else ' '.join(x.get('text', '') for x in c if isinstance(x, dict))
                    break
        hits = [s.strip()[:230] for s in re.split(r'(?<=[.\n])', brief) if re.search(r'(?i)(escalat|capital|haiku|route|why|tier|failed|previous|prior attempt|took over)', s)]
        print('=====', r['sprint'], r['story'], r['description'][:50], 'brief_len=%d' % len(brief))
        for h in hits[:6]: print('   *', h.replace('\n', ' '))
