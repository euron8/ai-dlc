#!/usr/bin/env python3 -I
"""readers_all.py SPRINT [exclude_sess_prefix]: for every LEAD session of the sprint (segs.jsonl), count executed
tool_use calls (paired with non-error result) whose input names a previous-retro output. Prefilters lines by substring.
Output: per pattern, sessions and counts, plus first example."""
import sys, json, glob, os, re, collections
MONO = "/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
sprint = int(sys.argv[1]); excl = sys.argv[2] if len(sys.argv) > 2 else "zzzz"
prev = sprint - 1
sess = sorted({s['sess'] for s in map(json.loads, open(MONO + "segs.jsonl")) if s['sprint'] == sprint and s['kind'] == 'lead' and not s['sess'].startswith(excl)})
root = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph/")
PATS = collections.OrderedDict([
    ("retro doc of previous sprint", r"docs/retro/s%d\b" % prev), ("any docs/retro", r"docs/retro/"),
    ("next-inputs bundle", r"next-inputs"), ("retro-artifacts", r"retro-artifacts/s%d" % prev),
    ("party-mode transcript of prev", r"party-mode-transcripts/s%d" % prev),
    ("push-candidate-ledger", r"push-candidate-ledger"), ("audit-anchors", r"audit-anchors"),
    ("prev sprint dir (archives)", r"implementation-artifacts/s%d/" % prev)])
quick = re.compile("|".join(p for p in PATS.values()))
hits = {k: collections.Counter() for k in PATS}; ex = {}
tot = 0
for sid in sess:
    f = glob.glob(root + sid + "*.jsonl")
    if not f: continue
    uses = {}; res = {}
    for l in open(f[0]):
        if '"tool_use' not in l and '"tool_result' not in l: continue
        if 'tool_use' in l and not quick.search(l) and 'tool_result' not in l: continue
        try: d = json.loads(l)
        except Exception: continue
        c = (d.get('message') or {}).get('content')
        if not isinstance(c, list): continue
        for x in c:
            if not isinstance(x, dict): continue
            if x.get('type') == 'tool_use':
                s = json.dumps(x.get('input', {}))
                if quick.search(s): uses[x['id']] = (x['name'], s)
            elif x.get('type') == 'tool_result': res[x['tool_use_id']] = bool(x.get('is_error'))
    for i, (n, s) in uses.items():
        if i in res and not res[i]:
            tot += 1
            for k, rx in PATS.items():
                if re.search(rx, s):
                    hits[k][sid[:8]] += 1; ex.setdefault(k, (sid[:8], n, s[:150]))
print("sprint", sprint, "lead sessions", len(sess), "excluded", excl)
for k in PATS:
    print("%-34s total %3d  sessions %s" % (k, sum(hits[k].values()), dict(hits[k])))
    if k in ex: print("      e.g.", ex[k])
