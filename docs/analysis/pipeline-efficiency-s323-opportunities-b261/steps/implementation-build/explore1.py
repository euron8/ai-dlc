import json,collections,sys
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
rows=[json.loads(l) for l in open(M+'spawns.jsonl')]
print(len(rows)); print({k:(str(v)[:60]) for k,v in rows[5].items()})
c=collections.Counter((r['sprint'],r['step'],r['role']) for r in rows)
for k,v in sorted(c.items()):
    if k[1]=='implementation' and k[0]>=321: print(k,v)
