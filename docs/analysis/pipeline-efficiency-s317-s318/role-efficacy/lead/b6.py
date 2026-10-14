import json, os, glob, re, collections
P=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph/')
# 1. lead inline edits to product source (Rule 28) by model
SRC=re.compile(r'/Users/n8/git/graph/(rebalancer|src|lambdas?|infra|web|app)/')
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
sess={json.loads(l)['sess'] for l in open(D+'segs.jsonl') if json.loads(l).get('kind')=='lead'}
c=collections.Counter(); ex=[]
for s in sess:
    for l in open(P+s+'.jsonl'):
        r=json.loads(l)
        if r.get('type')!='assistant' or r.get('isSidechain'): continue
        for x in r['message'].get('content',[]):
            if x.get('type')=='tool_use' and x['name'] in ('Edit','Write','MultiEdit'):
                fp=x['input'].get('file_path','')
                if SRC.search(fp) or fp.endswith('.py') and '/tests/' not in fp and '.claude' not in fp:
                    k=(r['message']['model'],r.get('effort')); c[k]+=1
                    ex.append((r['timestamp'][:16],s[:8],k[0],fp.replace('/Users/n8/git/graph/','')))
print('lead Edit/Write on product source by model',c)
for e in sorted(ex)[:20]: print('  ',e)
print('CONTROL: total lead Edit/Write calls', sum(1 for s in sess for l in open(P+s+'.jsonl') if '"name":"Edit"' in l or '"name": "Edit"' in l))
# 2. advisor calls per lead model
adv=collections.Counter(); calls=collections.Counter(); unav=collections.Counter()
for s in sess:
    ids={}
    for l in open(P+s+'.jsonl'):
        r=json.loads(l)
        if r.get('isSidechain'): continue
        if r.get('type')=='assistant':
            m=r['message'].get('model')
            if m=='<synthetic>': continue
            calls[m]+=1
            for x in r['message'].get('content',[]):
                if x.get('type') in ('server_tool_use','tool_use') and 'advisor' in x.get('name',''):
                    adv[(m,x['name'])]+=1; ids[x['id']]=m
        if r.get('type')=='user' and isinstance(r['message'].get('content'),list):
            for x in r['message']['content']:
                if x.get('type')=='tool_result' and x.get('tool_use_id') in ids:
                    t=x.get('content'); t=t if isinstance(t,str) else json.dumps(t)
                    if 'unavailable' in t or x.get('is_error'): unav[ids[x['tool_use_id']]]+=1
        if r.get('type')=='assistant':
            for x in r['message'].get('content',[]):
                if x.get('type')=='advisor_tool_result' or (x.get('type')=='server_tool_use' and x.get('name')=='advisor'): pass
print('advisor calls',adv); print('advisor unavailable/error',unav); print('lead calls',calls)
# 3. s318 lead-conduct disclosures in gate-log
G='/Users/n8/git/graph/_bmad-output/implementation-artifacts/gate-log.md'
for i,l in enumerate(open(G,errors='replace')):
    if re.search(r'(Lead-conduct|lead.s own|error was the lead|was the lead)',l,re.I): print('GL%d'%i,l[:400])
