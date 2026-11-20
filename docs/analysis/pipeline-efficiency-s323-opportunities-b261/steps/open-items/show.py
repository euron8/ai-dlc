"""print ask details: python3 -I show.py asks317.jsonl START_PREFIX... ; strips echoed question text from answer"""
import json,re,sys
rows=[json.loads(l) for l in open(sys.argv[1])]
for pre in sys.argv[2:]:
  for o in rows:
    if o['start'].startswith(pre):
      print('='*3,o['sprint'],o['start'],o['step'],f"{o['wait']/60:.1f}m err={o['err']}")
      for q in o['qs']:
        print(' Q:',q.get('header'),'|',q.get('question','')[:int(__import__('os').environ.get('QN','350'))].replace('\n',' '))
        print('   opts:',[x.get('label') for x in q.get('options',[])])
      a=o['ans']
      for q in o['qs']: a=a.replace(q.get('question',''),'<Q>')
      print(' A:',a[:int(__import__('os').environ.get('AN','700'))].replace('\n',' '))
