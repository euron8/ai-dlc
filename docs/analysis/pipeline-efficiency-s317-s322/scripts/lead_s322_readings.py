# BL-819 batch 259 C2: three owed readings on graph's s322 lead transcripts, s322 ONLY.
#   (A) step-reread overlap over PROCEDURE targets, (B) duplicate-read census over read-search, (C) the split of the
#   `text` class's active hours by the record that closes each interval, on extract.py's clock.
# usage: python3 -I lead_s322_readings.py [--self-test]
# WINDOW: a transcript is opened only if it was created at or before E (st_birthtime; a later file holds only later
# records) and modified at or after S; a read stops at the first record stamped after E. The first line prints the file
# counts with and without the window. No s323 file is opened.
# Executed calls only: a tool_use counts when a tool_result with its id exists and is not is_error.
# Epoch: a compaction (isCompactSummary record) starts a new epoch; a duplicate needs the SAME epoch.
# (B) STRICT duplicate: same key in the same epoch with no mutation between (any Edit/Write, non-read Bash or
#   ctx_execute, git write, Agent/Task/SendMessage). LOOSE: same key, same epoch, no Edit/Write of any path the call
#   targets between. COVERED (Read only): an earlier Read this epoch of a range that contains this one, file unedited.
# (C) clock: extract.py's Classer (monotone, 300 s active/gap split, the interval is charged to the class of the
#   record that opened it; compaction-recovery and idle-wait take precedence). A text message is a message.id with no
#   tool_use block in any of its records. Not restricted to the pipeline bucket or a step.
import json,glob,collections,re,os,sys,datetime
S="2026-11-09T00:00:00Z";E="2026-11-12T14:41:00Z"
ROOTD='/Users/n8/.claude/projects/-Users-n8-git-graph'
_ep=lambda s:datetime.datetime.strptime(s,'%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()
_TS=re.compile(r'"timestamp":"([^"]+)"')
def s322_files():
    allf=glob.glob(ROOTD+'/*.jsonl');keep=[];late=0
    for f in allf:
        st=os.stat(f)
        if st.st_birthtime>_ep(E) or st.st_mtime<_ep(S):continue
        keep.append(f)
        if st.st_mtime>_ep(E):late+=1
    print('window: files without window',len(allf),'with window',len(keep),'(of which appended after E, read to E only: %d)'%late)
    return sorted(keep)
def load(f):
    out=[]
    for l in open(f,errors='replace'):
        mt=_TS.search(l)
        if mt and mt.group(1)>E:break
        try:out.append(json.loads(l))
        except Exception:pass
    return out
def tsec(s):
    try:return datetime.datetime.strptime(s[:19],'%Y-%m-%dT%H:%M:%S').replace(tzinfo=datetime.timezone.utc).timestamp()+float('0'+s[19:].rstrip('Z'))
    except Exception:return None
PATH_RE=re.compile(r"(?:~|\.{1,2})?/?(?:[A-Za-z0-9_@.+-]+/)+[A-Za-z0-9_@.+*-]*")
PROC_RE=re.compile(r"(^|/)(\.claude/(skills|team-roles|agents|hooks|rules)|\.claude/settings[^/]*$|scripts/ai-dlc/)")
GATE_RE=re.compile(r"gate-log\.md|gate-metrics\.jsonl|gate-adjudication|gate-transition")
DELEG_RE=re.compile(r"/tmp/claude-|_bmad-output/(planning|implementation)-artifacts/s\d+/|/shards/")
def family(p):
    if PROC_RE.search(p):return 'procedure'
    if DELEG_RE.search(p) or GATE_RE.search(p):return 'delegate'
    if '_bmad-output' in p or p.endswith(('pipeline-paused.flag','spawn-ledger.jsonl')):return 'state'
    return 'project'
def fam_of(paths):
    fs={family(p) for p in paths}
    return 'none' if not fs else (fs.pop() if len(fs)==1 else 'mixed')
def targets(text,cwd):
    out=set()
    for p in PATH_RE.findall(text):
        if cwd and p.startswith(cwd+'/'):p=p[len(cwd)+1:]
        while p.startswith('./'):p=p[2:]
        p=p.rstrip('/')
        if '/' in p.lstrip('/'):out.add(p)
    return out
READV={'cat','head','tail','sed','grep','rg','ls','wc','awk','find','jq','diff','stat','cd','echo','true','printf','test','[','pwd','file','sort','uniq','cut','tr','tree','nl','column','xargs','basename','dirname'}
GITRO={'status','log','diff','show','ls-files','rev-parse','branch','remote','describe','rev-list','blame','grep','cat-file','ls-tree','config'}
WRITE_RE=re.compile(r"(?<![0-9&>])>{1,2}\s*(?!&|/dev/null)|\btee\b|\bsed\s+(-[A-Za-z]*i|--in-place)|\brm\s|\bmv\s|\bcp\s|\bmkdir\b|\btouch\b")
def strip_h(cmd):return cmd.split('<<')[0]
def shell_kind(cmd):
    """'read' | 'git' (read-only git) | 'mut'"""
    c=strip_h(cmd)
    if WRITE_RE.search(c):return 'mut'
    sawgit=False
    for seg in re.split(r"\|\||&&|[|;&\n]",c):
        w=[x.strip("\"'()") for x in seg.split()]
        while w and (w[0] in('bash','sh','env','time') or re.match(r'^[A-Za-z_][A-Za-z0-9_]*=',w[0])):w=w[1:]
        if not w:continue
        p=os.path.basename(w[0])
        if p=='git':
            sub=next((x for x in w[1:] if not x.startswith('-')),'')
            if sub in GITRO:sawgit=True;continue
            return 'mut'
        if p not in READV:return 'mut'
    return 'git' if sawgit else 'read'
CTX_READ=re.compile(r"\b(cat|head|tail|grep|rg|wc|ls|open\()")
CTX_MUT=re.compile(r"(?<![0-9&>])>{1,2}\s*(?!&|/dev/null)|\b(rm|mv|cp|mkdir|touch|git\s+(commit|add|checkout|merge|push|reset|rebase)|write|\.write\()|\bsed\s+-i|\.sh\b")
def human_prompt(r):
    if r.get('type')!='user' or r.get('isMeta') or r.get('isCompactSummary'):return False
    c=(r.get('message') or {}).get('content')
    if isinstance(c,str):return True
    return isinstance(c,list) and not any(isinstance(x,dict) and x.get('type')=='tool_result' for x in c) and any(isinstance(x,dict) and x.get('type')=='text' for x in c)
class Sess:
    def __init__(s,A,B,C):
        s.A,s.B,s.C=A,B,C
        s.epoch=0;s.tools_since=False;s.mut=0;s.pver=collections.Counter()
        s.reads={};s.seen={};s.touched=collections.defaultdict(set)
    def mutating(s,nm,inp):
        if nm in('Edit','Write'):s.pver[str(inp.get('file_path'))]+=1;return True
        if nm in('Agent','Task','SendMessage'):return True
        if nm=='Bash':return shell_kind(str(inp.get('command') or ''))=='mut'
        if nm.endswith('ctx_execute'):
            code=str(inp.get('code') or '');return bool(CTX_MUT.search(code)) or not CTX_READ.search(code)
        return False
    def note(s,b,cwd):
        nm=b.get('name');inp=b.get('input') or {}
        lo=hi=None
        if nm=='Read':
            p=str(inp.get('file_path') or '');paths={p};off=int(inp.get('offset') or 0);lim=int(inp.get('limit') or 2000)
            lo,hi=off,off+lim;key=('Read',p,off,lim);kind='read'
        elif nm=='Bash':
            cmd=str(inp.get('command') or '')
            if shell_kind(cmd)!='read':return
            paths=targets(strip_h(cmd),cwd);key=('sh',' '.join(strip_h(cmd).split()));kind='read'
        elif nm.endswith('ctx_execute'):
            code=str(inp.get('code') or '')
            if CTX_MUT.search(code) or not CTX_READ.search(code):return
            paths=targets(code,cwd);key=('cx',' '.join(code.split()));kind='read'
        elif nm.endswith('ctx_search'):
            paths=set();key=('cs',json.dumps(inp,sort_keys=True));kind='search'
        else:return
        fam='none' if kind=='search' else fam_of(paths)
        vsum=sum(s.pver[p] for p in paths)
        prev=s.seen.get(key)
        strict=prev is not None and prev[0]==s.epoch and prev[1]==s.mut
        loose=prev is not None and prev[0]==s.epoch and prev[2]==vsum
        covered=False
        if nm=='Read':
            p=next(iter(paths))
            for (e0,pv,l0,h0) in s.reads.get(p,[]):
                if e0==s.epoch and pv==s.pver[p] and l0<=lo and hi<=h0:covered=True
            s.reads.setdefault(p,[]).append((s.epoch,s.pver[p],lo,hi))
        s.seen[key]=(s.epoch,s.mut,vsum)
        row=s.B[(kind,fam)]
        row['n']+=1;row['strict']+=int(strict);row['loose']+=int(loose);row['covered']+=int(covered);row['strict_or_covered']+=int(strict or covered)
        if fam=='procedure' and kind=='read':
            for p in paths:
                if s.epoch in s.touched[p]:c='SAME-EPOCH'
                elif s.touched[p]:c='AFTER-COMPACTION'
                else:c='FIRST'
                if nm=='Read' and c=='SAME-EPOCH' and not covered and not strict:c='SAME-EPOCH-NEW-RANGE'
                s.A[c]+=1;s.touched[p].add(s.epoch)
    def run(s,recs):
        errs=set();done=set();withtool=set()
        for r in recs:
            m=r.get('message') or {};c=m.get('content')
            if not isinstance(c,list):continue
            for b in c:
                if not isinstance(b,dict):continue
                if b.get('type')=='tool_result':
                    done.add(b.get('tool_use_id'))
                    if b.get('is_error'):errs.add(b.get('tool_use_id'))
                elif b.get('type')=='tool_use' and r.get('type')=='assistant' and m.get('id'):withtool.add(m['id'])
        clk=None;key=('cls','other');recover=False;rec=set();tu_mid={};last_mid=None;seenmid=set()
        for r in recs:
            typ=r.get('type');tt=tsec(r.get('timestamp') or '')
            if tt is None:continue
            if clk is not None:
                d=max(0.0,tt-clk)
                if S<=r['timestamp']<=E and key[0]=='mid' and key[1] not in withtool and key[1] not in rec:
                    kind=typ+('/'+r['subtype'] if r.get('subtype') else '')+('/'+r['operation'] if r.get('operation') else '')
                    if typ=='user':kind='user/human' if human_prompt(r) else 'user/other'
                    s.C['act' if d<=300 else 'gap'][kind]+=d;s.C['n'][kind]+=1
            clk=tt if clk is None else max(clk,tt)
            if r.get('isCompactSummary'):
                recover=True
                if s.tools_since:s.epoch+=1;s.tools_since=False
            cwd=r.get('cwd') or ''
            if typ=='assistant':
                m=r.get('message') or {};mid=m.get('id')
                if not mid:key=('cls','other');continue
                last_mid=mid
                if mid not in seenmid:
                    seenmid.add(mid)
                    if recover:rec.add(mid)
                for b in m.get('content') or []:
                    if not isinstance(b,dict) or b.get('type')!='tool_use':continue
                    if recover and b.get('name') not in('Read','Grep','Glob'):recover=False;rec.discard(mid)
                    tu_mid[b.get('id')]=mid
                    if b.get('id') not in done or b.get('id') in errs:continue
                    s.tools_since=True
                    if S<=r['timestamp']<=E:s.note(b,cwd)
                    if s.mutating(b.get('name') or '',b.get('input') or {}):s.mut+=1
                key=('mid',mid)
            else:
                if recover:key=('cls','compaction-recovery')
                elif typ=='system' and r.get('subtype')=='turn_duration':key=('cls','idle-wait')
                else:
                    c=(r.get('message') or {}).get('content') if typ=='user' else None
                    tid=next((x.get('tool_use_id') for x in c if isinstance(x,dict) and x.get('type')=='tool_result'),None) if isinstance(c,list) else None
                    mm=(tu_mid.get(tid) if tid else None) or last_mid
                    key=('mid',mm) if mm else ('cls','other')
def run_files(files):
    A=collections.Counter();B=collections.defaultdict(collections.Counter);C={'act':collections.Counter(),'gap':collections.Counter(),'n':collections.Counter()}
    for f in files:Sess(A,B,C).run(load(f))
    return A,B,C
def asst(i,mid,blocks,t):return {'type':'assistant','timestamp':t,'cwd':'/w','message':{'id':mid,'content':blocks}}
def res(i,t,err=False):return {'type':'user','timestamp':t,'message':{'content':[{'type':'tool_result','tool_use_id':i,'is_error':err}]}}
def tu(i,name,**inp):return {'type':'tool_use','id':i,'name':name,'input':inp}
def self_test():
    T=lambda n:'2026-11-10T00:00:%02dZ'%n
    seq=[asst(1,'m1',[tu('a','Read',file_path='/w/x.md')],T(1)),res('a',T(2)),
         asst(2,'m2',[tu('b','Read',file_path='/w/x.md')],T(3)),res('b',T(4)),           # strict duplicate
         asst(3,'m3',[tu('c','Read',file_path='/w/x.md',offset=5,limit=10)],T(5)),res('c',T(6)),   # covered, not strict-key
         asst(4,'m4',[tu('d','Edit',file_path='/w/x.md')],T(7)),res('d',T(8)),
         asst(5,'m5',[tu('e','Read',file_path='/w/x.md')],T(9)),res('e',T(10)),           # near miss: edited between
         asst(6,'m6',[tu('f','Read',file_path='/w/x.md')],T(11)),res('f',T(12),True),     # denied: not counted
         asst(7,'m7',[{'type':'text','text':'hi'}],T(13)),{'type':'system','timestamp':T(20),'subtype':'x'}]
    A=collections.Counter();B=collections.defaultdict(collections.Counter);C={'act':collections.Counter(),'gap':collections.Counter(),'n':collections.Counter()}
    Sess(A,B,C).run(seq)
    row=B[('read','project')]
    ok=(row['n']==4 and row['strict']==1 and row['covered']==2 and row['loose']==1) and abs(C['act']['system/x']-7)<1e-6
    print('self-test',row,dict(C['act']),'OK' if ok else 'FAIL');return 0 if ok else 1
def main():
    files=s322_files()
    A,B,C=run_files(files)
    print('== (B) read-search by (kind, family): n, strict-duplicate, loose-duplicate, covered, strict-or-covered')
    tn=0
    for k in sorted(B):
        r=B[k];tn+=r['n'];print(k,r['n'],r['strict'],r['loose'],r['covered'],r['strict_or_covered'])
    g=collections.Counter()
    for (kind,fam),r in B.items():
        if kind=='read' and fam in('project','mixed','none'):
            for x in r:g[x]+=r[x]
    print('GROUP project+mixed+none (read kind):',dict(g),'control total read-search calls',tn)
    print('== (A) procedure-target touches by class:',dict(A),'total',sum(A.values()))
    print('== (C) text-class active hours by closing-record kind (h, intervals); gap h excluded')
    ta=sum(C['act'].values())
    for k,v in C['act'].most_common():print('  %-28s %.3f h %d'%(k,v/3600,C['n'][k]))
    print('  total active %.3f h; gap (>300 s) %.3f h'%(ta/3600,sum(C['gap'].values())/3600))
if __name__=='__main__':
    sys.exit(self_test()) if '--self-test' in sys.argv else main()
