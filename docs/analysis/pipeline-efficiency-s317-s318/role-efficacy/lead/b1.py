import json, collections, datetime
D='/private/tmp/claude-501/-Users-n8-git-ai-dlc/f5624388-e35c-4e6b-a5a5-7888910f861e/scratchpad/out/'
sp=[json.loads(l) for l in open(D+'spawns.jsonl')]
def T(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00'))
# discarded nonces: (label, nonce time UTC)
disc=[('s317 impl 124524Z waiver-no-exception','2026-10-09T12:45:24'),('s317 impl 192841Z check1','2026-10-09T19:28:41'),
('s317 impl 230257Z lead waiver paperwork','2026-10-10T23:02:57'),('s317 impl 083048Z stray hyphen','2026-10-11T08:30:48'),
('s318 planning 232108Z window lapsed','2026-10-12T23:21:08'),('s318 story 212500Z drift','2026-10-13T21:25:00'),
('s318 impl 010837Z stale story copies','2026-10-14T01:08:37'),('s318 impl 011534Z check22 waiver','2026-10-14T01:15:34'),
('s318 sprint-review 105054Z c21/915 FAIL','2026-10-14T10:50:54')]
ga=[s for s in sp if s['role']=='gate-adjudicator']
print('gate-adjudicator spawns',len(ga),'usd',round(sum(float(s['usd'] or 0) for s in ga),2), collections.Counter((s['model_ran'],s['effort_bound']) for s in ga))
for lab,t in disc:
    t0=T(t+'Z')
    hits=[s for s in ga if 0<= (T(s['start'])-t0).total_seconds() < 1200]
    print(lab, len(hits), 'usd',round(sum(float(s['usd'] or 0) for s in hits),2),'min',round(sum(float(s['minutes'] or 0) for s in hits),1), [s['description'][:35] for s in hits][:6])
# role summary for cross-cutting roles
for role in ['analyst','gate-adjudicator','retro','reconcile','ai-dlc-update']:
    rs=[s for s in sp if role in (s['role'] or '')]
    c=collections.Counter((s['sprint'],s['model_ran'],s['effort_bound']) for s in rs)
    print(role,len(rs),round(sum(float(s['usd'] or 0) for s in rs),2),dict(c))
print(collections.Counter(s['role'] for s in sp).most_common(40))
