import json, collections, statistics, re
D = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/c10-tokens/'
P = {'opus': (4, 20, 0.2, 8), 'sonnet': (2, 10, 0.2, 4), 'haiku': (.1, .5, .01, .2)}
BPT = 2.8   # bytes per token (calibrated from first-request deltas; assumption)
def load(s):
    R = [json.loads(l) for l in open(D + f's{s}.jsonl')]
    for r in R:
        cs = r['calls']
        r['i'] = sum(c[1] for c in cs); r['cw'] = sum(c[2] for c in cs); r['cr'] = sum(c[3] for c in cs); r['o'] = sum(c[4] for c in cs)
        r['th'] = sum(c[5] for c in cs)
        r['p'] = P.get(r['model'], (0, 0, 0, 0))
        a, b, c, d = r['p']
        r['c'] = (r['i'] * a + r['o'] * b + r['cr'] * c + r['cw'] * d) / 1e6
    return R
def pp(r): return r['p']   # (in,out,cr,cw) per M
def readcost(r, tokens, ci):
    """$ of tokens entering context at call index ci: written once, read by later calls"""
    a, b, c, d = r['p']
    n = len(r['calls'])
    return tokens * (d + max(0, n - 1 - ci) * c) / 1e6
def classify(path):
    if '/team-roles/' in path: return 'role-file'
    if '/skills/ai-dlc/steps/' in path or '/skills/ai-dlc/' in path: return 'engine-skill/steps'
    if '/.claude/' in path: return 'other .claude'
    if '_bmad-output/' in path: return 'bmad-output'
    if re.search(r'\.(py|js|ts|sh|json|yaml|yml|toml)$', path): return 'code/config'
    if path.endswith('.md'): return 'other md'
    return 'other'
