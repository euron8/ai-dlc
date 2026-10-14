import json, re
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
# sprint-review: non-seat spawns (fix work) both sprints
for r in sorted(rows, key=lambda r: r['start'] or ''):
    if r['step'] in ('sprint-review',) and not re.search(r'(?i)seat \d|party|cross|part \d', r['description'] or ''):
        print(r['sprint'], r['role'], r['model_ran'], r['effort_bound'], round(r['usd'] or 0, 1), '|', r['description'][:70], '|', (r['final_text'] or '')[-200:].replace('\n', ' ')[:200])
