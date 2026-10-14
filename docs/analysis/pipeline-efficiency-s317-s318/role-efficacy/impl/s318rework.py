import json, re, os, glob, collections
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
IA = '/Users/n8/' + 'git/graph/_bmad-output/implementation-artifacts/s318/'
RV = '/Users/n8/' + 'git/graph/docs/reviews/s318/'
# 1. any s318 spawn (any role/step) whose final_text or description mentions rework/fix for a story
print('--- s318 dev/dev-esc spawns, all steps, impl window (start >= 10-13T20)')
for r in sorted(rows, key=lambda r: r['start'] or ''):
    if r['sprint'] == 318 and r['role'] in ('dev', 'dev-escalated', 'protected-path-editor') and (r['start'] or '') >= '2026-10-13T20':
        print('  ', r['start'][5:16], r['step'][:12], r['role'], r['model_ran'], r['story'], '|', r['description'][:60])
# 2. who landed rework: scan p2+ review files for 'rework' attribution lines
print('--- rework attribution in s318 p2+ reviews')
for f in sorted(os.listdir(RV)):
    if re.search(r'-p[2-9]\.md$', f):
        t = open(RV + f, encoding='utf-8', errors='replace').read()
        hits = re.findall(r'(?i)[^\n]{0,90}\b(lead|dev seat|dev-escalated|haiku|sonnet|the dev|rework commit|repair commit)\b[^\n]{0,90}', t)
        lines = [l.strip()[:200] for l in t.splitlines() if re.search(r'(?i)(rework (was|commit|by|landed)|lead (applied|committed|landed|repaired|fixed)|repaired by|committed by|the lead)', l)]
        print('  ', f, '|', lines[:2])
for f in ('dev-report-1-5-fix.md', 'dev-report-1-4-fixes.md'):
    L = [l.strip() for l in open(IA + f, encoding='utf-8', errors='replace') if l.strip()]
    print('  ', f, '|', ' / '.join(x[:150] for x in L[:4]))
