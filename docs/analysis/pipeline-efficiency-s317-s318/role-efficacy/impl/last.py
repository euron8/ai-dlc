import json, re, collections
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
rows = json.load(open(B + 'joined.json'))
# advisor rate-limit in CR final_text, by sprint/binding; control = 'advisor' mention at all
c = collections.Counter(); ctl = collections.Counter(); n = collections.Counter()
for r in rows:
    if r['impl'] and r['role'].startswith('code-reviewer'):
        k = (r['sprint'], r['role'], r['model_ran'])
        n[k] += 1
        ft = r['final_text'] or ''
        if re.search(r'(?i)rate.?limit', ft): c[k] += 1
        if re.search(r'(?i)advisor', ft): ctl[k] += 1
for k in sorted(n): print('ratelimit', k, 'n=%d' % n[k], 'rate-limited=%d' % c[k], 'advisor-mentioned(control)=%d' % ctl[k])
# per-pass $ for the six sharded stories (pass number from description; p1 default)
for sp, sid in ((317, '1.2'), (317, '2.6'), (318, '1.1'), (318, '2.3'), (318, '2.4'), (318, '2.6'), (317, '2.5')):
    P = collections.defaultdict(float)
    for r in rows:
        if r['sprint'] == sp and r['story'] == sid and r['role'].startswith('code-reviewer') and 'losing' not in r['description']:
            m = re.search(r'\bp(?:ass\s*)?(\d)\b', r['description'])
            P[int(m.group(1)) if m else 1] += r['usd'] or 0
    print('CR$ per pass', sp, sid, {k: round(v, 1) for k, v in sorted(P.items())})
# 2.5 s317 CR spawns step-labelled outside impl
print('s317 2.5 CR spawns in non-impl steps:', sum(1 for r in rows if r['sprint'] == 317 and r['role'].startswith('code-reviewer') and '2.5' in (r['description'] or '') and not r['impl']),
      '$%.1f' % sum(r['usd'] or 0 for r in rows if r['sprint'] == 317 and r['role'].startswith('code-reviewer') and '2.5' in (r['description'] or '') and not r['impl']))
