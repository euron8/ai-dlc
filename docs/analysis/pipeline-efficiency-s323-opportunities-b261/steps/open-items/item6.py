"""item 6: s323 gate-3 implementation adjudicator verdict rows (graph _bmad-output/implementation-artifacts/s323/gate-adjudication/implementation-*.part-*.jsonl).
Unit = one verdict row (check_id x gate run), 15 runs x 15 checks = 225 rows (control: must be 225, 120 part files, 15 per check).
Classes for PASS rows (heuristic over the evidence TEXT, judgment-laden; samples printed for reading):
  SKIP   = the evidence's first 260 chars say self-skip / exempt / skip condition holds (scope clause, no artifact derived)
  SCRIPT = every sentence that is not a frozen-sha rev-parse is a script-output sentence (script name, exit code, counts line, PASS count)
  DERIVED= at least one sentence of the adjudicator's own grep / git / ls / line-cite / compare
Script arms the lead's gate-transition.sh already ran at a one-story gate 3 (gate-transition.sh header lines 41-45): Check 2 (vocabulary, suppression lifetime), 2a, 5, 16, 17, 22, 25, H2.
python3 -I item6.py [show CHECK N]"""
import json,glob,re,collections,sys,os
D='/Users/n8/git/graph/_bmad-output/implementation-artifacts/s323/gate-adjudication/'
rows=[];files=sorted(glob.glob(D+'implementation-*.part-*.jsonl'))
for f in files:
    for l in open(f):
        if l.strip(): r=json.loads(l);r['_f']=os.path.basename(f);rows.append(r)
assert len(rows)==225 and len(files)==120,(len(rows),len(files))
SC=re.compile(r"(\.sh\b|verdict\.sh|\bexit(ed)?[ =:]*0\b|exit code|\bcounts?\b|examined \d+|check-stories|derive-stories|validate-[a-z-]+|\bPASS\b|\bOK\b|printed|prints|output)",re.I)
DV=re.compile(r"(\bgrep\b|git (ls-files|diff|log|show|status|blame|merge-base|cat-file)|\bls\b|\bcat\b|\bwc\b|:\d{2,}\b|\bline[s]? \d+|byte|python|sha256|\bread\b|\bopened\b|\bcompar|\bconfirm|\bcontrol\b|non-zero)",re.I)
def sents(t): return [s.strip() for s in re.split(r'(?<=[.;])\s+',t) if s.strip()]
def klass(r):
    t=r['evidence']
    if r['verdict']!='PASS': return 'FAIL'
    if re.search(r"self-skip|self skip|skips?\b|exempt|skip condition|not applicable|N/A",t[:260],re.I): return 'SKIP'
    own=[]
    for s in sents(t):
        if re.search(r"rev-parse|HEAD (verified|confirmed)|frozen (worktree|sha)",s,re.I) and not DV.search(re.sub(r"rev-parse|frozen","",s)): continue
        if SC.search(s) and not re.search(r"\bgrep\b|git (ls-files|diff|log|show)|\bls\b|line \d+|:\d{3,}",s): continue
        if DV.search(s): own.append(s)
    return 'DERIVED' if own else 'SCRIPT'
by=collections.defaultdict(collections.Counter)
for r in rows: r['k']=klass(r);by[r['check_id']][r['k']]+=1
order=['1','2','3','4','5','6','7','8','9','10','11','11a','16','19','22']
armed={'2','5','16','22'}
print('check  armed-in-gate-transition  PASS-SCRIPT  PASS-SKIP  PASS-DERIVED  FAIL')
tot=collections.Counter()
for c in order:
    b=by[c];tot.update(b);print(f"{c:>4}  {'yes' if c in armed else 'no ':>3}  {b['SCRIPT']:>3} {b['SKIP']:>3} {b['DERIVED']:>3} {b['FAIL']:>3}")
print('TOTAL',dict(tot),sum(tot.values()))
if len(sys.argv)>2 and sys.argv[1]=='show':
    c=sys.argv[2];k=sys.argv[3] if len(sys.argv)>3 else 'SCRIPT'
    for r in rows:
        if r['check_id']==c and r['k']==k: print('--',r['_f'][15:31],r['_f'][-11:-6],'|',r['evidence'][:700].replace('\n',' '))
