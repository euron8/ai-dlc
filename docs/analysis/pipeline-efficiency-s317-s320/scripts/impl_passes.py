import json,collections,re,sys
from datetime import datetime
S=sys.argv[1]
# Sprints are an argument (argv[2], comma list), default every sprint the extractor assigned.
SPRINTS=tuple(int(x) for x in sys.argv[2].split(',')) if len(sys.argv)>2 else (314,315,316,317,318,319,320)
# Pass number: `p<N>` / `G1p<N>` / `pass <N>` / `pass-<N>` / `pass_<N>`, one or more digits.
PASS_RE=re.compile(r'(?:(?<![A-Za-z])p|[Pp]ass[ _-])(\d+)')
def pass_of(d):
    m=PASS_RE.search(d)
    return int(m.group(1)) if m else 1
rows=[]
for l in open(S+"/spawns.jsonl"):
    s=json.loads(l)
    st=s['step']; st=st[16:-1] if st.startswith('gate-validation[') else st
    if st!='implementation' or s['sprint'] not in SPRINTS: continue
    if not s['role'].startswith(('code-reviewer','qa')): continue
    d=s['description']
    story=re.search(r'(?<![\d.])(\d{1,2}\.\d{1,2})(?![\d.])',d)
    g=re.search(r'(?:[Gg]ate[- ]?|\bG|\bg(?=\d [a-z]))(\d)',d)
    kind='closing' if 'losing' in d else ('delta' if 'delta' in d.lower() else ('qa' if 'QA' in d or s['role'].startswith('qa') else 'cr'))
    sk=None
    if not story:
        # s322 spells a story `story N` (every s322 story is 1.N); a story-less spawn is keyed below by start time.
        m=re.search(r'\bstory (\d{1,2})\b',d)
        sk='1.'+m.group(1) if m else None
    rows.append(dict(sp=s['sprint'],story=story.group(1) if story else (sk or '?'),gate=g.group(1) if g else '?',ps=pass_of(d),kind=kind,usd=s['usd'],d=d,start=s['start'],role=s['role']))
def _t(r): return datetime.fromisoformat(r['start'].replace('Z','+00:00')).timestamp()
for n in SPRINTS:
    R=[r for r in rows if r['sp']==n]
    keyed=[r for r in R if r['story']!='?']
    for r in R:
        if r['story']=='?' and keyed and r['gate']=='1' and r['kind']!='qa': r['story']=min(keyed,key=lambda q:abs(_t(q)-_t(r)))['story']
    unparsed=sum(1 for r in R if r['story']=='?' or r['gate']=='?')
    passes=collections.defaultdict(set); shards=collections.Counter(); usd=collections.Counter()
    for r in R:
        k=(r['story'],r['gate'],r['kind']=='qa')
        passes[k].add(r['ps']); shards[(k,r['ps'])]+=1; usd[r['ps']]+=r['usd']
    cr=[k for k in passes if not k[2] and k[1]=='1']
    print(f"s{n}: {len(R)} spawns, unparsed {unparsed}; gate-1 CR story count {len(cr)}; passes per story(gate1 CR): {sorted(collections.Counter(max(passes[k]) for k in cr).items())}")
    print("   $ by pass#:", {k:round(v) for k,v in sorted(usd.items())}, " kinds:",dict(collections.Counter(r['kind'] for r in R)))
    gp=collections.Counter((r['gate'],r['kind']) for r in R); print("   by gate/kind:",dict(sorted(gp.items())))
    # shards per pass for gate1 cr
    sh=[shards[(k,p)] for k in cr for p in passes[k]]
    print("   gate1 CR shards/pass: mean %.1f max %d" % (sum(sh)/max(1,len(sh)),max(sh or [0])))
json.dump(rows,open(S+"/implrows.json","w"))
