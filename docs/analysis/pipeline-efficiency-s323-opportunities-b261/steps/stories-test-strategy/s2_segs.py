import json,sys
M="/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/"
sprint=int(sys.argv[1])
for l in open(M+"segs.jsonl"):
    s=json.loads(l)
    if s['sprint']==sprint and s['step'] in('stories-test-strategy','gate-validation[stories-test-strategy]'):
        print(s['kind'],s['step'][:6],s['first'][5:19],s['last'][5:19],'act',round(s['active']/60,1),'opw',round(s['op_wait']/60,1),'agw',round(s['agent_wait']/60,1),'hum',s['humans'],'cmp',s['compactions'],'lines',s['lines'])
