#!/usr/bin/env python3 -I
"""Segment s323 pipeline lead sessions at compact_boundary rows; find advisor calls and first dispatch/write.
Out: segs.json (list of per-compaction records). Read-only on transcripts."""
import json, glob, sys
from datetime import datetime
R = '/Users/n8/.claude/projects/-Users-n8-git-graph/'
OUT = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/advisor-r-value/'
SESS = ['0ef7ba46', '68cf8de7', '4b34031d', '53b4296a', '64926214']
T = lambda s: datetime.fromisoformat(s.replace('Z', '+00:00'))
GATE = ('Agent', 'Task', 'Write', 'Edit')
ADV = ('advisor', 'mcp__advisor__consult')

def load(sid):
    f = glob.glob(R + sid + '*.jsonl')[0]
    rows = []
    for i, l in enumerate(open(f), 1):
        try: r = json.loads(l)
        except Exception: continue
        r['_ln'] = i; rows.append(r)
    return f, rows

def events(rows):
    """flat events: dict(ln, ts, role, kind, name, id, text, err)"""
    ev = []
    for r in rows:
        if r.get('subtype') == 'compact_boundary':
            ev.append(dict(ln=r['_ln'], ts=r['timestamp'], kind='COMPACT')); continue
        if r.get('type') not in ('user', 'assistant'): continue
        m = r.get('message', {}); c = m.get('content') if isinstance(m, dict) else None
        ts = r.get('timestamp')
        if isinstance(c, str):
            ev.append(dict(ln=r['_ln'], ts=ts, role=r['type'], kind='str', text=c)); continue
        if not isinstance(c, list): continue
        for b in c:
            t = b.get('type')
            if t == 'text': ev.append(dict(ln=r['_ln'], ts=ts, role=r['type'], kind='text', text=b['text']))
            elif t == 'thinking' and b.get('thinking'): ev.append(dict(ln=r['_ln'], ts=ts, role='assistant', kind='think', text=b['thinking']))
            elif t in ('tool_use', 'server_tool_use'):
                ev.append(dict(ln=r['_ln'], ts=ts, role='assistant', kind='use', name=b['name'], id=b['id'], inp=b.get('input')))
            elif t in ('tool_result', 'advisor_tool_result'):
                cc = b.get('content')
                if isinstance(cc, list): cc = '\n'.join(x.get('text', '') if isinstance(x, dict) else str(x) for x in cc)
                ev.append(dict(ln=r['_ln'], ts=ts, role='user', kind='res', id=b.get('tool_use_id'), text=str(cc), err=b.get('is_error')))
    return ev

def main():
    out = []
    for sid in SESS:
        f, rows = load(sid); ev = events(rows)
        res = {e['id']: e for e in ev if e['kind'] == 'res'}
        cidx = [i for i, e in enumerate(ev) if e['kind'] == 'COMPACT']
        for k, ci in enumerate(cidx):
            end = cidx[k + 1] if k + 1 < len(cidx) else len(ev)
            seg = ev[ci + 1:end]
            rec = dict(sess=sid, n=k, cln=ev[ci]['ln'], cts=ev[ci]['ts'], endln=ev[end]['ln'] if end < len(ev) else None, nev=len(seg))
            advs, first_gate, first_ok = [], None, None; digs, rden = [], []
            for j, e in enumerate(seg):
                if e['kind'] != 'use': continue
                rs = res.get(e['id'])
                denied = bool(rs and rs.get('err'))
                if e['name'] == 'Read' and 'postcompact-digest.md' in json.dumps(e['inp']): digs.append(dict(j=j, ln=e['ln'], denied=denied))
                if rs and rs.get('err') and 'touchpoint R is owed' in rs['text']: rden.append(dict(j=j, ln=e['ln'], name=e['name']))
                if e['name'] in ADV:
                    a = dict(ln=e['ln'], ts=e['ts'], j=j, res_ln=rs['ln'] if rs else None, res_ts=rs['ts'] if rs else None,
                             err=bool(rs and rs.get('err')), text=rs['text'] if rs else None,
                             secs=(T(rs['ts']) - T(e['ts'])).total_seconds() if rs else None)
                    advs.append(a)
                if e['name'] in GATE and not denied and first_ok is None:
                    first_ok = dict(ln=e['ln'], ts=e['ts'], j=j, name=e['name'])
                if e['name'] in GATE and first_gate is None:
                    first_gate = dict(ln=e['ln'], ts=e['ts'], j=j, name=e['name'], denied=denied, deny=(rs['text'][:300] if denied else None))
            rec['advs'] = advs; rec['digs'] = digs; rec['rden'] = rden; rec['first_gate'] = first_gate; rec['first_ok'] = first_ok
            # gate denials mentioning advisor in this segment
            rec['advisor_denies'] = sum(1 for e in seg if e['kind'] == 'res' and e.get('err') and 'advisor' in e['text'][:600].lower() and 'hook error' in e['text'][:80])
            out.append(rec)
    json.dump(out, open(OUT + 'segs.json', 'w'))
    print(len(out), 'compactions')
main()
