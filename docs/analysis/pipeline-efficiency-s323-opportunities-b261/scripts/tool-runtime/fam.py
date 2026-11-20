import json,re,collections,sys
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10/'
def fam(c):
    if 'wait-for-deliverable' in c: return 'wait-for-deliverable'
    if re.search(r'merge-review-shards|record-run',c): return 'merge-review-shards(suite)'
    if re.search(r'pytest|python3? -m (pytest|unittest)',c): return 'pytest'
    if re.search(r'ci-local',c): return 'ci-local'
    if re.search(r'vitest|npm (run )?test|jest|playwright|npx',c): return 'web-tests'
    if re.search(r'\bsleep\b',c): return 'sleep'
    if re.search(r'pre-push|\bgit push',c): return 'git push'
    if re.search(r'\bgit (worktree|checkout|clone)',c): return 'git worktree'
    if re.search(r'\bgit\b',c): return 'git other'
    if re.search(r'npm install|pip install|venv|node_modules',c): return 'env-setup'
    if re.search(r'validate|check-|scripts/ai-dlc|lint|ruff|shellcheck',c): return 'validators/lint'
    if re.search(r'\b(cat|sed|head|tail|grep|ls|rg|find|wc|awk)\b',c): return 'read/grep'
    return 'other'
for sp in sys.argv[1:]:
    R=json.load(open(D+f'calls{sp}.json'))
    B=[r for r in R if r['tool']=='Bash']
    print(f'== s{sp}: calls {len(R)} bash {len(B)} bash-h {sum(r["lat"] for r in B)/3600:.2f} all-tool-h {sum(r["lat"] for r in R)/3600:.2f}')
    for role in ('ALL','dev','qa','code-reviewer'):
        sel=[r for r in B if role=='ALL' or r['role'].startswith(role)]
        a=collections.defaultdict(lambda:[0,0.0])
        for r in sel: x=a[fam(r['cmd'])]; x[0]+=1; x[1]+=r['lat']
        tot=sum(v[1] for v in a.values())
        print(f' [{role}] bash h {tot/3600:.2f} n={len(sel)}: '+'; '.join(f'{k} {v[0]}x {v[1]/3600:.2f}h ({v[1]/max(1,v[0]):.0f}s)' for k,v in sorted(a.items(),key=lambda kv:-kv[1][1])[:7]))
