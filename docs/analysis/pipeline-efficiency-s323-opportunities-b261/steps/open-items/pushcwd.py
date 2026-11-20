"""item 2: every `git push` Bash tool_use in s321 lead transcripts with record cwd + paired result head. python3 -I pushcwd.py A B (ISO prefixes)"""
import glob,json,os,sys,re
ROOT=os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
A,B=sys.argv[1],sys.argv[2]
uses={};res={}
for p in sorted(glob.glob(ROOT+"/*.jsonl")):
  for l in open(p,errors="replace"):
    if 'git' not in l or ('push' not in l and 'tool_result' not in l): continue
    try:r=json.loads(l)
    except: continue
    t=r.get("timestamp","")
    if not(A<=t<=B): continue
    c=r.get("message",{}).get("content")
    if not isinstance(c,list): continue
    for x in c:
      if not isinstance(x,dict): continue
      if x.get("type")=="tool_use" and x.get("name")=="Bash" and re.search(r"git (-C \S+ )?push",x["input"].get("command","")):
        uses[x["id"]]=(t,r.get("cwd"),x["input"]["command"][:300],os.path.basename(p)[:8])
      if x.get("type")=="tool_result": res[x.get("tool_use_id")]=(x.get("is_error"),json.dumps(x.get("content"))[:600])
for i,(t,cwd,cmd,s) in sorted(uses.items(),key=lambda kv:kv[1][0]):
  e,c=res.get(i,(None,"<none>"))
  print(t[5:19],s,cwd,"|",cmd.replace("\n"," ")[:220],"| err=",e,"|",c[:260])
