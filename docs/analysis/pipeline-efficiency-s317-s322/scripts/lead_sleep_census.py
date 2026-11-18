# Census of lead Bash commands in graph's s322 window that run `sleep <n>`, split by whether the command also names
# wait-for-deliverable. Reads ~/.claude/projects/-Users-n8-git-graph/*.jsonl (top-level), read only.
# WINDOW (s322 only, no s323 file is opened): created at or before E (st_birthtime), modified at or after S, and a
# read stops at the first record stamped after E. The first output line prints the file counts with and without it.
# Control: the printed total of lead Bash calls beside the sleep count.
import json,glob,collections,re,os,datetime
S="2026-11-09T00:00:00Z";E="2026-11-12T14:41:00Z"
ROOTD='/Users/n8/.claude/projects/-Users-n8-git-graph'
_ep=lambda s:datetime.datetime.strptime(s,'%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()
def s322_files():
    allf=glob.glob(ROOTD+'/*.jsonl');keep=[];late=0
    for f in allf:
        st=os.stat(f)
        if st.st_birthtime>_ep(E) or st.st_mtime<_ep(S):continue
        keep.append(f)
        if st.st_mtime>_ep(E):late+=1
    print('window: files without window',len(allf),'with window',len(keep),'(of which appended after E, read to E only: %d)'%late)
    return keep
_TS=re.compile(r'"timestamp":"([^"]+)"')
files=s322_files()
n=0;sl=0;c=collections.Counter();ex=[]
for f in files:
    for l in open(f,errors='replace'):
        mt=_TS.search(l)
        if mt and mt.group(1)>E: break
        if '"tool_use"' not in l:continue
        try:r=json.loads(l)
        except Exception:continue
        if not(S<=r.get('timestamp','')<=E):continue
        m=r.get('message') or {}
        if r.get('type')!='assistant' or not isinstance(m.get('content'),list):continue
        for b in m['content']:
            if b.get('type')=='tool_use' and b.get('name')=='Bash':
                n+=1
                cmd=b['input'].get('command','')
                if re.search(r'(^|[;&|\n]\s*)sleep\s+\d',cmd):
                    sl+=1
                    c['wait-for-deliverable' if 'wait-for-deliverable' in cmd else 'other']+=1
                    if len(ex)<12:ex.append(cmd[:110].replace('\n',' | '))
print('bash',n,'sleep cmds',sl,dict(c))
for e in ex:print(e)
