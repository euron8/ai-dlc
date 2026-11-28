import json, re, sys, os
# usage: scan.py <cutoff_iso> <regex> [ctxregex] ; prints ts|file|kind|snippet
cut = sys.argv[1]; rx = re.compile(sys.argv[2]); crx = re.compile(sys.argv[3], re.S) if len(sys.argv) > 3 else None
files = open(os.path.join(os.path.dirname(__file__), 'files.txt')).read().split('\n')
def texts(rec):
    m = rec.get('message') or {}
    c = m.get('content')
    if isinstance(c, str):
        yield 'text', c; return
    if not isinstance(c, list): return
    for b in c:
        if not isinstance(b, dict): continue
        t = b.get('type')
        if t == 'text': yield 'text', b.get('text', '')
        elif t == 'tool_use': yield 'tool_use', json.dumps(b.get('input'))
        elif t == 'tool_result':
            cc = b.get('content')
            if isinstance(cc, list): cc = ' '.join(x.get('text', '') for x in cc if isinstance(x, dict))
            yield 'tool_result', str(cc)
n = 0
for f in files:
    if not f: continue
    try: fh = open(f)
    except: continue
    for line in fh:
        if not rx.search(line): continue
        try: rec = json.loads(line)
        except: continue
        ts = rec.get('timestamp', '')
        if not ts or ts >= cut: continue
        for kind, tx in texts(rec):
            for mm in rx.finditer(tx):
                s = tx[max(0, mm.start()-250): mm.end()+250]
                if crx and not crx.search(s): continue
                n += 1
                print(ts, os.path.basename(os.path.dirname(os.path.dirname(f)))[:8] + '/' + os.path.basename(f)[:30], rec.get('type'), kind, '|', s.replace('\n', ' ⏎ '))
                break
print('TOTAL', n, file=sys.stderr)
