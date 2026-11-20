import sys,os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import re, os, collections, pickle
from lib import grp
def strip_heredocs(cmd):
    out=[]; end=None
    for ln in cmd.split("\n"):
        if end is not None:
            if ln.strip()==end: end=None
            continue
        out.append(ln)
        m=re.search(r"<<-?\s*(?:'([^']+)'|\"([^\"]+)\"|([A-Za-z_][A-Za-z0-9_]*))",ln)
        if m: end=m.group(1) or m.group(2) or m.group(3)
    return "\n".join(out)
SKIP={"bash","sh","env","python","python3","cd","set","export","then","do","done","fi","else","if","for","while","until","{","}","(",")","timeout","time","nohup","exec","command","!","VAR","true","false","[","[[","local","unset","trap","echo","printf",":"}
def progs(cmd):
    out=[]
    for seg in re.split(r"\|\||&&|[|;&\n]", strip_heredocs(cmd)):
        w=[x.strip("\"'()") for x in seg.split()]
        while w and (w[0] in ("bash","sh","env","python","python3","timeout","time","nohup","exec","command","sudo") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=",w[0]) or re.match(r"^\d+$",w[0])): w=w[1:]
        if w: out.append((os.path.basename(w[0]), w[1:]))
    return out
def bash_fam(cmd):
    ps=progs(cmd)
    ps2=[p for p in ps if p[0] not in SKIP and p[0]!=""]
    if not ps2:
        # echo-only or cd-only
        first=ps[0][0] if ps else "(empty)"
        return "sh:"+first
    p,a=ps2[0]
    if p in("git","gh"):
        sub=next((x for x in a if not x.startswith("-") and x!="-C" ),"")
        # skip path arg after -C
        if a and a[0]=="-C" and len(a)>2: sub=next((x for x in a[2:] if not x.startswith("-")),"")
        return p+" "+sub
    if p.startswith("-"): return "python-inline"
    if p.endswith(".sh") or p.endswith(".py"): return "script:"+p
    return "sh:"+p
def path_family(path):
    p=path
    for pre in ("/Users/n8/git/graph/",): 
        if p.startswith(pre): p=p[len(pre):]
    if "/tasks/" in p and p.endswith(".output"): return "task-output"
    if "skills/ai-dlc" in p and "/steps/" in p: return "step-file"
    if "skills/ai-dlc" in p or "/.claude/" in p or p.startswith(".claude/"): return "claude-skill/rules"
    if "pipeline-snapshot" in p: return "snapshot"
    if "gate-log" in p or "gate-metrics" in p or "gate-adj" in p: return "gate-records"
    if "_bmad-output/planning-artifacts" in p: return "planning-artifacts"
    if "_bmad-output/implementation-artifacts" in p: return "impl-artifacts"
    if "_bmad-output" in p: return "bmad-output-other"
    if p.startswith("scripts/") : return "scripts/"
    if p.startswith("docs/") or "/docs/" in p: return "docs/"
    if p.startswith("src/") or "/src/" in p or "/tests/" in p or p.startswith("tests/"): return "src/tests"
    return "other-path"
def fam(c):
    tus=[b for b in c["b"] if b[0]=="tu"]
    if not tus: return ("no-tool", "text/thinking only")
    n,s=tus[0][1],tus[0][3]
    if n=="Bash": return ("Bash", bash_fam(s))
    if n in("Read","Edit","Write","MultiEdit"):
        return (n, path_family(s.split(" |")[0]))
    if n in("Grep","Glob"): return (n, path_family(s.split(" @ ")[-1]) if " @ " in s else "")
    if n and "ctx_" in n:
        if n.endswith("ctx_execute"):
            lang=s.split(":")[0]
            code=s[len(lang)+2:]
            if lang=="shell": return (n.split("__")[-1], "shell:"+bash_fam(code))
            return (n.split("__")[-1], lang)
        return (n.split("__")[-1], "")
    return (n,"")
