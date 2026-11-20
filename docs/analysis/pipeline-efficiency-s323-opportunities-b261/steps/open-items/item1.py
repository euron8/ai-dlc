"""item 1 tally. Curated (start-prefix, header) keys -> category. Wait counted once per ask. python3 -I item1.py asks317.jsonl
Control: key not in data (must be reported MISSING) is seeded at the end."""
import json,sys,collections
exec(open('pm.py').read().split("PAT =")[0])
rows=[json.loads(l) for l in open(sys.argv[1])]
K={
'P':[('2026-10-11T15:19','Sprint PR'),('2026-10-11T23:36','Merge PR 1207'),('2026-10-14T14:39','Push + PR'),('2026-10-14T15:44','Merge PR'),
 ('2026-10-22T21:03','Push / PR'),('2026-10-23T00:20','Land fix'),('2026-10-29T16:32','PR #1277'),('2026-10-30T18:14','Land L2 fix'),
 ('2026-11-07T14:42','Push + PR'),('2026-11-07T14:48','Merge PR 1303'),('2026-11-07T15:41','Fix PR'),('2026-11-07T16:06','Merge #1304'),
 ('2026-11-07T18:48','Push + merge'),('2026-11-07T18:54','Merge #1305'),('2026-11-08T03:06','Push+merge'),('2026-11-19T13:24','2.2 reds')],
'F':[('2026-11-07T15:41','CDK deploys'),('2026-11-07T16:22','Monitoring'),('2026-11-08T00:35','Base PUT'),('2026-11-08T04:02','Router PUT'),('2026-11-08T04:34','Router PUT'),
 ('2026-11-13T09:33','Allowlist fire'),('2026-11-17T03:43','Fire order'),('2026-11-17T03:43','Proxy cert'),('2026-11-19T21:42','Allowlist PUT'),('2026-11-19T23:19','Fire precondition')],
'N':[('2026-10-09T14:15','Push blocked'),('2026-11-01T02:09','Push'),('2026-11-09T20:18','Push blocked'),('2026-11-11T06:45','Push block'),('2026-11-11T11:28','Push blockers'),('2026-11-14T15:59','Pre-push red')],
'U':[('2026-10-13T13:29','Merge #1218'),('2026-10-14T13:46','Merge #1219'),('2026-10-30T11:10','Merge #1283'),('2026-11-11T22:12','Merge pin'),('2026-11-13T04:37','Merge #1323')],
'R':[('2026-11-09T00:06','Roll fix')],
'ZZ-control':[('2026-01-01T00:00','NoSuchAsk')],
}
for cat,keys in K.items():
  seen=set();tab=collections.defaultdict(lambda:[0,0.0,collections.Counter()]);miss=0;diff=[]
  for pre,h in keys:
    hit=False
    for o in rows:
      if o['start'].startswith(pre):
        for q in o['qs']:
          if q.get('header')==h:
            hit=True
            ch=chosen(q,o['ans']);k='REJECTED' if o['err'] else kind(q,ch)
            t=tab[o['sprint']];t[2][k]+=1
            if o['id'] not in seen: seen.add(o['id']);t[0]+=1;t[1]+=o['wait']/60
            if k not in('rec','u-first'): diff.append((o['sprint'],o['start'][5:16],h,k,(ch or '')[:60]))
    if not hit: miss+=1;print('MISSING',cat,pre,h)
  tot=[sum(v[0] for v in tab.values()),sum(v[1] for v in tab.values())]
  print(cat,'asks',tot[0],'wait_min %.1f'%tot[1],{s:(v[0],round(v[1],1),dict(v[2])) for s,v in sorted(tab.items())})
  for d in diff: print('   NONDEFAULT',d)
