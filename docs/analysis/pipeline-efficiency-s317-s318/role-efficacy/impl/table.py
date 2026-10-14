import os, re, json, collections
B = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/hands/impl/'
G = '/Users/n8/git/graph/docs/reviews/'
VR = re.compile(r'(NEEDS_REWORK|APPROVED|PASS|FAIL|CONDITIONAL)')
def verdict(path):
    L = open(path, encoding='utf-8', errors='replace').read().splitlines()
    for i, l in enumerate(L):
        ls = l.strip()
        if re.match(r'(?i)^(#+\s*)?\**verdict\**\s*:?', ls) and 'rationale' not in ls.lower():
            m = VR.search(ls)
            if m: return m.group(1)
            for l2 in L[i+1:i+6]:
                m = VR.search(l2)
                if m: return m.group(1)
    return None
rev = collections.defaultdict(lambda: {'cr': [], 'qa': []})
for s in ('s317', 's318'):
    for f in sorted(os.listdir(G + s)):
        m = re.match(r'(\d-\d[ab]?)-(code-review|qa-validation)(?:-p(\d))?\.md$', f)
        if not m: continue
        sid = m.group(1).replace('-', '.')
        p = int(m.group(3) or 1)
        rev[(int(s[1:]), sid)]['cr' if m.group(2) == 'code-review' else 'qa'].append((p, verdict(G + s + '/' + f)))
rows = json.load(open(B + 'joined.json'))
DEVR = ('dev', 'dev-escalated', 'protected-path-editor')
stories = collections.defaultdict(list)
for r in rows:
    if r['impl'] and r['story']:
        stories[(r['sprint'], r['story'])].append(r)
out = []
for k in sorted(stories):
    rs = sorted(stories[k], key=lambda r: r['start'])
    devs = [r for r in rs if r['role'] in DEVR]
    first = devs[0] if devs else None
    writer = '%s/%s/%s' % (first['role'][:8], first['model_ran'], first['effort_bound']) if first else 'NONE'
    escal = any(r['role'] == 'dev-escalated' for r in devs)
    cr = sorted(rev[k]['cr']); qa = sorted(rev[k]['qa'])
    usd = sum(r['usd'] or 0 for r in rs)
    dusd = sum(r['usd'] or 0 for r in devs)
    crusd = sum(r['usd'] or 0 for r in rs if r['role'].startswith('code-reviewer'))
    qausd = sum(r['usd'] or 0 for r in rs if r['role'] == 'qa')
    gausd = sum(r['usd'] or 0 for r in rs if r['role'] == 'gate-adjudicator')
    wall = (max(r['end'] for r in rs if r['end']) and None)
    from datetime import datetime
    ts = lambda x: datetime.fromisoformat(x.replace('Z', '+00:00'))
    try:
        wall = (ts(max(r['end'] for r in rs if r['end'])) - ts(first['start'] if first else rs[0]['start'])).total_seconds() / 60
    except Exception:
        wall = -1
    crroles = collections.Counter('%s/%s/%s' % (r['role'].replace('code-reviewer', 'CR'), r['model_ran'], r['effort_bound']) for r in rs if r['role'].startswith('code-reviewer') and 'losing' not in r['description'])
    rec = dict(sprint=k[0], story=k[1], writer=writer, escal=escal, ndev=len(devs),
               devmodels=sorted(set('%s/%s/%s' % (r['role'][:8], r['model_ran'], r['effort_bound']) for r in devs)),
               cr=cr, qa=qa, ncr=len(cr), nqa=len(qa), usd=round(usd, 1), dusd=round(dusd, 1), crusd=round(crusd, 1), qausd=round(qausd, 1), gausd=round(gausd, 1),
               wall=round(wall), nspawn=len(rs), crroles=dict(crroles))
    out.append(rec)
    print(k[0], k[1].ljust(4), writer.ljust(26), 'esc' if escal else '   ', 'ndev=%d' % len(devs),
          'CR', ''.join((v or '?')[0] for p, v in cr), 'QA', ''.join((v or '?')[0] for p, v in qa),
          '$%.0f(d%.0f cr%.0f qa%.0f ga%.0f)' % (usd, dusd, crusd, qausd, gausd), 'wall=%dm' % wall, 'n=%d' % len(rs), dict(crroles))
json.dump(out, open(B + 'stories.json', 'w'))
# stories with reviews but no joined spawns
for k in sorted(rev):
    if k not in stories: print('REVIEWS BUT NO SPAWNS', k, rev[k])
