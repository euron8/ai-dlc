import json,sys
M='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
sp=int(sys.argv[1])
print("SEGS")
for l in open(M+'segs.jsonl'):
    r=json.loads(l)
    if r['sprint']==sp and r['step'] in('architecture','ui-direction'):
        print(r['kind'],r['step'],r['unit'][:14],r['first'][5:19],r['last'][5:19],round(r['active']/60,1),round(r['agent_wait']/60,1),r['humans'])
print("SPAWNS")
rows=[]
for l in open(M+'spawns.jsonl'):
    r=json.loads(l)
    if r['sprint']==sp and r['step'] in('architecture','ui-direction'):
        rows.append(r)
rows.sort(key=lambda r:r['start'])
for r in rows:
    print(r['start'][5:19],r['end'][11:19],r['step'][:4],r['role'][:10],r['model_ran'][:5],r['minutes'],r['usd'],r['description'][:70])
