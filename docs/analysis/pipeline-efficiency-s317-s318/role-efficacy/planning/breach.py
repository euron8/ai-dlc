import json,re,collections
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/'
rows=[json.loads(l) for l in open(D+'out/spawns.jsonl')]
P=('carry-over-evaluation','requirements','architecture')
B=re.compile(r'(?i)(not followed|against the .{0,20}rule|breaks the|did not call the advisor|without (its|the|an) advisor|rate-limited|overwrote|rewrote the file|not the single final write|made up|invented|mislabel|unverified|is an inference|not from a grep)')
ADV=re.compile(r'(?i)(rate-limited|advisor tool (was|is) unavailable)')
c=collections.defaultdict(lambda:[0,0,0])
for r in rows:
    if not any(r['step']==p or r['step']==f'gate-validation[{p}]' for p in P): continue
    k=(r['role'],r['model_ran'],str(r['effort_bound']))
    t=r['final_text'] or ''
    c[k][0]+=1
    hits=[m.group(0) for m in B.finditer(t) if not ADV.match(m.group(0))]
    if hits: c[k][1]+=1
    if ADV.search(t): c[k][2]+=1
for k,v in sorted(c.items()): print(k,'n',v[0],'self-reported-breach/uncertainty',v[1],'advisor-ratelimited',v[2])
