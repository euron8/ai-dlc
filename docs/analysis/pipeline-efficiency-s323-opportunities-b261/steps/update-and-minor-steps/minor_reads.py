"""minor_reads.py -- which lead sessions actually READ each minor step file (tool_use Read/Bash on steps/<name>.md), s317-s323.
usage: python3 -I minor_reads.py
Population: lead transcripts (top-level *.jsonl) listed in MONO/units.jsonl with kind lead. A hit = an assistant tool_use whose input.file_path
or input.command contains 'steps/<name>.md' (Read, Bash, ctx_execute). Mentions in prose / tool_result text do NOT count (text about a program).
Controls: implementation.md (must be many), zz-nonexistent-step.md (must be 0)."""
import json, os, collections
MONO = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
ROOT = os.path.expanduser('~/.claude/projects/-Users-n8-git-graph')
names = ['implementation', 'bug-investigation', 'artifact-consolidation', 'discovery', 'codebase-inventory', 'deep-codebase-analysis', 'doc-repair-backfill', 'doc-reconciliation', 'zz-nonexistent-step']
pop = [json.loads(l) for l in open(MONO + 'units.jsonl')]
pop = [u for u in pop if u['kind'] == 'lead']
hits = collections.defaultdict(list)
n = 0
for u in pop:
    p = ROOT + '/' + u['unit'] + '.jsonl'
    if not os.path.exists(p): continue
    n += 1
    txt = None
    with open(p, errors='replace') as fh:
        for l in fh:
            if 'steps/' not in l or '"tool_use"' not in l: continue
            try: d = json.loads(l)
            except Exception: continue
            c = (d.get('message') or {}).get('content')
            if not isinstance(c, list): continue
            for b in c:
                if not isinstance(b, dict) or b.get('type') != 'tool_use': continue
                inp = b.get('input', {}); s = (inp.get('file_path') or '') + ' ' + (inp.get('command') or '') + ' ' + (inp.get('code') or '')
                for nm in names:
                    if 'steps/%s.md' % nm in s: hits[nm].append((u['sprint'], u['unit'][:8], d.get('timestamp', '')[:16]))
print('lead transcripts scanned', n)
for nm in names:
    h = hits[nm]; bysp = collections.Counter(x[0] for x in h)
    print('%-24s reads=%4d sessions=%3d by sprint %s' % (nm, len(h), len(set(x[1] for x in h)), dict(sorted(bysp.items()))))
    if nm not in ('implementation',) and h: print('    first/last', min(h)[2], max(h)[2], 'sessions', sorted(set(x[1] for x in h))[:6])
