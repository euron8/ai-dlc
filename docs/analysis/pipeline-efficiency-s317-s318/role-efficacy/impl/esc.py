import os, re, json
GR = '/Users/n8/git/graph/_bmad-output/'
IA = GR + 'implementation-artifacts/'
PA = GR + 'planning-artifacts/'
# 1. ff1/ff2 motivation lines
for f in ('s317/ff1-capital-limit-dev-report.md', 's317/ff2-mint-resize-retry-dev-report-2.md'):
    L = [l.strip() for l in open(IA + f, encoding='utf-8', errors='replace') if l.strip()]
    print('=====', f)
    for l in L:
        if re.search(r'(?i)(pre-?exist|predat|since s\d|introduced|incident|revert|why|cause|execution_log|refus)', l):
            print('  *', l[:260])
# 2. did any s317 story file name the functions ff1/ff2/ff3 touched
sd = PA + 's317/stories/'
fns = ['_check_capital_limit', '_compute_live_valuation_usd', '_execute_mint', '_subscribe_layer_mints', '_execute_layer_chunked', 'manual rebalance', 'capital']
if os.path.isdir(sd):
    for f in sorted(os.listdir(sd)):
        t = open(sd + f, encoding='utf-8', errors='replace').read()
        hit = {fn: t.count(fn) for fn in fns if fn in t}
        if hit: print('STORY', f[:60], hit)
else:
    print('no', sd)
# 3. sprint-review fix artifacts s318
for f in ('s318/dev-report-sprint-review-fix.md',):
    L = [l.strip() for l in open(IA + f, encoding='utf-8', errors='replace') if l.strip()]
    print('=====', f)
    for l in L[:16]: print('   ', l[:240])
