import json, os, glob, re, sys, datetime as dt
R = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
OUT = sys.argv[1]
EDGES = [("2026-11-09T00:00:00Z", 321), ("2026-11-13T08:00:00Z", 322), ("2026-11-20T04:20:00Z", 323)]
START = "2026-11-09T00:00:00Z"; END = "2026-11-20T04:20:00Z"
def T(s): return dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
def sprint_of(t):
    prev = None
    for e, n in EDGES:
        if t < e: return n
    return None
cut = dt.datetime(2026, 11, 9).timestamp()
fs = [f for f in glob.glob(R + '*.jsonl') + glob.glob(R + '*/subagents/*.jsonl') if os.path.getmtime(f) >= cut]
fb = open(OUT + '/bash.jsonl', 'w'); fh = open(OUT + '/hookerr.jsonl', 'w'); fa = open(OUT + '/apierr.jsonl', 'w'); fo = open(OUT + '/othertools.jsonl', 'w')
for p in fs:
    kind = 'sub' if '/subagents/' in p else 'lead'
    sess = p.split('/')[-3] if kind == 'sub' else os.path.basename(p)[:8]
    unit = os.path.basename(p)[:-6]
    pend = {}
    for l in open(p, errors='replace'):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get('timestamp')
        if not t or t < START or t > END: continue
        ty = r.get('type')
        if ty == 'assistant':
            m = r.get('message', {})
            for c in (m.get('content') or []):
                if isinstance(c, dict) and c.get('type') == 'tool_use':
                    pend[c['id']] = (T(t), t, c['name'], c.get('input') or {})
                elif isinstance(c, dict) and c.get('type') == 'text' and r.get('isApiErrorMessage'):
                    fa.write(json.dumps(dict(kind=kind, unit=unit, ts=t, sprint=sprint_of(t), txt=c['text'][:160])) + '\n')
        elif ty == 'user':
            c = r.get('message', {}).get('content')
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get('type') == 'tool_result' and x.get('tool_use_id') in pend:
                        t0, ts, name, inp = pend.pop(x['tool_use_id'])
                        cont = x.get('content')
                        txt = cont if isinstance(cont, str) else ' '.join(y.get('text', '') for y in (cont or []) if isinstance(y, dict))
                        row = dict(kind=kind, sess=sess, unit=unit, ts=ts, sprint=sprint_of(ts), name=name, lat=round(T(t) - t0, 2),
                                   err=bool(x.get('is_error')), res=txt[:160] if x.get('is_error') else '')
                        if name == 'Bash':
                            row['cmd'] = (inp.get('command') or '')[:600]; row['bg'] = bool(inp.get('run_in_background'))
                            fb.write(json.dumps(row) + '\n')
                        elif name in ('Agent', 'Task', 'Monitor', 'WebFetch', 'AskUserQuestion', 'mcp__advisor__consult'):
                            fo.write(json.dumps(row) + '\n')
        elif ty == 'attachment':
            a = r.get('attachment') or {}
            if a.get('type') == 'hook_blocking_error':
                be = (a.get('blockingError') or {}).get('blockingError', '')
                fh.write(json.dumps(dict(kind=kind, unit=unit, ts=t, sprint=sprint_of(t), ev=a.get('hookEvent'), hn=a.get('hookName'),
                                         cmd=(a.get('command') or '')[:120], msg=be[:220], tuid=a.get('toolUseID'))) + '\n')
        elif ty == 'system' and r.get('subtype') not in ('turn_duration', 'stop_hook_summary', 'compact_boundary'):
            fa.write(json.dumps(dict(kind=kind, unit=unit, ts=t, sprint=sprint_of(t), sub=r.get('subtype'), txt=str(r)[:200])) + '\n')
print('files', len(fs))
