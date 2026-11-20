import json,sys
d='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
S=int(sys.argv[1])
sp=[json.loads(l) for l in open(d+'spawns.jsonl')]
L=sorted([s for s in sp if s['sprint']==S and s['step'] in('carry-over-evaluation','gate-validation[carry-over-evaluation]')],key=lambda s:s['start'])
for s in L: print(s['start'][5:16],s['minutes'],s['role'],round(s['usd'],1),s['description'][:60])
