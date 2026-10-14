import json,sys
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/'
rows=[json.loads(l) for l in open(D+'out/spawns.jsonl')]
sp=int(sys.argv[1]); step=sys.argv[2]; n=int(sys.argv[3]) if len(sys.argv)>3 else 120
rs=sorted([r for r in rows if r['sprint']==sp and r['step']==step], key=lambda r:r['start'] or '')
for r in rs:
    ft=(r['final_text'] or '').replace('\n',' ')
    print(r['start'][5:16] if r['start'] else '', r['role'], r['model_ran'], r['effort_bound'], round(r['usd'] or 0,2), round(r['minutes'] or 0,1), '|', (r['description'] or '')[:70], '||', ft[-n:])
