import json, collections
J = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/joined.json'
rows = json.load(open(J))
for r in rows:
    if r['impl'] and not r['story']:
        print(r['sprint'], r['role'], r['model_ran'], r['start'][:16] if r['start'] else '', '|', r['description'][:70])
