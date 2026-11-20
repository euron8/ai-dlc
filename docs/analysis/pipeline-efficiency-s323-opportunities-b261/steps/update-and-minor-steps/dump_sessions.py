"""dump_sessions.py -- compact per-session event timeline of every lead session that invoked the ai-dlc-update skill.
usage: python3 -I dump_sessions.py OUTDIR [SPRINTS e.g. 321,322,323]
Reads MONO/units.jsonl (population: kind==lead, skills has ai-dlc-update) and graph transcripts READ ONLY.
Writes OUTDIR/<sprint>_<first>_<unit8>.tsv with one row per event: ts, kind, text(<=300 chars).
kinds: H human text, A assistant text, T tool_use (name + arg head), R tool_result (bytes, err flag), Q AskUserQuestion, QA answer.
tool_use paired to tool_result by id; denied/is_error flagged in R rows."""
import json, os, sys, glob
MONO = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
ROOT = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph')
out = sys.argv[1]; sprints = set(int(x) for x in (sys.argv[2] if len(sys.argv) > 2 else '321,322,323').split(','))
os.makedirs(out, exist_ok=True)
pop = [json.loads(l) for l in open(MONO + 'units.jsonl')]
pop = [u for u in pop if u['kind'] == 'lead' and 'ai-dlc-update' in (u.get('skills') or {}) and u['sprint'] in sprints]
def flat(c):
    if isinstance(c, str): return c
    return ' '.join(x.get('text', '') if isinstance(x, dict) else str(x) for x in c)
n = 0
for u in sorted(pop, key=lambda u: u['first']):
    p = ROOT + '/' + u['unit'] + '.jsonl'
    if not os.path.exists(p): print('MISSING', p, file=sys.stderr); continue
    rows = []; tu = {}
    for l in open(p, errors='replace'):
        try: d = json.loads(l)
        except Exception: continue
        ts = d.get('timestamp', '')
        m = d.get('message') or {}
        c = m.get('content')
        if d.get('type') == 'user':
            if isinstance(c, str):
                rows.append((ts, 'H', c[:400].replace('\n', ' '))); continue
            for b in c or []:
                if b.get('type') == 'text': rows.append((ts, 'H', b['text'][:400].replace('\n', ' ')))
                elif b.get('type') == 'tool_result':
                    t = tu.get(b.get('tool_use_id'), ('?', ''))
                    s = flat(b.get('content'))
                    if t[0] == 'AskUserQuestion': rows.append((ts, 'QA', s[:6000].replace('\n', ' ')))
                    else: rows.append((ts, 'R', '%s bytes=%d err=%s' % (t[0], len(s), bool(b.get('is_error')))))
        elif d.get('type') == 'assistant':
            for b in c or []:
                if not isinstance(b, dict): continue
                if b.get('type') == 'text': rows.append((ts, 'A', b['text'][:300].replace('\n', ' ')))
                elif b.get('type') == 'tool_use':
                    nm = b['name']; inp = b.get('input', {}); tu[b['id']] = (nm, ts)
                    if nm == 'AskUserQuestion':
                        for q in inp.get('questions', []):
                            rows.append((ts, 'Q', '%s | %s | opts=%s' % (q.get('header'), q.get('question', '')[:300].replace('\n', ' '), [o.get('label') for o in q.get('options', [])])))
                    else:
                        arg = inp.get('command') or inp.get('file_path') or inp.get('skill') or inp.get('prompt') or json.dumps(inp)
                        rows.append((ts, 'T', nm + ' ' + str(arg)[:300].replace('\n', ' ')))
    fn = '%s/%d_%s_%s.tsv' % (out, u['sprint'], u['first'][:16].replace(':', ''), u['unit'][:8])
    with open(fn, 'w') as f:
        for r in rows: f.write('\t'.join(r) + '\n')
    n += 1
print('sessions', n, 'of', len(pop))
