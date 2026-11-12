"""BL-615 mechanism metric (reported beside the outcome, never deciding): nonexistent-path grep errors in
adversary-seat transcripts, per transcript and per grep, and on BL-550's like-for-like round.

Usage: python3 -I grep_misses.py [<transcript root>]     (default ~/.claude/projects/-Users-n8-git-graph)

Population: every subagent transcript whose meta.json says agentType=adversary, assigned to a window by its
FIRST timestamp. Tool_use ids are de-duplicated (one dict entry per id). A GREP is a Bash tool_use whose
command invokes grep, ugrep, egrep, fgrep or rg; a built-in Grep tool_use counts too. A MISS is a grep whose
result carries at least one line the grep tool itself emitted of the form
`<grep|ugrep|rg>: [warning: ]<path>: No such file or directory`. A `No such file` line from any other program
(ls, cat, sed, ...) is not a miss; it is counted separately as the near-miss control and must read non-zero.

Windows (first timestamp, half-open):
  s321-b250  2026-10-29T23:37:29Z (graph 0672c7221, the s321 fork base) .. 2026-11-05T06:07:47Z, the instant
             the b250 figures were committed (ai-dlc 20784dea2). Positive control: 244 transcripts, 0.37 per
             transcript, 0.85% per grep.
  s321       2026-10-29T23:37:29Z .. 2026-11-09T00:00:00Z (extract.py's s321 edge)
  s322       2026-11-09T00:00:00Z .. EXTRACT_WIN_END (default 2026-11-12T10:00:00Z)

BL-550's like-for-like round is the requirements step's first ADVERSARIAL round after its elicitation round.
It is declared here per sprint by lead session and description, read from the transcripts' meta.json:
  s319  lead f65eae3b, `Adversarial p1 ...` (BL-550's own round; control: 19 parts, 12 misses in 7 parts)
  s321  lead 59a855bd, `... pass 1`, plus lead d9d2b30c's three re-dispatched pass-1 shards
        `Adversary shard NN <topic>` (control: 16 parts, 18 misses in 10 parts, as recorded in b250)
  s322  lead 6c14d949, `Adversary p1 ...` (10 parts: 9 shards and a cross shard). Its briefs are
        `_bmad-output/planning-artifacts/s322/rounds/requirements-adversarial-p1/<n>.brief`, but extract.py
        labels the spawns gate-validation[carry-over-evaluation]: that lead's gate span never closed before the
        requirements round. The later lead 9a646a3b's `Adversarial p2/p3/p4` are later passes of the same step.
Records stamped after EXTRACT_WIN_END are dropped inside every transcript.
"""
import glob, json, os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/.claude/projects/-Users-n8-git-graph')
WIN_END = os.environ.get('EXTRACT_WIN_END') or '2026-11-12T10:00:00Z'
WINDOWS = [('s321-b250', '2026-10-29T23:37:29Z', '2026-11-05T06:07:47Z'),
           ('s321', '2026-10-29T23:37:29Z', '2026-11-09T00:00:00Z'),
           ('s322', '2026-11-09T00:00:00Z', WIN_END)]
ROUNDS = [('s319', [('f65eae3b', r'^Adversarial p1 ')], 19),
          ('s321', [('59a855bd', r' pass 1$'), ('d9d2b30c', r'^Adversary shard \d+ ')], 16),
          ('s322', [('6c14d949', r'^Adversary p1 ')], 10)]
GREP = re.compile(r'(?:^|[\s|;&(`])(?:grep|ugrep|egrep|fgrep|rg)\s')
MISS = re.compile(r'^(?:ugrep|grep|egrep|fgrep|rg): (?:warning: )?.+: No such file or directory$')
NEAR = re.compile(r'^[A-Za-z0-9_.-]+: .*No such file or directory$')
IMPOSSIBLE = 'bl615-impossible-token-x9q7'
# context-mode MCP shell tools (ctx_execute, ctx_batch_execute). b250's definition counted Bash and Grep only;
# these are counted in a SECOND column, so the b250 control is reproduced on b250's own definition.
CTX = re.compile(r'context-mode__ctx_(?:batch_)?execute')


def first_ts(p):
    with open(p) as f:
        for l in f:
            try:
                t = json.loads(l).get('timestamp')
            except Exception:
                continue
            if t:
                return t
    return None


def scan(p):
    uses = {}; res = {}
    with open(p) as f:
        for l in f:
            try:
                r = json.loads(l)
            except Exception:
                continue
            if (r.get('timestamp') or '') > WIN_END:
                continue   # records after the window end are dropped, as extract.py drops them
            c = (r.get('message') or {}).get('content')
            if not isinstance(c, list):
                continue
            for b in c:
                if not isinstance(b, dict):
                    continue
                if b.get('type') == 'tool_use':
                    uses[b.get('id')] = (b.get('name'), b.get('input') or {})
                elif b.get('type') == 'tool_result':
                    cc = b.get('content')
                    if isinstance(cc, list):
                        cc = '\n'.join(x.get('text', '') for x in cc if isinstance(x, dict))
                    res[b.get('tool_use_id')] = cc if isinstance(cc, str) else ''
    g = m = near = imp = cg = cm = 0
    for k, (name, inp) in uses.items():
        out = res.get(k, '')
        lines = [x.strip() for x in out.split('\n')]
        imp += IMPOSSIBLE in out
        ctx = False
        if name == 'Bash':
            is_grep = bool(GREP.search(' ' + (inp.get('command') or '')))
        elif CTX.search(name or ''):
            # a context-mode shell call: its code is the command (b250's population had none of these, see CTX)
            code = inp.get('code') if isinstance(inp.get('code'), str) else json.dumps(inp)
            is_grep = bool(GREP.search(' ' + code)); ctx = True
        else:
            is_grep = name == 'Grep'
        hit = any(MISS.match(x) for x in lines)
        if name == 'Grep' and ('does not exist' in out or 'No such file' in out):
            hit = True
        if is_grep and ctx:
            cg += 1; cm += hit
        elif is_grep:
            g += 1; m += hit
        near += sum(1 for x in lines if NEAR.match(x) and not MISS.match(x))
    return g, m, near, imp, cg, cm


def main():
    T = []
    metas = glob.glob(ROOT + '/*/subagents/*.meta.json')
    top = glob.glob(ROOT + '/*.jsonl')
    earliest = min((t for t in (first_ts(p) for p in top) if t), default=None)
    print('corpus: %s, %d top-level transcripts, earliest record %s, %d subagent meta files'
          % (ROOT, len(top), earliest, len(metas)))
    for mp in metas:
        try:
            d = json.load(open(mp))
        except Exception:
            continue
        if d.get('agentType') != 'adversary':
            continue
        p = mp[:-len('.meta.json')] + '.jsonl'
        if not os.path.exists(p):
            continue
        t = first_ts(p)
        if not t or t > WIN_END:
            continue
        T.append(dict(first=t, lead=mp.split('/')[-3][:8], desc=d.get('description') or '', scan=scan(p)))
    print('adversary transcripts with a first record at or before %s: %d' % (WIN_END, len(T)))
    print()
    for label, lo, hi in WINDOWS:
        R = [x for x in T if lo <= x['first'] < hi]
        n = len(R); g = sum(x['scan'][0] for x in R); m = sum(x['scan'][1] for x in R)
        near = sum(x['scan'][2] for x in R); imp = sum(x['scan'][3] for x in R)
        cg = sum(x['scan'][4] for x in R); cm = sum(x['scan'][5] for x in R)
        print('%-10s [%s, %s): %d transcripts, %d greps, %d misses: %.2f per transcript, %.2f%% per grep; '
              'near-miss control (other programs\' No such file lines) %d; impossible-token control %d'
              % (label, lo, hi, n, g, m, m / n if n else 0, 100.0 * m / g if g else 0, near, imp))
        print('%-10s with context-mode shell greps added: %d greps, %d misses: %.2f per transcript, %.2f%% per grep'
              % ('', g + cg, m + cm, (m + cm) / n if n else 0, 100.0 * (m + cm) / (g + cg) if g + cg else 0))
    print()
    for label, sel, want in ROUNDS:
        R = [x for x in T if any(x['lead'] == l and re.search(rx, x['desc']) for l, rx in sel)]
        m = sum(x['scan'][1] for x in R); parts = sum(1 for x in R if x['scan'][1])
        g = sum(x['scan'][0] for x in R)
        cm = sum(x['scan'][1] + x['scan'][5] for x in R); cparts = sum(1 for x in R if x['scan'][1] + x['scan'][5])
        ctl = '' if want is None else ('; part-count control %s (expected %d)' % ('OK' if len(R) == want else 'FAILED', want))
        print('like-for-like %s: %d parts, %d greps, %d misses in %d of %d parts%s; with context-mode shell greps: %d misses in %d parts'
              % (label, len(R), g, m, parts, len(R), ctl, cm, cparts))


if __name__ == '__main__':
    main()
