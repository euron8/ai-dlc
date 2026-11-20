import json, os, glob, datetime as dt, re, collections
R = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
def T(s): return dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()

def calls(path):
    """paired tool calls from one transcript: list of dict(t0,t1,name,inp,err,denied)"""
    pend = {}; out = []
    for l in open(path, errors='replace'):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get('timestamp')
        if not t: continue
        ty = r.get('type')
        if ty == 'assistant':
            for c in (r.get('message', {}).get('content') or []):
                if isinstance(c, dict) and c.get('type') == 'tool_use':
                    pend[c['id']] = dict(t0=T(t), ts=t, name=c['name'], inp=c.get('input') or {})
        elif ty == 'user':
            c = r.get('message', {}).get('content')
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get('type') == 'tool_result' and x.get('tool_use_id') in pend:
                        d = pend.pop(x['tool_use_id']); d['t1'] = T(t)
                        d['err'] = bool(x.get('is_error'))
                        cont = x.get('content')
                        txt = cont if isinstance(cont, str) else ' '.join(y.get('text', '') for y in (cont or []) if isinstance(y, dict))
                        d['txt'] = txt[:300]
                        d['denied'] = d['err'] and ('denied' in txt[:400].lower() or 'hook' in txt[:200].lower() or 'blocked' in txt[:200].lower())
                        out.append(d)
    return out

def lead_path(sess):
    return glob.glob(R + sess + '*.jsonl')[0]
