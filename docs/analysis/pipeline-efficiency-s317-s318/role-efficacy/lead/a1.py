import json, csv
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
for row in csv.reader(open(D+'leadmodel.csv')):
    if row[2]!='sonnet': print(row)
for f in ['units','spawns','tools','hooks']:
    r=json.loads(open(D+f+'.jsonl').readline())
    print(f, {k:(str(v)[:80]) for k,v in r.items()})
# qwen/local segments
for l in open(D+'segs.jsonl'):
    r=json.loads(l)
    ms=[m for m in r['tok'] if 'claude' not in m]
    if ms: print('LOCALSEG',r['sess'][:8],r['sprint'],r['step'],r['first'],r['last'],{m:r['tok'][m][:2] for m in r['tok']})
