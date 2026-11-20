"""item 7: did Step 0a checks 5/6/7 print failure text (assistant text or AskUserQuestion input) in s321-s323 lead transcripts?
Counts ASSISTANT text blocks and AskUserQuestion tool_use only (never tool_result: a Read of route.md echoes the failure text).
Controls: (c1) assistant text mentioning 'Step 0a' (the lead reporting the check ran); (c2) Bash `git branch --show-current` tool_uses
(check 5 executed); (c3) a Read of route.md that echoes the failure text in a tool_result (proves the phrase regex can match text).
python3 -I item7.py"""
import glob,json,os,re,collections
ROOT=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
E=[("2026-11-09T00:00:00Z",321),("2026-11-13T08:00:00Z",322),("2026-11-20T04:20:00Z",323)]
W0="2026-10-30T00:10:03Z"
def sp(t):
  for e,n in E:
    if t<e:return n
F={'5branch':re.compile(r"finalized on branch|Snapshot was finalized"),'6recency':re.compile(r"snapshot's last gate was|last gate was \d+ days"),'7stranded':re.compile(r"STRANDED|stranded|Snapshot is at `current_step_file")}
C=collections.Counter();ex=collections.defaultdict(list)
for p in sorted(glob.glob(ROOT+"/*.jsonl")):
  if os.path.getmtime(p)<1.7e9: continue
  for l in open(p,errors="replace"):
    if not re.search(r"finalized on branch|last gate was|tranded|STRANDED|Step 0a|show-current|current_step_file",l): continue
    try:r=json.loads(l)
    except: continue
    t=r.get("timestamp","")
    if not(W0<=t<"2026-11-20T04:20:00Z"):continue
    s=sp(t);c=r.get("message",{}).get("content")
    if not isinstance(c,list):continue
    for x in c:
      if not isinstance(x,dict):continue
      ty=x.get("type")
      if r.get("type")=="assistant" and ty=="text":
        tx=x.get("text","")
        if 'Step 0a' in tx: C[(s,'c1 text mentions Step 0a')]+=1
        for k,rx in F.items():
          if rx.search(tx): C[(s,k+' assistant text')]+=1; ex[(s,k)].append((t,os.path.basename(p)[:8],tx[:160].replace("\n"," ")))
      if ty=="tool_use":
        n=x.get("name");inp=json.dumps(x.get("input",{}))
        if n=="Bash" and "show-current" in inp: C[(s,'c2 git branch --show-current')]+=1
        if n=="AskUserQuestion":
          for k,rx in F.items():
            if rx.search(inp): C[(s,k+' AskUserQuestion')]+=1; ex[(s,k)].append((t,os.path.basename(p)[:8],inp[:160]))
      if ty=="tool_result" and r.get("type")=="user":
        tx=json.dumps(x.get("content"))
        if re.search(r"Snapshot was finalized on branch",tx): C[(s,'c3 tool_result echo of failure text (Read of route.md)')]+=1
for k in sorted(C):print(k,C[k])
for k,v in ex.items():
  print(k,len(v))
  for e in v[:6]:print("   ",e)
