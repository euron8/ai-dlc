#!/usr/bin/env python3
"""Extract the s323 lead's tool calls in the implementation window, paired tool_use/tool_result by id.
Usage: python3 -I extract_lead.py <transcript.jsonl> <win_start> <win_end> <out.jsonl>
Output row: ts (tool_use msg ts), rts (result ts), name, inp (<=600 chars of command/args), err (bool),
rlen (result chars), rhead (<=400 chars), model, out_tok, in_tok, cr, cw (from the assistant message usage).
Also emits {"ev":"human"|"notif", ...} rows for human-origin user messages and task-notification queue ops.
"""
import json, sys
P, W0, W1, OUT = sys.argv[1:5]
uses = {}
rows = []
def digest(inp):
    if not isinstance(inp, dict): return str(inp)[:600]
    for k in ('command', 'prompt', 'file_path', 'description', 'path', 'pattern', 'to', 'message', 'skill', 'code'):
        if k in inp:
            return (k + ':' + str(inp[k]))[:600]
    return json.dumps(inp)[:600]
with open(P) as f:
    for l in f:
        try: r = json.loads(l)
        except Exception: continue
        ts = r.get('timestamp')
        if not ts or ts < W0 or ts > W1: continue
        t = r.get('type')
        if t == 'assistant':
            m = r.get('message', {})
            u = m.get('usage', {}) or {}
            for b in m.get('content', []) if isinstance(m.get('content'), list) else []:
                if b.get('type') == 'tool_use':
                    uses[b['id']] = dict(ts=ts, name=b['name'], inp=digest(b.get('input')),
                                         bg=bool((b.get('input') or {}).get('run_in_background')) if isinstance(b.get('input'), dict) else False,
                                         model=m.get('model'), out_tok=u.get('output_tokens'), in_tok=u.get('input_tokens'),
                                         cr=u.get('cache_read_input_tokens'), cw=u.get('cache_creation_input_tokens'),
                                         subtype=(b.get('input') or {}).get('subagent_type') if isinstance(b.get('input'), dict) else None,
                                         desc=(b.get('input') or {}).get('description') if isinstance(b.get('input'), dict) else None,
                                         plen=len((b.get('input') or {}).get('prompt') or '') if isinstance(b.get('input'), dict) else 0)
        elif t == 'user':
            m = r.get('message', {})
            c = m.get('content')
            org = (r.get('origin') or {}).get('kind')
            if isinstance(c, list):
                for b in c:
                    if b.get('type') == 'tool_result':
                        u = uses.pop(b.get('tool_use_id'), None)
                        if not u: continue
                        cc = b.get('content')
                        if isinstance(cc, list):
                            cc = ' '.join(x.get('text', '') for x in cc if isinstance(x, dict))
                        cc = cc if isinstance(cc, str) else str(cc)
                        u.update(rts=ts, err=bool(b.get('is_error')), rlen=len(cc), rhead=cc[:400])
                        rows.append(u)
            if org == 'human' or (isinstance(c, str) and org not in ('task-notification',)):
                txt = c if isinstance(c, str) else ''
                rows.append(dict(ev='user', ts=ts, org=org, head=txt[:300]))
        elif t == 'queue-operation' and r.get('operation') == 'enqueue':
            rows.append(dict(ev='notif', ts=ts, head=(r.get('content') or '')[:300]))
for u in uses.values():  # unmatched
    u['unmatched'] = True
    rows.append(u)
rows.sort(key=lambda x: x.get('ts', ''))
with open(OUT, 'w') as o:
    for x in rows: o.write(json.dumps(x) + '\n')
print(len(rows), 'rows;', len(uses), 'unmatched')
