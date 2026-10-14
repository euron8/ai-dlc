import json, re, sys
P='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/spawns.jsonl'
rows=[json.loads(l) for l in open(P)]
sprint=int(sys.argv[1]); step=sys.argv[2]; role=sys.argv[3]; pat=sys.argv[4] if len(sys.argv)>4 else ''
n=int(sys.argv[5]) if len(sys.argv)>5 else 300
sel=[r for r in rows if r['sprint']==sprint and r['step']==step and r['role']==role and re.search(pat,r['description'] or '')]
sel.sort(key=lambda r:r['start'])
for r in sel:
    t=(r['final_text'] or '').replace('\n',' | ')
    print('##',r['start'][5:16],r['description'],'$%.2f'%r['usd'],r['unit'][-8:])
    print('   ',t[-n:])
