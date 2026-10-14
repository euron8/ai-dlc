import json, glob, os, re, collections
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
P = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
# lead sessions per sprint
sess = collections.defaultdict(set)
for r in rows:
    if r['impl']: sess[r['sprint']].add(r['sess'])
for sp in (317, 318):
    edits = collections.Counter(); bash_commit = collections.Counter(); ctl = 0
    for s in sess[sp]:
        for f in glob.glob(P + s + '*.jsonl'):
            for line in open(f, encoding='utf-8', errors='replace'):
                if '"tool_use"' not in line: continue
                try: o = json.loads(line)
                except Exception: continue
                for c in (o.get('message') or {}).get('content') or []:
                    if not isinstance(c, dict) or c.get('type') != 'tool_use': continue
                    inp = c.get('input') or {}
                    fp = str(inp.get('file_path') or '')
                    m = re.search(r'graph-s3\d\d-story-(\d-\d[ab]?)/(.*)', fp)
                    if c.get('name') in ('Edit', 'Write', 'MultiEdit') and m:
                        kind = 'code' if re.search(r'\.(py|js|ts|tsx|sh)$', m.group(2)) else 'docs'
                        edits[(m.group(1), kind)] += 1
                    if c.get('name') in ('Edit', 'Write'): ctl += 1
                    cmd = str(inp.get('command') or '')
                    m2 = re.search(r'graph-s3\d\d-story-(\d-\d[ab]?)', cmd)
                    if c.get('name') == 'Bash' and m2 and re.search(r'git (-C \S+ )?commit', cmd):
                        bash_commit[m2.group(1)] += 1
    print('== sprint', sp, 'lead sessions', len(sess[sp]), 'control: total lead Edit/Write calls', ctl)
    print('   lead Edit/Write in story worktrees (story,kind):', sorted(edits.items()))
    print('   lead git-commit Bash calls naming a story worktree:', sorted(bash_commit.items()))
# 2.5 s317 CR spawns around its window
print('--- s317 CR/CR-esc spawns 10-10T06..18 unjoined or 2.5')
for r in sorted(rows, key=lambda r: r['start'] or ''):
    if r['sprint'] == 317 and r['role'].startswith('code-reviewer') and '2026-10-10T06' <= (r['start'] or '') <= '2026-10-10T18':
        print('  ', r['start'][5:16], r['step'][:10], r['role'], r['story'], r['description'][:60])
