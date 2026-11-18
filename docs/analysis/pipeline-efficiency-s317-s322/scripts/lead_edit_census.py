# Census of the lead's Edit and Write tool_use blocks in graph's s322 window, by top-level directory and by path.
# Reads ~/.claude/projects/-Users-n8-git-graph/*.jsonl (top-level lead transcripts), read only.
# WINDOW (s322 only, no s323 file is opened): a file is opened only if it was created at or before E
# (st_birthtime; a later file holds only later records) and last modified at or after S (an older file holds no
# s322 record). A read stops at the first record stamped after E, so a file appended after E is read up to E.
# The first output line prints the file counts with and without the window (the control).
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
c=collections.Counter();n=0;tot=0
ex=collections.Counter()
for f in files:
    for l in open(f,errors='replace'):
        mt=_TS.search(l)
        if mt and mt.group(1)>E: break
        if '"tool_use"' not in l: continue
        try:r=json.loads(l)
        except Exception:continue
        ts=r.get('timestamp','')
        if not(S<=ts<=E): continue
        m=r.get('message') or {}
        if m.get('role')!='assistant' or not isinstance(m.get('content'),list): continue
        for b in m['content']:
            if b.get('type')!='tool_use':continue
            tot+=1
            if b.get('name') in('Edit','Write'):
                p=b['input'].get('file_path','')
                p=re.sub(r'.*/git/graph[^/]*/','',p)
                fam=p.split('/')[0] if '/' in p else p
                c[(b['name'],fam)]+=1;n+=1
                ex[p]+=1
print('files',len(files),'tool_use',tot,'edit/write',n)
for k,v in c.most_common(25):print(v,k)
print('--top paths')
for k,v in ex.most_common(30):print(v,k)
