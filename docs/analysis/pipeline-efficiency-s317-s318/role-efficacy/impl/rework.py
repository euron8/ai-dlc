import json, re, os
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
# all spawns (any step) whose description mentions rework/fix/repair for impl-window stories
for r in sorted(rows, key=lambda r: r['start'] or ''):
    d = r['description'] or ''
    if re.search(r'(?i)rework|fix|repair|amend|re-?arm', d) and r['sprint'] in (317, 318) and r['step'] not in ('stories-test-strategy', 'architecture', 'requirements', 'carry-over-evaluation'):
        print(r['sprint'], r['step'][:14], r['role'], r['model_ran'], r['effort_bound'], round(r['usd'] or 0, 1), '|', d[:70])
# who committed rework? scan s318 dev reports / IA for fix reports
IA = '/Users/n8/git/graph/_bmad-output/implementation-artifacts/s318/'
for f in sorted(os.listdir(IA)):
    if f.startswith('dev-report'):
        t = open(IA + f, encoding='utf-8', errors='replace').read()
        m = re.findall(r'(?i)(claude[- ](?:haiku|sonnet|opus)[^\n`]{0,25}|model[^\n]{0,60}(?:haiku|sonnet|opus)[^\n]{0,20})', t)
        print('IA', f, len(t), m[:2])
