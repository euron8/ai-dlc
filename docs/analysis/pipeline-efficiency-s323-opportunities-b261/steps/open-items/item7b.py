"""item 7 refined: strict+loose failure phrasing vs pass phrasing, assistant text + AskUserQuestion input only. python3 -I item7b.py"""
import glob,json,os,re,collections
ROOT=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
E=[("2026-11-09T00:00:00Z",321),("2026-11-13T08:00:00Z",322),("2026-11-20T04:20:00Z",323)];W0="2026-10-30T00:10:03Z"
def sp(t):
  for e,n in E:
    if t<e:return n
FAIL={'5 branch-mismatch (strict or loose)':r"finalized on branch|continue-here|branch mismatch|doesn.t match the snapshot|`switch`",
 '6 recency-warning':r"snapshot's last gate was|last gate was \d+ days|days ago.{0,40}snapshot|snapshot.{0,60}stale",
 '7 stranded-deploy-validate':r"Snapshot is at `current_step_file: deploy-validate\.md`|snapshot was never advanced|re-enter closed deploy work|stranded (on|at) .?deploy-validate|snapshot (is )?stranded"}
PASS={'pass: all seven checks pass':r"seven checks pass|all seven.{0,20}pass|checks 3.7 (all )?(pass|assess)|Step 0a integrity",
 'pass: not stranded':r"not stranded",'pass: branch matches':r"branch matches"}
C=collections.Counter();ex=collections.defaultdict(list)
big=re.compile("|".join(list(FAIL.values())+list(PASS.values())))
for p in sorted(glob.glob(ROOT+"/*.jsonl")):
  for l in open(p,errors="replace"):
    if not big.search(l): continue
    try:r=json.loads(l)
    except: continue
    t=r.get("timestamp","")
    if not(W0<=t<"2026-11-20T04:20:00Z"):continue
    s=sp(t);c=r.get("message",{}).get("content")
    if not isinstance(c,list) or r.get("type")!="assistant":continue
    for x in c:
      if not isinstance(x,dict):continue
      if x.get("type")=="text": tx=x.get("text","")
      elif x.get("type")=="tool_use" and x.get("name")=="AskUserQuestion": tx=json.dumps(x.get("input"))
      else: continue
      for k,rx in {**FAIL,**PASS}.items():
        m=re.search(rx,tx)
        if m:
          C[(s,k)]+=1
          if k in FAIL: ex[(s,k)].append((t[5:19],os.path.basename(p)[:8],tx[max(0,m.start()-80):m.start()+160].replace("\n"," ")))
for k in sorted(C):print(k,C[k])
for k,v in sorted(ex.items()):
  print("FAIL-CANDIDATES",k,len(v))
  for e in v[:8]:print("   ",e)
