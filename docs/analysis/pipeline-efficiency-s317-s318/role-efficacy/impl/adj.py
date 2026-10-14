import os, re, json, collections
GR = '/Users/n8/git/graph/_bmad-output/'
dirs = [GR + 'implementation-artifacts/s317/gate-adjudication', GR + 'gate-adjudication']
seen = set()
for d in dirs:
    if not os.path.isdir(d):
        print('NO DIR', d); continue
    fs = sorted(os.listdir(d))
    nonces = collections.OrderedDict()
    for f in fs:
        m = re.match(r'(implementation-(2026101[0-4]|2026100[9])T\d+Z)\.(part-(\d)of(\d)\.jsonl|verdict\.json)$', f)
        if not m: continue
        n = m.group(1)
        if (n) in seen: continue
        nonces.setdefault(n, {'parts': 0, 'of': None, 'verdict': False, 'fail': [], 'pass': 0, 'other': collections.Counter()})
        e = nonces[n]
        if m.group(4):
            e['parts'] += 1; e['of'] = m.group(5)
            for line in open(d + '/' + f, encoding='utf-8', errors='replace'):
                line = line.strip()
                if not line: continue
                try: o = json.loads(line)
                except Exception: e['other']['badjson'] += 1; continue
                st = str(o.get('verdict') or o.get('status') or o.get('result') or '').upper()
                cid = o.get('check_id') or o.get('check') or '?'
                if st.startswith('FAIL'): e['fail'].append(str(cid))
                elif st.startswith('PASS'): e['pass'] += 1
                else: e['other'][st or 'none'] += 1
        else:
            e['verdict'] = True
    print('==', d.replace(GR, ''), 'implementation nonces', len(nonces))
    for n, e in nonces.items():
        seen.add(n)
        print('  ', n, 'parts %d/%s' % (e['parts'], e['of']), 'verdict.json' if e['verdict'] else 'NO-VERDICT', 'pass=%d' % e['pass'], 'FAIL=%s' % e['fail'], dict(e['other']))
