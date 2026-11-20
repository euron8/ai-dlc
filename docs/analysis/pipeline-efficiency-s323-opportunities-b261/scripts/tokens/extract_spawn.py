"""Per-spawn extraction for s323 subagents. Usage: extract_spawn.py <sprint> <out.jsonl>
Reads MONO/spawns.jsonl rows of the sprint, locates each subagent transcript, writes one compact record per spawn."""
import json, os, sys, glob, collections
from multiprocessing import Pool
MONO = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
P = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')

def find(row):
    u = row['unit']
    g = glob.glob(P + row['sess'] + '*/subagents/' + u + '.jsonl')
    return g[0] if g else None

def proc(row):
    f = find(row)
    if not f:
        return {'unit': row['unit'], 'missing': True}
    msgs = {}      # msg id -> dict(ts, usage, tools[], order)
    results = {}   # tool_use_id -> (bytes, is_error)
    shape = None; blobs = {}; first_req = None; reqs = []
    n = 0
    for line in open(f):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get('type')
        if t == 'assistant':
            m = r['message']; mid = m['id']
            d = msgs.get(mid)
            if d is None:
                d = msgs[mid] = {'ts': r.get('timestamp'), 'tools': [], 'order': n, 'think_blocks': 0, 'txt': 0}
                n += 1
            d['usage'] = m['usage']
            for b in m['content']:
                if b['type'] == 'tool_use':
                    inp = b.get('input', {})
                    d['tools'].append((b['id'], b['name'], inp.get('file_path') or inp.get('path') or '', inp.get('offset'), inp.get('limit')))
                elif b['type'] == 'thinking': d['think_blocks'] += 1
                elif b['type'] == 'text': d['txt'] += len(b.get('text', ''))
        elif t == 'user':
            c = r['message']['content']
            if isinstance(c, list):
                for b in c:
                    if b.get('type') == 'tool_result':
                        cc = b.get('content')
                        ln = len(cc) if isinstance(cc, str) else len(json.dumps(cc))
                        results[b['tool_use_id']] = (ln, bool(b.get('is_error')))
        elif t == 'api-request-shape':
            if shape is None: shape = r['shape']
        elif t == 'api-request-blob':
            blobs[r['hash']] = r['message']
        elif t == 'api-request':
            if first_req is None: first_req = r
            reqs.append(r.get('timestamp'))
    ms = sorted(msgs.values(), key=lambda d: d['order'])
    calls = []
    for d in ms:
        u = d['usage']; cc = u.get('cache_creation') or {}
        calls.append([d['ts'], u.get('input_tokens', 0), u.get('cache_creation_input_tokens', 0), u.get('cache_read_input_tokens', 0),
                      u.get('output_tokens', 0), (u.get('output_tokens_details') or {}).get('thinking_tokens', 0),
                      cc.get('ephemeral_1h_input_tokens', 0), d['think_blocks']])
    tools = []
    for ci, d in enumerate(ms):
        for (tid, nm, fp, off, lim) in d['tools']:
            ln, er = results.get(tid, (None, None))
            tools.append([nm, fp, off, lim, ln, er, ci])
    comp = {}
    if shape:
        comp['sys'] = [len(x.get('text', '')) for x in shape.get('system', [])]
        comp['tools_bytes'] = len(json.dumps(shape.get('tools', [])))
        comp['ntools'] = len(shape.get('tools', []))
    if first_req:
        tl = []
        for h in first_req.get('tail', []):
            b = blobs.get(h)
            if b:
                cont = b['content'] if isinstance(b['content'], list) else [{'type': 'text', 'text': b['content']}]
                tl.append([b['role'], [len(x.get('text', '')) if x.get('type') == 'text' else len(json.dumps(x)) for x in cont]])
        comp['tail'] = tl
    # first user message (brief) length
    return {'unit': row['unit'], 'role': row['role'], 'step': row['step'], 'model': row['model_ran'], 'bound': row['model_bound'],
            'effort': row['effort_bound'], 'start': row['start'], 'end': row['end'], 'usd': row['usd'], 'calls': calls,
            'tools': tools, 'comp': comp, 'qs': first_req.get('querySource') if first_req else None}

if __name__ == '__main__':
    sprint = int(sys.argv[1]); out = sys.argv[2]
    rows = [json.loads(l) for l in open(MONO + 'spawns.jsonl')]
    rows = [r for r in rows if r['sprint'] == sprint]
    with Pool(8) as p, open(out, 'w') as o:
        for rec in p.imap_unordered(proc, rows, chunksize=4):
            o.write(json.dumps(rec) + '\n')
