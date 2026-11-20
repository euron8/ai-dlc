import json,os,csv,collections,datetime as dt
R=os.path.dirname(os.path.abspath(__file__))+'/'
MONO=R+'../../MONO/'
EDGES=[("2026-09-28T19:10:00Z",314),("2026-09-30T20:58:00Z",315),("2026-10-05T14:00:00Z",316),("2026-10-12T02:30:00Z",317),("2026-10-14T22:00:00Z",318),("2026-10-23T09:53:00Z",319),("2026-10-30T00:10:03Z",320),("2026-11-09T00:00:00Z",321),("2026-11-13T08:00:00Z",322),("2026-11-20T04:20:00Z",323),("2099-01-01T00:00:00Z",324)]
def sprint_of(t):
    for e,n in EDGES:
        if t<e: return n
def T(s): return dt.datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
def base(st): return st[16:-1] if st.startswith('gate-validation') else st
def bucket():
    b={}
    for l in open(MONO+'units.jsonl'):
        u=json.loads(l)
        if u['kind']!='lead': continue
        stepped=any(k.split('|',1)[0]!='pre-step' for k in u['tok'])
        b[u['sess']]='pipeline' if stepped else ('ai-dlc-update' if u['skills'].get('ai-dlc-update') else 'other')
    return b
def recs():
    for l in open(R+'D/recs.jsonl'): yield json.loads(l)
def by_session():
    S=collections.OrderedDict()
    for r in recs(): S.setdefault(r['s'],[]).append(r)
    return S
